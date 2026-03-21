package main

import (
	"archive/zip"
	"crypto/tls"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ── Shared HTTP transport ─────────────────────────────────────────────────────
//
// One Transport for the whole process: keeps TLS sessions alive,
// reuses TCP connections across goroutines, enables HTTP/2.

var ghHTTP = &http.Client{
	Timeout: 120 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:          300,
		MaxIdleConnsPerHost:   30,
		MaxConnsPerHost:       30,
		IdleConnTimeout:       120 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 30 * time.Second,
		DisableCompression:    false,
		ForceAttemptHTTP2:     true,
		TLSClientConfig:       &tls.Config{InsecureSkipVerify: false},
	},
}

// Rotating User-Agents reduces the chance GitHub fingerprints us as a scraper.
var userAgents = []string{
	"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
	"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0",
	"Mozilla/5.0 (X11; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0",
}

func randomUA() string {
	return userAgents[rand.Intn(len(userAgents))]
}

// ── Image extension filter ─────────────────────────────────────────────────────

var imgExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true,
	".webp": true, ".gif": true, ".bmp": true,
	".tiff": true, ".tif": true, ".heic": true,
	".heif": true, ".avif": true, ".jxl": true,
	".svg": true, ".ico": true, ".psd": true,
	".raw": true, ".arw": true, ".cr2": true,
	".nef": true, ".orf": true, ".dng": true,
	".exr": true, ".hdr": true, ".rgbe": true,
	".pnm": true, ".ppm": true, ".pgm": true,
	".pbm": true, ".pcx": true, ".tga": true,
	".xbm": true, ".xpm": true, ".wbmp": true,
}

func isImage(name string) bool {
	return imgExts[strings.ToLower(filepath.Ext(name))]
}

// ── Core types ────────────────────────────────────────────────────────────────

type DownloadStats struct {
	New    int64
	Dupes  int64
	Errors int64
}

type RepoSpec struct {
	Slug       string
	Owner      string
	Repo       string
	BranchHint string
	Subdir     string
}

type progressFn func(new, dupe, errInc int)

type ResolvedRepo struct {
	Spec   RepoSpec
	Branch string // empty = unreachable
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

// doGET performs a GET with a rotating User-Agent.
func doGET(url string) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", randomUA())
	req.Header.Set("Accept-Encoding", "gzip, deflate, br")
	return ghHTTP.Do(req)
}

// doHEAD performs a HEAD with a rotating User-Agent.
func doHEAD(url string) (*http.Response, error) {
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", randomUA())
	return ghHTTP.Do(req)
}

// retryAfterSeconds reads the Retry-After header (seconds or HTTP-date).
func retryAfterSeconds(resp *http.Response) int {
	if resp == nil {
		return 0
	}
	v := resp.Header.Get("Retry-After")
	if v == "" {
		return 0
	}
	if n, err := strconv.Atoi(v); err == nil {
		return n
	}
	if t, err := http.ParseTime(v); err == nil {
		if d := time.Until(t); d > 0 {
			return int(d.Seconds()) + 1
		}
	}
	return 0
}

// fetchBytesRetry downloads url, retrying on 429/403/5xx with backoff + jitter.
// maxAttempts = 5 is a good default.
func fetchBytesRetry(url string, maxAttempts int) ([]byte, error) {
	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		if attempt > 0 {
			// base: 2^attempt seconds, jitter ±50%
			base := time.Duration(1<<uint(attempt)) * time.Second
			jitter := time.Duration(rand.Int63n(int64(base/2) + 1))
			time.Sleep(base + jitter)
		}

		resp, err := doGET(url)
		if err != nil {
			lastErr = err
			continue
		}

		switch {
		case resp.StatusCode == 200:
			data, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				lastErr = err
				continue
			}
			return data, nil

		case resp.StatusCode == 429 || resp.StatusCode == 403:
			// Respect Retry-After; fall back to 60s
			wait := retryAfterSeconds(resp)
			resp.Body.Close()
			if wait <= 0 {
				wait = 30 * (attempt + 1)
			}
			// Cap wait so we don't stall forever
			if wait > 120 {
				wait = 120
			}
			time.Sleep(time.Duration(wait) * time.Second)
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)

		case resp.StatusCode >= 500:
			resp.Body.Close()
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)

		default:
			resp.Body.Close()
			return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
		}
	}
	return nil, fmt.Errorf("after %d attempts: %w", maxAttempts, lastErr)
}

