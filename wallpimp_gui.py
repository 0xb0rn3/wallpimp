#!/usr/bin/env python3
# wallpimp_gui.py — WallPimp graphical interface
# Developer : 0xb0rn3  |  oxbv1@proton.me  |  github.com/0xb0rn3/wallpimp
#
# Requires: pip install pywebview
# Windows:  Edge WebView2 (built into Windows 10/11)
# macOS:    System WebKit
# Linux:    pip install pywebview[gtk]

import os, sys, json, shutil, socket as _socket, subprocess as _subprocess
import threading, time, random
from pathlib import Path

# ── auto-install pywebview ────────────────────────────────────────────────────
def _ensure_deps():
    try:
        import webview  # noqa
    except ImportError:
        print("[wallpimp] Installing pywebview...")
        args = [] if sys.platform == "win32" else ["--break-system-packages"]
        _subprocess.check_call(
            [sys.executable, "-m", "pip", "install"] + args + ["pywebview"],
            stdout=_subprocess.DEVNULL, stderr=_subprocess.DEVNULL,
        )
_ensure_deps()
import webview

# ── platform ──────────────────────────────────────────────────────────────────
_OS = ("windows" if sys.platform == "win32"
       else "macos" if sys.platform == "darwin"
       else "linux")

# ── paths ─────────────────────────────────────────────────────────────────────
if _OS == "windows":
    _CFG_DIR = Path(os.environ.get("APPDATA", Path.home())) / "wallpimp"
elif _OS == "macos":
    _CFG_DIR = Path.home() / "Library" / "Application Support" / "wallpimp"
else:
    _CFG_DIR = Path.home() / ".config" / "wallpimp"

_CFG_FILE  = _CFG_DIR / "config.json"
_HASH_DB   = _CFG_DIR / "hashes.json"
_WIN_TASK  = "WallPimp Slideshow"
_PLIST_DIR = Path.home() / "Library" / "LaunchAgents"
_PLIST_FILE = _PLIST_DIR / "com.wallpimp.slideshow.plist"

_DEFAULT_CFG = {
    "wallpaper_dir":      str(Path.home() / "Pictures" / "Wallpapers"),
    "slideshow_interval": 300,
    "download_workers":   8,
}

_IMG_EXTS = {
    ".jpg",".jpeg",".png",".webp",".gif",".bmp",
    ".tiff",".tif",".heic",".heif",".avif",".jxl",
    ".svg",".ico",".psd",".raw",".arw",".cr2",
    ".nef",".orf",".dng",".exr",".hdr",".rgbe",
    ".pnm",".ppm",".pgm",".pbm",".pcx",".tga",
    ".xbm",".xpm",".wbmp",
}

# ── config ────────────────────────────────────────────────────────────────────
def load_config():
    if _CFG_FILE.exists():
        try:
            cfg = json.loads(_CFG_FILE.read_text())
            for k, v in _DEFAULT_CFG.items():
                cfg.setdefault(k, v)
            return cfg
        except Exception:
            pass
    return dict(_DEFAULT_CFG)

def save_config(cfg):
    _CFG_DIR.mkdir(parents=True, exist_ok=True)
    _CFG_FILE.write_text(json.dumps(cfg, indent=2))

# ── wallpaper setter ──────────────────────────────────────────────────────────
def set_wallpaper(path):
    if _OS == "windows":
        try:
            import ctypes
            return bool(ctypes.windll.user32.SystemParametersInfoW(20, 0, str(path), 3))
        except Exception:
            return False
    if _OS == "macos":
        script = (
            'tell application "System Events"\n'
            '  tell every desktop\n'
            f'    set picture to "{path}"\n'
            '  end tell\n'
            'end tell'
        )
        try:
            _subprocess.run(["osascript","-e",script], capture_output=True, check=True)
            return True
        except Exception:
            return False
    de = (os.environ.get("XDG_CURRENT_DESKTOP","") or
          os.environ.get("DESKTOP_SESSION","")).lower()
    if "gnome" in de:
        uri = f"file://{path}"
        for cmd in [
            ["gsettings","set","org.gnome.desktop.background","picture-uri",uri],
            ["gsettings","set","org.gnome.desktop.background","picture-uri-dark",uri],
        ]:
            try: _subprocess.run(cmd, capture_output=True)
            except Exception: pass
        return True
    if "xfce" in de:
        try:
            _subprocess.run(
                ["xfconf-query","-c","xfce4-desktop",
                 "-p","/backdrop/screen0/monitor0/workspace0/last-image",
                 "-s",str(path)], capture_output=True)
            return True
        except Exception:
            return False
    return False

# ── Go engine bridge ──────────────────────────────────────────────────────────
class _Engine:
    def __init__(self, workers):
        self._mu   = threading.Lock()
        self._proc = None
        self._sock = None
        self._fobj = None
        self._connect(workers)

    @staticmethod
    def _find_binary():
        name = "wallpimp-engine.exe" if _OS == "windows" else "wallpimp-engine"
        for c in [
            Path(sys.argv[0]).resolve().parent / name,
            Path(shutil.which(name) or ""),
        ]:
            if c.exists():
                return str(c)
        return None

    def _connect(self, workers):
        binary = self._find_binary()
        if not binary:
            raise FileNotFoundError(
                "wallpimp-engine not found. "
                "Build: cd src && go build -o ../wallpimp-engine ."
            )
        _CFG_DIR.mkdir(parents=True, exist_ok=True)
        self._proc = _subprocess.Popen(
            [binary, str(_HASH_DB), str(workers)],
            stdout=_subprocess.PIPE,
            stderr=_subprocess.DEVNULL,
        )
        sock_path = self._proc.stdout.readline().decode().strip()
        if not sock_path:
            raise RuntimeError("Engine did not report socket path.")
        for _ in range(50):
            if Path(sock_path).exists():
                break
            time.sleep(0.05)
        if not hasattr(_socket, "AF_UNIX"):
            raise OSError("Unix sockets unavailable. Requires Windows 10 build 17063+.")
        raw = _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM)
        raw.connect(sock_path)
        raw.settimeout(None)
        self._sock = raw
        self._fobj = raw.makefile("r", encoding="utf-8")

    def send(self, cmd):
        with self._mu:
            self._sock.sendall((json.dumps(cmd) + "\n").encode())

    def recv(self):
        line = self._fobj.readline()
        if not line:
            raise ConnectionError("Engine closed.")
        return json.loads(line)

    def rpc(self, cmd):
        self.send(cmd)
        FINAL = {"done","error","bye","pong","scan_result",
                 "topics","collections","resolution"}
        while True:
            ev = self.recv()
            if ev.get("event") in FINAL:
                return ev

    def stream(self, cmd, on_progress=None):
        self.send(cmd)
        while True:
            ev = self.recv()
            if ev.get("event") == "progress":
                if on_progress:
                    on_progress(ev)
            elif ev.get("event") in ("done","error"):
                return ev

    def shutdown(self):
        try: self.send({"cmd":"shutdown"})
        except Exception: pass
        try: self._sock.close()
        except Exception: pass
        if self._proc:
            try: self._proc.wait(timeout=3)
            except Exception: self._proc.kill()

