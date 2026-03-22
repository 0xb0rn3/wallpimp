#!/usr/bin/env python3
"""
WallPimp GUI v2.1 — by 0xb0rn3
contact@oxborn3.com  |  oxborn3.com  |  github.com/0xb0rn3/wallpimp

Tkinter front-end that communicates with wallpimp-engine over a Unix socket.
Features: wallpaper preview grid, stop & resume downloads, gradient UI.
"""

import json, math, os, platform, queue, random, shutil, socket
import subprocess, sys, threading, time
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import tkinter.font as tkfont

# ── Auto-install Pillow for preview thumbnails ────────────────────────────────
try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    try:
        _pip = [] if sys.platform == "win32" else ["--break-system-packages"]
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install"] + _pip + ["Pillow"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        from PIL import Image, ImageTk
        HAS_PIL = True
    except Exception:
        HAS_PIL = False


# ── Font detection ─────────────────────────────────────────────────────────────
def _best_mono() -> str:
    try: available = set(tkfont.families())
    except Exception: return "Courier"
    for f in ["JetBrains Mono","Cascadia Code","Fira Code","Hack","Iosevka",
              "Source Code Pro","Inconsolata","DejaVu Sans Mono",
              "Liberation Mono","Noto Mono","Courier New","Courier"]:
        if f in available: return f
    return "TkFixedFont"

def _best_ui() -> str:
    try: available = set(tkfont.families())
    except Exception: return "TkDefaultFont"
    for f in ["SF Pro Display","Segoe UI","Helvetica Neue","Ubuntu",
              "Cantarell","Noto Sans","Roboto","Arial"]:
        if f in available: return f
    return "TkDefaultFont"

def _best_display() -> str:
    try: available = set(tkfont.families())
    except Exception: return _best_ui()
    for f in ["SF Pro Display","Segoe UI Semibold","Helvetica Neue",
              "Ubuntu Bold","Cantarell Bold"]:
        if f in available: return f
    return _best_ui()

MONO    = _best_mono()
UI_FONT = _best_ui()
DISPLAY = _best_display()

# ── Palette ───────────────────────────────────────────────────────────────────
BG=      "#06090f"; BG2=     "#0a0e16"; PANEL=   "#0c1018"
CARD=    "#111820"; CARD_H=  "#161e28"; BORDER=  "#1a2332"; BORDER2= "#243044"
ACCENT=  "#00e5b0"; ACCENT2= "#0088ff"; ACCENT3= "#6c5ce7"
TEXT=    "#e8edf5"; TEXT2=   "#c8d0dc"; MUTED=   "#6b7a8d"; DIM=     "#3d4a5c"
SUCCESS= "#00d68f"; WARN=    "#ffbb33"; ERR=     "#ff4757"
BTN=     "#1a2332"; BTN_H=   "#243044"
BTN_ACC= "#0077e6"; BTN_ACCH="#0066cc"
BTN_WARN="#cc8800"; BTN_WARNH="#b37700"

MONO_SZ=10; UI_SZ=10; HEAD_SZ=14; SMALL_SZ=9; TINY_SZ=8; NAV_W=230

_IMG_EXTS = {".jpg",".jpeg",".png",".webp",".gif",".bmp",".tiff",".tif",
             ".heic",".heif",".avif",".jxl"}

# ── Platform ──────────────────────────────────────────────────────────────────
OS = platform.system()

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
    if here.exists(): return here
    found = shutil.which(name)
    return Path(found) if found else None


# ── Engine client ─────────────────────────────────────────────────────────────
class EngineClient:
    def __init__(self, hash_path: Path, workers: int = 16):
        self.hash_path = hash_path
        self.workers   = workers
        self._proc = self._sock = self._sockf = None
        self._lock = threading.Lock()

    @property
    def alive(self) -> bool:
        return self._proc is not None and self._proc.poll() is None

    def start(self) -> str | None:
        eng = find_engine()
        if not eng:
            return ("wallpimp-engine binary not found.\n"
                    "Build it:  cd src && go build -o ../wallpimp-engine .\n"
                    "Then place it next to wallpimp_gui.py or on your PATH.")
        self.hash_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._proc = subprocess.Popen(
                [str(eng), str(self.hash_path), str(self.workers)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            addr = self._proc.stdout.readline().strip()
            if not addr:
                return f"Engine did not emit address.\n{self._proc.stderr.read(2048)}"
            if addr.startswith("tcp:"):
                port = int(addr.split(":",1)[1])
                for _ in range(60):
                    try:
                        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                        s.connect(("127.0.0.1", port))
                        self._sock = s; self._sockf = s.makefile("r"); return None
                    except (ConnectionRefusedError, OSError): time.sleep(0.05)
                return f"Timed out on 127.0.0.1:{port}"
            else:
                for _ in range(60):
                    try:
                        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                        s.connect(addr)
                        self._sock = s; self._sockf = s.makefile("r"); return None
                    except (ConnectionRefusedError, FileNotFoundError, OSError):
                        time.sleep(0.05)
                return f"Timed out on socket: {addr}"
        except Exception as e: return str(e)

    def kill(self):
        try:
            if self._sock: self._sock.close()
        except Exception: pass
        self._sock = self._sockf = None
        try:
            if self._proc: self._proc.kill(); self._proc.wait(timeout=3)
        except Exception: pass
        self._proc = None

    def stop(self):
        try: self.send({"cmd":"shutdown"})
        except Exception: pass
        for o in (self._sock, self._proc):
            try:
                if o: (o.close() if hasattr(o,"close") else o.terminate())
            except Exception: pass

    def send(self, cmd: dict):
        with self._lock:
            if self._sock:
                self._sock.sendall((json.dumps(cmd)+"\n").encode())

    def recv(self) -> dict | None:
        try:
            line = self._sockf.readline()
            return json.loads(line) if line else None
        except Exception: return None


# ── Color helpers ─────────────────────────────────────────────────────────────
def _hex2rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2],16) for i in (0,2,4))

def _rgb2hex(r,g,b): return f"#{int(r):02x}{int(g):02x}{int(b):02x}"

def _lerp(c1,c2,t):
    r1,g1,b1=_hex2rgb(c1); r2,g2,b2=_hex2rgb(c2)
    return _rgb2hex(r1+(r2-r1)*t, g1+(g2-g1)*t, b1+(b2-b1)*t)


# ── Widget helpers ────────────────────────────────────────────────────────────
def _btn(parent, text, cmd, *, accent=False, danger=False, warn=False,
         w=None, pady=8, small=False):
    sz = SMALL_SZ if small else MONO_SZ
    if accent:   bg, hov = BTN_ACC, BTN_ACCH
    elif danger: bg, hov = ERR, "#ff6b7a"
    elif warn:   bg, hov = BTN_WARN, BTN_WARNH
    else:        bg, hov = BTN, BTN_H
    b = tk.Button(parent, text=text, command=cmd, bg=bg, fg=TEXT,
                  activebackground=hov, activeforeground=TEXT,
                  font=(MONO, sz, "bold" if accent else "normal"),
                  bd=0, padx=16, pady=pady, cursor="hand2", relief="flat",
                  **({} if w is None else {"width": w}))
    b.bind("<Enter>", lambda _: b.config(bg=hov))
    b.bind("<Leave>", lambda _: b.config(bg=bg))
    return b

def _sep(parent, bg=BORDER, h=1):
    return tk.Frame(parent, bg=bg, height=h)

