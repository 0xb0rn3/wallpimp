# WallPimp - Linux Wallpaper Manager

Single-file wallpaper manager with automated slideshow support for GNOME and XFCE4.

## Features

- Single executable Python script
- GitHub repository downloads with rate limit bypass
- Hash-based duplicate detection across downloads
- Real-time loading animations
- GNOME and XFCE4 slideshow support with reliable systemd integration
- Session environment persistence (fixes slideshow in systemd context)
- Automatic D-Bus session discovery for wallpaper tools
- Shuffle-queue slideshow (every wallpaper shown once before repeating)
- Repository validation and error handling
- Parallel downloads with progress tracking
- Minimal terminal interface

## Requirements

- Python 3.6+
- GNOME or XFCE4 desktop environment (for slideshow)
- systemd (for slideshow service)

## Installation

```bash
chmod +x wallpimp
sudo mv wallpimp /usr/local/bin/
wallpimp
```

Dependencies (requests, tqdm) are auto-installed on first run.

## Usage

### Interactive Menu

```bash
wallpimp
```

Main menu options:
1. Download wallpapers - Access repository downloads
2. Settings - Configure directories and intervals
3. Slideshow control - Start/stop/manage slideshow
4. Set random wallpaper - Apply single wallpaper
5. Exit

### Download Repositories

Built-in repositories:
- minimalist - Clean minimalist designs
- anime - Anime & manga artwork
- nature - Nature landscapes
- scenic - Scenic vistas
- artistic - Artistic styles

Custom repository download supported via GitHub URL.

### Duplicate Detection

WallPimp automatically detects and skips duplicate wallpapers:

- MD5 hash calculated for every downloaded image
- Hash database stored in `~/.config/wallpimp/hashes.json`
- Duplicates skipped during download with counter
- Works across interrupted downloads and re-runs
- Cleanup orphaned hashes via Settings menu

Example output:
```
✓ anime: 847 new, 132 duplicates skipped
```

### Slideshow Control

**GNOME and XFCE4 only**

> **Important:** Always run **Save session env** (option 1) first, from a
> graphical desktop terminal — not over SSH. This is a one-time setup step
> that makes the slideshow work reliably when launched by systemd.

#### First-time setup

```
wallpimp → Slideshow control → 1. Save session env
wallpimp → Slideshow control → 2. Start slideshow service
```

#### Full slideshow menu options

| # | Option | Description |
|---|--------|-------------|
| 1 | Save session env | Captures display/D-Bus variables from the running desktop session and saves them to `~/.config/wallpimp/session.env`. **Required before starting the service for the first time.** Re-run this after a system reboot if the service stops working. |
| 2 | Start slideshow service | Writes the systemd unit and starts it immediately. |
| 3 | Stop slideshow service | Stops the running service. |
| 4 | Enable autostart on login | Enables the service to start automatically after login. |
| 5 | Disable autostart | Disables automatic start. |
| 6 | Check status & logs | Shows `systemctl status` output and the last 30 journal lines, plus the saved session env for diagnostics. |
| 7 | Run slideshow now (foreground) | Runs the daemon directly in your terminal — useful for testing and diagnosing issues. |

### Direct Daemon Mode

```bash
wallpimp --daemon
```

Runs the slideshow in the foreground with signal handling (SIGINT/SIGTERM).
All output goes to stderr so it appears correctly in `journalctl`.

## Configuration

Config location: `~/.config/wallpimp/config.json`

```json
{
  "wallpaper_dir": "/home/user/Pictures/Wallpapers",
  "slideshow_interval": 300,
  "download_workers": 8
}
```

Hash database: `~/.config/wallpimp/hashes.json`

```json
{
  "a1b2c3d4e5f6...": "/home/user/Pictures/Wallpapers/anime/image1.jpg",
  "f6e5d4c3b2a1...": "/home/user/Pictures/Wallpapers/nature/image2.png"
}
```

Session env: `~/.config/wallpimp/session.env`

```
DISPLAY=:0
WAYLAND_DISPLAY=wayland-0
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
XDG_RUNTIME_DIR=/run/user/1000
XDG_CURRENT_DESKTOP=GNOME
```