# ── Python API ────────────────────────────────────────────────────────────────
class WallPimpAPI:
    def __init__(self):
        self._engine  = None
        self._window  = None
        self._cfg     = load_config()
        self._busy    = False

    def _eng(self):
        if self._engine is None:
            self._engine = _Engine(int(self._cfg.get("download_workers", 8)))
        return self._engine

    def _push(self, event, data=None):
        if self._window:
            payload = json.dumps({"event": event, "data": data or {}})
            self._window.evaluate_js(f"window._wpEvent({payload})")

    def _run(self, fn, *args):
        threading.Thread(target=fn, args=args, daemon=True).start()

    # settings
    def get_config(self):
        self._cfg = load_config()
        return self._cfg

    def save_config(self, cfg):
        for k in _DEFAULT_CFG:
            if k in cfg:
                self._cfg[k] = cfg[k]
        save_config(self._cfg)
        return {"ok": True}

    def browse_folder(self):
        result = self._window.create_file_dialog(
            webview.FOLDER_DIALOG,
            directory=self._cfg.get("wallpaper_dir", str(Path.home())),
        )
        if result:
            return result[0]
        return None

    # downloads
    def scan_library(self):
        try:
            ev = self._eng().rpc({"cmd":"scan"})
            return {"total": ev.get("total", 0)}
        except Exception as e:
            return {"error": str(e)}

    def download(self, target=0):
        if self._busy:
            self._push("error", {"msg": "A download is already running."})
            return
        self._busy = True
        def _run():
            try:
                self._push("download_start", {})
                cfg = self._cfg
                def on_prog(ev):
                    self._push("download_progress", {
                        "new":   ev.get("new", 0),
                        "dupes": ev.get("dupes", 0),
                        "total": target,
                    })
                ev = self._eng().stream(
                    {"cmd":"download",
                     "wdir":    cfg["wallpaper_dir"],
                     "workers": int(cfg["download_workers"]),
                     "target":  target},
                    on_progress=on_prog,
                )
                self._push("download_done", {
                    "new":    ev.get("new",0),
                    "dupes":  ev.get("dupes",0),
                    "errors": ev.get("errors",0),
                })
            except Exception as e:
                self._push("error", {"msg": str(e)})
            finally:
                self._busy = False
        self._run(_run)

    # unsplash
    def unsplash_resolution(self):
        try:
            return self._eng().rpc({"cmd":"resolution"})
        except Exception as e:
            return {"error": str(e)}

    def unsplash_topics(self):
        try:
            ev  = self._eng().rpc({"cmd":"topics"})
            raw = ev.get("Topics") or ev.get("topics") or []
            return {"topics": [
                {"id":    t.get("Slug",  t.get("slug",  "")),
                 "title": t.get("Title", t.get("title", "")),
                 "total": t.get("Total", t.get("total_photos", 0))}
                for t in raw
            ]}
        except Exception as e:
            return {"error": str(e)}

    def unsplash_collections(self, page=1):
        try:
            ev  = self._eng().rpc({"cmd":"collections","page":page})
            raw = ev.get("Cols") or ev.get("cols") or []
            return {"collections": [
                {"id":    str(c.get("ID",    c.get("id",    ""))),
                 "title": c.get("Title",     c.get("title", "")),
                 "total": c.get("Total",     c.get("total_photos", 0))}
                for c in raw
            ], "page": page}
        except Exception as e:
            return {"error": str(e)}

    def unsplash_download(self, kind, param="", page=1, count=15):
        if self._busy:
            self._push("error", {"msg": "A download is already running."})
            return
        self._busy = True
        def _run():
            try:
                dest    = self._cfg["wallpaper_dir"]
                workers = int(self._cfg.get("download_workers", 8))
                self._push("download_start", {"kind": kind})
                def on_prog(ev):
                    self._push("download_progress", {
                        "new":   ev.get("new", 0),
                        "dupes": ev.get("dupes", 0),
                        "total": 0,
                    })
                cmds = {
                    "search":     {"cmd":"search",      "query":  param,  "page":page, "dest":dest,"workers":workers},
                    "topic":      {"cmd":"topic_photos","slug":   param,  "page":page, "dest":dest,"workers":workers},
                    "collection": {"cmd":"col_photos",  "col_id": param,  "page":page, "dest":dest,"workers":workers},
                    "random":     {"cmd":"random",      "count":  count,              "dest":dest,"workers":workers},
                }
                if kind not in cmds:
                    self._push("error", {"msg": f"Unknown kind: {kind}"}); return
                ev = self._eng().stream(cmds[kind], on_progress=on_prog)
                self._push("download_done", {
                    "new":    ev.get("new",0),
                    "dupes":  ev.get("dupes",0),
                    "errors": ev.get("errors",0),
                    "kind":   kind,
                })
            except Exception as e:
                self._push("error", {"msg": str(e)})
            finally:
                self._busy = False
        self._run(_run)

    # random wallpaper
    def set_random_wallpaper(self):
        wdir  = Path(self._cfg["wallpaper_dir"])
        walls = [p for p in wdir.rglob("*") if p.suffix.lower() in _IMG_EXTS]
        if not walls:
            return {"error": "No wallpapers found. Download some first."}
        wall = random.choice(walls)
        ok   = set_wallpaper(str(wall))
        return {"ok": True, "file": wall.name} if ok else \
               {"error": f"Could not set wallpaper on {_OS}."}

    # slideshow
    def slideshow_action(self, action):
        if _OS == "linux":   return self._svc_linux(action)
        if _OS == "macos":   return self._svc_macos(action)
        if _OS == "windows": return self._svc_windows(action)
        return {"error": f"Unsupported OS: {_OS}"}

    def _svc_linux(self, action):
        svc = "wallpimp-slideshow.service"
        try:
            if action == "start":
                self._write_linux_unit()
                r = _subprocess.run(["systemctl","--user","start",svc],
                                    capture_output=True, text=True)
                return {"ok": r.returncode==0,
                        "msg":"Started" if r.returncode==0 else r.stderr.strip()}
            elif action == "stop":
                _subprocess.run(["systemctl","--user","stop",svc],capture_output=True)
                return {"ok":True,"msg":"Stopped"}
            elif action == "enable":
                self._write_linux_unit()
                _subprocess.run(["systemctl","--user","enable",svc],capture_output=True)
                return {"ok":True,"msg":"Autostart enabled"}
            elif action == "disable":
                _subprocess.run(["systemctl","--user","disable",svc],capture_output=True)
                return {"ok":True,"msg":"Autostart disabled"}
            elif action == "status":
                r = _subprocess.run(["systemctl","--user","is-active",svc],
                                    capture_output=True,text=True)
                return {"ok":True,"msg":r.stdout.strip()}
        except Exception as e:
            return {"error":str(e)}
        return {"error":"Unknown action"}

    def _write_linux_unit(self):
        d = Path.home()/".config"/"systemd"/"user"
        d.mkdir(parents=True,exist_ok=True)
        unit = (
            "[Unit]\nDescription=WallPimp Slideshow\n"
            "PartOf=graphical-session.target\nAfter=graphical-session.target\n\n"
            "[Service]\nType=simple\n"
            f"ExecStart={sys.executable} "
            f"{Path(sys.argv[0]).resolve().parent/'wallpimp'} --daemon\n"
            f"EnvironmentFile={_CFG_DIR/'session.env'}\n"
            "Restart=on-failure\nRestartSec=10\n\n"
            "[Install]\nWantedBy=graphical-session.target\n"
        )
        (d/"wallpimp-slideshow.service").write_text(unit)
        _subprocess.run(["systemctl","--user","daemon-reload"],capture_output=True)

    def _svc_macos(self, action):
        try:
            if action in ("start","enable"):
                log = Path.home()/"Library"/"Logs"/"wallpimp-slideshow.log"
                plist = (
                    '<?xml version="1.0" encoding="UTF-8"?>\n'
                    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"\n'
                    '  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
                    '<plist version="1.0"><dict>\n'
                    '  <key>Label</key><string>com.wallpimp.slideshow</string>\n'
                    '  <key>ProgramArguments</key><array>\n'
                    f'    <string>{sys.executable}</string>\n'
                    f'    <string>{Path(sys.argv[0]).resolve().parent/"wallpimp"}</string>\n'
                    '    <string>--daemon</string>\n'
                    '  </array>\n'
                    '  <key>RunAtLoad</key><true/>\n'
                    '  <key>KeepAlive</key><true/>\n'
                    '  <key>StandardErrorPath</key>\n'
                    f'  <string>{log}</string>\n'
                    '</dict></plist>\n'
                )
                _PLIST_DIR.mkdir(parents=True,exist_ok=True)
                _PLIST_FILE.write_text(plist)
                _subprocess.run(["launchctl","load",str(_PLIST_FILE)],capture_output=True)
                return {"ok":True,"msg":"Slideshow started"}
            elif action in ("stop","disable"):
                _subprocess.run(["launchctl","unload",str(_PLIST_FILE)],capture_output=True)
                if action=="disable" and _PLIST_FILE.exists():
                    _PLIST_FILE.unlink()
                return {"ok":True,"msg":"Slideshow stopped"}
            elif action == "status":
                r = _subprocess.run(
                    ["launchctl","list","com.wallpimp.slideshow"],
                    capture_output=True,text=True)
                return {"ok":True,"msg":"Running" if r.returncode==0 else "Stopped"}
        except Exception as e:
            return {"error":str(e)}
        return {"error":"Unknown action"}

    def _svc_windows(self, action):
        try:
            exe = (f'"{sys.executable}" '
                   f'"{Path(sys.argv[0]).resolve().parent/"wallpimp"}" --daemon')
            if action == "start":
                _subprocess.run(
                    ["schtasks","/create","/f","/tn",_WIN_TASK,
                     "/tr",exe,"/sc","onlogon","/rl","limited"],
                    capture_output=True)
                r = _subprocess.run(["schtasks","/run","/tn",_WIN_TASK],
                                    capture_output=True,text=True)
                return {"ok":r.returncode==0,
                        "msg":"Started" if r.returncode==0 else r.stderr.strip()}
            elif action == "stop":
                _subprocess.run(
                    ["taskkill","/f","/fi",f"WINDOWTITLE eq {_WIN_TASK}"],
                    capture_output=True)
                return {"ok":True,"msg":"Stop signal sent"}
            elif action == "enable":
                r = _subprocess.run(
                    ["schtasks","/create","/f","/tn",_WIN_TASK,
                     "/tr",exe,"/sc","onlogon","/rl","limited"],
                    capture_output=True,text=True)
                return {"ok":r.returncode==0,
                        "msg":"Autostart enabled" if r.returncode==0 else r.stderr.strip()}
            elif action == "disable":
                _subprocess.run(["schtasks","/delete","/f","/tn",_WIN_TASK],
                                 capture_output=True)
                return {"ok":True,"msg":"Autostart removed"}
            elif action == "status":
                r = _subprocess.run(
                    ["schtasks","/query","/tn",_WIN_TASK,"/fo","list"],
                    capture_output=True,text=True)
                msg = "Running" if "Running" in r.stdout else \
                      "Ready"   if r.returncode==0 else "Not installed"
                return {"ok":True,"msg":msg}
        except Exception as e:
            return {"error":str(e)}
        return {"error":"Unknown action"}

    # hash db
    def get_hash_count(self):
        try:
            if _HASH_DB.exists():
                db = json.loads(_HASH_DB.read_text())
                return {"count": len(db)}
        except Exception:
            pass
        return {"count": 0}

    def cleanup_hashes(self):
        try:
            if not _HASH_DB.exists():
                return {"removed": 0}
            db     = json.loads(_HASH_DB.read_text())
            before = len(db)
            db     = {h: p for h, p in db.items() if Path(p).exists()}
            _HASH_DB.write_text(json.dumps(db, indent=2))
            return {"removed": before - len(db)}
        except Exception as e:
            return {"error": str(e)}

    def quit(self):
        if self._engine:
            self._engine.shutdown()
        if self._window:
            self._window.destroy()

