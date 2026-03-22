package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

// ── Protocol types ─────────────────────────────────────────────────────────────

type Cmd struct {
	Cmd      string `json:"cmd"`
	Wdir     string `json:"wdir,omitempty"`
	HashPath string `json:"hash_path,omitempty"`
	Workers  int    `json:"workers,omitempty"`
	Target   int    `json:"target,omitempty"` // 0 = unlimited
	Query    string `json:"query,omitempty"`
	Page     int    `json:"page,omitempty"`
	Dest     string `json:"dest,omitempty"`
	Slug     string `json:"slug,omitempty"`
	ColID    string `json:"col_id,omitempty"`
	Count    int    `json:"count,omitempty"`
}

type Event struct {
	Event   string      `json:"event"`
	New     int64       `json:"new,omitempty"`
	Dupes   int64       `json:"dupes,omitempty"`
	Errors  int64       `json:"errors,omitempty"`
	Total   int         `json:"total,omitempty"`
	Wait    int         `json:"wait,omitempty"`
	Msg     string      `json:"msg,omitempty"`
	Topics  interface{} `json:"topics,omitempty"`
	Cols    interface{} `json:"cols,omitempty"`
	ResW    int         `json:"res_w,omitempty"`
	ResH    int         `json:"res_h,omitempty"`
	DlW     int         `json:"dl_w,omitempty"`
	DlH     int         `json:"dl_h,omitempty"`
	Speed   float64     `json:"speed,omitempty"` // files/sec
	Elapsed float64     `json:"elapsed,omitempty"` // seconds since download started
}

// ── Transport selection ───────────────────────────────────────────────────────
//
// Windows: use TCP loopback on a random port assigned by the OS.
//   - AF_UNIX requires Windows 10 build 17063+; older builds lack it entirely.
//   - TCP works on every Windows version without any prerequisite.
//   - The engine prints "tcp:<port>" to stdout; Python parses the prefix.
//
// Linux / macOS: Unix socket — lower overhead, no port allocation needed.

func listenAddr() (network, address string) {
	if runtime.GOOS == "windows" {
		return "tcp", "127.0.0.1:0" // OS picks a free port
	}
	return "unix", fmt.Sprintf("/tmp/wallpimp-%d.sock", os.Getuid())
}

// ── Built-in repo list ────────────────────────────────────────────────────────

var builtinRepos = []RepoSpec{
	{"dharmx-walls", "dharmx", "walls", "", ""},
	{"frenzyexists", "FrenzyExists", "wallpapers", "", ""},
	{"michaelscopic", "michaelScopic", "Wallpapers", "", ""},
	{"dreamer-paul-anime", "Dreamer-Paul", "Anime-Wallpaper", "", ""},
	{"pollux78-linuxnext", "pollux78", "linuxnext-wallpapers", "", ""},
	{"samyc2002-anime", "Samyc2002", "Anime-Wallpapers", "", ""},
	{"logicyugi-bgs", "logicyugi", "Backgrounds", "", ""},
	{"lukepeetoom-anime", "LukePeetoom", "anime_wallpapers", "", ""},
	{"k1ng440-walls", "k1ng440", "Wallpapers", "master", "wallpapers"},
	{"port19x-walls", "port19x", "Wallpapers", "", ""},
	{"lordofhunger-walls", "lordofhunger", "wallpapers", "master", "wallpapers"},
	{"rubens-shoji-walls", "rubens-shoji", "wallpapers", "", ""},
	{"hentaicoder-anime", "HENTAI-CODER", "Anime-Wallpaper", "main", "Wallpapers"},
	{"chrollokyber-ghibli", "ChrolloKyber", "ghibli-wallpapers", "", ""},
	{"icepocket-walls", "IcePocket", "Wallpapers", "", ""},
	{"expandpi-walls", "expandpi", "wallpapers", "", ""},
	{"kaikselhorst-walls", "KaikSelhorst", "wallpaper-pack", "", ""},
	{"ankitvashisht12-walls", "ankitvashisht12", "wallpapers", "", ""},
	{"erickmartin890-anime", "erickmartin890", "Anime-Wallpapers", "", ""},
}

// ── Session ───────────────────────────────────────────────────────────────────

type session struct {
	db      *HashDB
	cli     *UnsplashClient
	workers int
}

func newSession(hashPath string, workers int) *session {
	res := DetectResolution()
	return &session{
		db:      loadHashDB(hashPath),
		cli:     NewUnsplashClient(res),
		workers: workers,
	}
}

// ── Connection handler ────────────────────────────────────────────────────────