// fetchToTempFile streams a URL to a temp file and returns its path.
// Caller must os.Remove the file when done.
// Using a temp file instead of []byte avoids holding 15 × ~100MB in RAM
// when downloading many archives concurrently.
func fetchToTempFile(url string, maxAttempts int) (string, error) {
	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		if attempt > 0 {
			base := time.Duration(1<<uint(attempt)) * time.Second
			jitter := time.Duration(rand.Int63n(int64(base/2) + 1))
			time.Sleep(base + jitter)
		}

		resp, err := doGET(url)
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode == 429 || resp.StatusCode == 403 {
			wait := retryAfterSeconds(resp)
			resp.Body.Close()
			if wait <= 0 {
				wait = 30 * (attempt + 1)
			}
			if wait > 120 {
				wait = 120
			}
			time.Sleep(time.Duration(wait) * time.Second)
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)
			continue
		}
		if resp.StatusCode >= 500 {
			resp.Body.Close()
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)
			continue
		}
		if resp.StatusCode != 200 {
			resp.Body.Close()
			return "", fmt.Errorf("HTTP %d", resp.StatusCode)
		}

		f, err := os.CreateTemp("", "wallpimp-*.zip")
		if err != nil {
			resp.Body.Close()
			return "", err
		}
		_, err = io.Copy(f, resp.Body)
		resp.Body.Close()
		f.Close()
		if err != nil {
			os.Remove(f.Name())
			lastErr = err
			continue
		}
		return f.Name(), nil
	}
	return "", fmt.Errorf("after %d attempts: %w", maxAttempts, lastErr)
}

// ── Branch resolution ─────────────────────────────────────────────────────────
//
// All candidates (hint, main, master) are HEAD-checked simultaneously.
// First success by original priority order wins.

func resolveBranch(owner, repo, hint string) string {
	// Build ordered candidate list (deduplicated)
	seen := map[string]bool{}
	var candidates []string
	for _, b := range []string{hint, "main", "master"} {
		if b != "" && !seen[b] {
			seen[b] = true
			candidates = append(candidates, b)
		}
	}

	type result struct {
		branch string
		order  int
	}
	ch := make(chan result, len(candidates))

	for i, b := range candidates {
		go func(idx int, branch string) {
			url := fmt.Sprintf("https://github.com/%s/%s/archive/%s.zip", owner, repo, branch)
			resp, err := doHEAD(url)
			if resp != nil {
				resp.Body.Close()
			}
			if err == nil && resp.StatusCode == 200 {
				ch <- result{branch, idx}
			} else {
				ch <- result{"", idx}
			}
		}(i, b)
	}

	// Collect all, return first by original order
	out := make([]string, len(candidates))
	for range candidates {
		r := <-ch
		out[r.order] = r.branch
	}
	for _, b := range out {
		if b != "" {
			return b
		}
	}
	return ""
}

// ── Pipelined download ────────────────────────────────────────────────────────
//
// Key change vs original: branches are resolved one goroutine per repo, and
// each resolved repo is sent immediately to the download channel — downloads
// start as soon as the FIRST branch resolves, not after ALL 19 do.
//
// repoConcurrency controls how many archive downloads happen simultaneously.
// 16 is a safe default for a typical broadband connection.

func DownloadAllRepos(resolved []ResolvedRepo, wdir string,
	imgWorkers, repoConcurrency int,
	db *HashDB, prog progressFn, capRemaining *int64) {

	if repoConcurrency <= 0 {
		repoConcurrency = 16
	}
	sem := make(chan struct{}, repoConcurrency)
	var wg sync.WaitGroup

	for _, r := range resolved {
		if r.Branch == "" {
			continue
		}
		if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
			break
		}
		sem <- struct{}{}
		wg.Add(1)
		go func(rr ResolvedRepo) {
			defer wg.Done()
			defer func() { <-sem }()
			DownloadRepoBranch(rr.Spec, rr.Branch, wdir, imgWorkers, db, prog, capRemaining)
		}(r)
	}
	wg.Wait()
}

// ResolveAndDownload pipelines resolution + download: a repo's download starts
// the moment its branch resolves, with no waiting for the rest.
// This replaces the two-step ResolveAllBranches → DownloadAllRepos pattern.
func ResolveAndDownload(specs []RepoSpec, wdir string,
	imgWorkers, repoConcurrency int,
	db *HashDB, prog progressFn, capRemaining *int64) {

	if repoConcurrency <= 0 {
		repoConcurrency = 16
	}

	// Resolved repos flow through this channel as branches are discovered.
	resolvedCh := make(chan ResolvedRepo, len(specs))

	// Phase 1: fire one resolver goroutine per repo — all run simultaneously.
	var resolveWg sync.WaitGroup
	for _, spec := range specs {
		resolveWg.Add(1)
		go func(s RepoSpec) {
			defer resolveWg.Done()
			branch := resolveBranch(s.Owner, s.Repo, s.BranchHint)
			resolvedCh <- ResolvedRepo{Spec: s, Branch: branch}
		}(spec)
	}
	// Close channel once all resolvers finish.
	go func() {
		resolveWg.Wait()
		close(resolvedCh)
	}()

	// Phase 2: consume resolved repos and start downloads immediately,
	// bounded by repoConcurrency semaphore.
	sem := make(chan struct{}, repoConcurrency)
	var dlWg sync.WaitGroup

	for rr := range resolvedCh {
		if rr.Branch == "" {
			continue
		}
		if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
			// Drain remaining channel entries so the closer goroutine unblocks.
			go func() {
				for range resolvedCh {
				}
			}()
			break
		}
		sem <- struct{}{}
		dlWg.Add(1)
		go func(r ResolvedRepo) {
			defer dlWg.Done()
			defer func() { <-sem }()
			DownloadRepoBranch(r.Spec, r.Branch, wdir, imgWorkers, db, prog, capRemaining)
		}(rr)
	}
	dlWg.Wait()
}

