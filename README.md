# WallPimp - Wallpaper Manager

Cross-platform wallpaper manager for Linux, macOS, and Windows.  
Python handles the interactive terminal UI. A compiled Go engine handles all
downloads — GitHub archives and Unsplash — using native goroutines and a
persistent socket connection for maximum throughput with zero per-operation overhead.

## Architecture

```
wallpimp (Python)          wallpimp-engine (Go binary)
  Terminal UI  ──────────── newline-delimited JSON ────  Goroutine pool
  GUI (tkinter)        Unix socket / named pipe           GitHub downloader
  Menus & settings                                        Unsplash client
  Slideshow control                                       Hash database
  Wallpaper setter                                        Rate limiter
```

Python spawns the Go engine once on first use and holds a single persistent
socket connection for the entire session. All download concurrency happens inside
Go — no Python threads involved in the hot path.

The optional tkinter GUI (`wallpimp_gui.py`) communicates with the same engine
over the same socket — no separate backend needed.

## Features

- Hybrid Python + Go architecture — UI in Python, engine in Go
- **GUI mode** (tkinter) and **CLI mode** — choose at launch
- 19 curated wallpaper sources behind one seamless progress bar
- Full library or custom amount download with live source scanning
- GitHub rate-limit bypass (zip archive → git clone fallback, no tokens)
- Unsplash integration — search, topics, curated collections, random
- Unsplash sliding-window rate limiter (45 req/hr, auto-pause and resume)
- Auto screen resolution detection — downloads matched to display (up to 4K)
- Per-option save directory changeable at runtime
- MD5 hash dedup shared across all sources — one pool, zero cross-source duplicates
- Privilege escalation for system directories (sudo on Linux/macOS, UAC on Windows)
- Slideshow: systemd (Linux) · launchd (macOS) · Task Scheduler (Windows)
- Shuffle-queue slideshow — every wallpaper shown once before any repeats
- Configurable parallel download workers

## Requirements

| Component | Requirement |
|-----------|-------------|
| Python | 3.10+ (for `\|` union type hints) |
| Go | 1.21+ (to build the engine) |
| GUI (optional) | Python `tkinter` — ships with standard Python installs |
| Linux slideshow | GNOME or XFCE4 + systemd |
| macOS | 10.13+ High Sierra or later |
| Windows | Windows 10 or later |

## Project Structure

```
wallpimp                  # Python script (CLI — UI + wallpaper setters + slideshow)
wallpimp_gui.py           # Python script (GUI — tkinter front-end, same engine)
wallpimp_launch.py        # Launcher — prompts GUI / CLI choice (Linux/macOS)
setup                  # Bash — one-line installer for Linux / macOS
setup.ps1                 # One-line installer for Windows
src/
  go.mod                  # Go module
  main.go                 # Socket server + command dispatcher
  github.go               # GitHub archive downloader (goroutine pool)
  unsplash.go             # Unsplash client + rate limiter + image fetcher
  hash.go                 # Thread-safe MD5 hash database
  screen.go               # Screen resolution detection (all platforms)
  creds.go                # Obfuscated credential resolution (XOR + base64)
```

## Build

```bash
cd src
go build -o ../wallpimp-engine .
```

Cross-compile for other platforms:

```bash
# Windows (from Linux/macOS)
GOOS=windows GOARCH=amd64 go build -o ../wallpimp-engine.exe .

# macOS Apple Silicon
GOOS=darwin GOARCH=arm64 go build -o ../wallpimp-engine-arm64 .

# Linux ARM (e.g. Raspberry Pi)
GOOS=linux GOARCH=arm64 go build -o ../wallpimp-engine-arm64 .
```

The binary lands at the repo root alongside the `wallpimp` script.
The engine is auto-located and started on first use — no configuration needed.

---

## Installation

### Linux / macOS — one-line setup (recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup)
```

`setup` automatically:
- Detects your package manager (apt / dnf / pacman / zypper / brew)
- Checks and installs Go 1.21+ and Git if missing
- Clones the repository to `~/wallpimp`
- Builds the Go engine (`wallpimp-engine`)
- Installs Python dependencies (`requests`, `tqdm`)
- Prompts you to choose **GUI** or **CLI** at launch

After the prompt:

```
  ─────────────────────────────────────────────────────────────────
  How would you like to launch WallPimp?
  ─────────────────────────────────────────────────────────────────

    i)   Launch GUI  — graphical interface
   ii)   Stay on CLI — classic terminal UI

  Enter choice [i / ii]:
```

To re-run setup or update an existing installation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup)
```

It will pull the latest repo, rebuild the engine only if source has changed,
then show the launch prompt again.

#### Flags (skip the prompt)

```bash
# Force GUI launch
bash <(curl -fsSL .../setup) --gui

# Force CLI launch
bash <(curl -fsSL .../setup) --cli

# Pull + rebuild only, no launch
bash <(curl -fsSL .../setup) --update
```

#### tkinter (GUI prerequisite)

`tkinter` ships with the standard Python installer on most platforms. If the
GUI option shows as unavailable, install it with:

```bash
sudo apt-get install python3-tk   # Debian / Ubuntu / Kali
sudo dnf install python3-tkinter  # Fedora / RHEL
sudo pacman -S tk                 # Arch / ArchBang
sudo zypper install python3-tk    # openSUSE
brew install python-tk            # macOS (Homebrew)
```

Then re-run setup — the GUI option will appear automatically.

---

### Windows — one-line setup (recommended)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup.ps1 | iex
```

`setup.ps1` automatically:
- Checks and installs Python 3.10+, Go 1.21+, and Git via winget if missing
- Clones the repository to `%USERPROFILE%\wallpimp`
- Builds the Go engine (`wallpimp-engine.exe`)
- Installs Python dependencies
- Prompts you to choose **GUI** or **CLI** at launch (same prompt as Linux)

> **Do not close the window** while setup is running.

To re-run setup or update an existing installation, run the same command again —
it will pull the latest repo, rebuild the engine only if source has changed, and
show the launch prompt again.

If you prefer to run the script locally:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\setup.ps1
```

---

### Manual install (all platforms)

```bash
git clone --depth 1 https://github.com/0xb0rn3/wallpimp.git ~/wallpimp
cd ~/wallpimp/src && go build -o ../wallpimp-engine . && cd ..
chmod +x wallpimp wallpimp_launch.py
pip install requests tqdm
```

Then launch via the prompt:

```bash
python3 wallpimp_launch.py        # shows GUI / CLI choice
python3 wallpimp_launch.py --gui  # force GUI
python3 wallpimp_launch.py --cli  # force CLI
```

Or directly:

```bash
python3 wallpimp_gui.py   # GUI
python3 wallpimp          # CLI
```

---

## Launching after setup

Once installed, you can launch WallPimp any time with the same launcher:

```bash
# Linux / macOS — from the install directory
cd ~/wallpimp && python3 wallpimp_launch.py

# Or re-run setup (bash) — it skips all already-done steps and goes straight to the prompt
bash <(curl -fsSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup)
```

---

## GUI Overview

The tkinter GUI (`wallpimp_gui.py`) communicates with the same Go engine as the CLI.
All download logic and socket protocol are identical — only the front-end differs.

```
┌─────────────────────────────────────────────────────────────┐
│  WallPimp                                                    │
├────────────┬────────────────────────────────────────────────┤
│            │                                                │
│  ⌂ Home    │   Page content                                 │
│  ↓ Download│                                                │
│  ◈ Unsplash│                                                │
│  ▶ Slideshow                                                │
│  ⚙ Settings│                                                │
│            │                                                │
├────────────┴────────────────────────────────────────────────┤
│  Status strip                                               │
└─────────────────────────────────────────────────────────────┘
```

| Page | Features |
|------|----------|
| Home | Quick-action tiles for common tasks |
| Download | Scan sources, download full library or custom count, live progress bar |
| Unsplash | Search by keyword, browse topics, grab randoms — tabbed interface |
| Slideshow | Platform-aware start/stop, interval control |
| Settings | Wallpaper directory, worker count, slideshow interval |

---

## Usage

### CLI

```bash
python3 wallpimp
```

Main menu:

| # | Option |
|---|--------|
| 1 | Download wallpapers |
| 2 | Unsplash |
| 3 | Settings |
| 4 | Slideshow control |
| 5 | Set random wallpaper |
| 6 | Exit |

---

## Download Wallpapers

```
wallpimp → 1. Download wallpapers
```

| Option | Description |
|--------|-------------|
| 1. Download full library | Scans all sources then downloads everything |
| 2. Download custom amount | Scans total available, prompts for count |
| c. Change save directory | Change where wallpapers are saved |

### How it works

The Go engine scans all 19 GitHub repos via the tree API and Unsplash topic totals —
no images downloaded during scan. It then shows:

```
  Available : 14,823 wallpapers
```

Downloads stream behind a live progress bar rendered by Python off engine events:

```
  DOWNLOADING  ████████████░░░░░░░░  6,241/14,823
```

Sources are processed in order: GitHub repos first, then Unsplash topics, then
Unsplash random fill to hit a custom target.

### Engine Protocol

Python sends newline-delimited JSON commands to the Go engine over a Unix socket.
The engine streams `progress` events in real time and sends a final `done` event:

```json
→ {"cmd":"download","wdir":"/home/user/Pictures/Wallpapers","target":500}
← {"event":"progress","new":47,"dupes":3,"errors":0}
← {"event":"progress","new":89,"dupes":5,"errors":0}
← ...
← {"event":"done","new":500,"dupes":62,"errors":1}
```

Both the CLI and GUI use this same protocol — the engine is unaware of which
front-end is connected.

---

## Unsplash

```
wallpimp → 2. Unsplash
```

| # | Option |
|---|--------|
| 1 | Search by keyword |
| 2 | Browse topics |
| 3 | Browse curated collections |
| 4 | Random wallpapers |
| 5 | Change save directory |

Every option shows the current save path and offers to change it before starting.

### Rate Limiting

The Go engine enforces 45 requests/hour (free tier cap is 50 — 5 held in reserve)
using a sliding-window token bucket. If the limit is hit during bulk download,
the engine blocks internally and Python receives a `wait` event:

```
  Rate limit buffer reached. Pausing 312s …
```

No user action needed — the engine resumes automatically.

### Auto Resolution

| Platform | Detection method |
|----------|-----------------|
| Linux | `xrandr`, `/sys/class/graphics/fb0/virtual_size`, `xdpyinfo` |
| macOS | `system_profiler SPDisplaysDataType`, AppleScript Finder bounds |
| Windows | PowerShell `System.Windows.Forms.Screen` |

Images fetched at nearest tier: 1280 · 1920 · 2560 · 3840px wide.

---

## Wallpaper Setting

| Platform | Method |
|----------|--------|
| Linux (GNOME) | `gsettings` with D-Bus session env + `dbus-launch` fallback |
| Linux (XFCE4) | `xfconf-query` across all monitors and workspaces |
| macOS | AppleScript via `osascript` — sets all desktops simultaneously |
| Windows | `SystemParametersInfoW` via `ctypes` |

---

## Slideshow Control

### Linux (systemd)

> Run **Save session env** from a graphical terminal first (not SSH). One-time setup.

```
wallpimp → Slideshow control → 1. Save session env
wallpimp → Slideshow control → 2. Start slideshow service
```

Service: `~/.config/systemd/user/wallpimp-slideshow.service`

```bash
systemctl --user start wallpimp-slideshow.service
journalctl --user -u wallpimp-slideshow.service -f
```

### macOS (launchd)

WallPimp writes a plist to `~/Library/LaunchAgents/com.wallpimp.slideshow.plist`
and loads it immediately. Autostart on login is automatic.

Logs: `~/Library/Logs/wallpimp-slideshow.log`

```bash
launchctl load   ~/Library/LaunchAgents/com.wallpimp.slideshow.plist
launchctl unload ~/Library/LaunchAgents/com.wallpimp.slideshow.plist
```

### Windows (Task Scheduler)

WallPimp registers a `WallPimp Slideshow` task set to run at logon.
Run as Administrator if it fails.

```powershell
schtasks /run    /tn "WallPimp Slideshow"
schtasks /delete /tn "WallPimp Slideshow" /f
```

### Direct daemon mode (all platforms)

```bash
wallpimp --daemon        # Linux / macOS
python wallpimp --daemon # Windows
```

---

## Configuration

| Platform | Path |
|----------|------|
| Linux | `~/.config/wallpimp/config.json` |
| macOS | `~/Library/Application Support/wallpimp/config.json` |
| Windows | `%APPDATA%\wallpimp\config.json` |

```json
{
  "wallpaper_dir": "/home/user/Pictures/Wallpapers",
  "slideshow_interval": 300,
  "download_workers": 8
}
```

`download_workers` controls the Go engine's goroutine pool size (1–32).

---

## Directory Structure

```
<config>/wallpimp/
  ├── config.json         # Settings
  ├── hashes.json         # Dedup database (written by Go engine)
  └── session.env         # Linux: D-Bus session variables

~/Pictures/Wallpapers/
  ├── dharmx-walls/       # GitHub sources (one folder per repo slug)
  ├── frenzyexists/
  ├── ...
  └── unsplash/
      ├── search/<query>/
      ├── topics/<slug>/
      ├── collections/<name>/
      └── random/
```