func handleConn(conn net.Conn, sess *session) {
	defer conn.Close()
	enc := json.NewEncoder(conn)
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 4*1024*1024), 4*1024*1024)

	emit := func(ev Event) { _ = enc.Encode(ev) }

	// Progress callback that also emits speed + elapsed.
	mkProg := func(accumNew, accumDupe, accumErr *int64, start time.Time) progressFn {
		var mu sync.Mutex
		return func(n, d, e int) {
			mu.Lock()
			defer mu.Unlock()
			*accumNew += int64(n)
			*accumDupe += int64(d)
			*accumErr += int64(e)
			elapsed := time.Since(start).Seconds()
			speed := 0.0
			if elapsed > 0 {
				speed = float64(*accumNew) / elapsed
			}
			emit(Event{
				Event:   "progress",
				New:     *accumNew,
				Dupes:   *accumDupe,
				Errors:  *accumErr,
				Speed:   speed,
				Elapsed: elapsed,
			})
		}
	}

	for scanner.Scan() {
		var cmd Cmd
		if err := json.Unmarshal(scanner.Bytes(), &cmd); err != nil {
			emit(Event{Event: "error", Msg: "bad json: " + err.Error()})
			continue
		}

		switch strings.ToLower(cmd.Cmd) {

		// ── ping ───────────────────────────────────────────────────────────────
		case "ping":
			emit(Event{Event: "pong"})

		// ── resolution ────────────────────────────────────────────────────────
		case "resolution":
			res := sess.cli.res
			p := res.DownloadParams()
			dlW, _ := strconv.Atoi(p["w"])
			dlH, _ := strconv.Atoi(p["h"])
			emit(Event{
				Event: "resolution",
				ResW:  res.W, ResH: res.H,
				DlW: dlW, DlH: dlH,
			})

		// ── scan ──────────────────────────────────────────────────────────────
		case "scan":
			var repoTotal, unspTotal int64
			var scanWg sync.WaitGroup

			scanWg.Add(1)
			go func() {
				defer scanWg.Done()
				atomic.StoreInt64(&repoTotal, int64(CountAllRepos(builtinRepos)))
			}()

			scanWg.Add(1)
			go func() {
				defer scanWg.Done()
				topics, err := sess.cli.Topics()
				if err == nil {
					var t int64
					for _, tp := range topics {
						t += int64(tp.Total)
					}
					atomic.StoreInt64(&unspTotal, t)
				} else {
					atomic.StoreInt64(&unspTotal, 1500)
				}
			}()

			scanWg.Wait()
			emit(Event{Event: "scan_result",
				Total: int(atomic.LoadInt64(&repoTotal) + atomic.LoadInt64(&unspTotal))})

		// ── download ──────────────────────────────────────────────────────────
		//
		// Pipeline:
		//   Phase 1 — resolve branches + start downloads immediately as each resolves
		//             (16 concurrent archive downloads, no waiting for all 19)
		//   Phase 2 — Unsplash topics: multiple topics pipelined concurrently
		//             (page N+1 fetch overlaps with page N image downloads)
		//   Phase 3 — random fill to hit exact target
		//
		case "download":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			wdir := cmd.Wdir
			capN := int64(cmd.Target)
			var capPtr *int64
			if capN > 0 {
				capPtr = &capN
			}
			var totalNew, totalDupe, totalErr int64
			start := time.Now()
			prog := mkProg(&totalNew, &totalDupe, &totalErr, start)

			// Phase 1: pipelined branch resolution + concurrent archive downloads
			emit(Event{Event: "progress", New: 0, Dupes: 0, Errors: 0, Msg: "resolving"})
			ResolveAndDownload(builtinRepos, wdir, workers, 16, sess.db, prog, capPtr)

			// Phase 2: Unsplash topics — concurrent with page-ahead pipelining
			if capPtr == nil || atomic.LoadInt64(capPtr) > 0 {
				topics, err := sess.cli.Topics()
				if err == nil {
					downloadTopicsConcurrent(topics, wdir, workers, sess.cli, sess.db, prog, capPtr)
				}
			}

			// Phase 3: random fill
			for capPtr != nil && atomic.LoadInt64(capPtr) > 0 {
				need := int(atomic.LoadInt64(capPtr))
				if need > 30 {
					need = 30
				}
				photos, err := sess.cli.Random(need)
				if err != nil || len(photos) == 0 {
					break
				}
				s := DownloadPhotos(photos, wdir, workers, sess.db, prog)
				if s.New == 0 {
					break
				}
			}

			_ = sess.db.save()
			emit(Event{
				Event:   "done",
				New:     totalNew,
				Dupes:   totalDupe,
				Errors:  totalErr,
				Elapsed: time.Since(start).Seconds(),
			})

		// ── unsplash: list topics ──────────────────────────────────────────────
		case "topics":
			topics, err := sess.cli.Topics()
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			emit(Event{Event: "topics", Topics: topics})

		// ── unsplash: topic photos ────────────────────────────────────────────
		case "topic_photos":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			photos, err := sess.cli.TopicPhotos(cmd.Slug, cmd.Page)
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			var n, d, e int64
			prog := mkProg(&n, &d, &e, time.Now())
			DownloadPhotos(photos, cmd.Dest, workers, sess.db, prog)
			_ = sess.db.save()
			emit(Event{Event: "done", New: n, Dupes: d, Errors: e})

		// ── unsplash: search ──────────────────────────────────────────────────
		case "search":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			photos, err := sess.cli.Search(cmd.Query, cmd.Page)
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			var n, d, e int64
			prog := mkProg(&n, &d, &e, time.Now())
			DownloadPhotos(photos, cmd.Dest, workers, sess.db, prog)
			_ = sess.db.save()
			emit(Event{Event: "done", New: n, Dupes: d, Errors: e})

		// ── unsplash: list collections ────────────────────────────────────────
		case "collections":
			cols, err := sess.cli.Collections(cmd.Page)
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			emit(Event{Event: "collections", Cols: cols})

		// ── unsplash: collection photos ───────────────────────────────────────
		case "col_photos":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			photos, err := sess.cli.CollectionPhotos(cmd.ColID, cmd.Page)
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			var n, d, e int64
			prog := mkProg(&n, &d, &e, time.Now())
			DownloadPhotos(photos, cmd.Dest, workers, sess.db, prog)
			_ = sess.db.save()
			emit(Event{Event: "done", New: n, Dupes: d, Errors: e})

		// ── unsplash: random ──────────────────────────────────────────────────
		case "random":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			n := cmd.Count
			if n <= 0 {
				n = 15
			}
			photos, err := sess.cli.Random(n)
			if err != nil {
				emit(Event{Event: "error", Msg: err.Error()})
				continue
			}
			var sn, sd, se int64
			prog := mkProg(&sn, &sd, &se, time.Now())
			DownloadPhotos(photos, cmd.Dest, workers, sess.db, prog)
			_ = sess.db.save()
			emit(Event{Event: "done", New: sn, Dupes: sd, Errors: se})

		// ── shutdown ──────────────────────────────────────────────────────────
		case "shutdown":
			emit(Event{Event: "bye"})
			return

		default:
			emit(Event{Event: "error", Msg: "unknown command: " + cmd.Cmd})
		}
	}
}