// ResolveAllBranches kept for compatibility (scan command uses it).
func ResolveAllBranches(specs []RepoSpec) []ResolvedRepo {
	results := make([]ResolvedRepo, len(specs))
	var wg sync.WaitGroup
	for i, spec := range specs {
		wg.Add(1)
		go func(idx int, s RepoSpec) {
			defer wg.Done()
			results[idx] = ResolvedRepo{
				Spec:   s,
				Branch: resolveBranch(s.Owner, s.Repo, s.BranchHint),
			}
		}(i, spec)
	}
	wg.Wait()
	return results
}

// ── Single repo download ───────────────────────────────────────────────────────

func DownloadRepo(spec RepoSpec, wdir string, workers int,
	db *HashDB, prog progressFn) DownloadStats {
	branch := resolveBranch(spec.Owner, spec.Repo, spec.BranchHint)
	if branch == "" {
		return DownloadStats{Errors: 1}
	}
	return DownloadRepoBranch(spec, branch, wdir, workers, db, prog, nil)
}

func DownloadRepoBranch(spec RepoSpec, branch, wdir string,
	workers int, db *HashDB, prog progressFn,
	capRemaining *int64) DownloadStats {

	archiveURL := fmt.Sprintf(
		"https://github.com/%s/%s/archive/%s.zip",
		spec.Owner, spec.Repo, branch,
	)
	if err := os.MkdirAll(wdir, 0755); err != nil {
		return DownloadStats{Errors: 1}
	}

	// Stream to temp file — avoids holding multiple 100MB+ archives in RAM.
	tmpPath, err := fetchToTempFile(archiveURL, 5)
	if err != nil {
		return cloneFallback(spec, branch, wdir, db, prog, capRemaining)
	}
	defer os.Remove(tmpPath)

	return extractZipFile(tmpPath, spec.Repo, branch, spec.Subdir,
		wdir, workers, db, prog, capRemaining)
}

// ── Repo counting (for scan) ──────────────────────────────────────────────────

func CountRepoImages(owner, repo, branch, subdir string) int {
	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
		owner, repo, branch,
	)
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", randomUA())
	resp, err := ghHTTP.Do(req)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	if resp.StatusCode == 403 || resp.StatusCode == 429 {
		return 0
	}
	body, _ := io.ReadAll(resp.Body)
	prefix := ""
	if subdir != "" {
		prefix = strings.ToLower(subdir) + "/"
	}
	count := 0
	needle := []byte(`"path":"`)
	pos := 0
	for {
		idx := indexBytes(body[pos:], needle)
		if idx < 0 {
			break
		}
		pos += idx + len(needle)
		end := indexByte(body[pos:], '"')
		if end < 0 {
			break
		}
		path := strings.ToLower(string(body[pos : pos+end]))
		pos += end + 1
		if isImage(path) && (prefix == "" || strings.HasPrefix(path, prefix)) {
			count++
		}
	}
	return count
}

// indexBytes / indexByte — avoid importing bytes just for these.
func indexBytes(s, sep []byte) int {
	n := len(sep)
	for i := 0; i <= len(s)-n; i++ {
		if string(s[i:i+n]) == string(sep) {
			return i
		}
	}
	return -1
}
func indexByte(s []byte, c byte) int {
	for i, b := range s {
		if b == c {
			return i
		}
	}
	return -1
}

