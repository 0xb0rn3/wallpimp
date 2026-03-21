package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sync"
	"sync/atomic"
	"time"
)

const pageSz = 30

// ── Rate limiter ──────────────────────────────────────────────────────────────

// RateLimiter is a sliding-window token bucket: max 45 calls per hour.
type RateLimiter struct {
	limit  int
	window time.Duration
	calls  []time.Time
	mu     sync.Mutex
}

func newRateLimiter() *RateLimiter {
	return &RateLimiter{
		limit:  45,
		window: time.Hour,
	}
}

// Wait blocks until the call is within the allowed rate. Returns wait duration.
func (rl *RateLimiter) Wait() time.Duration {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	// Expire old entries
	cutoff := now.Add(-rl.window)
	fresh := rl.calls[:0]
	for _, t := range rl.calls {
		if t.After(cutoff) {
			fresh = append(fresh, t)
		}
	}
	rl.calls = fresh

	if len(rl.calls) >= rl.limit {
		// Must wait until oldest call falls outside window
		waitUntil := rl.calls[0].Add(rl.window).Add(time.Second)
		wait := time.Until(waitUntil)
		if wait > 0 {
			rl.mu.Unlock()
			time.Sleep(wait)
			rl.mu.Lock()
			// Re-expire after sleep
			now = time.Now()
			cutoff = now.Add(-rl.window)
			fresh2 := rl.calls[:0]
			for _, t := range rl.calls {
				if t.After(cutoff) {
					fresh2 = append(fresh2, t)
				}
			}
			rl.calls = fresh2
			rl.mu.Unlock()
			return wait
		}
	}
	rl.calls = append(rl.calls, time.Now())
	return 0
}

// ── Unsplash client ───────────────────────────────────────────────────────────

type unsplashPhoto struct {
	ID   string `json:"id"`
	URLs struct {
		Raw string `json:"raw"`
	} `json:"urls"`
}

type unsplashTopic struct {
	Slug  string `json:"slug"`
	Title string `json:"title"`
	Total int    `json:"total_photos"`
}

type unsplashCollection struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Total int    `json:"total_photos"`
}

// PhotoMeta is the normalised form sent back to Python.
type PhotoMeta struct {
	ID  string
	URL string
}

type UnsplashClient struct {
	res Resolution
	rl  *RateLimiter
	hc  *http.Client
}

func NewUnsplashClient(res Resolution) *UnsplashClient {
	return &UnsplashClient{
		res: res,
		rl:  newRateLimiter(),
		hc:  &http.Client{Timeout: 20 * time.Second},
	}
}