// ── Concurrent Unsplash topic downloader ──────────────────────────────────────
//
// Runs up to 4 topics concurrently. Within each topic, a page-ahead goroutine
// fetches the next page from the API while the current page's images download —
// API rate limiter serialises the fetches but downloads overlap.

func downloadTopicsConcurrent(
	topics []unsplashTopic,
	wdir string,
	workers int,
	cli *UnsplashClient,
	db *HashDB,
	prog progressFn,
	capRemaining *int64,
) {
	const topicConcurrency = 4
	sem := make(chan struct{}, topicConcurrency)
	var wg sync.WaitGroup

	for _, t := range topics {
		if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
			break
		}
		sem <- struct{}{}
		wg.Add(1)
		go func(topic unsplashTopic) {
			defer wg.Done()
			defer func() { <-sem }()

			// Page-ahead pipeline: fetcher goroutine sends pages into a buffered
			// channel; downloader goroutine consumes and downloads images.
			// The rate limiter in cli.TopicPhotos naturally throttles the fetcher.
			pageCh := make(chan []PhotoMeta, 2)

			go func() {
				defer close(pageCh)
				for page := 1; ; page++ {
					if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
						return
					}
					photos, err := cli.TopicPhotos(topic.Slug, page)
					if err != nil || len(photos) == 0 {
						return
					}
					pageCh <- photos
				}
			}()

			for photos := range pageCh {
				if capRemaining != nil && atomic.LoadInt64(capRemaining) <= 0 {
					break
				}
				DownloadPhotos(photos, wdir, workers, db, prog)
			}
		}(t)
	}
	wg.Wait()
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: wallpimp-engine <hash_db_path> <workers>")
		os.Exit(1)
	}
	hashPath := os.Args[1]
	workers := 16 // bumped from 8
	fmt.Sscanf(os.Args[2], "%d", &workers)

	network, addr := listenAddr()

	// Clean up stale Unix socket if present.
	if network == "unix" {
		_ = os.Remove(addr)
	}

	ln, err := net.Listen(network, addr)
	if err != nil {
		fmt.Fprintln(os.Stderr, "listen error:", err)
		os.Exit(1)
	}
	defer ln.Close()
	if network == "unix" {
		defer os.Remove(addr)
	}

	// Tell Python how to connect.
	// Unix: print the socket path as-is.
	// TCP:  print "tcp:<port>" so Python knows to use TCP.
	if network == "tcp" {
		port := ln.Addr().(*net.TCPAddr).Port
		fmt.Printf("tcp:%d\n", port)
	} else {
		fmt.Println(addr)
	}
	os.Stdout.Sync()

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigs
		ln.Close()
	}()

	sess := newSession(hashPath, workers)

	for {
		conn, err := ln.Accept()
		if err != nil {
			break
		}
		handleConn(conn, sess)
	}
}
