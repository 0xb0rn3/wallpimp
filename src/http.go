package main

import (
	"fmt"
	"net"
	"net/http"
	"strconv"
	"time"
)

// sharedTransport is used by every HTTP caller in the engine.
// Tuned for high-concurrency bulk downloads:
//   - HTTP/2 enabled (multiplexed streams over one TCP connection)
//   - 32 idle connections per host (GitHub CDN, Unsplash, etc.)
//   - 15s dial timeout, 30s keep-alive so long downloads don't stall
var sharedTransport = &http.Transport{
	Proxy: http.ProxyFromEnvironment,
	DialContext: (&net.Dialer{
		Timeout:   15 * time.Second,
		KeepAlive: 30 * time.Second,
	}).DialContext,
	MaxIdleConns:          300,
	MaxIdleConnsPerHost:   32,
	MaxConnsPerHost:       0, // unlimited per-host — semaphores in callers control this
	IdleConnTimeout:       90 * time.Second,
	TLSHandshakeTimeout:   10 * time.Second,
	ExpectContinueTimeout: 1 * time.Second,
	ForceAttemptHTTP2:     true,
}

// SharedClient is the single HTTP client used everywhere.
// Timeout is 0 (no global timeout) because large archive downloads
// can take minutes — individual operations set their own deadlines.
var SharedClient = &http.Client{
	Transport: sharedTransport,
}

// userAgent is sent with every request to avoid anonymous bot throttling.
const userAgent = "WallPimp/2.0 (github.com/0xb0rn3/wallpimp)"

// newReq builds a GET request with the shared User-Agent header.
func newReq(url string) (*http.Request, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	return req, nil
}

// headReq fires a HEAD request and returns the status code (0 on error).
func headReq(url string) int {
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		return 0
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := SharedClient.Do(req)
	if err != nil {
		return 0
	}
	resp.Body.Close()
	return resp.StatusCode
}

// fetchWithRetry performs a GET with up to maxRetries retries.
// It respects Retry-After headers on 429/503 responses and uses
// exponential backoff (1s, 2s, 4s) for other transient errors.
func fetchWithRetry(url string, maxRetries int) (*http.Response, error) {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			backoff := time.Duration(1<<uint(attempt-1)) * time.Second
			time.Sleep(backoff)
		}
		req, err := newReq(url)
		if err != nil {
			return nil, err
		}
		resp, err := SharedClient.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		switch resp.StatusCode {
		case 200:
			return resp, nil
		case 429, 503:
			resp.Body.Close()
			wait := time.Duration(1<<uint(attempt)) * time.Second
			if ra := resp.Header.Get("Retry-After"); ra != "" {
				if secs, err2 := strconv.Atoi(ra); err2 == nil && secs > 0 {
					wait = time.Duration(secs) * time.Second
				}
			}
			time.Sleep(wait)
			lastErr = fmt.Errorf("HTTP %d (rate limited)", resp.StatusCode)
		case 404:
			resp.Body.Close()
			return nil, fmt.Errorf("HTTP 404: %s", url)
		default:
			resp.Body.Close()
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)
		}
	}
	return nil, lastErr
}
