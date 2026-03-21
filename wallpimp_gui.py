#!/usr/bin/env python3
"""
WallPimp GUI — by 0xb0rn3 | github.com/0xb0rn3/wallpimp
Tkinter front-end that communicates with wallpimp-engine over a Unix socket.
"""

import json
import os
import platform
import queue
import shutil
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


# ── Palette ────────────────────────────────────────────────────────────────────
BG       = "#080c10"
PANEL    = "#0d1117"
CARD     = "#161b22"
BORDER   = "#21262d"
BORDER2  = "#30363d"
ACCENT   = "#00d4aa"        # teal — matches kitty/terminal aesthetic
ACCENT2  = "#1f6feb"        # blue for secondary actions
TEXT     = "#e6edf3"
MUTED    = "#7d8590"
DIM      = "#484f58"
SUCCESS  = "#3fb950"
WARN     = "#d29922"
ERR      = "#f85149"
BTN      = "#21262d"
BTN_H    = "#30363d"
PINK     = "#ff7b72"

MONO     = "Courier"        # universal fallback; looks good enough everywhere
MONO_SZ  = 10
HEAD_SZ  = 13


# ── Platform helpers ───────────────────────────────────────────────────────────
OS = platform.system()   # "Linux" | "Darwin" | "Windows"

def config_dir() -> Path:
    if OS == "Windows":
        return Path(os.environ.get("APPDATA", Path.home())) / "wallpimp"
    if OS == "Darwin":
        return Path.home() / "Library" / "Application Support" / "wallpimp"
    return Path.home() / ".config" / "wallpimp"

def default_wallpaper_dir() -> Path:
    return Path.home() / "Pictures" / "Wallpapers"

def find_engine() -> Path | None:
    name = "wallpimp-engine.exe" if OS == "Windows" else "wallpimp-engine"
    here = Path(__file__).parent / name
    if here.exists():
        return here
    found = shutil.which(name)
    return Path(found) if found else None


