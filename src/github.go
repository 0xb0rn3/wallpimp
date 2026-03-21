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
	ext := strings.ToLower(filepath.Ext(name))
	return imgExts[ext]
}

// DownloadStats holds counters updated atomically during a download.
type DownloadStats struct {
	New    int64
	Dupes  int64
	Errors int64
}

// RepoSpec describes one source repository.
type RepoSpec struct {
	Slug        string
	Owner       string
	Repo        string
	BranchHint  string // try first; "" = auto
	Subdir      string // only extract files under this path; "" = all
}

// progressFn is called after each image is processed (new or dupe).
type progressFn func(new, dupe, errInc int)

// DownloadRepo downloads one GitHub repository into wdir/<slug>/.
func DownloadRepo(spec RepoSpec, wdir string, workers int,
	db *HashDB, prog progressFn) DownloadStats {

	branch := resolveBranch(spec.Owner, spec.Repo, spec.BranchHint)
	if branch == "" {
		if prog != nil {
			prog(0, 0, 1)
		}
		return DownloadStats{Errors: 1}
	}

	destDir := filepath.Join(wdir, spec.Slug)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return DownloadStats{Errors: 1}
	}

	archiveURL := fmt.Sprintf(
		"https://github.com/%s/%s/archive/%s.zip",
		spec.Owner, spec.Repo, branch,
	)

	data, err := fetchBytes(archiveURL)
	if err != nil {
		// Fallback: git clone
		return cloneFallback(spec, branch, destDir, db, prog)
	}

	return extractZip(data, spec.Repo, branch, spec.Subdir,
		destDir, workers, db, prog)
}

// CountRepoImages uses the GitHub tree API to count images without downloading.
func CountRepoImages(owner, repo, branch, subdir string) int {
	url := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1",
		owner, repo, branch,
	)
	resp, err := http.Get(url) //nolint:noctx
	if err != nil || resp.StatusCode == 403 || resp.StatusCode == 429 {
		return 0
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	// Simple JSON scan — avoids importing encoding/json for a hot path
	prefix := ""
	if subdir != "" {
		prefix = strings.ToLower(subdir) + "/"
	}
	count := 0
	// Match "path":"<value>" entries
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
	workers int, db *HashDB, prog progressFn) DownloadStats {

	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return DownloadStats{Errors: 1}
	}

	// Prefix inside the zip: "<repo>-<branch>/"
	zipPfx := strings.ToLower(repo + "-" + branch + "/")
	subPfx := ""
	if subdir != "" {
		subPfx = zipPfx + strings.ToLower(subdir) + "/"
	}

	// Collect matching files
	var imgs []*zip.File
	for _, f := range zr.File {
		nameLower := strings.ToLower(f.Name)
		if f.FileInfo().IsDir() {
			continue
		}
		if !isImage(f.Name) {
			continue
		}
		if subPfx != "" && !strings.HasPrefix(nameLower, subPfx) {
			continue
		}
		imgs = append(imgs, f)
	}

	var stats DownloadStats
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup

	for _, zf := range imgs {
		sem <- struct{}{}
		wg.Add(1)
		go func(f *zip.File) {
			defer wg.Done()
			defer func() { <-sem }()

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
			if prog != nil {
				prog(1, 0, 0)
			}
		}(zf)
	}
	wg.Wait()
	return stats
}

func cloneFallback(spec RepoSpec, branch, destDir string,
	db *HashDB, prog progressFn) DownloadStats {

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
		if prog != nil {
			prog(1, 0, 0)
		}
		return nil
	})
	return stats
}
