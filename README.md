# WallPimp - Linux Wallpaper Manager

Single-file wallpaper manager with automated slideshow support for GNOME and XFCE4.

## Features

- Single executable Python script
- GitHub repository downloads with rate limit bypass
- GNOME and XFCE4 slideshow support
- Systemd service integration
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

### Slideshow Control

**GNOME and XFCE4 only**

Start slideshow service:
```bash
wallpimp → Slideshow control → Start slideshow
```

Enable autostart on boot:
```bash
wallpimp → Slideshow control → Enable autostart
```

Run in foreground (testing):
```bash
wallpimp → Slideshow control → Run slideshow now
```

### Direct Daemon Mode

```bash
wallpimp --daemon
```

Runs slideshow in foreground with signal handling (SIGINT/SIGTERM).

## Configuration

Config location: `~/.config/wallpimp/config.json`

```json
{
  "wallpaper_dir": "/home/user/Pictures/Wallpapers",
  "slideshow_interval": 300,
  "download_workers": 8
}
```

- `wallpaper_dir` - Wallpaper storage location
- `slideshow_interval` - Seconds between changes
- `download_workers` - Parallel download threads (1-32)

## Rate Limit Bypass

WallPimp bypasses GitHub API rate limits using:

1. **Direct archive downloads** - Primary method using `https://github.com/owner/repo/archive/branch.zip`
2. **Git clone fallback** - Uses git operations (no API limits)
3. **Repository validation** - Pre-validates repos before download

No API tokens required.

## Error Handling

### Non-Existent Repositories

```
Error: Repo faulty or non-existent. Please verify the repository exists.
```

Repository URLs are validated before download. Invalid repos are skipped with error message.

### Network Errors

Automatic retry with alternative download methods (archive → git clone).

### Missing Wallpapers

Slideshow checks for wallpapers before starting. Exit with error if none found.

### Unsupported Desktop Environments

```
Error: Slideshow only supports XFCE and GNOME
Detected: kde
```

Slideshow menu blocks non-GNOME/XFCE systems.

## Systemd Service

Service files are auto-generated when starting slideshow:

- `~/.config/systemd/user/wallpimp-slideshow.service`
- `~/.config/systemd/user/wallpimp-slideshow.timer`

Manual control:
```bash
systemctl --user start wallpimp-slideshow.service
systemctl --user stop wallpimp-slideshow.service
systemctl --user enable wallpimp-slideshow.service
systemctl --user status wallpimp-slideshow.service
```

## Desktop Environment Support

### XFCE4
Uses `xfconf-query` to set wallpaper across all monitors and workspaces.

### GNOME
Uses `gsettings` for both light and dark mode wallpapers.

### Others
Slideshow feature disabled. Static wallpaper setting unavailable.

## Directory Structure

```
~/.config/wallpimp/
  └── config.json

~/.config/systemd/user/
  ├── wallpimp-slideshow.service
  └── wallpimp-slideshow.timer

~/Pictures/Wallpapers/
  ├── minimalist/
  ├── anime/
  ├── nature/
  └── ...
```

## Custom Repository Download

1. Go to Downloads menu
2. Select "Download custom URL"
3. Enter GitHub repository URL
4. Repository is validated before download
5. Wallpapers extracted to subdirectory

Invalid repositories display error and continue.

## Troubleshooting

### Slideshow not working

Check service status:
```bash
systemctl --user status wallpimp-slideshow.service
journalctl --user -u wallpimp-slideshow.service
```

Verify desktop environment:
```bash
echo $XDG_CURRENT_DESKTOP
```

### No wallpapers found

Check directory:
```bash
ls ~/Pictures/Wallpapers/
```

Download repositories via menu.

### Repository download fails

Verify repository exists on GitHub. Check network connection. Install git for fallback method:
```bash
sudo apt install git
```

### Dependencies not installing

Manual installation:
```bash
pip install --break-system-packages requests tqdm
```

## Performance

- Parallel downloads: 8 workers default (configurable 1-32)
- Archive extraction: Filters image files only
- Memory usage: ~50MB during operation
- CPU usage: Minimal (slideshow daemon)

## Security

- No authentication required
- No API tokens stored
- Public repository access only
- Repository validation before download

## Developer

- **Developer**: 0xb0rn3
- **Email**: q4n0@proton.me
- **GitHub**: https://github.com/0xb0rn3/wallpimp

## License

Open source - Cybersecurity research and educational purposes

## Contributing

Bug reports and feature requests welcome via GitHub issues.