# ── HTML / CSS / JS (embedded) ────────────────────────────────────────────────
HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>WallPimp</title>
<style>
:root{--bg:#0d0d0d;--panel:#141414;--border:#1e1e1e;--cyan:#00e5cc;
--cyan-dim:#007a6e;--green:#39ff14;--red:#ff3b3b;--yellow:#ffd600;
--text:#e0e0e0;--muted:#555;--r:6px;--f:'Consolas','Fira Code','Courier New',monospace}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:var(--f);font-size:13px;
height:100vh;display:flex;flex-direction:column;overflow:hidden;user-select:none}
#tb{background:#080808;padding:10px 16px;display:flex;align-items:center;gap:12px;
border-bottom:1px solid var(--border);-webkit-app-region:drag;flex-shrink:0}
#logo{color:var(--cyan);font-size:10.5px;line-height:1.15;white-space:pre;font-weight:bold}
#tbr{margin-left:auto;display:flex;align-items:center;gap:8px;-webkit-app-region:no-drag}
.badge{background:var(--border);color:var(--muted);padding:2px 7px;border-radius:3px;font-size:10px}
#lay{display:flex;flex:1;overflow:hidden}
#sb{width:176px;background:var(--panel);border-right:1px solid var(--border);
display:flex;flex-direction:column;padding:12px 0;flex-shrink:0}
.ni{display:flex;align-items:center;gap:10px;padding:9px 16px;cursor:pointer;
color:var(--muted);transition:all .15s;font-size:12px;border-left:2px solid transparent}
.ni:hover{color:var(--text);background:#1a1a1a}
.ni.on{color:var(--cyan);background:#0d1f1e;border-left-color:var(--cyan)}
.nicon{width:16px;text-align:center;font-size:13px}
#sbf{margin-top:auto;padding:12px 16px;border-top:1px solid var(--border)}
#main{flex:1;overflow-y:auto;padding:20px 24px;background:var(--bg)}
#main::-webkit-scrollbar{width:5px}
#main::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
.pg{display:none}.pg.on{display:block}
h2{color:var(--cyan);font-size:14px;margin-bottom:16px;display:flex;align-items:center;gap:8px}
h2::after{content:'';flex:1;height:1px;background:var(--border)}
.card{background:var(--panel);border:1px solid var(--border);border-radius:var(--r);
padding:16px;margin-bottom:14px}
.ct{color:var(--cyan);font-size:11px;text-transform:uppercase;letter-spacing:1px;margin-bottom:10px}
.btn{display:inline-flex;align-items:center;gap:6px;padding:7px 14px;border-radius:var(--r);
cursor:pointer;font-family:var(--f);font-size:12px;border:none;transition:all .15s;font-weight:500}
.btn:disabled{opacity:.4;cursor:not-allowed}
.bp{background:var(--cyan);color:#000}.bp:hover:not(:disabled){background:#00fff5}
.bs{background:var(--border);color:var(--text)}.bs:hover:not(:disabled){background:#2a2a2a}
.bd{background:#2a0000;color:var(--red);border:1px solid #500}.bd:hover:not(:disabled){background:#3a0000}
.bg{background:#002a00;color:var(--green);border:1px solid #050}
.brow{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
input[type=text],input[type=number],select{background:#0a0a0a;border:1px solid var(--border);
color:var(--text);padding:7px 10px;border-radius:var(--r);font-family:var(--f);
font-size:12px;width:100%;outline:none;transition:border-color .15s}
input:focus,select:focus{border-color:var(--cyan-dim)}
label{color:var(--muted);font-size:11px;margin-bottom:4px;display:block}
.fld{margin-bottom:12px}
.fr{display:flex;gap:8px;align-items:flex-end}.fr .fld{flex:1;margin-bottom:0}
.pbg{background:var(--border);border-radius:3px;height:6px;overflow:hidden}
.pf{height:100%;background:var(--cyan);border-radius:3px;transition:width .2s;width:0%}
.pf.ind{width:30%;animation:slide 1.2s linear infinite}
@keyframes slide{0%{transform:translateX(-100%)}100%{transform:translateX(450%)}}
.ps{display:flex;justify-content:space-between;color:var(--muted);font-size:11px;margin-top:5px}
.dot{width:7px;height:7px;border-radius:50%;display:inline-block;margin-right:5px}
.dg{background:var(--green);box-shadow:0 0 5px var(--green)}.dr{background:var(--red)}.dm{background:var(--muted)}
#tc{position:fixed;bottom:16px;right:16px;display:flex;flex-direction:column;gap:6px;
z-index:9999;pointer-events:none}
.t{padding:8px 14px;border-radius:var(--r);font-size:12px;max-width:320px;animation:fi .2s ease}
.tok{background:#001a00;border:1px solid #1a5200;color:var(--green)}
.ter{background:#1a0000;border:1px solid #520000;color:var(--red)}
.tin{background:#001a1a;border:1px solid #004a4a;color:var(--cyan)}
@keyframes fi{from{opacity:0;transform:translateY(8px)}to{opacity:1}}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:8px;margin-top:10px}
.gi{background:var(--panel);border:1px solid var(--border);border-radius:var(--r);
padding:10px 12px;cursor:pointer;transition:all .15s}
.gi:hover{border-color:var(--cyan-dim);background:#0d1f1e}
.git{color:var(--text);font-size:12px;margin-bottom:3px}
.gis{color:var(--muted);font-size:10px}
.sts{display:flex;align-items:center;gap:8px;padding:10px 14px;border-radius:var(--r);
background:var(--panel);border:1px solid var(--border);margin-bottom:14px;font-size:12px}
.sp{display:inline-block;width:13px;height:13px;border:2px solid var(--border);
border-top-color:var(--cyan);border-radius:50%;animation:spin .6s linear infinite;vertical-align:middle}
@keyframes spin{to{transform:rotate(360deg)}}
.tabs{display:flex;gap:2px;margin-bottom:16px;background:var(--panel);
border:1px solid var(--border);border-radius:var(--r);padding:3px;width:fit-content}
.tab{font-size:11px;padding:5px 12px}
</style>
</head>
<body>
<div id="tb">
  <pre id="logo">&#x2588;&#x2588;&#x2557;    &#x2588;&#x2588;&#x2557; &#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2557;     &#x2588;&#x2588;&#x2557;     &#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557; &#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2588;&#x2557;   &#x2588;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557;&#xa;&#x2588;&#x2588;&#x2551;    &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557; &#x2588;&#x2588;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2588;&#x2588;&#x2557;&#xa;&#x2588;&#x2588;&#x2551; &#x2588;&#x2557; &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2554;&#x255d;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2554;&#x2588;&#x2588;&#x2588;&#x2588;&#x2554;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2554;&#x255d;&#xa;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2550;&#x255d; &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2551;&#x2554;&#x2588;&#x2588;&#x2554;&#x255d;&#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2554;&#x2550;&#x2550;&#x2550;&#x255d; &#xa;&#x255a;&#x2588;&#x2588;&#x2588;&#x2554;&#x2588;&#x2588;&#x2588;&#x2554;&#x255d;&#x2588;&#x2588;&#x2551;  &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2588;&#x2557;&#x2588;&#x2588;&#x2551;     &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2551; &#x255a;&#x2550;&#x255d; &#x2588;&#x2588;&#x2551;&#x2588;&#x2588;&#x2551;     &#xa; &#x255a;&#x2550;&#x2550;&#x255d;&#x255a;&#x2550;&#x2550;&#x255d; &#x255a;&#x2550;&#x255d;  &#x255a;&#x2550;&#x255d;&#x255a;&#x2550;&#x2550;&#x2550;&#x2550;&#x2550;&#x255d;&#x255a;&#x2550;&#x2550;&#x2550;&#x2550;&#x2550;&#x255d;&#x255a;&#x2550;&#x255d;     &#x255a;&#x2550;&#x255d;&#x255a;&#x2550;&#x255d;     &#x255a;&#x2550;&#x255d;&#x255a;&#x2550;&#x255d;     </pre>
  <div id="tbr"><span class="badge" id="plat">windows</span></div>
</div>
<div id="lay">
  <nav id="sb">
    <div class="ni on" data-p="download"><span class="nicon">&#x2B07;</span>Download</div>
    <div class="ni" data-p="unsplash"><span class="nicon">&#x1F5BC;</span>Unsplash</div>
    <div class="ni" data-p="slideshow"><span class="nicon">&#x25B6;</span>Slideshow</div>
    <div class="ni" data-p="settings"><span class="nicon">&#x2699;</span>Settings</div>
    <div class="ni" data-p="random"><span class="nicon">&#x1F3B2;</span>Random</div>
    <div id="sbf"><div style="color:var(--muted);font-size:10px">0xb0rn3 &middot; wallpimp</div></div>
  </nav>
  <div id="main">

    <!-- Download -->
    <div class="pg on" id="pg-download">
      <h2>&#x2B07; Download Wallpapers</h2>
      <div class="card">
        <div class="ct">Library Scan</div>
        <p style="color:var(--muted);font-size:12px;margin-bottom:10px">Count available wallpapers across all sources before downloading.</p>
        <div class="brow">
          <button class="btn bs" id="bscan">&#x27F3; Scan sources</button>
          <span id="scan-res" style="color:var(--cyan);font-size:12px;padding:7px 0"></span>
        </div>
      </div>
      <div class="card">
        <div class="ct">Full Library</div>
        <p style="color:var(--muted);font-size:12px;margin-bottom:10px">Download everything from all repos and Unsplash topics.</p>
        <button class="btn bp" id="bdlf">&#x2B07; Download full library</button>
      </div>
      <div class="card">
        <div class="ct">Custom Amount</div>
        <div class="fr">
          <div class="fld"><label>Number of wallpapers</label><input type="number" id="cust-n" value="100" min="1"></div>
          <button class="btn bp" id="bdlc" style="flex-shrink:0">&#x2B07; Download</button>
        </div>
      </div>
      <div class="card" id="dl-prog" style="display:none">
        <div class="ct">Progress</div>
        <div style="margin:8px 0"><div class="pbg"><div class="pf ind" id="dl-bar"></div></div>
        <div class="ps"><span id="dl-new">0 new</span><span id="dl-dup">0 dupes</span><span id="dl-pct"></span></div></div>
      </div>
    </div>

    <!-- Unsplash -->
    <div class="pg" id="pg-unsplash">
      <h2>&#x1F5BC; Unsplash</h2>
      <div id="unsp-res" style="color:var(--muted);font-size:11px;margin-bottom:12px"></div>
      <div class="tabs">
        <button class="btn bp tab unsp-tab" data-t="search">Search</button>
        <button class="btn bs tab unsp-tab" data-t="topics">Topics</button>
        <button class="btn bs tab unsp-tab" data-t="cols">Collections</button>
        <button class="btn bs tab unsp-tab" data-t="rand">Random</button>
      </div>
      <div class="unsp-pnl" id="up-search">
        <div class="card">
          <div class="fr">
            <div class="fld"><label>Query</label><input type="text" id="sq" placeholder="e.g. cyberpunk city"></div>
            <input type="number" id="sp" value="1" min="1" style="width:64px;flex-shrink:0" title="Page">
            <button class="btn bp" id="bsearch" style="flex-shrink:0">Search</button>
          </div>
        </div>
      </div>
      <div class="unsp-pnl" id="up-topics" style="display:none">
        <div class="card">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
            <span style="color:var(--muted);font-size:11px">Click a topic to download</span>
            <button class="btn bs" id="bltop" style="font-size:11px;padding:5px 10px">Load topics</button>
          </div>
          <div class="grid" id="top-grid"><div style="color:var(--muted);font-size:11px">Click "Load topics"</div></div>
        </div>
        <div class="card" id="top-sel" style="display:none">
          <div class="ct" id="top-sel-title"></div>
          <div class="fr">
            <div class="fld"><label>Page</label><input type="number" id="top-pg" value="1" min="1"></div>
            <button class="btn bp" id="btdl" style="flex-shrink:0">Download page</button>
          </div>
        </div>
      </div>
      <div class="unsp-pnl" id="up-cols" style="display:none">
        <div class="card">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
            <div style="display:flex;gap:6px;align-items:center">
              <span style="color:var(--muted);font-size:11px">Page</span>
              <input type="number" id="clp" value="1" min="1" style="width:55px">
            </div>
            <button class="btn bs" id="blcol" style="font-size:11px;padding:5px 10px">Load collections</button>
          </div>
          <div class="grid" id="col-grid"><div style="color:var(--muted);font-size:11px">Click "Load collections"</div></div>
        </div>
        <div class="card" id="col-sel" style="display:none">
          <div class="ct" id="col-sel-title"></div>
          <div class="fr">
            <div class="fld"><label>Page</label><input type="number" id="col-pg" value="1" min="1"></div>
            <button class="btn bp" id="bcdl" style="flex-shrink:0">Download page</button>
          </div>
        </div>
      </div>
      <div class="unsp-pnl" id="up-rand" style="display:none">
        <div class="card">
          <div class="fr">
            <div class="fld"><label>Photos (1&#x2013;30)</label><input type="number" id="rn" value="15" min="1" max="30"></div>
            <button class="btn bp" id="brand" style="flex-shrink:0">&#x1F3B2; Fetch random</button>
          </div>
        </div>
      </div>
      <div class="card" id="unsp-prog" style="display:none;margin-top:14px">
        <div class="ct" id="unsp-prog-title">Downloading&#x2026;</div>
        <div class="pbg"><div class="pf ind" id="unsp-bar"></div></div>
        <div class="ps"><span id="unsp-new">0 new</span><span id="unsp-dup">0 dupes</span></div>
      </div>
    </div>

    <!-- Slideshow -->
    <div class="pg" id="pg-slideshow">
      <h2>&#x25B6; Slideshow Control</h2>
      <div class="sts">
        <span class="dot dm" id="svc-dot"></span>
        <span id="svc-txt">Unknown</span>
        <button class="btn bs" id="bsvcr" style="margin-left:auto;font-size:11px;padding:4px 9px">Refresh</button>
      </div>
      <div class="card">
        <div class="ct">Service</div>
        <div class="brow">
          <button class="btn bg" id="bsvcs">&#x25B6; Start</button>
          <button class="btn bd" id="bsvcx">&#x25FC; Stop</button>
          <button class="btn bs" id="bsvce">Enable autostart</button>
          <button class="btn bs" id="bsvcd">Disable autostart</button>
        </div>
      </div>
      <div class="card" id="linux-note" style="display:none">
        <div class="ct">Linux D-Bus Setup</div>
        <p style="color:var(--muted);font-size:12px;margin-bottom:8px">
          Before first use, run <b style="color:var(--cyan)">Save session env</b> from a desktop terminal:
        </p>
        <code style="color:var(--cyan);font-size:11px">wallpimp &#x2192; Slideshow control &#x2192; 1. Save session env</code>
      </div>
    </div>

    <!-- Settings -->
    <div class="pg" id="pg-settings">
      <h2>&#x2699; Settings</h2>
      <div class="card">
        <div class="ct">Storage</div>
        <div class="fld">
          <label>Wallpaper directory</label>
          <div class="fr">
            <input type="text" id="cfg-dir">
            <button class="btn bs" id="bbrowse" style="flex-shrink:0">Browse&#x2026;</button>
          </div>
        </div>
      </div>
      <div class="card">
        <div class="ct">Slideshow</div>
        <div class="fld"><label>Interval (seconds)</label><input type="number" id="cfg-int" min="5"></div>
      </div>
      <div class="card">
        <div class="ct">Downloads</div>
        <div class="fld"><label>Parallel workers (1&#x2013;32)</label><input type="number" id="cfg-wk" min="1" max="32"></div>
      </div>
      <div class="card">
        <div class="ct">Hash Database</div>
        <div style="display:flex;align-items:center;gap:12px;margin-bottom:10px">
          <span style="color:var(--muted);font-size:12px">Tracked: <span id="hcount" style="color:var(--text)">&#x2014;</span></span>
          <button class="btn bs" id="bhr" style="font-size:11px;padding:4px 9px">Refresh</button>
        </div>
        <button class="btn bd" id="bclean">&#x1F5D1; Cleanup orphaned hashes</button>
      </div>
      <div class="brow" style="margin-top:4px">
        <button class="btn bp" id="bsave">&#x1F4BE; Save settings</button>
      </div>
    </div>

    <!-- Random -->
    <div class="pg" id="pg-random">
      <h2>&#x1F3B2; Random Wallpaper</h2>
      <div class="card">
        <p style="color:var(--muted);font-size:12px;margin-bottom:14px">Pick a random wallpaper from your collection and set it as your desktop background.</p>
        <button class="btn bp" id="brand2" style="font-size:14px;padding:10px 20px">&#x1F3B2; Set random wallpaper</button>
        <div id="rand-res" style="margin-top:14px;font-size:12px;display:none"></div>
      </div>
    </div>

  </div>
</div>
<div id="tc"></div>

<script>
var _busy=false,_dlt=0,_sTopic=null,_sCol=null;

window._wpEvent=function(p){
  var e=p.event,d=p.data;
  if(e==='download_start')dlStart(d);
  else if(e==='download_progress')dlProg(d);
  else if(e==='download_done')dlDone(d);
  else if(e==='error')toast(d.msg||'Error','ter');
};

// nav
document.querySelectorAll('.ni').forEach(function(el){
  el.addEventListener('click',function(){
    document.querySelectorAll('.ni').forEach(function(n){n.classList.remove('on')});
    document.querySelectorAll('.pg').forEach(function(p){p.classList.remove('on')});
    el.classList.add('on');
    document.getElementById('pg-'+el.dataset.p).classList.add('on');
    if(el.dataset.p==='settings')loadCfg();
    if(el.dataset.p==='slideshow')refreshSvc();
    if(el.dataset.p==='unsplash')loadUnspRes();
  });
});

// toast
function toast(msg,cls,dur){
  dur=dur||3500;
  var c=document.getElementById('tc'),t=document.createElement('div');
  t.className='t '+(cls||'tin');t.textContent=msg;c.appendChild(t);
  setTimeout(function(){t.style.opacity='0';t.style.transition='opacity .3s';
    setTimeout(function(){t.remove()},300)},dur);
}

// download
document.getElementById('bscan').addEventListener('click',async function(){
  var b=this;b.disabled=true;b.innerHTML='<span class="sp"></span> Scanning\u2026';
  document.getElementById('scan-res').textContent='';
  var r=await window.pywebview.api.scan_library();
  b.disabled=false;b.innerHTML='&#x27F3; Scan sources';
  if(r.error){toast(r.error,'ter');return;}
  var n=r.total||0;
  document.getElementById('scan-res').textContent=n>0?n.toLocaleString()+' available':'Unknown count';
});

document.getElementById('bdlf').addEventListener('click',function(){
  if(_busy){toast('Download already running','tin');return;}
  _dlt=0;window.pywebview.api.download(0);
});
document.getElementById('bdlc').addEventListener('click',function(){
  if(_busy){toast('Download already running','tin');return;}
  _dlt=parseInt(document.getElementById('cust-n').value)||100;
  window.pywebview.api.download(_dlt);
});

function dlStart(d){
  _busy=true;
  document.getElementById('dl-prog').style.display='block';
  document.getElementById('unsp-prog').style.display='none';
  document.getElementById('dl-bar').className='pf ind';
  document.getElementById('dl-new').textContent='0 new';
  document.getElementById('dl-dup').textContent='0 dupes';
  document.getElementById('dl-pct').textContent='';
}
function dlProg(d){
  var n=d.new||0,du=d.dupes||0,t=d.total||_dlt;
  document.getElementById('dl-new').textContent=n.toLocaleString()+' new';
  document.getElementById('dl-dup').textContent=du.toLocaleString()+' dupes';
  var bar=document.getElementById('dl-bar');
  if(t>0){var p=Math.min((n+du)/t*100,100);bar.className='pf';bar.style.width=p.toFixed(1)+'%';
    document.getElementById('dl-pct').textContent=p.toFixed(0)+'%';}
  else{bar.className='pf ind';}
  if(document.getElementById('unsp-prog').style.display!=='none'){
    document.getElementById('unsp-new').textContent=n.toLocaleString()+' new';
    document.getElementById('unsp-dup').textContent=du.toLocaleString()+' dupes';
  }
}
function dlDone(d){
  _busy=false;var n=d.new||0;
  document.getElementById('dl-bar').className='pf';
  document.getElementById('dl-bar').style.width='100%';
  document.getElementById('dl-pct').textContent='100%';
  document.getElementById('unsp-prog').style.display='none';
  toast('Done \u2014 '+n.toLocaleString()+' new wallpapers','tok');
  setTimeout(function(){document.getElementById('dl-prog').style.display='none'},4000);
}

// unsplash tabs
document.querySelectorAll('.unsp-tab').forEach(function(b){
  b.addEventListener('click',function(){
    document.querySelectorAll('.unsp-tab').forEach(function(x){x.className='btn bs tab unsp-tab'});
    document.querySelectorAll('.unsp-pnl').forEach(function(p){p.style.display='none'});
    b.className='btn bp tab unsp-tab';
    document.getElementById('up-'+b.dataset.t).style.display='block';
  });
});

async function loadUnspRes(){
  var ev=await window.pywebview.api.unsplash_resolution();
  if(ev&&!ev.error){
    var rw=ev.res_w||ev.ResW||'?',rh=ev.res_h||ev.ResH||'?',
        dw=ev.dl_w||ev.DlW||'?',dh=ev.dl_h||ev.DlH||'?';
    document.getElementById('unsp-res').textContent='Screen '+rw+'\xd7'+rh+' \u2192 downloads '+dw+'\xd7'+dh;
  }
}

// search
document.getElementById('bsearch').addEventListener('click',function(){
  if(_busy){toast('Download already running','tin');return;}
  var q=document.getElementById('sq').value.trim();
  var pg=parseInt(document.getElementById('sp').value)||1;
  if(!q){toast('Enter a search query','tin');return;}
  startUDl('search',q,pg);
});
document.getElementById('sq').addEventListener('keydown',function(e){
  if(e.key==='Enter')document.getElementById('bsearch').click();
});

// topics
document.getElementById('bltop').addEventListener('click',async function(){
  var b=this;b.disabled=true;b.innerHTML='<span class="sp"></span>';
  var r=await window.pywebview.api.unsplash_topics();
  b.disabled=false;b.textContent='Load topics';
  if(r.error){toast(r.error,'ter');return;}
  var g=document.getElementById('top-grid');g.innerHTML='';
  (r.topics||[]).forEach(function(t){
    var el=document.createElement('div');el.className='gi';
    el.innerHTML='<div class="git">'+t.title+'</div><div class="gis">'+(t.total||0).toLocaleString()+' photos</div>';
    el.addEventListener('click',function(){
      _sTopic=t;
      document.getElementById('top-sel').style.display='block';
      document.getElementById('top-sel-title').textContent=t.title;
      document.getElementById('top-pg').value=1;
    });
    g.appendChild(el);
  });
});
document.getElementById('btdl').addEventListener('click',function(){
  if(!_sTopic||_busy){return;}
  startUDl('topic',_sTopic.id,parseInt(document.getElementById('top-pg').value)||1);
});

// collections
document.getElementById('blcol').addEventListener('click',async function(){
  var b=this;b.disabled=true;b.innerHTML='<span class="sp"></span>';
  var pg=parseInt(document.getElementById('clp').value)||1;
  var r=await window.pywebview.api.unsplash_collections(pg);
  b.disabled=false;b.textContent='Load collections';
  if(r.error){toast(r.error,'ter');return;}
  var g=document.getElementById('col-grid');g.innerHTML='';
  (r.collections||[]).forEach(function(c){
    var el=document.createElement('div');el.className='gi';
    el.innerHTML='<div class="git">'+c.title+'</div><div class="gis">'+(c.total||0).toLocaleString()+' photos</div>';
    el.addEventListener('click',function(){
      _sCol=c;
      document.getElementById('col-sel').style.display='block';
      document.getElementById('col-sel-title').textContent=c.title;
      document.getElementById('col-pg').value=1;
    });
    g.appendChild(el);
  });
});
document.getElementById('bcdl').addEventListener('click',function(){
  if(!_sCol||_busy){return;}
  startUDl('collection',_sCol.id,parseInt(document.getElementById('col-pg').value)||1);
});

// random unsplash
document.getElementById('brand').addEventListener('click',function(){
  if(_busy){toast('Download already running','tin');return;}
  var n=parseInt(document.getElementById('rn').value)||15;
  startUDl('random','',1,n);
});

function startUDl(kind,param,page,count){
  count=count||15;_busy=true;
  var c=document.getElementById('unsp-prog');
  document.getElementById('dl-prog').style.display='none';
  c.style.display='block';
  document.getElementById('unsp-prog-title').textContent=
    kind==='search'?'Searching "'+param+'"...':
    kind==='topic'?'Topic: '+(_sTopic?_sTopic.title:param)+'...':
    kind==='collection'?'Collection: '+(_sCol?_sCol.title:param)+'...':
    'Fetching random photos...';
  document.getElementById('unsp-bar').className='pf ind';
  document.getElementById('unsp-new').textContent='0 new';
  document.getElementById('unsp-dup').textContent='0 dupes';
  window.pywebview.api.unsplash_download(kind,param,page,count);
}

// slideshow
async function refreshSvc(){
  var r=await window.pywebview.api.slideshow_action('status');
  var dot=document.getElementById('svc-dot'),txt=document.getElementById('svc-txt');
  if(r.error){dot.className='dot dm';txt.textContent=r.error;return;}
  var m=r.msg||'Unknown',run=m.toLowerCase().includes('running')||m.toLowerCase().includes('active');
  dot.className=run?'dot dg':'dot dr';txt.textContent=m;
}
document.getElementById('bsvcr').addEventListener('click',refreshSvc);
['s','x','e','d'].forEach(function(a){
  var map={s:'start',x:'stop',e:'enable',d:'disable'};
  document.getElementById('bsvc'+a).addEventListener('click',async function(){
    var r=await window.pywebview.api.slideshow_action(map[a]);
    if(r.error)toast(r.error,'ter');else toast(r.msg||map[a],'tok');
    refreshSvc();
  });
});

// settings
async function loadCfg(){
  var c=await window.pywebview.api.get_config();
  document.getElementById('cfg-dir').value=c.wallpaper_dir||'';
  document.getElementById('cfg-int').value=c.slideshow_interval||300;
  document.getElementById('cfg-wk').value=c.download_workers||8;
  refreshHC();
}
async function refreshHC(){
  var r=await window.pywebview.api.get_hash_count();
  document.getElementById('hcount').textContent=r.count!==undefined?r.count.toLocaleString():'\u2014';
}
document.getElementById('bbrowse').addEventListener('click',async function(){
  var p=await window.pywebview.api.browse_folder();
  if(p)document.getElementById('cfg-dir').value=p;
});
document.getElementById('bsave').addEventListener('click',async function(){
  var r=await window.pywebview.api.save_config({
    wallpaper_dir:     document.getElementById('cfg-dir').value.trim(),
    slideshow_interval:parseInt(document.getElementById('cfg-int').value)||300,
    download_workers:  parseInt(document.getElementById('cfg-wk').value)||8,
  });
  if(r.ok)toast('Settings saved','tok');else toast(r.error||'Save failed','ter');
});
document.getElementById('bhr').addEventListener('click',refreshHC);
document.getElementById('bclean').addEventListener('click',async function(){
  var r=await window.pywebview.api.cleanup_hashes();
  if(r.error)toast(r.error,'ter');
  else{toast('Removed '+r.removed+' orphaned entries','tok');refreshHC();}
});

// random wallpaper
document.getElementById('brand2').addEventListener('click',async function(){
  var b=this;b.disabled=true;
  var r=await window.pywebview.api.set_random_wallpaper();
  b.disabled=false;
  var d=document.getElementById('rand-res');d.style.display='block';
  if(r.ok){
    d.innerHTML='<span style="color:var(--green)">\u2713</span> Set: <span style="color:var(--cyan)">'+r.file+'</span>';
    toast('Set: '+r.file,'tok');
  }else{
    d.innerHTML='<span style="color:var(--red)">\u2717 '+r.error+'</span>';
    toast(r.error,'ter');
  }
});

// init
window.addEventListener('pywebviewready',function(){
  var p=navigator.platform.toLowerCase();
  document.getElementById('plat').textContent=
    p.includes('win')?'windows':p.includes('mac')?'macos':'linux';
  if(p.includes('linux'))document.getElementById('linux-note').style.display='block';
});
</script>
</body>
</html>"""

# ── entry ─────────────────────────────────────────────────────────────────────
def main():
    api    = WallPimpAPI()
    window = webview.create_window(
        title            = "WallPimp",
        html             = HTML,
        js_api           = api,
        width            = 1020,
        height           = 680,
        min_size         = (780, 520),
        background_color = "#0d0d0d",
        easy_drag        = False,
    )
    api._window = window
    window.events.closing += lambda: api.quit()
    webview.start(debug=False)

if __name__ == "__main__":
    main()