# ── Engine client ──────────────────────────────────────────────────────────────
class EngineClient:
    """Starts wallpimp-engine and holds a persistent Unix-socket connection."""

    def __init__(self, hash_path: Path, workers: int = 8):
        self.hash_path = hash_path
        self.workers   = workers
        self._proc: subprocess.Popen | None  = None
        self._sock: socket.socket | None     = None
        self._sockf                          = None
        self._lock                           = threading.Lock()

    # -- lifecycle -------------------------------------------------------------
    def start(self) -> str | None:
        """Spawn engine, connect to its socket. Returns error string or None."""
        eng = find_engine()
        if not eng:
            return (
                "wallpimp-engine binary not found.\n"
                "Build it:  cd src && go build -o ../wallpimp-engine .\n"
                "Then place it next to wallpimp_gui.py or on your PATH."
            )
        self.hash_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._proc = subprocess.Popen(
                [str(eng), str(self.hash_path), str(self.workers)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            sock_path = self._proc.stdout.readline().strip()
            if not sock_path:
                return "Engine did not emit socket path — check stderr."
            # retry loop: engine needs a moment to bind()
            for _ in range(40):
                try:
                    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    s.connect(sock_path)
                    self._sock  = s
                    self._sockf = s.makefile("r")
                    return None
                except (ConnectionRefusedError, FileNotFoundError):
                    time.sleep(0.05)
            return f"Timed out connecting to engine socket: {sock_path}"
        except Exception as e:
            return str(e)

    def stop(self):
        try: self.send({"cmd": "shutdown"})
        except Exception: pass
        for obj in (self._sock, self._proc):
            try:
                if obj: (obj.close() if hasattr(obj, "close") else obj.terminate())
            except Exception: pass

    # -- I/O -------------------------------------------------------------------
    def send(self, cmd: dict):
        with self._lock:
            if self._sock:
                self._sock.sendall((json.dumps(cmd) + "\n").encode())

    def recv(self) -> dict | None:
        try:
            line = self._sockf.readline()
            return json.loads(line) if line else None
        except Exception:
            return None


# ── Widget helpers ─────────────────────────────────────────────────────────────
def _btn(parent, text, cmd, *, accent=False, danger=False, w=None, pady=8):
    bg  = ACCENT2 if accent else (ERR if danger else BTN)
    hov = "#388bfd" if accent else (PINK if danger else BTN_H)
    fg  = TEXT
    kw  = dict(text=text, command=cmd, bg=bg, fg=fg, activebackground=hov,
               activeforeground=fg, font=(MONO, MONO_SZ), bd=0,
               padx=14, pady=pady, cursor="hand2", relief="flat")
    if w: kw["width"] = w
    b = tk.Button(parent, **kw)
    b.bind("<Enter>", lambda _: b.config(bg=hov))
    b.bind("<Leave>", lambda _: b.config(bg=bg))
    return b

def _lbl(parent, text, bg=CARD, fg=TEXT, size=MONO_SZ, bold=False, anchor="w"):
    return tk.Label(parent, text=text, bg=bg, fg=fg, anchor=anchor,
                    font=(MONO, size, "bold" if bold else "normal"))

def _sep(parent, bg=BORDER2, h=1):
    return tk.Frame(parent, bg=bg, height=h)

def _entry(parent, var=None, w=30, *, bg=CARD):
    kw = dict(bg=bg, fg=TEXT, insertbackground=ACCENT, font=(MONO, MONO_SZ),
              bd=0, relief="flat", highlightthickness=1,
              highlightbackground=BORDER2, width=w)
    e = tk.Entry(parent, textvariable=var, **kw) if var else tk.Entry(parent, **kw)
    return e

def _spinbox(parent, var, lo, hi, w=6):
    return tk.Spinbox(
        parent, from_=lo, to=hi, textvariable=var, width=w,
        bg=CARD, fg=TEXT, buttonbackground=BORDER,
        font=(MONO, MONO_SZ), bd=0, relief="flat",
        highlightthickness=1, highlightbackground=BORDER2,
    )

def _listbox(parent, h=8):
    lb = tk.Listbox(
        parent, bg=CARD, fg=TEXT, selectbackground=ACCENT2,
        selectforeground=TEXT, font=(MONO, MONO_SZ),
        bd=0, relief="flat", highlightthickness=1,
        highlightbackground=BORDER2, height=h, activestyle="none",
    )
    sb = ttk.Scrollbar(parent, orient="vertical", command=lb.yview)
    lb.config(yscrollcommand=sb.set)
    return lb, sb


# ── Main App ───────────────────────────────────────────────────────────────────
class WallPimpGUI:
    def __init__(self, root: tk.Tk):
        self.root         = root
        self.engine: EngineClient | None = None
        self._q           = queue.Queue()
        self._busy        = False           # engine has an active download
        self._scan_total  = 0
        self._dl_target   = 0
        self._topic_slugs: list[str] = []

        self._cfg_dir  = config_dir()
        self._cfg_file = self._cfg_dir / "config.json"
        self._cfg      = self._load_cfg()

        self._setup_styles()
        self._build_ui()
        self._start_engine()
        self._poll()

    # ── config ────────────────────────────────────────────────────────────────
    def _load_cfg(self) -> dict:
        d = {"wallpaper_dir": str(default_wallpaper_dir()),
             "slideshow_interval": 300, "download_workers": 8}
        try: d.update(json.loads(self._cfg_file.read_text()))
        except Exception: pass
        return d

    def _save_cfg(self):
        self._cfg_dir.mkdir(parents=True, exist_ok=True)
        self._cfg_file.write_text(json.dumps(self._cfg, indent=2))

    # ── ttk styles ────────────────────────────────────────────────────────────
    def _setup_styles(self):
        s = ttk.Style()
        s.theme_use("default")
        s.configure("TProgressbar", troughcolor=BORDER2,
                    background=ACCENT, thickness=10, borderwidth=0)
        s.configure("TNotebook",    background=PANEL,  borderwidth=0)
        s.configure("TNotebook.Tab", background=CARD, foreground=MUTED,
                    padding=[14, 7], font=(MONO, MONO_SZ))
        s.map("TNotebook.Tab",
              background=[("selected", ACCENT2)],
              foreground=[("selected", TEXT)])

    # ── engine lifecycle ──────────────────────────────────────────────────────
    def _start_engine(self):
        workers = int(self._cfg.get("download_workers", 8))
        self.engine = EngineClient(self._cfg_dir / "hashes.json", workers)
        err = self.engine.start()
        if err:
            messagebox.showerror("Engine Error", err)
            return
        threading.Thread(target=self._reader, daemon=True).start()
        self.engine.send({"cmd": "ping"})

    def _reader(self):
        while True:
            ev = self.engine.recv()
            if ev is None: break
            self._q.put(ev)

    def _poll(self):
        try:
            while True:
                ev = self._q.get_nowait()
                self._handle(ev)
        except queue.Empty:
            pass
        self.root.after(50, self._poll)

    def _handle(self, ev: dict):
        k = ev.get("event", "")
        if   k == "pong":        self._status("Engine connected ✓", SUCCESS)
        elif k == "scan_result": self._on_scan(ev.get("total", 0))
        elif k == "progress":    self._on_progress(ev)
        elif k == "done":        self._on_done(ev)
        elif k == "topics":      self._on_topics(ev.get("topics", []))
        elif k == "collections": self._on_collections(ev.get("cols", []))
        elif k == "error":       self._status(f"✗ {ev.get('msg','')}", ERR)

    # ── UI skeleton ───────────────────────────────────────────────────────────
    def _build_ui(self):
        self.root.title("WallPimp")
        self.root.configure(bg=BG)
        self.root.geometry("1020x660")
        self.root.minsize(820, 520)

        # ── Left rail ─────────────────────────────────────────────────────────
        rail = tk.Frame(self.root, bg=PANEL, width=210)
        rail.pack(side="left", fill="y")
        rail.pack_propagate(False)

        # Logo
        logo = tk.Frame(rail, bg=PANEL, pady=22)
        logo.pack(fill="x")
        tk.Label(logo, text="WallPimp", bg=PANEL, fg=ACCENT,
                 font=(MONO, 15, "bold")).pack()
        tk.Label(logo, text="by 0xb0rn3", bg=PANEL, fg=DIM,
                 font=(MONO, 8)).pack(pady=(2, 0))
        _sep(rail, bg=BORDER).pack(fill="x", padx=18)

        # Nav
        self._nav_btns: dict[str, tk.Button] = {}
        self._cur_page: str = ""
        nav = tk.Frame(rail, bg=PANEL, pady=10)
        nav.pack(fill="x")
        items = [
            ("home",      "⌂   Home"),
            ("download",  "↓   Download"),
            ("unsplash",  "◈   Unsplash"),
            ("slideshow", "▶   Slideshow"),
            ("settings",  "⚙   Settings"),
        ]
        for key, lbl in items:
            b = tk.Button(
                nav, text=lbl, bg=PANEL, fg=MUTED,
                font=(MONO, MONO_SZ), bd=0, pady=11, padx=22,
                anchor="w", cursor="hand2", relief="flat",
                activebackground=CARD, activeforeground=ACCENT,
                command=lambda k=key: self._nav(k),
            )
            b.pack(fill="x")
            b.bind("<Enter>", lambda e, b=b, k=key: b.config(
                bg=CARD if self._cur_page != k else ACCENT2,
                fg=ACCENT))
            b.bind("<Leave>", lambda e, b=b, k=key: b.config(
                bg=ACCENT2 if self._cur_page == k else PANEL,
                fg=TEXT    if self._cur_page == k else MUTED))
            self._nav_btns[key] = b

        # Status strip (bottom of rail)
        _sep(rail, bg=BORDER).pack(side="bottom", fill="x")
        self._stat_lbl = tk.Label(
            rail, text="Connecting...", bg=PANEL, fg=DIM,
            font=(MONO, 8), wraplength=190, justify="left",
            padx=14, pady=10,
        )
        self._stat_lbl.pack(side="bottom", fill="x")

        # ── Content area ──────────────────────────────────────────────────────
        self._content = tk.Frame(self.root, bg=BG)
        self._content.pack(side="right", fill="both", expand=True)

        self._pages: dict[str, tk.Frame] = {}
        self._build_home()
        self._build_download()
        self._build_unsplash()
        self._build_slideshow()
        self._build_settings()
        self._nav("home")

    def _status(self, msg: str, color: str = MUTED):
        self._stat_lbl.config(text=msg, fg=color)

    def _nav(self, page: str):
        for p in self._pages.values(): p.pack_forget()
        for k, b in self._nav_btns.items():
            if k == page:
                b.config(bg=ACCENT2, fg=TEXT)
            else:
                b.config(bg=PANEL, fg=MUTED)
        self._cur_page = page
        self._pages[page].pack(fill="both", expand=True)

    # ── page scaffolding helpers ──────────────────────────────────────────────
    def _page(self, name: str) -> tk.Frame:
        f = tk.Frame(self._content, bg=BG)
        self._pages[name] = f
        return f

    def _inner(self, page: tk.Frame, px=30, py=26) -> tk.Frame:
        f = tk.Frame(page, bg=BG, padx=px, pady=py)
        f.pack(fill="both", expand=True)
        return f

    def _heading(self, parent: tk.Frame, title: str):
        tk.Label(parent, text=title, bg=BG, fg=TEXT,
                 font=(MONO, HEAD_SZ, "bold")).pack(anchor="w")
        _sep(parent).pack(fill="x", pady=(6, 18))

    def _card(self, parent: tk.Frame, px=20, py=16, **kw) -> tk.Frame:
        f = tk.Frame(parent, bg=CARD, padx=px, pady=py,
                     highlightthickness=1, highlightbackground=BORDER2, **kw)
        return f

    # ── Home ──────────────────────────────────────────────────────────────────
    def _build_home(self):
        page  = self._page("home")
        inner = self._inner(page)
        self._heading(inner, "WallPimp  /  Wallpaper Manager")

        grid = tk.Frame(inner, bg=BG)
        grid.pack(fill="x")
        for col in range(2): grid.columnconfigure(col, weight=1)

        tiles = [
            ("↓  Download Library",  "Fetch all 19 curated GitHub repos + Unsplash",  "download", True),
            ("◈  Unsplash",          "Search, browse topics, or grab randoms",         "unsplash", False),
            ("▶  Slideshow",         "Manage the wallpaper rotation service",          "slideshow",False),
            ("↺  Random Wallpaper",  "Set a random wallpaper right now",               None,       False),
        ]
        for i, (title, desc, target, hi) in enumerate(tiles):
            row, col = divmod(i, 2)
            c = self._card(grid)
            c.grid(row=row, column=col, padx=7, pady=7, sticky="nsew")
            tk.Label(c, text=title, bg=CARD, fg=ACCENT if hi else TEXT,
                     font=(MONO, 11, "bold")).pack(anchor="w")
            tk.Label(c, text=desc, bg=CARD, fg=MUTED,
                     font=(MONO, 8)).pack(anchor="w", pady=(4, 12))
            cmd = (lambda t=target: self._nav(t)) if target else self._quick_random
            _btn(c, "Open →", cmd, accent=hi).pack(anchor="w")

        self._home_dir_lbl = tk.Label(
            inner, text=f"  ⌂  {self._cfg['wallpaper_dir']}",
            bg=BG, fg=DIM, font=(MONO, 8),
        )
        self._home_dir_lbl.pack(anchor="w", pady=(18, 0))

    def _quick_random(self):
        dest = str(Path(self._cfg["wallpaper_dir"]) / "unsplash" / "random")
        self.engine.send({"cmd": "random", "dest": dest, "count": 1,
                          "workers": int(self._cfg["download_workers"])})
        self._status("Fetching random wallpaper...", WARN)

    # ── Download ──────────────────────────────────────────────────────────────
    def _build_download(self):
        page  = self._page("download")
        inner = self._inner(page)
        self._heading(inner, "Download Wallpapers")

        # Dir row
        dr = tk.Frame(inner, bg=BG)
        dr.pack(fill="x", pady=(0, 12))
        tk.Label(dr, text="Save dir:", bg=BG, fg=MUTED, font=(MONO, 9)).pack(side="left")
        self._dl_dir_var = tk.StringVar(value=self._cfg["wallpaper_dir"])
        tk.Label(dr, textvariable=self._dl_dir_var, bg=BG, fg=TEXT,
                 font=(MONO, 9)).pack(side="left", padx=8)
        _btn(dr, "Browse", self._dl_change_dir).pack(side="left")

        # Action row
        ar = tk.Frame(inner, bg=BG)
        ar.pack(fill="x", pady=(0, 16))
        _btn(ar, "Scan Sources",          self._do_scan,     accent=False).pack(side="left", padx=(0, 8))
        _btn(ar, "Download Full Library", self._dl_full,     accent=True ).pack(side="left", padx=(0, 8))
        _btn(ar, "Custom Amount",         self._dl_custom                ).pack(side="left")

        self._scan_var = tk.StringVar(value="")
        tk.Label(inner, textvariable=self._scan_var, bg=BG, fg=ACCENT,
                 font=(MONO, 11)).pack(anchor="w", pady=(0, 12))

        # Progress card
        pc = self._card(inner)
        pc.pack(fill="x")

        self._prog_title = tk.StringVar(value="Idle")
        tk.Label(pc, textvariable=self._prog_title, bg=CARD, fg=TEXT,
                 font=(MONO, MONO_SZ, "bold")).pack(anchor="w")

        self._prog_bar = ttk.Progressbar(pc, mode="determinate", maximum=100)
        self._prog_bar.pack(fill="x", pady=(8, 4))

        self._prog_stats = tk.StringVar(value="")
        tk.Label(pc, textvariable=self._prog_stats, bg=CARD, fg=MUTED,
                 font=(MONO, 8)).pack(anchor="w")

    def _dl_change_dir(self):
        d = filedialog.askdirectory(initialdir=self._cfg["wallpaper_dir"])
        if d:
            self._cfg["wallpaper_dir"] = d
            self._dl_dir_var.set(d)
            self._home_dir_lbl.config(text=f"  ⌂  {d}")
            self._save_cfg()

    def _do_scan(self):
        self._scan_var.set("Scanning all sources...")
        self._status("Scanning...", WARN)
        self.engine.send({"cmd": "scan"})

    def _on_scan(self, total: int):
        self._scan_total = total
        self._scan_var.set(f"  Available: {total:,} wallpapers")
        self._status(f"Found {total:,} wallpapers", SUCCESS)

    def _dl_full(self):
        if self._busy: return
        self._begin_download(0)

    def _dl_custom(self):
        if self._busy: return
        dlg = tk.Toplevel(self.root)
        dlg.title("Custom Download")
        dlg.configure(bg=BG)
        dlg.geometry("300x140")
        dlg.resizable(False, False)
        dlg.transient(self.root)
        dlg.grab_set()
        tk.Label(dlg, text="How many wallpapers?", bg=BG, fg=TEXT,
                 font=(MONO, 10)).pack(pady=(20, 8))
        e = _entry(dlg, w=14)
        e.pack(ipady=6)
        e.insert(0, "500")
        e.focus_set()

        def go():
            try:
                n = int(e.get().strip())
                if n < 1: raise ValueError
            except ValueError:
                messagebox.showerror("Invalid", "Enter a positive number.", parent=dlg)
                return
            dlg.destroy()
            self._begin_download(n)

        _btn(dlg, "Download", go, accent=True).pack(pady=12)
        e.bind("<Return>", lambda _: go())

    def _begin_download(self, target: int):
        self._busy       = True
        self._dl_target  = target
        self._prog_bar["value"] = 0
        self._prog_title.set("DOWNLOADING ...")
        self._prog_stats.set("")
        self._status("Downloading...", WARN)
        cmd: dict = {"cmd": "download", "wdir": self._cfg["wallpaper_dir"],
                     "workers": int(self._cfg["download_workers"])}
        if target > 0: cmd["target"] = target
        self.engine.send(cmd)

    def _on_progress(self, ev: dict):
        new   = ev.get("new",    0)
        dupes = ev.get("dupes",  0)
        errs  = ev.get("errors", 0)
        total = self._dl_target or self._scan_total
        pct   = min(100, int(new / total * 100)) if total else 0
        self._prog_bar["value"] = pct
        label = f"DOWNLOADING  {new:,} / {total:,}" if total else f"DOWNLOADING  {new:,}"
        self._prog_title.set(label)
        self._prog_stats.set(f"{new:,} new  ·  {dupes:,} dupes  ·  {errs:,} errors")

    def _on_done(self, ev: dict):
        self._busy = False
        new   = ev.get("new",    0)
        dupes = ev.get("dupes",  0)
        errs  = ev.get("errors", 0)
        self._prog_bar["value"] = 100
        self._prog_title.set("Done ✓")
        self._prog_stats.set(f"{new:,} new  ·  {dupes:,} dupes  ·  {errs:,} errors")
        self._status(f"Done — {new:,} new wallpapers saved", SUCCESS)

    # ── Unsplash ──────────────────────────────────────────────────────────────
    def _build_unsplash(self):
        page  = self._page("unsplash")
        inner = self._inner(page)
        self._heading(inner, "Unsplash")

        nb = ttk.Notebook(inner)
        nb.pack(fill="both", expand=True)

        st = tk.Frame(nb, bg=BG, padx=16, pady=16)
        nb.add(st, text="  Search  ")
        self._build_search_tab(st)

        tt = tk.Frame(nb, bg=BG, padx=16, pady=16)
        nb.add(tt, text="  Topics  ")
        self._build_topics_tab(tt)

        rt = tk.Frame(nb, bg=BG, padx=16, pady=16)
        nb.add(rt, text="  Random  ")
        self._build_random_tab(rt)

    # -- search tab ------------------------------------------------------------
    def _build_search_tab(self, parent):
        row = tk.Frame(parent, bg=BG)
        row.pack(fill="x", pady=(0, 10))
        tk.Label(row, text="Query:", bg=BG, fg=MUTED, font=(MONO, 9)).pack(side="left")
        self._search_q = tk.StringVar()
        e = _entry(row, self._search_q, w=26)
        e.pack(side="left", padx=10, ipady=5)
        tk.Label(row, text="Page:", bg=BG, fg=MUTED, font=(MONO, 9)).pack(side="left")
        self._search_pg = tk.IntVar(value=1)
        _spinbox(row, self._search_pg, 1, 999, 5).pack(side="left", padx=6, ipady=4)
        _btn(row, "Search & Download", self._do_search, accent=True).pack(side="left", padx=10)
        e.bind("<Return>", lambda _: self._do_search())

        dr = tk.Frame(parent, bg=BG)
        dr.pack(fill="x")
        tk.Label(dr, text="Save to:", bg=BG, fg=MUTED, font=(MONO, 8)).pack(side="left")
        self._search_dir = tk.StringVar(
            value=str(Path(self._cfg["wallpaper_dir"]) / "unsplash" / "search"))
        tk.Label(dr, textvariable=self._search_dir, bg=BG, fg=DIM,
                 font=(MONO, 8)).pack(side="left", padx=8)
        _btn(dr, "Change", lambda: self._pick_dir(self._search_dir)).pack(side="left")

    def _do_search(self):
        q = self._search_q.get().strip()
        if not q:
            messagebox.showwarning("Search", "Enter a keyword first."); return
        dest = str(Path(self._search_dir.get()) / q)
        self.engine.send({"cmd": "search", "query": q,
                          "page": self._search_pg.get(), "dest": dest,
                          "workers": int(self._cfg["download_workers"])})
        self._status(f"Searching: {q} ...", WARN)

    # -- topics tab ------------------------------------------------------------
    def _build_topics_tab(self, parent):
        top = tk.Frame(parent, bg=BG)
        top.pack(fill="x", pady=(0, 10))
        _btn(top, "Load Topics", self._load_topics, accent=True).pack(side="left")

        lf = tk.Frame(parent, bg=BG)
        lf.pack(fill="both", expand=True, pady=(0, 10))
        self._topics_lb, sb = _listbox(lf)
        self._topics_lb.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")

        self._topics_dir = tk.StringVar(
            value=str(Path(self._cfg["wallpaper_dir"]) / "unsplash" / "topics"))
        bot = tk.Frame(parent, bg=BG)
        bot.pack(fill="x")
        _btn(bot, "Download Selected", self._dl_topic, accent=True).pack(side="left", padx=(0, 8))
        tk.Label(bot, text="dir:", bg=BG, fg=MUTED, font=(MONO, 8)).pack(side="left")
        tk.Label(bot, textvariable=self._topics_dir, bg=BG, fg=DIM,
                 font=(MONO, 8)).pack(side="left", padx=6)
        _btn(bot, "Change", lambda: self._pick_dir(self._topics_dir)).pack(side="left")

    def _load_topics(self):
        self.engine.send({"cmd": "topics"})
        self._status("Loading topics...", WARN)

    def _on_topics(self, topics: list):
        self._topics_lb.delete(0, tk.END)
        self._topic_slugs = []
        for t in topics:
            slug  = t.get("slug", "")
            title = t.get("title", slug)
            total = t.get("total_photos", 0)
            self._topics_lb.insert(tk.END, f"  {title:<28}  {total:>6,} photos")
            self._topic_slugs.append(slug)
        self._status(f"Loaded {len(topics)} topics", SUCCESS)

    def _dl_topic(self):
        sel = self._topics_lb.curselection()
        if not sel: messagebox.showinfo("Topics", "Select a topic first."); return
        slug = self._topic_slugs[sel[0]]
        dest = str(Path(self._topics_dir.get()) / slug)
        self.engine.send({"cmd": "topic_photos", "slug": slug, "page": 1,
                          "dest": dest, "workers": int(self._cfg["download_workers"])})
        self._status(f"Downloading topic: {slug} ...", WARN)

    # -- random tab ------------------------------------------------------------
    def _build_random_tab(self, parent):
        tk.Label(parent, text="Grab random landscape wallpapers from Unsplash.",
                 bg=BG, fg=MUTED, font=(MONO, 9)).pack(anchor="w", pady=(0, 12))

        row = tk.Frame(parent, bg=BG)
        row.pack(fill="x", pady=(0, 8))
        tk.Label(row, text="Count (1–30):", bg=BG, fg=MUTED, font=(MONO, 9)).pack(side="left")
        self._rand_count = tk.IntVar(value=15)
        _spinbox(row, self._rand_count, 1, 30, 5).pack(side="left", padx=8, ipady=4)

        dr = tk.Frame(parent, bg=BG)
        dr.pack(fill="x", pady=(0, 14))
        tk.Label(dr, text="Save to:", bg=BG, fg=MUTED, font=(MONO, 8)).pack(side="left")
        self._rand_dir = tk.StringVar(
            value=str(Path(self._cfg["wallpaper_dir"]) / "unsplash" / "random"))
        tk.Label(dr, textvariable=self._rand_dir, bg=BG, fg=DIM,
                 font=(MONO, 8)).pack(side="left", padx=8)
        _btn(dr, "Change", lambda: self._pick_dir(self._rand_dir)).pack(side="left")

        _btn(parent, "Download Random", self._dl_random, accent=True).pack(anchor="w")

    def _dl_random(self):
        self.engine.send({"cmd": "random", "count": self._rand_count.get(),
                          "dest": self._rand_dir.get(),
                          "workers": int(self._cfg["download_workers"])})
        self._status("Downloading randoms...", WARN)

    def _on_collections(self, cols: list):
        pass  # extendable

    def _pick_dir(self, var: tk.StringVar):
        d = filedialog.askdirectory(initialdir=var.get())
        if d: var.set(d)

    # ── Slideshow ─────────────────────────────────────────────────────────────
    def _build_slideshow(self):
        page  = self._page("slideshow")
        inner = self._inner(page)
        self._heading(inner, "Slideshow Control")

        card = self._card(inner)
        card.pack(fill="x")

        tk.Label(card, text="Interval (seconds)", bg=CARD, fg=MUTED,
                 font=(MONO, 9)).pack(anchor="w")
        self._interval_var = tk.IntVar(value=int(self._cfg.get("slideshow_interval", 300)))
        _spinbox(card, self._interval_var, 10, 86400, 8).pack(anchor="w", pady=(4, 16), ipady=5)

        _sep(card, bg=BORDER).pack(fill="x", pady=(0, 16))

        br = tk.Frame(card, bg=CARD)
        br.pack(anchor="w")

        if OS == "Linux":
            _btn(br, "Save Session Env",    self._ss_save_env           ).pack(side="left", padx=(0, 8))
            _btn(br, "Start  (systemd)",    self._ss_start_linux, accent=True).pack(side="left", padx=(0, 8))
            _btn(br, "Stop",                self._ss_stop_linux,  danger=True).pack(side="left")
        elif OS == "Darwin":
            _btn(br, "Start  (launchd)",    self._ss_start_mac,   accent=True).pack(side="left", padx=(0, 8))
            _btn(br, "Stop",                self._ss_stop_mac,    danger=True).pack(side="left")
        else:  # Windows
            _btn(br, "Start  (Task Sched)", self._ss_start_win,   accent=True).pack(side="left", padx=(0, 8))
            _btn(br, "Stop",                self._ss_stop_win,    danger=True).pack(side="left")

        tk.Label(card,
                 text="\nTerminal daemon:   wallpimp --daemon",
                 bg=CARD, fg=DIM, font=(MONO, 8)).pack(anchor="w")

    def _ss_save_interval(self):
        self._cfg["slideshow_interval"] = self._interval_var.get()
        self._save_cfg()

    def _ss_save_env(self):
        messagebox.showinfo("Session Env",
            "Run this from a graphical terminal (not SSH):\n\n"
            "  wallpimp → Slideshow control → Save session env\n\n"
            "This captures D-Bus variables needed by the systemd service.")

    def _ss_start_linux(self):
        self._ss_save_interval()
        try:
            subprocess.Popen(["systemctl", "--user", "start", "wallpimp-slideshow.service"])
            self._status("Slideshow started (systemd) ✓", SUCCESS)
        except Exception as ex:
            messagebox.showerror("Slideshow", str(ex))

    def _ss_stop_linux(self):
        try:
            subprocess.Popen(["systemctl", "--user", "stop", "wallpimp-slideshow.service"])
            self._status("Slideshow stopped", MUTED)
        except Exception as ex:
            messagebox.showerror("Slideshow", str(ex))

    def _ss_start_mac(self):
        self._ss_save_interval()
        plist = Path.home() / "Library" / "LaunchAgents" / "com.wallpimp.slideshow.plist"
        if plist.exists():
            subprocess.Popen(["launchctl", "load", str(plist)])
            self._status("Slideshow started (launchd) ✓", SUCCESS)
        else:
            messagebox.showinfo("Slideshow",
                "Run  wallpimp  from Terminal first to install the launchd service.")

    def _ss_stop_mac(self):
        plist = Path.home() / "Library" / "LaunchAgents" / "com.wallpimp.slideshow.plist"
        subprocess.Popen(["launchctl", "unload", str(plist)])
        self._status("Slideshow stopped", MUTED)

    def _ss_start_win(self):
        self._ss_save_interval()
        try:
            subprocess.Popen(["schtasks", "/run", "/tn", "WallPimp Slideshow"], shell=True)
            self._status("Slideshow started (Task Scheduler) ✓", SUCCESS)
        except Exception as ex:
            messagebox.showerror("Slideshow", str(ex))

    def _ss_stop_win(self):
        try:
            subprocess.Popen(["schtasks", "/end", "/tn", "WallPimp Slideshow"], shell=True)
            self._status("Slideshow stopped", MUTED)
        except Exception as ex:
            messagebox.showerror("Slideshow", str(ex))

    # ── Settings ──────────────────────────────────────────────────────────────
    def _build_settings(self):
        page  = self._page("settings")
        inner = self._inner(page)
        self._heading(inner, "Settings")

        card = self._card(inner)
        card.pack(fill="x")

        # Wallpaper dir
        tk.Label(card, text="Wallpaper directory", bg=CARD, fg=MUTED,
                 font=(MONO, 9)).pack(anchor="w")
        dr = tk.Frame(card, bg=CARD)
        dr.pack(fill="x", pady=(4, 18))
        self._s_dir = tk.StringVar(value=self._cfg["wallpaper_dir"])
        tk.Label(dr, textvariable=self._s_dir, bg=CARD, fg=TEXT,
                 font=(MONO, 9)).pack(side="left")
        _btn(dr, "Browse", self._s_pick_dir).pack(side="left", padx=10)

        # Workers
        tk.Label(card, text="Download workers  (1–32)", bg=CARD, fg=MUTED,
                 font=(MONO, 9)).pack(anchor="w")
        self._s_workers = tk.IntVar(value=int(self._cfg.get("download_workers", 8)))
        _spinbox(card, self._s_workers, 1, 32, 6).pack(anchor="w", pady=(4, 18), ipady=5)

        # Interval
        tk.Label(card, text="Slideshow interval  (seconds)", bg=CARD, fg=MUTED,
                 font=(MONO, 9)).pack(anchor="w")
        self._s_interval = tk.IntVar(value=int(self._cfg.get("slideshow_interval", 300)))
        _spinbox(card, self._s_interval, 10, 86400, 8).pack(anchor="w", pady=(4, 20), ipady=5)

        _btn(card, "Save Settings", self._save_settings, accent=True).pack(anchor="w")

    def _s_pick_dir(self):
        d = filedialog.askdirectory(initialdir=self._cfg["wallpaper_dir"])
        if d:
            self._s_dir.set(d)
            self._cfg["wallpaper_dir"] = d
            self._dl_dir_var.set(d)
            self._home_dir_lbl.config(text=f"  ⌂  {d}")

    def _save_settings(self):
        self._cfg["wallpaper_dir"]      = self._s_dir.get()
        self._cfg["download_workers"]   = self._s_workers.get()
        self._cfg["slideshow_interval"] = self._s_interval.get()
        self._save_cfg()
        self._status("Settings saved ✓", SUCCESS)
        messagebox.showinfo("Settings", "Settings saved.")

    # ── cleanup ───────────────────────────────────────────────────────────────
    def on_close(self):
        if self.engine: self.engine.stop()
        self.root.destroy()


# ── Entry point ────────────────────────────────────────────────────────────────
def main():
    root = tk.Tk()
    app  = WallPimpGUI(root)
    root.protocol("WM_DELETE_WINDOW", app.on_close)
    root.update_idletasks()
    sw = root.winfo_screenwidth()
    sh = root.winfo_screenheight()
    ww = root.winfo_width()
    wh = root.winfo_height()
    root.geometry(f"+{(sw - ww)//2}+{(sh - wh)//2}")
    root.mainloop()


if __name__ == "__main__":
    main()
