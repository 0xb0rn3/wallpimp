# WallPimp - Modern Linux Wallpaper Manager

A powerful, terminal-driven wallpaper manager with slideshow support for Linux desktop environments, featuring a minimal-overhead C daemon and comprehensive desktop environment support.

## Features

- 🎨 **Multi-Desktop Support**: XFCE, GNOME, KDE Plasma, MATE, Cinnamon, i3, Sway
- 🔄 **Automated Slideshow**: C-based daemon for minimal resource usage
- 📥 **Repository Downloads**: Curated wallpaper collections from GitHub
- ⚙️ **Systemd Integration**: Service and timer-based slideshow control
- 🖥️ **Display Manager Support**: SDDM, LightDM, GDM/GDM3
- 🎯 **Terminal-Driven**: Clean, organized menu system
- 🚀 **Auto-Detection**: Automatically detects distribution, DE, and display manager
- 💾 **Low Resource Usage**: Efficient C daemon for slideshow functionality

## System Requirements

- Linux distribution (Arch, Debian, Ubuntu, Fedora, openSUSE, etc.)
- Python 3.6+
- GCC compiler
- systemd
- One of: XFCE, GNOME, KDE, or window manager with feh support

## Installation

### Automatic Installation

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Detect your distribution and package manager
2. Install required dependencies
3. Compile the C slideshow daemon
4. Install binaries to `~/.local/bin`
5. Set up systemd user services
6. Configure your shell PATH

### Manual Installation

#### Dependencies

**Arch Linux:**
```bash
sudo pacman -S python python-pip python-requests python-tqdm \
               python-pillow python-colorama gcc make feh
```

**Debian/Ubuntu:**
```bash
sudo apt install python3 python3-pip python3-requests python3-tqdm \
                 python3-pil python3-colorama gcc make feh
```

**Fedora:**
```bash
sudo dnf install python3 python3-pip python3-requests python3-tqdm \
                 python3-pillow python3-colorama gcc make feh
```

#### Build and Install

```bash
# Compile daemon
gcc -O2 -Wall -o wallpimp_daemon wallpimp_daemon.c

# Copy files
mkdir -p ~/.local/bin ~/.config/systemd/user
cp wallpimp.py ~/.local/bin/wallpimp
cp wallpimp_daemon ~/.local/bin/
chmod +x ~/.local/bin/wallpimp ~/.local/bin/wallpimp_daemon

# Install systemd services
cp wallpimp-slideshow.service ~/.config/systemd/user/
cp wallpimp-slideshow.timer ~/.config/systemd/user/
systemctl --user daemon-reload

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

### Interactive Menu

Simply run:
```bash
wallpimp
```

This launches the interactive terminal menu with options for:

**1. Downloads**
- List available repositories
- Download from specific repository
- Download all repositories
- Download from custom GitHub URL

**2. Settings**
- Change wallpaper directory
- Set slideshow interval
- Configure download workers
- View current settings
- Use existing wallpaper directory

**3. Slideshow Control**
- Start/stop slideshow
- Enable/disable autostart
- Check slideshow status

**4. Set Static Wallpaper**
- Randomly select and set a wallpaper

### Command Line Control

Start slideshow:
```bash
systemctl --user start wallpimp-slideshow.timer
```

Enable autostart on login:
```bash
systemctl --user enable wallpimp-slideshow.timer
```

Stop slideshow:
```bash
systemctl --user stop wallpimp-slideshow.timer
```

Check status:
```bash
systemctl --user status wallpimp-slideshow.timer
```

## Configuration

Configuration is stored in `~/.config/wallpimp/config.json`:

```json
{
  "wallpaper_dir": "/home/user/Pictures/Wallpapers",
  "slideshow_interval": 300,
  "download_workers": 4
}
```

- `wallpaper_dir`: Directory containing wallpapers
- `slideshow_interval`: Seconds between wallpaper changes
- `download_workers`: Parallel downloads (1-8 recommended)

## Available Wallpaper Repositories

- **minimalist**: Clean minimalist designs
- **anime**: Anime & manga artwork
- **nature**: Nature landscapes
- **scenic**: Scenic vistas
- **artistic**: Artistic styles
- **animated**: Animated GIF wallpapers

## Desktop Environment Support

### XFCE
Uses `xfconf-query` to set wallpaper across all monitors and workspaces.

### GNOME
Uses `gsettings` for both light and dark mode wallpapers.

### KDE Plasma
Uses `qdbus` to interact with Plasma desktop.

### i3/Sway/Other WMs
Uses `feh` as fallback wallpaper setter.

## Display Manager Support

WallPimp can set wallpapers for login screens:

### SDDM (KDE)
Modify theme configuration in `/usr/share/sddm/themes/[theme-name]/theme.conf`

### LightDM
Edit `/etc/lightdm/lightdm-gtk-greeter.conf`:
```ini
[greeter]
background=/path/to/wallpaper.jpg
```

### GDM/GDM3 (GNOME)
Uses GNOME's wallpaper settings which sync with GDM.

## Slideshow Daemon

The slideshow functionality uses a lightweight C daemon that:
- Scans wallpaper directory recursively
- Randomly selects wallpapers
- Sets wallpapers at configured intervals
- Consumes minimal system resources (~2MB RAM)
- Respects systemd signals for clean shutdown

## Directory Structure

```
~/.config/wallpimp/
  ├── config.json                    # Configuration file

~/.local/bin/
  ├── wallpimp                       # Main Python script
  └── wallpimp_daemon                # C slideshow daemon

~/.config/systemd/user/
  ├── wallpimp-slideshow.service     # Systemd service
  └── wallpimp-slideshow.timer       # Systemd timer

~/Pictures/Wallpapers/               # Default wallpaper directory
  ├── minimalist/
  ├── anime/
  ├── nature/
  └── ...
```

## Troubleshooting

### Slideshow not working

Check service status:
```bash
systemctl --user status wallpimp-slideshow.service
journalctl --user -u wallpimp-slideshow.service
```

Ensure daemon is executable:
```bash
chmod +x ~/.local/bin/wallpimp_daemon
```

### Wallpaper not changing

Verify wallpapers exist:
```bash
ls ~/Pictures/Wallpapers/
```

Check desktop environment detection:
```bash
echo $XDG_CURRENT_DESKTOP
echo $DESKTOP_SESSION
```

### PATH issues

Reload shell configuration:
```bash
source ~/.bashrc
# or
source ~/.zshrc
```

Manually add to PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Advanced Usage

### Custom Wallpaper Directory

1. Create your directory structure
2. Run `wallpimp`
3. Go to Settings → Use existing wallpaper directory
4. Enter your directory path

### Custom Slideshow Interval

1. Run `wallpimp`
2. Go to Settings → Set slideshow interval
3. Enter interval in seconds (e.g., 600 for 10 minutes)
4. Restart slideshow service

### Download from Custom Repository

1. Run `wallpimp`
2. Go to Downloads → Download from custom URL
3. Enter GitHub repository URL
4. Wallpapers will be downloaded to a subdirectory

## Contributing

Contributions welcome! This is an open-source cybersecurity student project.

## License

Open source - feel free to modify and distribute

## Developer

- **Developer**: 0xb0rn3
- **Email**: q4n0@proton.me
- **GitHub**: https://github.com/0xb0rn3/wallpimp

## Acknowledgments

Built as part of cybersecurity research and Linux desktop customization studies.