- `wallpaper_dir` - Wallpaper storage location
- `slideshow_interval` - Seconds between wallpaper changes
- `download_workers` - Parallel download threads (1-32)

## Rate Limit Bypass

WallPimp bypasses GitHub API rate limits using:

1. **Direct archive downloads** - Primary method using `https://github.com/owner/repo/archive/branch.zip`
2. **Git clone fallback** - Uses git operations (no API limits)
3. **Repository validation** - Pre-validates repos before download

No API tokens required.

## Real-Time Loaders

Animated loading indicators during operations:

- Scanning for images: Spinner animation
- Cleaning hash database: Spinner animation
- Processing downloads: Progress bar with counters

## Hash Database Management

### Automatic Cleanup

Remove orphaned hashes (files no longer exist):

```bash
wallpimp → Settings → Cleanup hash database
```

### Manual Management

View hash count:
```bash
wallpimp → Settings → View settings
```

Hash database location:
```bash
~/.config/wallpimp/hashes.json
```

### How It Works

1. Download starts, archive extracted
2. Each image file hashed (MD5)
3. Hash checked against database
4. If exists: Skip file, increment duplicate counter
5. If new: Save file, add hash to database
6. Progress bar shows: "847 new, 132 duplicates skipped"

### Benefits

- Resume interrupted downloads without re-downloading
- Multiple repositories can share same images (no duplicates)
- Hash cleanup removes entries for deleted files
- Persistent across tool restarts and system reboots

## How the Slideshow Works (Technical)

### The systemd D-Bus Problem

`gsettings` (GNOME) and `xfconf-query` (XFCE4) both require an active
D-Bus session to set wallpapers. When systemd starts a user service it does
**not** inherit the graphical session's environment variables (`DISPLAY`,
`WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`, etc.), which causes wallpaper
calls to silently fail.

WallPimp solves this with a layered approach:

1. **`session.env` file** - When you run *Save session env* from your desktop
   terminal, WallPimp captures all required variables and writes them to
   `~/.config/wallpimp/session.env`. The systemd service unit loads this file
   via `EnvironmentFile=` so the variables are present from the start.

2. **Automatic D-Bus discovery** - Even without the env file, the daemon
   tries to find the D-Bus address automatically via:
   - `systemctl --user show-environment`
   - The well-known socket at `/run/user/<uid>/bus`
   - Scanning `/proc` for a live graphical session process

3. **`dbus-launch` fallback** (GNOME) - If `gsettings` still cannot connect,
   it retries via `dbus-launch --exit-with-session` as a last resort.

### Shuffle Queue

The slideshow uses a shuffle queue instead of pure random selection:

- All wallpapers are shuffled into a queue at the start of each cycle
- Each wallpaper is shown exactly once before any image repeats
- The wallpaper directory is re-scanned at the start of each new cycle,
  so newly downloaded wallpapers appear automatically without restarting
  the service

### Signal Handling

The daemon sleeps in 1-second ticks rather than a single long `time.sleep()`,
so `SIGINT` (Ctrl-C) and `SIGTERM` (from `systemctl stop`) take effect
immediately rather than waiting for the full interval to expire.

## Error Handling

### Non-Existent Repositories

```
Error: Repo faulty or non-existent. Please verify the repository exists.
```

Repository URLs are validated before download. Invalid repos are skipped with error message.

### Network Errors

Automatic retry with alternative download methods (git clone → archive).

### Missing Wallpapers

Slideshow checks for wallpapers before starting. If none are found it waits
30 seconds and retries, rather than exiting, so the service recovers
automatically after a download completes.

### Unsupported Desktop Environments

```
Error: Slideshow only supports XFCE and GNOME
Detected: kde
```

Slideshow menu blocks non-GNOME/XFCE systems.

## Systemd Service

The service file is auto-generated when starting or enabling the slideshow.
It uses `PartOf=graphical-session.target` so it starts and stops with
your desktop session.

Service location: `~/.config/systemd/user/wallpimp-slideshow.service`

Manual control:
```bash
systemctl --user start   wallpimp-slideshow.service
systemctl --user stop    wallpimp-slideshow.service
systemctl --user enable  wallpimp-slideshow.service
systemctl --user disable wallpimp-slideshow.service
systemctl --user status  wallpimp-slideshow.service
```

