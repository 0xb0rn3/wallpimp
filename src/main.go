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
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
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
	Event    string      `json:"event"`
	New      int64       `json:"new,omitempty"`
	Dupes    int64       `json:"dupes,omitempty"`
	Errors   int64       `json:"errors,omitempty"`
	Total    int         `json:"total,omitempty"`
	Wait     int         `json:"wait,omitempty"`
	Msg      string      `json:"msg,omitempty"`
	Topics   interface{} `json:"topics,omitempty"`
	Cols     interface{} `json:"cols,omitempty"`
	ResW     int         `json:"res_w,omitempty"`
	ResH     int         `json:"res_h,omitempty"`
	DlW      int         `json:"dl_w,omitempty"`
	DlH      int         `json:"dl_h,omitempty"`
}

// ── Socket path + network ─────────────────────────────────────────────────────

func socketPath() string {
	if runtime.GOOS == "windows" {
		// AF_UNIX on Windows requires path inside a short temp dir
		return filepath.Join(os.TempDir(), "wallpimp-engine.sock")
	}
	// Use uid in path so multiple users on the same machine don't collide
	return fmt.Sprintf("/tmp/wallpimp-%d.sock", os.Getuid())
}

// listenNetwork returns the correct network string for net.Listen.
// AF_UNIX is "unix" everywhere — Windows 10 1803+ supports it natively.
func listenNetwork() string {
	return "unix"
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

// ── Session state ─────────────────────────────────────────────────────────────

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

	emit := func(ev Event) {
		_ = enc.Encode(ev)
	}

	// progress callback factory — emits incremental progress over the socket
	mkProg := func(accumNew, accumDupe, accumErr *int64) progressFn {
		var mu sync.Mutex
		return func(n, d, e int) {
			mu.Lock()
			defer mu.Unlock()
			*accumNew += int64(n)
			*accumDupe += int64(d)
			*accumErr += int64(e)
			emit(Event{
				Event:  "progress",
				New:    *accumNew,
				Dupes:  *accumDupe,
				Errors: *accumErr,
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
			dlW, _ := fmt.Sscanf(p["w"], "%d")
			dlH, _ := fmt.Sscanf(p["h"], "%d")
			_ = dlW; _ = dlH
			emit(Event{
				Event: "resolution",
				ResW:  res.W, ResH: res.H,
				DlW: res.W, DlH: res.H,
			})

		// ── scan ──────────────────────────────────────────────────────────────
		// All branch resolution + image counting runs in parallel goroutines.
		case "scan":
			var repoTotal, unspTotal int64
			var scanWg sync.WaitGroup

			// Repo count: resolve + count all repos concurrently
			scanWg.Add(1)
			go func() {
				defer scanWg.Done()
				n := CountAllRepos(builtinRepos)
				atomic.StoreInt64(&repoTotal, int64(n))
			}()

			// Unsplash count: single API call
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

		// ── download (full or targeted) ────────────────────────────────────────
		//
		// Pipeline:
		//   Phase 1 — resolve all 19 branches simultaneously (goroutine per repo)
		//   Phase 2 — download all repo archives concurrently (5 at a time)
		//   Phase 3 — stream Unsplash topics concurrently with remaining quota
		//
		case "download":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			wdir  := cmd.Wdir
			capN  := int64(cmd.Target) // 0 = unlimited
			var capPtr *int64
			if capN > 0 {
				capPtr = &capN
			}
			var totalNew, totalDupe, totalErr int64
			prog := mkProg(&totalNew, &totalDupe, &totalErr)

			// Phase 1+2: resolve all branches in parallel, then download concurrently
			emit(Event{Event: "progress", New: 0, Dupes: 0, Errors: 0, Msg: "resolving"})
			resolved := ResolveAllBranches(builtinRepos)
			DownloadAllRepos(resolved, wdir, workers, 5, sess.db, prog, capPtr)

			// Phase 3: Unsplash topics
			if capPtr == nil || atomic.LoadInt64(capPtr) > 0 {
				topics, err := sess.cli.Topics()
				if err == nil {
					for _, t := range topics {
						if capPtr != nil && atomic.LoadInt64(capPtr) <= 0 {
							break
						}
						page := 1
						for {
							if capPtr != nil && atomic.LoadInt64(capPtr) <= 0 {
								break
							}
							photos, err := sess.cli.TopicPhotos(t.Slug, page)
							if err != nil || len(photos) == 0 {
								break
							}
							dest := wdir // flat: all images in one directory
							stopAt := int64(0)
							if capPtr != nil {
								stopAt = atomic.LoadInt64(capPtr)
							}
							_ = stopAt
							DownloadPhotos(photos, dest, workers, sess.db, prog)
							page++
						}
					}
				}
			}

			// Random fill to hit exact target
			for capPtr != nil && atomic.LoadInt64(capPtr) > 0 {
				need := int(atomic.LoadInt64(capPtr))
				if need > 30 {
					need = 30
				}
				photos, err := sess.cli.Random(need)
				if err != nil || len(photos) == 0 {
					break
				}
				dest := wdir // flat: all images in one directory
				s := DownloadPhotos(photos, dest, workers, sess.db, prog)
				if s.New == 0 {
					break
				}
			}

			_ = sess.db.save()
			emit(Event{
				Event: "done",
				New: totalNew, Dupes: totalDupe, Errors: totalErr,
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
			prog := mkProg(&n, &d, &e)
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
			prog := mkProg(&n, &d, &e)
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
			prog := mkProg(&n, &d, &e)
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
			prog := mkProg(&sn, &sd, &se)
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

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: wallpimp-engine <hash_db_path> <workers>")
		os.Exit(1)
	}
	hashPath := os.Args[1]
	workers := 8
	fmt.Sscanf(os.Args[2], "%d", &workers)

	sockPath := socketPath()
	// Clean up stale socket
	_ = os.Remove(sockPath)

	ln, err := net.Listen(listenNetwork(), sockPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "listen error:", err)
		os.Exit(1)
	}
	defer ln.Close()
	defer os.Remove(sockPath)

	// Write socket path to stdout so Python knows where to connect
	fmt.Println(sockPath)
	os.Stdout.Sync()

	// Graceful shutdown on signal
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigs
		ln.Close()
	}()

	sess := newSession(hashPath, workers)

	// One connection at a time — Python holds a single persistent connection
	for {
		conn, err := ln.Accept()
		if err != nil {
			break
		}
		// Each connection runs a full command loop (not goroutined —
		// Python is single-threaded on the menu side)
		handleConn(conn, sess)
	}
}