func (c *UnsplashClient) get(endpoint string, params map[string]string) ([]byte, error) {
	_ = c.rl.Wait() // blocks if rate limit hit
	u, _ := url.Parse(apiEndpoint() + endpoint)
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("Authorization", "Client-ID "+accessKey())
	req.Header.Set("Accept-Version", "v1")

	resp, err := c.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func (c *UnsplashClient) imageURL(raw string) string {
	p := c.res.DownloadParams()
	return raw + "&w=" + p["w"] + "&h=" + p["h"] +
		"&fit=crop&fm=jpg&q=85"
}

func (c *UnsplashClient) normalize(photos []unsplashPhoto) []PhotoMeta {
	out := make([]PhotoMeta, 0, len(photos))
	for _, p := range photos {
		out = append(out, PhotoMeta{ID: p.ID, URL: c.imageURL(p.URLs.Raw)})
	}
	return out
}

func (c *UnsplashClient) Random(n int) ([]PhotoMeta, error) {
	if n > 30 {
		n = 30
	}
	body, err := c.get("/photos/random", map[string]string{
		"orientation": "landscape",
		"count":       fmt.Sprintf("%d", n),
	})
	if err != nil {
		return nil, err
	}
	// May be an array or single object
	var arr []unsplashPhoto
	if err := json.Unmarshal(body, &arr); err != nil {
		var single unsplashPhoto
		if err2 := json.Unmarshal(body, &single); err2 != nil {
			return nil, err2
		}
		arr = []unsplashPhoto{single}
	}
	return c.normalize(arr), nil
}

func (c *UnsplashClient) Search(query string, page int) ([]PhotoMeta, error) {
	body, err := c.get("/search/photos", map[string]string{
		"query":       query,
		"orientation": "landscape",
		"per_page":    fmt.Sprintf("%d", pageSz),
		"page":        fmt.Sprintf("%d", page),
	})
	if err != nil {
		return nil, err
	}
	var result struct {
		Results []unsplashPhoto `json:"results"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return c.normalize(result.Results), nil
}

func (c *UnsplashClient) Topics() ([]unsplashTopic, error) {
	body, err := c.get("/topics", map[string]string{
		"per_page": "20", "order_by": "featured",
	})
	if err != nil {
		return nil, err
	}
	var topics []unsplashTopic
	return topics, json.Unmarshal(body, &topics)
}

func (c *UnsplashClient) TopicPhotos(slug string, page int) ([]PhotoMeta, error) {
	body, err := c.get("/topics/"+slug+"/photos", map[string]string{
		"orientation": "landscape",
		"per_page":    fmt.Sprintf("%d", pageSz),
		"page":        fmt.Sprintf("%d", page),
	})
	if err != nil {
		return nil, err
	}
	var photos []unsplashPhoto
	return c.normalize(photos), json.Unmarshal(body, &photos)
}

func (c *UnsplashClient) Collections(page int) ([]unsplashCollection, error) {
	body, err := c.get("/collections", map[string]string{
		"per_page": "20",
		"page":     fmt.Sprintf("%d", page),
	})
	if err != nil {
		return nil, err
	}
	var cols []unsplashCollection
	return cols, json.Unmarshal(body, &cols)
}

func (c *UnsplashClient) CollectionPhotos(id string, page int) ([]PhotoMeta, error) {
	body, err := c.get("/collections/"+id+"/photos", map[string]string{
		"orientation": "landscape",
		"per_page":    fmt.Sprintf("%d", pageSz),
		"page":        fmt.Sprintf("%d", page),
	})
	if err != nil {
		return nil, err
	}
	var photos []unsplashPhoto
	return c.normalize(photos), json.Unmarshal(body, &photos)
}

// ── Image downloader ──────────────────────────────────────────────────────────

// DownloadPhotos downloads a slice of PhotoMeta into destDir concurrently.
func DownloadPhotos(photos []PhotoMeta, destDir string, workers int,
	db *HashDB, prog progressFn) DownloadStats {

	if err := os.MkdirAll(destDir, 0755); err != nil {
		return DownloadStats{Errors: int64(len(photos))}
	}

	var stats DownloadStats
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup
	hc := &http.Client{Timeout: 30 * time.Second}

	for _, photo := range photos {
		sem <- struct{}{}
		wg.Add(1)
		go func(p PhotoMeta) {
			defer wg.Done()
			defer func() { <-sem }()

			resp, err := hc.Get(p.URL)
			if err != nil {
				atomic.AddInt64(&stats.Errors, 1)
				if prog != nil {
					prog(0, 0, 1)
				}
				return
			}
			data, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				atomic.AddInt64(&stats.Errors, 1)
				if prog != nil {
					prog(0, 0, 1)
				}
				return
			}

			digest := md5hex(data)
			if db.has(digest) {
				atomic.AddInt64(&stats.Dupes, 1)
				if prog != nil {
					prog(0, 1, 0)
				}
				return
			}

			fname := "unsplash_" + p.ID + ".jpg"
			outPath := flatSavePath(destDir, fname, digest)
			if err := os.WriteFile(outPath, data, 0644); err != nil {
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
		}(photo)
	}
	wg.Wait()
	return stats
}