def _entry(parent, var=None, w=30):
    kw = dict(bg="#0d1520", fg=TEXT, insertbackground=ACCENT,
              font=(MONO,MONO_SZ), bd=0, relief="flat",
              highlightthickness=1, highlightbackground=BORDER2,
              highlightcolor=ACCENT2, width=w)
    return tk.Entry(parent, textvariable=var, **kw) if var else tk.Entry(parent, **kw)

def _spinbox(parent, var, lo, hi, w=6):
    return tk.Spinbox(parent, from_=lo, to=hi, textvariable=var, width=w,
                      bg="#0d1520", fg=TEXT, buttonbackground=BORDER,
                      font=(MONO,MONO_SZ), bd=0, relief="flat",
                      highlightthickness=1, highlightbackground=BORDER2)

def _listbox(parent, h=8):
    lb = tk.Listbox(parent, bg="#0d1520", fg=TEXT, selectbackground=ACCENT2,
                    selectforeground=TEXT, font=(MONO,MONO_SZ), bd=0,
                    relief="flat", highlightthickness=1,
                    highlightbackground=BORDER2, height=h, activestyle="none")
    sb = ttk.Scrollbar(parent, orient="vertical", command=lb.yview)
    lb.config(yscrollcommand=sb.set)
    return lb, sb

def _log_widget(parent, h=6):
    f = tk.Frame(parent, bg="#0a1018", highlightthickness=1,
                 highlightbackground=BORDER)
    sb = ttk.Scrollbar(f, orient="vertical")
    tw = tk.Text(f, bg="#0a1018", fg=MUTED, font=(MONO,SMALL_SZ), bd=0,
                 relief="flat", state="disabled", height=h, wrap="word",
                 yscrollcommand=sb.set, insertbackground=ACCENT, padx=10, pady=6)
    sb.config(command=tw.yview); sb.pack(side="right", fill="y")
    tw.pack(side="left", fill="both", expand=True)
    return f, tw

def log_append(tw, msg, color=MUTED):
    tw.config(state="normal")
    tag = f"c{color}"
    tw.insert("end", f" {time.strftime('%H:%M:%S')}  ", "ts")
    tw.insert("end", f"{msg}\n", tag)
    tw.tag_config("ts", foreground=DIM, font=(MONO,TINY_SZ))
    tw.tag_config(tag, foreground=color)
    tw.see("end"); tw.config(state="disabled")