func CountAllRepos(specs []RepoSpec) int {
	resolved := ResolveAllBranches(specs)
	var total int64
	// Throttle tree API calls — 60 req/hr unauthenticated.
	// 8 concurrent is safe (well under the limit for 19 repos).
	sem := make(chan struct{}, 8)
	var wg sync.WaitGroup
	for _, r := range resolved {
		if r.Branch == "" {
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(rr ResolvedRepo) {
			defer wg.Done()
			defer func() { <-sem }()
			n := CountRepoImages(rr.Spec.Owner, rr.Spec.Repo, rr.Branch, rr.Spec.Subdir)
			atomic.AddInt64(&total, int64(n))
		}(r)
	}
	wg.Wait()
	return int(total)
}

// ── Zip extraction ────────────────────────────────────────────────────────────

// flatSavePath returns a collision-safe output path.
func flatSavePath(dir, base, digest string) string {
	p := filepath.Join(dir, base)
	if _, err := os.Stat(p); os.IsNotExist(err) {
		return p
	}
	existing, err := os.ReadFile(p)
	if err == nil && md5hex(existing) == digest {
		return p
	}
	ext := filepath.Ext(base)
	stem := base[:len(base)-len(ext)]
	return filepath.Join(dir, stem+"_"+digest[:8]+ext)
}

// extractZipFile opens a zip from a temp file path and extracts images.
func extractZipFile(zipPath, repo, branch, subdir, destDir string,
	workers int, db *HashDB, prog progressFn,
	capRemaining *int64) DownloadStats {

	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return DownloadStats{Errors: 1}
	}
	defer zr.Close()

	zipPfx := strings.ToLower(repo + "-" + branch + "/")
	subPfx := ""
	if subdir != "" {
		subPfx = zipPfx + strings.ToLower(subdir) + "/"
	}

	var imgs []*zip.File
	for _, f := range zr.File {
		if f.FileInfo().IsDir() || !isImage(f.Name) {
			continue
		}
		nameLower := strings.ToLower(f.Name)
		if subPfx != "" && !strings.HasPrefix(nameLower, subPfx) {
			continue
		}
		imgs = append(imgs, f)
	}

	var stats DownloadStats
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup

	for _, zf := range imgs {
		if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
			break
		}
		sem <- struct{}{}
		wg.Add(1)
		go func(f *zip.File) {
			defer wg.Done()
			defer func() { <-sem }()

			if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
				return
			}

			rc, err := f.Open()
			if err != nil {
				atomic.AddInt64(&stats.Errors, 1)
				if prog != nil {
					prog(0, 0, 1)
				}
				return
			}
			imgData, err := io.ReadAll(rc)
			rc.Close()
			if err != nil {
				atomic.AddInt64(&stats.Errors, 1)
				if prog != nil {
					prog(0, 0, 1)
				}
				return
			}

			digest := md5hex(imgData)
			if db.has(digest) {
				atomic.AddInt64(&stats.Dupes, 1)
				if prog != nil {
					prog(0, 1, 0)
				}
				return
			}

			fname := filepath.Base(f.Name)
			outPath := flatSavePath(destDir, fname, digest)
			if err := os.WriteFile(outPath, imgData, 0644); err != nil {
				atomic.AddInt64(&stats.Errors, 1)
				if prog != nil {
					prog(0, 0, 1)
				}
				return
			}
			db.add(digest, outPath)
			atomic.AddInt64(&stats.New, 1)
			if capRemaining != nil {
				atomic.AddInt64(capRemaining, -1)
			}
			if prog != nil {
				prog(1, 0, 0)
			}
		}(zf)
	}
	wg.Wait()
	return stats
}

// ── Git clone fallback ────────────────────────────────────────────────────────

func cloneFallback(spec RepoSpec, branch, destDir string,
	db *HashDB, prog progressFn, capRemaining *int64) DownloadStats {

	var stats DownloadStats
	cloneDir := filepath.Join(os.TempDir(), fmt.Sprintf("wallpimp-clone-%s-%d", spec.Slug, os.Getpid()))
	defer os.RemoveAll(cloneDir)

	cloneURL := fmt.Sprintf("https://github.com/%s/%s.git", spec.Owner, spec.Repo)
	cmd := exec.Command("git", "clone", "--depth=1", "--single-branch",
		"--branch", branch, cloneURL, cloneDir)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		stats.Errors++
		return stats
	}

	_ = filepath.WalkDir(cloneDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !isImage(path) {
			return nil
		}
		if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
			return filepath.SkipAll
		}
		if spec.Subdir != "" {
			rel, _ := filepath.Rel(cloneDir, path)
			if !strings.HasPrefix(strings.ToLower(rel),
				strings.ToLower(spec.Subdir)+string(os.PathSeparator)) {
				return nil
			}
		}
		imgData, err := os.ReadFile(path)
		if err != nil {
			stats.Errors++
			return nil
		}
		digest := md5hex(imgData)
		if db.has(digest) {
			stats.Dupes++
			if prog != nil {
				prog(0, 1, 0)
			}
			return nil
		}
		dest := flatSavePath(destDir, filepath.Base(path), digest)
		if err := os.WriteFile(dest, imgData, 0644); err != nil {
			stats.Errors++
			return nil
		}
		db.add(digest, dest)
		stats.New++
		if capRemaining != nil {
			atomic.AddInt64(capRemaining, -1)
		}
		if prog != nil {
			prog(1, 0, 0)
		}
		return nil
	})
	return stats
}