View live logs:
```bash
journalctl --user -u wallpimp-slideshow.service -f
```

## Desktop Environment Support

### XFCE4
Uses `xfconf-query` to set wallpaper across all monitors and workspaces.
Monitor and workspace properties are queried dynamically; if the query
fails, common property paths are guessed from `xrandr --listmonitors`.

### GNOME
Uses `gsettings` for both light and dark mode wallpapers
(`picture-uri` and `picture-uri-dark`). Falls back to `dbus-launch` if
the session bus is not reachable directly.

### Others
Slideshow feature disabled. Static wallpaper setting unavailable.

## Directory Structure

```
~/.config/wallpimp/
  ├── config.json          # Main configuration
  ├── hashes.json          # Duplicate detection database
  └── session.env          # Saved graphical session environment

~/.config/systemd/user/
  └── wallpimp-slideshow.service

~/Pictures/Wallpapers/
  ├── minimalist/
  ├── anime/
  ├── nature/
  ├── scenic/
  ├── artistic/
  └── ...
```

> **Note:** The legacy `wallpimp-slideshow.timer` unit is no longer used.
> If it exists from a previous installation it will be removed automatically.

## Custom Repository Download

1. Go to Downloads menu
2. Select "Download custom URL"
3. Enter GitHub repository URL
4. Repository is validated before download
5. Wallpapers extracted to subdirectory named after the repo
6. Duplicates automatically skipped

Invalid repositories display an error and return to the menu.

## Troubleshooting

### Slideshow not changing wallpaper (most common issue)

This is almost always the D-Bus / session environment problem described above.

```bash
# Step 1: open wallpimp from your DESKTOP terminal (not SSH)
wallpimp

# Step 2: go to Slideshow control → Save session env

# Step 3: restart the service
systemctl --user restart wallpimp-slideshow.service

# Step 4: watch the logs to confirm it's working
journalctl --user -u wallpimp-slideshow.service -f
```

If you see `[wallpimp HH:MM:SS] Set: image.jpg` in the logs, it is working.
If you see `gsettings: ...` or `xfconf-query ...` error lines, the session
env may be stale — re-run *Save session env* and restart the service.

### Slideshow works interactively but not as a service

Your `session.env` was saved before the D-Bus address was fully initialised,
or it has changed since the last reboot.

```bash
# Re-save from a fresh desktop terminal session
wallpimp → Slideshow control → 1. Save session env
systemctl --user restart wallpimp-slideshow.service
```

### Service fails to start

```bash
systemctl --user status wallpimp-slideshow.service
journalctl --user -u wallpimp-slideshow.service -n 50
```

Also try running in foreground to see errors directly:
```bash
wallpimp → Slideshow control → 7. Run slideshow now
```

### No wallpapers found

```bash
ls ~/Pictures/Wallpapers/
```

Download repositories via the Downloads menu, then the running service will
pick them up automatically at the start of the next cycle.

### Repository download fails

Verify the repository exists on GitHub. Check your network connection.
Install git for the primary download method:
```bash
sudo apt install git
```

### Hash database corruption

Delete and rebuild:
```bash
rm ~/.config/wallpimp/hashes.json
wallpimp
# Re-download or run Settings → Cleanup hash database
```

### Dependencies not installing

Manual installation:
```bash
pip install --break-system-packages requests tqdm
```

## Performance

- Parallel downloads: 8 workers default (configurable 1-32)
- Archive extraction: Filters image files only
- Hash calculation: MD5 streaming (4KB chunks)
- Duplicate detection: O(1) hash lookup
- Memory usage: ~50MB during download operation
- CPU usage: Minimal (slideshow daemon sleeps between changes)
- Storage: ~1KB per 1000 tracked hashes

## Security

- No authentication required
- No API tokens stored
- Public repository access only
- Repository validation before download
- MD5 hashing for duplicate detection (not cryptographic)
- Session env file is user-readable only (contains display socket paths)

## Developer

- **Developer**: 0xb0rn3
- **Email**: q4n0@proton.me
- **GitHub**: https://github.com/0xb0rn3/wallpimp

## License

Open source - Cybersecurity research and educational purposes

## Contributing

Bug reports and feature requests welcome via GitHub issues.
