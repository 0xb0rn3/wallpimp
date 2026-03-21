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

// ── Socket path ───────────────────────────────────────────────────────────────

func socketPath() string {
	if runtime.GOOS == "windows" {
		return filepath.Join(os.TempDir(), "wallpimp-engine.sock")
	}
	uid := os.Getuid()
	return fmt.Sprintf("/tmp/wallpimp-%d.sock", uid)
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
		case "scan":
			total := 0
			for _, spec := range builtinRepos {
				b := resolveBranch(spec.Owner, spec.Repo, spec.BranchHint)
				if b != "" {
					total += CountRepoImages(spec.Owner, spec.Repo, b, spec.Subdir)
				}
			}
			topics, err := sess.cli.Topics()
			unspTotal := 1500
			if err == nil {
				unspTotal = 0
				for _, t := range topics {
					unspTotal += t.Total
				}
			}
			total += unspTotal
			emit(Event{Event: "scan_result", Total: total})

		// ── download (full or targeted) ────────────────────────────────────────
		case "download":
			workers := sess.workers
			if cmd.Workers > 0 {
				workers = cmd.Workers
			}
			wdir := cmd.Wdir
			cap := cmd.Target // 0 = unlimited
			var totalNew, totalDupe, totalErr int64

			prog := mkProg(&totalNew, &totalDupe, &totalErr)

			// GitHub repos
			for _, spec := range builtinRepos {
				if cap > 0 && totalNew >= int64(cap) {
					break
				}
				stopAt := 0
				if cap > 0 {
					stopAt = cap - int(totalNew)
				}
				stats := DownloadRepo(spec, wdir, workers, sess.db,
					func(n, d, e int) {
						if stopAt > 0 && int(totalNew) >= stopAt {
							return
						}
						prog(n, d, e)
					})
				_ = stats
			}

			// Unsplash topics fill-up
			if cap == 0 || totalNew < int64(cap) {
				topics, err := sess.cli.Topics()
				if err == nil {
					for _, t := range topics {
						if cap > 0 && totalNew >= int64(cap) {
							break
						}
						page := 1
						for {
							if cap > 0 && totalNew >= int64(cap) {
								break
							}
							photos, err := sess.cli.TopicPhotos(t.Slug, page)
							if err != nil || len(photos) == 0 {
								break
							}
							dest := filepath.Join(wdir, "unsplash", "topics", t.Slug)
							DownloadPhotos(photos, dest, workers, sess.db, prog)
							page++
						}
					}
				}
			}

			// Random fill
			for cap > 0 && totalNew < int64(cap) {
				need := int(int64(cap) - totalNew)
				if need > 30 {
					need = 30
				}
				photos, err := sess.cli.Random(need)
				if err != nil || len(photos) == 0 {
					break
				}
				dest := filepath.Join(wdir, "unsplash", "random")
				s := DownloadPhotos(photos, dest, workers, sess.db, prog)
				if s.New == 0 {
					break
				}
			}

			_ = sess.db.save()
			emit(Event{
				Event: "done",
				New:   totalNew, Dupes: totalDupe, Errors: totalErr,
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

	ln, err := net.Listen("unix", sockPath)
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
