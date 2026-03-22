# WallPimp — Wallpaper Manager

Cross-platform wallpaper manager for Linux, macOS, and Windows.  
Python handles the interactive terminal UI. A compiled Go engine handles all
downloads — GitHub archives and Unsplash — using native goroutines and a
persistent socket connection for maximum throughput with zero per-operation overhead.

---

## Architecture

```
wallpimp (Python)          wallpimp-engine (Go binary)
  Terminal UI  ──────────── newline-delimited JSON ────  Goroutine pool
  GUI (tkinter)        Unix socket / TCP (Windows)        GitHub downloader
  Menus & settings                                        Unsplash client
  Slideshow control                                       Hash database
  Wallpaper setter                                        Rate limiter
```

Python spawns the Go engine once on first use and holds a single persistent
socket connection for the entire session. All download concurrency happens inside
Go — no Python threads involved in the hot path.

The optional tkinter GUI (`wallpimp_gui.py`) communicates with the same engine
over the same socket — no separate backend needed.

---

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
- **Pre-built Windows engine binary shipped in repo — Go not required on user machines**

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| Python | 3.10+ |
| Go | 1.21+ (Linux/macOS builds only — Windows uses pre-built binary) |
| GUI (optional) | Python `tkinter` — ships with standard Python installs |
| Linux slideshow | GNOME or XFCE4 + systemd |
| macOS | 10.13+ High Sierra or later |
| Windows | Windows 10 or later |

---

## Project Structure

```
wallpimp                  # Python script (CLI — UI + wallpaper setters + slideshow)
wallpimp_gui.py           # Python script (GUI — tkinter front-end, same engine)
wallpimp-engine.exe       # Pre-built Windows Go engine (no Go install required)
setup                     # Bash — one-line installer for Linux / macOS
setup.ps1                 # PowerShell — one-line installer for Windows
src/
  go.mod                  # Go module
  main.go                 # Socket server + command dispatcher
  github.go               # GitHub archive downloader (goroutine pool)
  unsplash.go             # Unsplash client + rate limiter + image fetcher
  hash.go                 # Thread-safe MD5 hash database
  screen.go               # Screen resolution detection (all platforms)
  http.go                 # Shared HTTP transport + retry logic
  creds.go                # Obfuscated credential resolution (XOR + base64)
  zipextract.go           # Zip fallback extractor for large repos
```

---

## Installation

### Windows — one-line setup (recommended)

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup.ps1 | iex
```

`setup.ps1` automatically:
- Checks and installs Python 3.12, Git, and Visual C++ Redistributable if missing
- Clones the repository to `%USERPROFILE%\wallpimp`
- Uses the pre-built `wallpimp-engine.exe` from the repo — **no Go required**
- Detects and auto-repairs corrupt Go installations if one exists on the machine
- Installs Python dependencies (`requests`, `tqdm`)
- Prompts you to choose **GUI** or **CLI** at launch

> **Do not close the window** while setup is running.

#### Corrupt Go detection

If a pre-existing Go installation on the machine is corrupt (e.g. from system
tweaking tools), setup detects it at build time and shows a recovery prompt:

```
  ╔═══════════════════════════════════════════════════════════════╗
  ║  ✘  ERROR — CORRUPT GO INSTALLATION DETECTED                 ║
  ╠═══════════════════════════════════════════════════════════════╣
  ║  There is an error / conflict with an internal package in     ║
  ║  your Go installation...                                      ║
  ╚═══════════════════════════════════════════════════════════════╝

  Type  YES  to proceed with cleanup and reinstall.
  Type  NO   to quit setup.
```

Typing `YES` performs a full nuke and reinstall automatically. No manual
intervention required.

To re-run setup or update an existing installation, run the same command again.

---

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

To re-run setup or update:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup)
```

It will pull the latest repo, rebuild the engine only if source has changed,
then show the launch prompt again.

#### Flags (skip the prompt)

```bash
bash <(curl -fsSL .../setup) --gui     # Force GUI launch
bash <(curl -fsSL .../setup) --cli     # Force CLI launch
bash <(curl -fsSL .../setup) --update  # Pull + rebuild only, no launch
```

#### tkinter (GUI prerequisite)