---

## Permissions

### Linux / macOS
Directories requiring root trigger a native `sudo mkdir` prompt, followed by
`chown` so future writes don't need elevation again.

### Windows
If a directory requires elevated access, WallPimp instructs you to either run as
Administrator or choose a user-owned path.

---

## Go Engine — Concurrency Model

Each download operation maps to a bounded goroutine pool:

```
command arrives
      │
      ▼
semaphore chan (size = workers)
      │
      ├──► goroutine: fetch image bytes (HTTP)
      │         └──► md5 check (HashDB RWMutex)
      │         └──► write file
      │         └──► emit progress event over socket
      ├──► goroutine: ...
      └──► goroutine: ...
            │
            ▼
     all goroutines join
            │
            ▼
     "done" event → Python (CLI or GUI)
```

The hash database uses `sync.RWMutex` — multiple goroutines read concurrently,
writes are serialised. All stat counters use `sync/atomic`.

---

## Duplicate Detection

All sources (GitHub + Unsplash) share one MD5 hash database managed entirely by
the Go engine. The same image from two different repos is only saved once.
The database persists across restarts and is safe to access from multiple goroutines.

---

## Troubleshooting

### Engine binary not found

```
Go engine not found
  Build it with:  cd src && go build -o ../wallpimp-engine .
  Then place it next to this script.
```

Build the engine and ensure it sits in the same directory as `wallpimp`, or
anywhere on your `PATH`.

### GUI option not appearing (Linux)

The GUI requires `tkinter`. Install it for your distro:

```bash
sudo apt-get install python3-tk   # Debian / Ubuntu / Kali / Mint
sudo dnf install python3-tkinter  # Fedora / RHEL / Rocky
sudo pacman -S tk                 # Arch / ArchBang / Manjaro
sudo zypper install python3-tk    # openSUSE
```

Then re-run `setup` — the GUI option will appear automatically.

### Slideshow not working (Linux)

```bash
wallpimp → Slideshow control → 1. Save session env
systemctl --user restart wallpimp-slideshow.service
journalctl --user -u wallpimp-slideshow.service -f
```

### Slideshow not working (macOS)

```bash
launchctl list com.wallpimp.slideshow
cat ~/Library/Logs/wallpimp-slideshow.log
```

Also check System Preferences → Security & Privacy → Accessibility / Automation
and grant Terminal (or Python) permission.

### Slideshow not working (Windows)

Run wallpimp as Administrator and use `Start slideshow` again:

```powershell
schtasks /query /tn "WallPimp Slideshow"
```

### Download stalls

Install `git` to enable the clone fallback:

```bash
sudo apt install git   # Debian / Ubuntu
brew install git       # macOS
winget install Git.Git # Windows
```

### Python deps not installing

```bash
pip install requests tqdm
```

### Go not found after setup (Linux)

`setup` (bash) installs Go to `/usr/local/go` and appends to `~/.profile`,
`~/.bashrc`, and `~/.zshrc`. If `go` is still not found, source your profile:

```bash
source ~/.profile
# or open a new terminal
```

---

## Performance

| Metric | Notes |
|--------|-------|
| Engine latency | Sub-millisecond per command (Unix socket, no spawn overhead) |
| Download workers | 8 default, configurable 1–32 via `download_workers` |
| Hash lookup | O(1) — `sync.RWMutex` map |
| Archive extraction | Streamed in 64KB chunks, images only |
| Image format | JPEG 85%, resolution matched to screen |
| Memory | ~50MB during large downloads |

---

## Security

- No plaintext credentials anywhere on disk or in source files
- Credentials use XOR + base64 obfuscation, split across unrelated variable names,
  identical scheme in both Go (`creds.go`) and Python (`wallpimp`)
- GitHub downloads use public archive URLs — no tokens required
- MD5 is used for duplicate detection only, not cryptography
- Session env file is `chmod 600` (Linux/macOS)
- sudo / UAC elevation only invoked when a directory explicitly requires it

---

## Developer

- **Developer**: 0xb0rn3
- **Email**: oxbv1@proton.me
- **GitHub**: https://github.com/0xb0rn3/wallpimp

## License

Open source — Cybersecurity research and educational purposes

## Contributing

Bug reports and feature requests welcome via GitHub issues.
