package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
)

var imgExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true,
	".webp": true, ".gif": true, ".bmp": true, ".tiff": true,
}

func isImage(name string) bool {
	return imgExts[strings.ToLower(filepath.Ext(name))]
}

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

// ResolvedRepo pairs a spec with its resolved branch.
type ResolvedRepo struct {
	Spec   RepoSpec
	Branch string // empty = unreachable
}

// ResolveAllBranches fires one goroutine per repo — all HEAD requests run
// simultaneously instead of sequentially.
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

// DownloadAllRepos downloads all resolved repos concurrently.
// repoConcurrency: simultaneous archive downloads (5 is a safe default).
// imgWorkers: goroutines per archive for image extraction.
func DownloadAllRepos(resolved []ResolvedRepo, wdir string,
	imgWorkers, repoConcurrency int,
	db *HashDB, prog progressFn, capRemaining *int64) {

	if repoConcurrency <= 0 {
		repoConcurrency = 5
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

// DownloadRepo resolves branch then downloads (use DownloadRepoBranch if
// branch is already known to avoid a redundant HEAD request).
func DownloadRepo(spec RepoSpec, wdir string, workers int,
	db *HashDB, prog progressFn) DownloadStats {

	branch := resolveBranch(spec.Owner, spec.Repo, spec.BranchHint)
	if branch == "" {
		return DownloadStats{Errors: 1}
	}
	return DownloadRepoBranch(spec, branch, wdir, workers, db, prog, nil)
}

// DownloadRepoBranch downloads one repo given an already-resolved branch.
// capRemaining is decremented atomically; nil means unlimited.
func DownloadRepoBranch(spec RepoSpec, branch, wdir string,
	workers int, db *HashDB, prog progressFn,
	capRemaining *int64) DownloadStats {

	archiveURL := fmt.Sprintf(
		"https://github.com/%s/%s/archive/%s.zip",
		spec.Owner, spec.Repo, branch,
	)
	destDir := filepath.Join(wdir, spec.Slug)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return DownloadStats{Errors: 1}
	}

	data, err := fetchBytes(archiveURL)
	if err != nil {
		return cloneFallback(spec, branch, destDir, db, prog, capRemaining)
	}
	return extractZip(data, spec.Repo, branch, spec.Subdir,
		destDir, workers, db, prog, capRemaining)
}

// CountRepoImages uses the GitHub tree API to count images without downloading.
func CountRepoImages(owner, repo, branch, subdir string) int {
	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
		owner, repo, branch,
	)
	resp, err := http.Get(url) //nolint:noctx
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
		idx := bytes.Index(body[pos:], needle)
		if idx < 0 {
			break
		}
		pos += idx + len(needle)
		end := bytes.IndexByte(body[pos:], '"')
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

// CountAllRepos resolves branches and counts images for all repos in parallel.
func CountAllRepos(specs []RepoSpec) int {
	resolved := ResolveAllBranches(specs)
	var total int64
	var wg sync.WaitGroup
	for _, r := range resolved {
		if r.Branch == "" {
			continue
		}
		wg.Add(1)
		go func(rr ResolvedRepo) {
			defer wg.Done()
			n := CountRepoImages(rr.Spec.Owner, rr.Spec.Repo, rr.Branch, rr.Spec.Subdir)
			atomic.AddInt64(&total, int64(n))
		}(r)
	}
	wg.Wait()
	return int(total)
}

// ── internal helpers ──────────────────────────────────────────────────────────

func resolveBranch(owner, repo, hint string) string {
	candidates := []string{}
	if hint != "" {
		candidates = append(candidates, hint)
	}
	candidates = append(candidates, "main", "master")
	seen := map[string]bool{}
	for _, b := range candidates {
		if seen[b] {
			continue
		}
		seen[b] = true
		url := fmt.Sprintf(
			"https://github.com/%s/%s/archive/%s.zip", owner, repo, b)
		resp, err := http.Head(url) //nolint:noctx
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			return b
		}
		if resp != nil {
			resp.Body.Close()
		}
	}
	return ""
}

func fetchBytes(url string) ([]byte, error) {
	resp, err := http.Get(url) //nolint:noctx
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func extractZip(data []byte, repo, branch, subdir, destDir string,
	workers int, db *HashDB, prog progressFn,
	capRemaining *int64) DownloadStats {

	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return DownloadStats{Errors: 1}
	}

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
			outPath := filepath.Join(destDir, fname)
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

func cloneFallback(spec RepoSpec, branch, destDir string,
	db *HashDB, prog progressFn, capRemaining *int64) DownloadStats {

	var stats DownloadStats
	cloneDir := filepath.Join(destDir, "_clone")
	defer os.RemoveAll(cloneDir)

	cloneURL := fmt.Sprintf(
		"https://github.com/%s/%s.git", spec.Owner, spec.Repo)
	cmd := exec.Command("git", "clone", "--depth=1", cloneURL, cloneDir)
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
		dest := filepath.Join(destDir, filepath.Base(path))
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