# ── Gradient progress bar ────────────────────────────────────────────────────
class GradientBar(tk.Canvas):
    def __init__(self, parent, height=8, **kw):
        super().__init__(parent, height=height, bd=0, highlightthickness=0,
                         bg=CARD, **kw)
        self._pct=0; self._h=height; self.bind("<Configure>", self._draw)

    def set(self, pct):
        self._pct = max(0, min(100, pct)); self._draw()

    def _draw(self, _e=None):
        self.delete("all"); w=self.winfo_width(); h=self._h
        if w<2: return
        self.create_rectangle(0,0,w,h,fill="#0d1520",outline="")
        fw=int(w*self._pct/100)
        if fw>0:
            steps=max(1,fw//3)
            for i in range(steps):
                t=i/max(1,steps-1); c=_lerp(ACCENT,ACCENT2,t)
                self.create_rectangle(int(i*fw/steps),0,int((i+1)*fw/steps),h,fill=c,outline="")
            self.create_line(0,0,fw,0,fill=ACCENT,width=1)


# ── Pulsing dot ──────────────────────────────────────────────────────────────
class StatusDot(tk.Canvas):
    def __init__(self, parent, size=8, **kw):
        super().__init__(parent, width=size+4, height=size+4, bd=0,
                         highlightthickness=0, bg=kw.pop("bg",PANEL))
        self._size=size; self._color=DIM; self._phase=0.0; self._animating=False

    def set_color(self, color, animate=False):
        self._color=color; self._animating=animate
        if animate: self._pulse()
        else: self._draw(1.0)

    def _draw(self, alpha=1.0):
        self.delete("all"); s=self._size; c=self._color
        if self._animating and alpha>0.3:
            self.create_oval(0,0,s+4,s+4,fill="",outline=c,width=1)
        self.create_oval(2,2,s+2,s+2,fill=c,outline="")

    def _pulse(self):
        if not self._animating: return
        self._phase+=0.1
        self._draw((math.sin(self._phase)+1)/2)
        self.after(80, self._pulse)


# ── Preview panel ────────────────────────────────────────────────────────────
class PreviewPanel:
    THUMB_SZ = 180; COLS = 4

    def __init__(self, parent, wdir, set_wp_cb=None):
        self.parent=parent; self.wdir=wdir; self.set_wp_cb=set_wp_cb
        self._thumbs=[]; self._files=[]; self._loading=False; self._pwin=None

        self.frame = tk.Frame(parent, bg=BG)

        # Toolbar
        tb = tk.Frame(self.frame, bg=BG); tb.pack(fill="x", pady=(0,12))
        _btn(tb,"⟳  Refresh",self.load_thumbnails,accent=True,small=True).pack(side="left",padx=(0,8))
        _btn(tb,"🗁  Open Folder",self._open_folder,small=True).pack(side="left",padx=(0,8))
        self._count_var=tk.StringVar(value="")
        tk.Label(tb,textvariable=self._count_var,bg=BG,fg=MUTED,font=(MONO,SMALL_SZ)).pack(side="left",padx=(12,0))
        self._loading_var=tk.StringVar(value="")
        tk.Label(tb,textvariable=self._loading_var,bg=BG,fg=WARN,font=(MONO,TINY_SZ)).pack(side="right")

        # Scrollable canvas
        ct = tk.Frame(self.frame, bg=BG); ct.pack(fill="both", expand=True)
        self._canvas = tk.Canvas(ct, bg=BG, bd=0, highlightthickness=0)
        vsb = ttk.Scrollbar(ct, orient="vertical", command=self._canvas.yview)
        self._canvas.configure(yscrollcommand=vsb.set)
        vsb.pack(side="right", fill="y")
        self._canvas.pack(side="left", fill="both", expand=True)
        self._grid = tk.Frame(self._canvas, bg=BG)
        self._cwin = self._canvas.create_window((0,0), window=self._grid, anchor="nw")
        self._grid.bind("<Configure>", lambda _: self._canvas.configure(
            scrollregion=self._canvas.bbox("all")))
        self._canvas.bind("<Configure>", lambda e: self._canvas.itemconfig(
            self._cwin, width=e.width))
        for ev in ("<MouseWheel>","<Button-4>","<Button-5>"):
            self._canvas.bind_all(ev, self._scroll)

        if not HAS_PIL:
            tk.Label(self._grid, text="Install Pillow for preview:\n  pip install Pillow",
                     bg=BG, fg=ERR, font=(MONO,MONO_SZ), justify="left").grid(
                         row=0, column=0, padx=20, pady=20)

    def _scroll(self, evt):
        if not self._canvas.winfo_viewable(): return
        if evt.num==4 or evt.delta>0: self._canvas.yview_scroll(-3,"units")
        elif evt.num==5 or evt.delta<0: self._canvas.yview_scroll(3,"units")

    def set_dir(self, wdir): self.wdir = wdir
    def _open_folder(self):
        p=Path(self.wdir)
        if not p.exists(): return
        if OS=="Windows": os.startfile(str(p))
        elif OS=="Darwin": subprocess.Popen(["open",str(p)])
        else: subprocess.Popen(["xdg-open",str(p)])

    def load_thumbnails(self):
        if not HAS_PIL or self._loading: return
        self._loading=True; self._loading_var.set("Loading...")
        threading.Thread(target=self._load_bg, daemon=True).start()

    def _load_bg(self):
        files = sorted(
            [p for p in Path(self.wdir).rglob("*") if p.suffix.lower() in _IMG_EXTS],
            key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True)[:200]
        self._files = files; thumbs = []
        for i,fp in enumerate(files):
            try:
                img = Image.open(fp)
                img.thumbnail((self.THUMB_SZ, self.THUMB_SZ), Image.LANCZOS)
                thumbs.append((fp, img))
            except Exception: continue
            if (i+1)%10==0:
                self.parent.after(0, self._loading_var.set, f"Loading {i+1}/{len(files)}...")
        self.parent.after(0, self._render, thumbs)

    def _render(self, thumbs):
        for w in self._grid.winfo_children(): w.destroy()
        self._thumbs.clear()
        if not thumbs:
            tk.Label(self._grid, text="No wallpapers found.\nDownload some first!",
                     bg=BG, fg=MUTED, font=(MONO,MONO_SZ), justify="center").grid(
                         row=0, column=0, padx=40, pady=40)
            self._count_var.set("0 wallpapers")
            self._loading_var.set(""); self._loading=False; return

        for i,(fp,pil_img) in enumerate(thumbs):
            r,c = divmod(i, self.COLS)
            tk_img = ImageTk.PhotoImage(pil_img); self._thumbs.append(tk_img)
            cell = tk.Frame(self._grid, bg=CARD, padx=3, pady=3,
                            highlightthickness=1, highlightbackground=BORDER)
            cell.grid(row=r, column=c, padx=4, pady=4, sticky="nsew")
            lbl = tk.Label(cell, image=tk_img, bg=CARD, cursor="hand2"); lbl.pack()
            nm = fp.name if len(fp.name)<28 else fp.name[:25]+"..."
            tk.Label(cell, text=nm, bg=CARD, fg=DIM, font=(MONO,TINY_SZ),
                     anchor="w").pack(fill="x", padx=4, pady=(2,0))
            brow = tk.Frame(cell, bg=CARD); brow.pack(fill="x", padx=2, pady=(2,2))
            zl = tk.Label(brow, text="🔍", bg=CARD, fg=ACCENT2, font=(MONO,SMALL_SZ),
                          cursor="hand2"); zl.pack(side="left", padx=(2,4))
            zl.bind("<Button-1>", lambda e,p=fp: self._full(p))
            sl = tk.Label(brow, text="Set", bg=CARD, fg=ACCENT, font=(MONO,TINY_SZ,"bold"),
                          cursor="hand2"); sl.pack(side="right", padx=(4,2))
            sl.bind("<Button-1>", lambda e,p=fp: self.set_wp_cb(str(p)) if self.set_wp_cb else None)
            for ww in (cell,lbl):
                ww.bind("<Enter>", lambda e,c=cell: c.config(highlightbackground=ACCENT2))
                ww.bind("<Leave>", lambda e,c=cell: c.config(highlightbackground=BORDER))
            lbl.bind("<Button-1>", lambda e,p=fp: self._full(p))

        for c in range(self.COLS): self._grid.columnconfigure(c, weight=1)
        total=len(self._files); shown=len(thumbs)
        ex = f" (showing {shown})" if shown<total else ""
        self._count_var.set(f"{total} wallpapers{ex}")
        self._loading_var.set(""); self._loading=False
        self._canvas.yview_moveto(0)

    def _full(self, path):
        if not HAS_PIL: return
        if self._pwin and self._pwin.winfo_exists(): self._pwin.destroy()
        try: img = Image.open(path)
        except Exception: return
        win = tk.Toplevel(self.parent); self._pwin = win
        win.title(f"Preview — {path.name}"); win.configure(bg=BG)
        win.transient(self.parent)
        sw,sh = win.winfo_screenwidth(), win.winfo_screenheight()
        img.thumbnail((int(sw*0.8), int(sh*0.8)), Image.LANCZOS)
        tk_img = ImageTk.PhotoImage(img)
        win.geometry(f"{img.width+20}x{img.height+80}")
        win.update_idletasks()
        win.geometry(f"+{(sw-win.winfo_width())//2}+{(sh-win.winfo_height())//2}")
        il = tk.Label(win, image=tk_img, bg=BG); il.image=tk_img; il.pack(padx=10,pady=(10,4))
        bar = tk.Frame(win, bg=BG); bar.pack(fill="x", padx=10, pady=(4,10))
        tk.Label(bar, text=path.name, bg=BG, fg=MUTED, font=(MONO,SMALL_SZ)).pack(side="left")
        if self.set_wp_cb:
            _btn(bar, "Set as Wallpaper",
                 lambda: (self.set_wp_cb(str(path)), win.destroy()),
                 accent=True, small=True).pack(side="right")
        _btn(bar, "Close", win.destroy, small=True).pack(side="right", padx=(0,8))
        win.bind("<Escape>", lambda _: win.destroy())


# ══════════════════════════════════════════════════════════════════════════════
#  Main App
# ══════════════════════════════════════════════════════════════════════════════
class WallPimpGUI:
    def __init__(self, root):
        self.root = root
        self.engine = None
        self._q = queue.Queue()
        self._busy = False
        self._stopped = False
        self._scan_total = 0
        self._dl_target = self._dl_last_new = 0
        self._dl_start = self._dl_prev_ts = 0.0
        self._dl_last_cmd = None
        self._topic_slugs = []
        self._cfg_dir = config_dir()
        self._cfg_file = self._cfg_dir / "config.json"
        self._cfg = self._load_cfg()
        self._setup_styles(); self._build_ui()
        self._start_engine(); self._poll()

    def _load_cfg(self):
        d={"wallpaper_dir":str(default_wallpaper_dir()),"slideshow_interval":300,"download_workers":16}
        try: d.update(json.loads(self._cfg_file.read_text()))
        except Exception: pass
        return d

    def _save_cfg(self):
        self._cfg_dir.mkdir(parents=True,exist_ok=True)
        self._cfg_file.write_text(json.dumps(self._cfg,indent=2))

    def _setup_styles(self):
        s=ttk.Style(); s.theme_use("default")
        s.configure("TProgressbar",troughcolor="#0d1520",background=ACCENT,thickness=8,borderwidth=0)
        s.configure("TNotebook",background=BG,borderwidth=0)
        s.configure("TNotebook.Tab",background=CARD,foreground=MUTED,padding=[16,8],font=(UI_FONT,SMALL_SZ,"bold"))
        s.map("TNotebook.Tab",background=[("selected",ACCENT2)],foreground=[("selected",TEXT)])
        s.configure("TScrollbar",background=BORDER,troughcolor=BG2,arrowcolor=MUTED,borderwidth=0)

    # ── Engine ────────────────────────────────────────────────────────────────
    def _start_engine(self):
        w=int(self._cfg.get("download_workers",16))
        self.engine=EngineClient(self._cfg_dir/"hashes.json",w)
        err=self.engine.start()
        if err: messagebox.showerror("Engine Error",err); return
        self._rthread=threading.Thread(target=self._reader,daemon=True); self._rthread.start()
        self.engine.send({"cmd":"ping"})

    def _restart_engine(self):
        if self.engine: self.engine.kill()
        w=int(self._cfg.get("download_workers",16))
        self.engine=EngineClient(self._cfg_dir/"hashes.json",w)
        err=self.engine.start()
        if err: return err
        while not self._q.empty():
            try: self._q.get_nowait()
            except queue.Empty: break
        self._rthread=threading.Thread(target=self._reader,daemon=True); self._rthread.start()
        self.engine.send({"cmd":"ping"}); return None

    def _reader(self):
        while True:
            if not self.engine or not self.engine.alive: break
            ev=self.engine.recv()
            if ev is None: break
            self._q.put(ev)

    def _poll(self):
        try:
            while True: self._handle(self._q.get_nowait())
        except queue.Empty: pass
        self.root.after(40, self._poll)

    def _handle(self, ev):
        k=ev.get("event","")
        if   k=="pong":        self._on_pong()
        elif k=="scan_result": self._on_scan(ev.get("total",0))
        elif k=="progress":    self._on_progress(ev)
        elif k=="done":        self._on_done(ev)
        elif k=="topics":      self._on_topics(ev.get("topics",[]))
        elif k=="error":
            m=ev.get("msg",""); self._status(f"Error: {m}",ERR)
            log_append(self._log,f"Error: {m}",ERR)

    # ── UI ────────────────────────────────────────────────────────────────────
    def _build_ui(self):
        self.root.title("WallPimp"); self.root.configure(bg=BG)
        self.root.geometry("1120x720"); self.root.minsize(900,580)

        # Rail
        ro=tk.Frame(self.root,bg=PANEL,width=NAV_W); ro.pack(side="left",fill="y"); ro.pack_propagate(False)
        tk.Frame(ro,bg=ACCENT,width=2).pack(side="left",fill="y")
        rail=tk.Frame(ro,bg=PANEL); rail.pack(side="left",fill="both",expand=True)

        # Logo
        lf=tk.Frame(rail,bg=PANEL); lf.pack(fill="x",padx=20,pady=(24,4))
        tr=tk.Frame(lf,bg=PANEL); tr.pack(fill="x")
        tk.Label(tr,text="Wall",bg=PANEL,fg=TEXT,font=(DISPLAY,18,"bold")).pack(side="left")
        tk.Label(tr,text="Pimp",bg=PANEL,fg=ACCENT,font=(DISPLAY,18,"bold")).pack(side="left")
        vr=tk.Frame(lf,bg=PANEL); vr.pack(fill="x",pady=(2,0))
        tk.Label(vr,text="v2.1",bg=PANEL,fg=DIM,font=(MONO,TINY_SZ)).pack(side="left")
        tk.Label(vr,text="  ·  by 0xb0rn3",bg=PANEL,fg=MUTED,font=(MONO,TINY_SZ)).pack(side="left")
        _sep(rail,bg=BORDER).pack(fill="x",pady=(16,0))

        # Nav
        self._nav_btns={}; self._cur_page=""
        nav=tk.Frame(rail,bg=PANEL); nav.pack(fill="x",pady=(8,0))
        for key,icon,label in [("home","⌂","Dashboard"),("download","↓","Downloads"),
                                ("preview","⊞","Preview"),("unsplash","◈","Unsplash"),
                                ("slideshow","▶","Slideshow"),("settings","⚙","Settings")]:
            row=tk.Frame(nav,bg=PANEL,cursor="hand2"); row.pack(fill="x")
            ind=tk.Frame(row,bg=PANEL,width=3); ind.pack(side="left",fill="y")
            inn=tk.Frame(row,bg=PANEL,pady=11,padx=18); inn.pack(fill="x")
            il=tk.Label(inn,text=icon,bg=PANEL,fg=DIM,font=(MONO,12),width=2); il.pack(side="left")
            tl=tk.Label(inn,text=label,bg=PANEL,fg=MUTED,font=(UI_FONT,UI_SZ)); tl.pack(side="left",padx=(8,0))
            self._nav_btns[key]={"row":row,"ind":ind,"inner":inn,"icon":il,"text":tl}
            for ww in (row,inn,il,tl):
                ww.bind("<Button-1>",lambda e,k=key:self._nav(k))
                ww.bind("<Enter>",lambda e,k=key:self._nhov(k,True))
                ww.bind("<Leave>",lambda e,k=key:self._nhov(k,False))

        # Footer
        ft=tk.Frame(rail,bg=PANEL); ft.pack(side="bottom",fill="x")
        _sep(ft,bg=BORDER).pack(fill="x")
        sf=tk.Frame(ft,bg=PANEL,padx=16,pady=10); sf.pack(fill="x")
        dr2=tk.Frame(sf,bg=PANEL); dr2.pack(fill="x")
        self._sdot=StatusDot(dr2,size=6,bg=PANEL); self._sdot.pack(side="left")
        self._slbl=tk.Label(dr2,text=" Connecting...",bg=PANEL,fg=DIM,font=(MONO,TINY_SZ))
        self._slbl.pack(side="left",padx=(4,0))
        _sep(ft,bg=BORDER).pack(fill="x")
        br=tk.Frame(ft,bg=PANEL,padx=16,pady=12); br.pack(fill="x")
        for t in ["github.com/0xb0rn3/wallpimp","contact@oxborn3.com","oxborn3.com"]:
            tk.Label(br,text=t,bg=PANEL,fg=DIM,font=(MONO,TINY_SZ),cursor="hand2").pack(fill="x",pady=1)

        tk.Frame(self.root,bg=BORDER,width=1).pack(side="left",fill="y")
        self._content=tk.Frame(self.root,bg=BG); self._content.pack(side="right",fill="both",expand=True)
        self._pages={}
        self._build_home(); self._build_download(); self._build_preview()
        self._build_unsplash(); self._build_slideshow(); self._build_settings()
        self._nav("home")

    def _status(self, msg, color=MUTED):
        self._slbl.config(text=f" {msg}",fg=color)
        if color==SUCCESS:   self._sdot.set_color(SUCCESS)
        elif color==ERR:     self._sdot.set_color(ERR)
        elif color==WARN:    self._sdot.set_color(WARN,animate=True)
        else:                self._sdot.set_color(DIM)

    def _nhov(self, key, enter):
        if key==self._cur_page: return
        p=self._nav_btns[key]; bg2=CARD_H if enter else PANEL
        for w in ("row","inner"): p[w].config(bg=bg2)
        p["icon"].config(bg=bg2,fg=ACCENT if enter else DIM)
        p["text"].config(bg=bg2,fg=TEXT2 if enter else MUTED)

    def _nav(self, page):
        for p in self._pages.values(): p.pack_forget()
        for k,p in self._nav_btns.items():
            a=k==page; bg2=CARD if a else PANEL
            p["ind"].config(bg=ACCENT if a else PANEL)
            for w in ("row","inner"): p[w].config(bg=bg2)
            p["icon"].config(bg=bg2,fg=ACCENT if a else DIM)
            p["text"].config(bg=bg2,fg=TEXT if a else MUTED)
        self._cur_page=page; self._pages[page].pack(fill="both",expand=True)
        if page=="preview" and HAS_PIL: self._preview.load_thumbnails()

    def _page(self, name):
        f=tk.Frame(self._content,bg=BG); self._pages[name]=f; return f

    def _inner(self, page, px=32, py=28):
        f=tk.Frame(page,bg=BG,padx=px,pady=py); f.pack(fill="both",expand=True); return f

    def _heading(self, parent, title, subtitle=""):
        r=tk.Frame(parent,bg=BG); r.pack(fill="x")
        tk.Label(r,text=title,bg=BG,fg=TEXT,font=(DISPLAY,HEAD_SZ,"bold")).pack(side="left")
        if subtitle:
            tk.Label(r,text=f"  {subtitle}",bg=BG,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="left",pady=(3,0))
        sc=tk.Canvas(parent,height=2,bd=0,highlightthickness=0,bg=BG); sc.pack(fill="x",pady=(10,20))
        def _ds(e=None):
            w=sc.winfo_width()
            if w<2: return
            sc.delete("all")
            for i in range(min(w,60)):
                t=i/max(1,min(w,60)-1); c=_lerp(ACCENT,BORDER,t)
                sc.create_rectangle(int(i*w/min(w,60)),0,int((i+1)*w/min(w,60)),2,fill=c,outline="")
        sc.bind("<Configure>", _ds)

    def _card(self, parent, px=20, py=18):
        return tk.Frame(parent,bg=CARD,padx=px,pady=py,highlightthickness=1,highlightbackground=BORDER)

    # ── Home ──────────────────────────────────────────────────────────────────
    def _build_home(self):
        page=self._page("home"); inner=self._inner(page)
        self._heading(inner,"Dashboard","WallPimp Control Center")
        grid=tk.Frame(inner,bg=BG); grid.pack(fill="x")
        for c in range(2): grid.columnconfigure(c,weight=1)
        tiles=[("↓","Download Library","Fetch all 19 curated repos + Unsplash","download",True,ACCENT),
               ("⊞","Preview","Browse and preview your wallpaper collection","preview",False,SUCCESS),
               ("◈","Unsplash","Search by keyword, browse topics, grab randoms","unsplash",False,ACCENT2),
               ("▶","Slideshow","Manage the wallpaper rotation service","slideshow",False,ACCENT3)]
        for i,(ic,ti,de,tg,hi,co) in enumerate(tiles):
            r,c=divmod(i,2); cd=self._card(grid,px=22,py=20)
            cd.grid(row=r,column=c,padx=8,pady=8,sticky="nsew")
            hd=tk.Frame(cd,bg=CARD); hd.pack(fill="x")
            tk.Label(hd,text=ic,bg=CARD,fg=co,font=(MONO,16)).pack(side="left")
            tk.Label(hd,text=f"  {ti}",bg=CARD,fg=TEXT,font=(UI_FONT,11,"bold")).pack(side="left")
            tk.Label(cd,text=de,bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ),wraplength=260,
                     justify="left").pack(fill="x",pady=(6,14))
            _btn(cd,"Open  →",lambda t=tg:self._nav(t),accent=hi,small=True).pack(anchor="w")
        ic=tk.Frame(inner,bg=CARD,padx=16,pady=12,highlightthickness=1,highlightbackground=BORDER)
        ic.pack(fill="x",pady=(16,0)); ir=tk.Frame(ic,bg=CARD); ir.pack(fill="x")
        tk.Label(ir,text="📁",bg=CARD,fg=MUTED,font=(MONO,10)).pack(side="left")
        self._home_dir_lbl=tk.Label(ir,text=f"  {self._cfg['wallpaper_dir']}",bg=CARD,fg=DIM,font=(MONO,SMALL_SZ))
        self._home_dir_lbl.pack(side="left",fill="x",expand=True)

    # ── Download (Stop & Resume) ──────────────────────────────────────────────
    def _build_download(self):
        page=self._page("download"); inner=self._inner(page)
        self._heading(inner,"Download Wallpapers","19 curated repos + Unsplash")
        dr=tk.Frame(inner,bg=BG); dr.pack(fill="x",pady=(0,12))
        tk.Label(dr,text="Save to",bg=BG,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(side="left")
        self._dl_dir_var=tk.StringVar(value=self._cfg["wallpaper_dir"])
        tk.Label(dr,textvariable=self._dl_dir_var,bg=BG,fg=TEXT2,font=(MONO,SMALL_SZ)).pack(side="left",padx=(10,0))
        _btn(dr,"Browse",self._dl_chdir,small=True).pack(side="right")

        ar=tk.Frame(inner,bg=BG); ar.pack(fill="x",pady=(0,16))
        self._btn_scan=_btn(ar,"⟳  Scan",self._do_scan); self._btn_scan.pack(side="left",padx=(0,6))
        self._btn_full=_btn(ar,"↓  Full Library",self._dl_full,accent=True); self._btn_full.pack(side="left",padx=(0,6))
        self._btn_cust=_btn(ar,"↓  Custom",self._dl_custom); self._btn_cust.pack(side="left",padx=(0,6))
        self._btn_stop=_btn(ar,"■  Stop",self._do_stop,danger=True)
        self._btn_resume=_btn(ar,"▶  Resume",self._do_resume,warn=True)

        self._scan_var=tk.StringVar(value="")
        tk.Label(inner,textvariable=self._scan_var,bg=BG,fg=ACCENT,font=(MONO,11,"bold")).pack(anchor="w",pady=(0,14))

        pc=self._card(inner,py=20); pc.pack(fill="x")
        tr=tk.Frame(pc,bg=CARD); tr.pack(fill="x")
        self._prog_title=tk.StringVar(value="Idle")
        tk.Label(tr,textvariable=self._prog_title,bg=CARD,fg=TEXT,font=(MONO,MONO_SZ,"bold")).pack(side="left")
        self._speed_var=tk.StringVar(value="")
        tk.Label(tr,textvariable=self._speed_var,bg=CARD,fg=ACCENT,font=(MONO,SMALL_SZ,"bold")).pack(side="right")
        self._prog_bar=GradientBar(pc); self._prog_bar.pack(fill="x",pady=(10,6))
        self._prog_stats=tk.StringVar(value=""); self._eta_var=tk.StringVar(value="")
        sr=tk.Frame(pc,bg=CARD); sr.pack(fill="x")
        tk.Label(sr,textvariable=self._prog_stats,bg=CARD,fg=MUTED,font=(MONO,SMALL_SZ)).pack(side="left")
        tk.Label(sr,textvariable=self._eta_var,bg=CARD,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="right")

        lh=tk.Frame(inner,bg=BG); lh.pack(fill="x",pady=(16,6))
        tk.Label(lh,text="Activity Log",bg=BG,fg=MUTED,font=(UI_FONT,SMALL_SZ,"bold")).pack(side="left")
        lf,self._log=_log_widget(inner,h=7); lf.pack(fill="both",expand=True)

    def _set_dl_btns(self, mode):
        for b in (self._btn_stop,self._btn_resume): b.pack_forget()
        if mode=="idle":
            for b in (self._btn_scan,self._btn_full,self._btn_cust): b.config(state="normal")
        elif mode=="downloading":
            for b in (self._btn_scan,self._btn_full,self._btn_cust): b.config(state="disabled")
            self._btn_stop.pack(side="left",padx=(6,0))
        elif mode=="stopped":
            for b in (self._btn_scan,self._btn_full,self._btn_cust): b.config(state="normal")
            self._btn_resume.pack(side="left",padx=(6,0))

    def _dl_chdir(self):
        d=filedialog.askdirectory(initialdir=self._cfg["wallpaper_dir"])
        if d:
            self._cfg["wallpaper_dir"]=d; self._dl_dir_var.set(d)
            self._home_dir_lbl.config(text=f"  {d}"); self._preview.set_dir(d); self._save_cfg()

    def _do_scan(self):
        self._scan_var.set("Scanning..."); self._status("Scanning...",WARN)
        log_append(self._log,"Scanning all 19 repos + Unsplash topics...",WARN)
        self.engine.send({"cmd":"scan"})

    def _on_pong(self):
        self._status("Engine connected",SUCCESS)
        log_append(self._log,"Engine connected and ready.",SUCCESS)

    def _on_scan(self, total):
        self._scan_total=total; self._scan_var.set(f"  {total:,} wallpapers available")
        self._status(f"Scan complete — {total:,} available",SUCCESS)
        log_append(self._log,f"Scan complete: {total:,} wallpapers available.",SUCCESS)

    def _dl_full(self):
        if self._busy: return
        self._begin_dl(0)

    def _dl_custom(self):
        if self._busy: return
        dlg=tk.Toplevel(self.root); dlg.title("Custom Download"); dlg.configure(bg=BG)
        dlg.geometry("340x180"); dlg.resizable(False,False); dlg.transient(self.root); dlg.grab_set()
        dlg.update_idletasks()
        dlg.geometry(f"+{self.root.winfo_x()+(self.root.winfo_width()-340)//2}+{self.root.winfo_y()+(self.root.winfo_height()-180)//2}")
        f=tk.Frame(dlg,bg=BG,padx=30,pady=20); f.pack(fill="both",expand=True)
        tk.Label(f,text="How many wallpapers?",bg=BG,fg=TEXT,font=(UI_FONT,11,"bold")).pack(pady=(0,12))
        e=_entry(f,w=14); e.pack(ipady=7); e.insert(0,"500"); e.focus_set(); e.select_range(0,tk.END)
        def go():
            try: n=int(e.get().strip()); assert n>0
            except: messagebox.showerror("Invalid","Enter a positive number.",parent=dlg); return
            dlg.destroy(); self._begin_dl(n)
        _btn(f,"Download",go,accent=True).pack(pady=(14,0))
        e.bind("<Return>",lambda _:go()); dlg.bind("<Escape>",lambda _:dlg.destroy())

    def _begin_dl(self, target):
        self._busy=True; self._stopped=False; self._dl_target=target
        self._dl_start=time.time(); self._dl_last_new=0
        self._prog_bar.set(0); self._prog_title.set("DOWNLOADING ...")
        self._prog_stats.set(""); self._speed_var.set(""); self._eta_var.set("")
        self._status("Downloading...",WARN); self._set_dl_btns("downloading")
        lab=f"target: {target}" if target else "full library"
        log_append(self._log,f"Starting download ({lab})...",WARN)
        cmd={"cmd":"download","wdir":self._cfg["wallpaper_dir"],"workers":int(self._cfg["download_workers"])}
        if target>0: cmd["target"]=target
        self._dl_last_cmd=cmd; self.engine.send(cmd)

    def _do_stop(self):
        if not self._busy: return
        self._stopped=True; self._busy=False
        log_append(self._log,f"Stopped by user at {self._dl_last_new:,} new.",WARN)
        self._prog_title.set(f"STOPPED  ({self._dl_last_new:,} downloaded)")
        self._speed_var.set(""); self._eta_var.set("")
        self._status("Download stopped",WARN); self._set_dl_btns("stopped")
        threading.Thread(target=self._restart_engine,daemon=True).start()

    def _do_resume(self):
        if self._busy or not self._stopped: return
        cmd=self._dl_last_cmd
        if not cmd: log_append(self._log,"Nothing to resume.",MUTED); return
        already=self._dl_last_new; old_tgt=cmd.get("target",0)
        remaining = max(1, old_tgt-already) if old_tgt>0 else 0
        log_append(self._log,f"Resuming download"+(f" ({remaining:,} remaining)" if remaining else "")+"...",WARN)
        self._begin_dl(remaining)

    def _on_progress(self, ev):
        if self._stopped: return
        nw=ev.get("new",0); dp=ev.get("dupes",0); er=ev.get("errors",0)
        sp=ev.get("speed",0.0); msg=ev.get("msg","")
        self._dl_last_new=nw
        total=self._dl_target or self._scan_total
        pct=min(100,int(nw/total*100)) if total>0 else 0
        self._prog_bar.set(pct)
        self._prog_title.set(f"DOWNLOADING  {nw:,} / {total:,}  ({pct}%)" if total else f"DOWNLOADING  {nw:,}")
        self._prog_stats.set(f"{nw:,} new  ·  {dp:,} dupes  ·  {er:,} errors")
        if sp>0:
            self._speed_var.set(f"{sp:.1f} files/s")
            if total and sp>0:
                eta=max(0,(total-nw)/sp)
                self._eta_var.set(f"ETA {eta:.0f}s" if eta<60 else f"ETA {eta/60:.0f}m" if eta<3600 else f"ETA {eta/3600:.1f}h")
        if msg: log_append(self._log,msg,MUTED)

    def _on_done(self, ev):
        if self._stopped: return
        self._busy=False; nw=ev.get("new",0); dp=ev.get("dupes",0); er=ev.get("errors",0); el=ev.get("elapsed",0.0)
        self._prog_bar.set(100); self._prog_title.set("Complete")
        self._prog_stats.set(f"{nw:,} new  ·  {dp:,} dupes  ·  {er:,} errors")
        self._speed_var.set(""); self._eta_var.set(f"{el:.0f}s" if el else "")
        self._status(f"Done — {nw:,} new wallpapers saved",SUCCESS); self._set_dl_btns("idle")
        log_append(self._log,f"Done: {nw:,} new, {dp:,} dupes, {er:,} errors"+(f"  ({el:.0f}s)" if el else ""),SUCCESS)

    # ── Preview ───────────────────────────────────────────────────────────────
    def _build_preview(self):
        page=self._page("preview"); inner=self._inner(page)
        self._heading(inner,"Preview","Browse your wallpaper collection")
        self._preview=PreviewPanel(inner,self._cfg["wallpaper_dir"],set_wp_cb=self._set_wp)
        self._preview.frame.pack(fill="both",expand=True)

    def _set_wp(self, path):
        self._status(f"Setting: {Path(path).name}",WARN)
        log_append(self._log,f"Set wallpaper: {Path(path).name}",SUCCESS)
        try:
            if OS=="Linux":
                uri=f"file://{path}"
                subprocess.run(["gsettings","set","org.gnome.desktop.background","picture-uri",uri],capture_output=True)
                subprocess.run(["gsettings","set","org.gnome.desktop.background","picture-uri-dark",uri],capture_output=True)
            elif OS=="Darwin":
                subprocess.run(["osascript","-e",f'tell application "System Events" to tell every desktop to set picture to "{path}"'],capture_output=True)
            elif OS=="Windows":
                import ctypes; ctypes.windll.user32.SystemParametersInfoW(20,0,path,3)
            self._status(f"Wallpaper set: {Path(path).name}",SUCCESS)
        except Exception as ex:
            self._status(f"Could not set wallpaper: {ex}",ERR)

    # ── Unsplash ──────────────────────────────────────────────────────────────
    def _build_unsplash(self):
        page=self._page("unsplash"); inner=self._inner(page)
        self._heading(inner,"Unsplash","High-quality photos")
        nb=ttk.Notebook(inner); nb.pack(fill="both",expand=True)
        st=tk.Frame(nb,bg=BG,padx=18,pady=18); nb.add(st,text="  Search  "); self._build_search(st)
        tt=tk.Frame(nb,bg=BG,padx=18,pady=18); nb.add(tt,text="  Topics  "); self._build_topics(tt)
        rt=tk.Frame(nb,bg=BG,padx=18,pady=18); nb.add(rt,text="  Random  "); self._build_random(rt)

    def _build_search(self, parent):
        cd=self._card(parent,px=18,py=16); cd.pack(fill="x",pady=(0,12))
        r=tk.Frame(cd,bg=CARD); r.pack(fill="x")
        tk.Label(r,text="Query",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(side="left")
        self._sq=tk.StringVar(); e=_entry(r,self._sq,w=24); e.pack(side="left",padx=(12,12),ipady=5)
        tk.Label(r,text="Page",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(side="left")
        self._spg=tk.IntVar(value=1); _spinbox(r,self._spg,1,999,5).pack(side="left",padx=(8,12),ipady=4)
        _btn(r,"Search & Download",self._do_search,accent=True,small=True).pack(side="left")
        e.bind("<Return>",lambda _:self._do_search())
        dr=tk.Frame(parent,bg=BG); dr.pack(fill="x")
        tk.Label(dr,text="Save to:",bg=BG,fg=MUTED,font=(MONO,SMALL_SZ)).pack(side="left")
        self._sdir=tk.StringVar(value=str(Path(self._cfg["wallpaper_dir"])/"unsplash"/"search"))
        tk.Label(dr,textvariable=self._sdir,bg=BG,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="left",padx=8)
        _btn(dr,"Change",lambda:self._pick_dir(self._sdir),small=True).pack(side="left")

    def _do_search(self):
        q=self._sq.get().strip()
        if not q: messagebox.showwarning("Search","Enter a keyword first."); return
        self.engine.send({"cmd":"search","query":q,"page":self._spg.get(),
                          "dest":str(Path(self._sdir.get())/q),"workers":int(self._cfg["download_workers"])})
        self._status(f"Searching: {q}...",WARN)
        log_append(self._log,f"Unsplash search: '{q}' page {self._spg.get()}",WARN)

    def _build_topics(self, parent):
        top=tk.Frame(parent,bg=BG); top.pack(fill="x",pady=(0,10))
        _btn(top,"Load Topics",self._load_topics,accent=True).pack(side="left")
        lf=tk.Frame(parent,bg=BG); lf.pack(fill="both",expand=True,pady=(0,10))
        self._tlb,sb=_listbox(lf,h=9); self._tlb.pack(side="left",fill="both",expand=True); sb.pack(side="right",fill="y")
        self._tdir=tk.StringVar(value=str(Path(self._cfg["wallpaper_dir"])/"unsplash"/"topics"))
        bot=tk.Frame(parent,bg=BG); bot.pack(fill="x")
        _btn(bot,"Download Selected",self._dl_topic,accent=True,small=True).pack(side="left",padx=(0,8))
        tk.Label(bot,text="dir:",bg=BG,fg=MUTED,font=(MONO,SMALL_SZ)).pack(side="left")
        tk.Label(bot,textvariable=self._tdir,bg=BG,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="left",padx=6)
        _btn(bot,"Change",lambda:self._pick_dir(self._tdir),small=True).pack(side="left")

    def _load_topics(self): self.engine.send({"cmd":"topics"}); self._status("Loading topics...",WARN)

    def _on_topics(self, topics):
        self._tlb.delete(0,tk.END); self._topic_slugs=[]
        for t in topics:
            s=t.get("slug",""); ti=t.get("title",s); tp=t.get("total_photos",0)
            self._tlb.insert(tk.END,f"  {ti:<30}  {tp:>6,} photos"); self._topic_slugs.append(s)
        self._status(f"Loaded {len(topics)} topics",SUCCESS)
        log_append(self._log,f"Loaded {len(topics)} Unsplash topics.",SUCCESS)

    def _dl_topic(self):
        sel=self._tlb.curselection()
        if not sel: messagebox.showinfo("Topics","Select a topic first."); return
        slug=self._topic_slugs[sel[0]]; dest=str(Path(self._tdir.get())/slug)
        self.engine.send({"cmd":"topic_photos","slug":slug,"page":1,"dest":dest,
                          "workers":int(self._cfg["download_workers"])})
        self._status(f"Downloading topic: {slug}...",WARN)
        log_append(self._log,f"Downloading Unsplash topic: {slug}",WARN)

    def _build_random(self, parent):
        cd=self._card(parent,px=18,py=16); cd.pack(fill="x")
        tk.Label(cd,text="Grab random landscape wallpapers from Unsplash.",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(anchor="w",pady=(0,14))
        r=tk.Frame(cd,bg=CARD); r.pack(fill="x",pady=(0,12))
        tk.Label(r,text="Count (1–30)",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(side="left")
        self._rcnt=tk.IntVar(value=15); _spinbox(r,self._rcnt,1,30,5).pack(side="left",padx=(10,0),ipady=4)
        dr=tk.Frame(cd,bg=CARD); dr.pack(fill="x",pady=(0,14))
        tk.Label(dr,text="Save to:",bg=CARD,fg=MUTED,font=(MONO,SMALL_SZ)).pack(side="left")
        self._rdir=tk.StringVar(value=str(Path(self._cfg["wallpaper_dir"])/"unsplash"/"random"))
        tk.Label(dr,textvariable=self._rdir,bg=CARD,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="left",padx=8)
        _btn(dr,"Change",lambda:self._pick_dir(self._rdir),small=True).pack(side="left")
        _btn(cd,"Download Random",self._dl_rand,accent=True).pack(anchor="w")

    def _dl_rand(self):
        self.engine.send({"cmd":"random","count":self._rcnt.get(),"dest":self._rdir.get(),
                          "workers":int(self._cfg["download_workers"])})
        self._status("Downloading randoms...",WARN)
        log_append(self._log,f"Downloading {self._rcnt.get()} random wallpapers...",WARN)

    def _pick_dir(self, var):
        d=filedialog.askdirectory(initialdir=var.get())
        if d: var.set(d)

    # ── Slideshow ─────────────────────────────────────────────────────────────
    def _build_slideshow(self):
        page=self._page("slideshow"); inner=self._inner(page)
        self._heading(inner,"Slideshow Control","Wallpaper rotation")
        cd=self._card(inner); cd.pack(fill="x")
        tk.Label(cd,text="Rotation Interval",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w")
        tk.Label(cd,text="Time between changes (seconds)",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(anchor="w",pady=(2,8))
        self._intvar=tk.IntVar(value=int(self._cfg.get("slideshow_interval",300)))
        _spinbox(cd,self._intvar,10,86400,8).pack(anchor="w",ipady=5)
        _sep(cd,bg=BORDER).pack(fill="x",pady=(18,18))
        tk.Label(cd,text="Service Control",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w",pady=(0,10))
        br=tk.Frame(cd,bg=CARD); br.pack(anchor="w")
        if OS=="Linux":
            _btn(br,"Save Session Env",self._ss_env,small=True).pack(side="left",padx=(0,8))
            _btn(br,"Start (systemd)",self._ss_start_lin,accent=True,small=True).pack(side="left",padx=(0,8))
            _btn(br,"Stop",self._ss_stop_lin,danger=True,small=True).pack(side="left")
        elif OS=="Darwin":
            _btn(br,"Start (launchd)",self._ss_start_mac,accent=True,small=True).pack(side="left",padx=(0,8))
            _btn(br,"Stop",self._ss_stop_mac,danger=True,small=True).pack(side="left")
        else:
            _btn(br,"Start (Task Sched)",self._ss_start_win,accent=True,small=True).pack(side="left",padx=(0,8))
            _btn(br,"Stop",self._ss_stop_win,danger=True,small=True).pack(side="left")
        ht=tk.Frame(cd,bg=CARD); ht.pack(fill="x",pady=(18,0))
        tk.Label(ht,text="CLI:  wallpimp --daemon",bg=CARD,fg=DIM,font=(MONO,SMALL_SZ)).pack(side="left")

    def _ss_savi(self): self._cfg["slideshow_interval"]=self._intvar.get(); self._save_cfg()
    def _ss_env(self): messagebox.showinfo("Session Env","Run from a graphical terminal:\n\nwallpimp → Slideshow → Save session env\n\nCaptures D-Bus vars for systemd.")
    def _ss_start_lin(self):
        self._ss_savi()
        try: subprocess.Popen(["systemctl","--user","start","wallpimp-slideshow.service"]); self._status("Slideshow started (systemd)",SUCCESS)
        except Exception as e: messagebox.showerror("Slideshow",str(e))
    def _ss_stop_lin(self):
        try: subprocess.Popen(["systemctl","--user","stop","wallpimp-slideshow.service"]); self._status("Slideshow stopped",MUTED)
        except Exception as e: messagebox.showerror("Slideshow",str(e))
    def _ss_start_mac(self):
        self._ss_savi(); p=Path.home()/"Library"/"LaunchAgents"/"com.wallpimp.slideshow.plist"
        if p.exists(): subprocess.Popen(["launchctl","load",str(p)]); self._status("Slideshow started (launchd)",SUCCESS)
        else: messagebox.showinfo("Slideshow","Run wallpimp from Terminal first.")
    def _ss_stop_mac(self): subprocess.Popen(["launchctl","unload",str(Path.home()/"Library"/"LaunchAgents"/"com.wallpimp.slideshow.plist")]); self._status("Slideshow stopped",MUTED)
    def _ss_start_win(self):
        self._ss_savi()
        try: subprocess.Popen(["schtasks","/run","/tn","WallPimp Slideshow"],shell=True); self._status("Slideshow started",SUCCESS)
        except Exception as e: messagebox.showerror("Slideshow",str(e))
    def _ss_stop_win(self):
        try: subprocess.Popen(["schtasks","/end","/tn","WallPimp Slideshow"],shell=True); self._status("Slideshow stopped",MUTED)
        except Exception as e: messagebox.showerror("Slideshow",str(e))

    # ── Settings ──────────────────────────────────────────────────────────────
    def _build_settings(self):
        page=self._page("settings"); inner=self._inner(page)
        self._heading(inner,"Settings","Configuration")
        cd=self._card(inner,py=22); cd.pack(fill="x")
        tk.Label(cd,text="Wallpaper Directory",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w")
        dr=tk.Frame(cd,bg=CARD); dr.pack(fill="x",pady=(6,20))
        self._sdir2=tk.StringVar(value=self._cfg["wallpaper_dir"])
        tk.Label(dr,textvariable=self._sdir2,bg=CARD,fg=TEXT,font=(MONO,SMALL_SZ)).pack(side="left")
        _btn(dr,"Browse",self._s_pick,small=True).pack(side="left",padx=10)
        tk.Label(cd,text="Download Workers",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w")
        tk.Label(cd,text="Concurrent threads (1–32)",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(anchor="w",pady=(2,6))
        self._sw=tk.IntVar(value=int(self._cfg.get("download_workers",16)))
        _spinbox(cd,self._sw,1,32,6).pack(anchor="w",ipady=5)
        tk.Frame(cd,bg=CARD,height=16).pack()
        tk.Label(cd,text="Slideshow Interval",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w")
        tk.Label(cd,text="Seconds between changes",bg=CARD,fg=MUTED,font=(UI_FONT,SMALL_SZ)).pack(anchor="w",pady=(2,6))
        self._si=tk.IntVar(value=int(self._cfg.get("slideshow_interval",300)))
        _spinbox(cd,self._si,10,86400,8).pack(anchor="w",ipady=5)
        tk.Frame(cd,bg=CARD,height=20).pack()
        _btn(cd,"Save Settings",self._save_settings,accent=True).pack(anchor="w")
        inf=tk.Frame(inner,bg=CARD,padx=16,pady=14,highlightthickness=1,highlightbackground=BORDER)
        inf.pack(fill="x",pady=(14,0))
        pil_s="Pillow ✓" if HAS_PIL else "Pillow ✗ (no preview)"
        tk.Label(inf,text=f"System: {OS}  ·  Python {sys.version.split()[0]}  ·  {pil_s}  ·  Font: {MONO}",
                 bg=CARD,fg=DIM,font=(MONO,TINY_SZ)).pack(anchor="w")
        ab=tk.Frame(inner,bg=CARD,padx=16,pady=14,highlightthickness=1,highlightbackground=BORDER)
        ab.pack(fill="x",pady=(8,0))
        tk.Label(ab,text="WallPimp v2.1",bg=CARD,fg=TEXT2,font=(UI_FONT,UI_SZ,"bold")).pack(anchor="w")
        for l in ["Developer:  0xb0rn3","Email:      contact@oxborn3.com",
                   "Web:        oxborn3.com","Repo:       github.com/0xb0rn3/wallpimp"]:
            tk.Label(ab,text=l,bg=CARD,fg=MUTED,font=(MONO,SMALL_SZ)).pack(anchor="w",pady=1)

    def _s_pick(self):
        d=filedialog.askdirectory(initialdir=self._cfg["wallpaper_dir"])
        if d: self._sdir2.set(d)

    def _save_settings(self):
        self._cfg["wallpaper_dir"]=self._sdir2.get()
        self._cfg["download_workers"]=self._sw.get()
        self._cfg["slideshow_interval"]=self._si.get()
        self._save_cfg(); self._dl_dir_var.set(self._cfg["wallpaper_dir"])
        self._home_dir_lbl.config(text=f"  {self._cfg['wallpaper_dir']}")
        self._preview.set_dir(self._cfg["wallpaper_dir"])
        self._status("Settings saved",SUCCESS); messagebox.showinfo("Settings","Settings saved.")

    def on_close(self):
        if self.engine: self.engine.stop()
        self.root.destroy()


def main():
    root=tk.Tk(); root.withdraw()
    try: root.tk.call("tk","scaling",root.winfo_fpixels("1i")/72.0)
    except Exception: pass
    app=WallPimpGUI(root)
    root.protocol("WM_DELETE_WINDOW",app.on_close); root.update_idletasks()
    sw,sh=root.winfo_screenwidth(),root.winfo_screenheight()
    root.geometry(f"1120x720+{(sw-1120)//2}+{(sh-720)//2}")
    root.deiconify(); root.mainloop()

if __name__=="__main__": main()