```bash
sudo apt-get install python3-tk   # Debian / Ubuntu / Kali
sudo dnf install python3-tkinter  # Fedora / RHEL
sudo pacman -S tk                 # Arch / ArchBang
sudo zypper install python3-tk    # openSUSE
brew install python-tk            # macOS (Homebrew)
```

Then re-run setup — the GUI option will appear automatically.

---

### Manual install (all platforms)

```bash
git clone --depth 1 https://github.com/0xb0rn3/wallpimp.git ~/wallpimp
cd ~/wallpimp/src && go build -o ../wallpimp-engine . && cd ..
chmod +x wallpimp
pip install requests tqdm
```

Windows manual (if not using setup.ps1):

```powershell
git clone --depth 1 https://github.com/0xb0rn3/wallpimp.git $env:USERPROFILE\wallpimp
# wallpimp-engine.exe is already included — no build needed
cd $env:USERPROFILE\wallpimp
pip install requests tqdm
python wallpimp
```

---

## Build

```bash
cd src
go build -o ../wallpimp-engine .
```

Cross-compile for other platforms:

```bash
# Windows (from Linux/macOS)
GOOS=windows GOARCH=amd64 GO111MODULE=on go build -o ../wallpimp-engine.exe .

# macOS Apple Silicon
GOOS=darwin GOARCH=arm64 go build -o ../wallpimp-engine-arm64 .

# Linux ARM (e.g. Raspberry Pi)
GOOS=linux GOARCH=arm64 go build -o ../wallpimp-engine-arm64 .
```

The binary lands at the repo root alongside the `wallpimp` script.
The engine is auto-located and started on first use — no configuration needed.

---

## Launching after setup

```bash
# Linux / macOS
cd ~/wallpimp && python3 wallpimp

# Or re-run setup — skips all already-done steps and goes straight to the prompt
bash <(curl -fsSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup)
```

```powershell
# Windows
cd $env:USERPROFILE\wallpimp
python wallpimp
# or
python wallpimp_gui.py
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
| 3 | Set wallpaper |
| 4 | Slideshow control |
| 5 | Settings |
| 6 | Exit |

---

## Resolution Detection

| Platform | Method |
|----------|---------|
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

```bash
launchctl load   ~/Library/LaunchAgents/com.wallpimp.slideshow.plist
launchctl unload ~/Library/LaunchAgents/com.wallpimp.slideshow.plist
```

### Windows (Task Scheduler)

WallPimp registers a `WallPimp Slideshow` task set to run at logon.

```powershell
schtasks /run    /tn "WallPimp Slideshow"
schtasks /delete /tn "WallPimp Slideshow" /f
```

### Direct daemon mode (all platforms)

```bash
python3 wallpimp --daemon   # Linux / macOS
python wallpimp --daemon    # Windows
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
      ├── collections/<n>/
      └── random/
```

---

## Go Engine — Concurrency Model

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

On Windows, `wallpimp-engine.exe` is shipped in the repo — ensure the clone
completed successfully. On Linux/macOS, build it from source.

### GUI option not appearing (Linux)

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

### go build fails with internal package error (Windows)

This is caused by a corrupt Go installation, often from system tweaking tools
like WinUtil. Run setup again — it detects the corruption automatically and
prompts you to nuke and reinstall Go cleanly.

If you're not using `setup.ps1`, run this in an admin PowerShell to fix manually:

```powershell
takeown /f "C:\Program Files\Go" /r /d y
icacls "C:\Program Files\Go" /grant administrators:F /t
Remove-Item -Recurse -Force "C:\Program Files\Go"
# Then reinstall Go from https://go.dev/dl/
```

### Python deps not installing

```bash
pip install requests tqdm
```

---

## Performance

| Metric | Notes |
|--------|-------|
| Engine latency | Sub-millisecond per command (Unix socket / TCP loopback) |
| Download workers | 8 default, configurable 1–32 via `download_workers` |
| Hash lookup | O(1) — `sync.RWMutex` map |
| Archive extraction | Streamed, images only |
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
- **Website**: [oxborn3.com](https://oxborn3.com)
- **Email**: contact@oxborn3.com
- **GitHub**: [github.com/0xb0rn3/wallpimp](https://github.com/0xb0rn3/wallpimp)

---

## License

Open source — Cybersecurity research and educational purposes.

---

## Contributing

Bug reports and feature requests welcome via [GitHub Issues](https://github.com/0xb0rn3/wallpimp/issues).
