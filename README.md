# WallPimp Enhanced 🎨

**The Ultimate Linux Wallpaper Manager with Slideshow**

WallPimp Enhanced is a comprehensive wallpaper management solution that combines powerful downloading capabilities with universal Linux slideshow functionality. Automatically fetch high-quality wallpapers from curated GitHub repositories and enjoy seamless slideshow experiences across all desktop environments.

## ✨ Features

### 🖼️ **Smart Repository Management**
- 12+ curated wallpaper repositories covering diverse styles
- Support for any public GitHub repository
- Automatic recursive directory traversal
- Branch-specific downloads (main, dev, etc.)

### ⚡ **Intelligent Download System**
- Multi-threaded parallel downloads for maximum speed
- Smart caching prevents duplicate downloads
- Automatic image validation and corruption detection
- Resume capability for interrupted downloads

### 🖥️ **Universal Linux Slideshow**
- **Auto-detects all desktop environments**: GNOME, KDE/Plasma, XFCE, MATE, Cinnamon, i3, Sway, and more
- **Flexible time formats**: `30s`, `5m`, `1h`, or precise combinations like `1h 30m 45s`
- **Autostart integration**: Automatic slideshow on login via XDG autostart
- **Graceful shutdown**: Proper signal handling and background operation

### 🔧 **Cross-Platform Compatibility**
- Universal Linux distribution support
- Automatic dependency installation with multiple fallback strategies
- Handles system package manager differences gracefully
- Fallback wallpaper setters for window managers

### 🎯 **User-Friendly Interface**
- Interactive setup wizard for first-time users
- Colorful terminal output with progress bars
- Detailed statistics and comprehensive error reporting
- Organized folder structure by repository

## 🚀 Installation

### Automatic Installation (Recommended)
```bash
# Clone the repository
git clone https://github.com/0xb0rn3/wallpimp-enhanced.git
cd wallpimp-enhanced

# Run WallPimp - dependencies install automatically
python3 wallpimp.py --setup
```

### Manual Dependency Installation
```bash
# Arch Linux
sudo pacman -S python-requests python-tqdm python-pillow python-colorama

# Ubuntu/Debian
sudo apt install python3-requests python3-tqdm python3-pil python3-colorama

# Fedora/RHEL
sudo dnf install python3-requests python3-tqdm python3-pillow python3-colorama

# OpenSUSE
sudo zypper install python3-requests python3-tqdm python3-Pillow python3-colorama

# Via pip (fallback)
pip3 install requests tqdm Pillow colorama --break-system-packages
```

## 🏃‍♂️ Quick Start

### **Interactive Setup (Recommended)**
```bash
python3 wallpimp.py --setup
```

### **Download Wallpapers**
```bash
# View all available repositories
python3 wallpimp.py --list

# Download anime wallpapers
python3 wallpimp.py --repo anime

# Download everything
python3 wallpimp.py --all
```

### **Wallpaper Management**
```bash
# Set random static wallpaper
python3 wallpimp.py --static --dir ~/Pictures

# Start slideshow (5-minute intervals)
python3 wallpimp.py --slideshow --dir ~/Pictures --interval 5m

# Enable autostart slideshow
python3 wallpimp.py --enable-autostart --dir ~/Pictures --interval 10m
```

## 🎨 Curated Repositories

Carefully selected repositories covering various aesthetic preferences:

| Repository | Theme | Icon | Description |
|------------|--------|------|-------------|
| **minimalist** | Clean Design | 🖼️ | Minimalist and clean aesthetic wallpapers |
| **anime** | Anime/Manga | 🌸 | High-quality anime and manga artwork |
| **nature** | Landscapes | 🌿 | Beautiful nature and landscape photography |
| **scenic** | Vistas | 🏞️ | Breathtaking scenic vistas and panoramas |
| **artistic** | Art Styles | 🎨 | Diverse artistic styles and digital art |
| **anime_pack** | Curated Anime | 🎎 | Carefully curated anime wallpaper collection |
| **linux** | Linux Themes | 🐧 | Linux desktop and distribution-themed art |
| **mixed** | Diverse | 🌟 | Mixed collection of various styles |
| **desktop** | Desktop Focus | 💻 | Minimalist desktop-oriented wallpapers |
| **gaming** | Gaming | 🎮 | Gaming-inspired artwork and screenshots |
| **photos** | Photography | 📷 | Professional photography and artistic shots |
| **digital** | Digital Art | 🖥️ | Modern digital creations and computer art |

## 💡 Usage Examples

### **Download Operations**
```bash
# Interactive repository selection and setup
python3 wallpimp.py --setup

# Download with custom directory
python3 wallpimp.py --repo nature --dir ~/MyWallpapers

# High-speed download with 8 workers
python3 wallpimp.py --repo minimalist --workers 8

# Download from custom GitHub repository
python3 wallpimp.py --url https://github.com/user/wallpapers --branch main

# Bulk download with progress tracking
python3 wallpimp.py --all --workers 6
```

### **Wallpaper Management**
```bash
# Set specific image as wallpaper
python3 wallpimp.py --static --dir ~/Pictures --image ~/Pictures/favorite.jpg

# Start slideshow with complex timing
python3 wallpimp.py --slideshow --dir ~/Pictures --interval "2h 30m"

# Quick 30-second slideshow for testing
python3 wallpimp.py --slideshow --dir ~/Pictures --interval 30s
```

### **Autostart Configuration**
```bash
# Enable slideshow to start on login
python3 wallpimp.py --enable-autostart --dir ~/Pictures --interval 15m

# Enable static wallpaper on login
python3 wallpimp.py --enable-autostart --dir ~/Pictures

# Disable autostart
python3 wallpimp.py --disable-autostart
```

### **Maintenance**
```bash
# Clean cache and orphaned entries
python3 wallpimp.py --cleanup
```

## 🛠️ Command Line Reference

### **Download Options**
```
--list                     List all curated repositories
--repo REPO               Download from specific repository
--url URL                 Download from GitHub repository URL
--branch BRANCH           Repository branch (default: main)
--all                     Download from all repositories
--dir DIR                 Download directory
--workers N               Parallel workers (default: 4)
--cleanup                 Clean cache and orphaned entries
```

### **Wallpaper Management**
```
--setup                   Interactive configuration wizard
--static                  Set random static wallpaper
--slideshow              Start slideshow mode
--interval TIME          Slideshow interval (30s, 5m, 1h, "1h 30m")
--image PATH             Specific image for static mode
```

### **Autostart Management**
```
--enable-autostart       Enable autostart functionality
--disable-autostart      Disable autostart functionality
```

## 🖥️ Supported Desktop Environments

### **Full Native Support**
- **GNOME** (gsettings)
- **KDE/Plasma** (qdbus)
- **XFCE** (xfconf-query)
- **MATE** (gsettings)
- **Cinnamon** (gsettings)
- **LXDE** (pcmanfm)
- **LXQt** (pcmanfm-qt)

### **Window Manager Support**
- **i3, Sway, bspwm** (via feh/sway commands)
- **Openbox, Fluxbox** (via feh)
- **dwm, Awesome, Qtile** (via feh)
- **Universal fallback** (feh, nitrogen, hsetroot)

## ⏱️ Time Format Examples

WallPimp Enhanced supports flexible time interval formats:

```bash
# Simple formats
--interval 30s           # 30 seconds
--interval 5m            # 5 minutes
--interval 2h            # 2 hours

# Precise combinations
--interval "1h 30m"      # 1 hour 30 minutes
--interval "2h 15m 30s"  # 2 hours 15 minutes 30 seconds
--interval "45m 30s"     # 45 minutes 30 seconds
```

## 🔧 How It Works

### **Repository Discovery**
Uses GitHub API to recursively traverse repository structures, identifying all image files regardless of location. Ensures comprehensive wallpaper collection coverage.

### **Universal Desktop Integration**
Automatically detects your desktop environment using multiple detection methods:
- Environment variables (`XDG_CURRENT_DESKTOP`, `DESKTOP_SESSION`)
- Process detection for window managers
- Intelligent fallback chain for maximum compatibility

### **Smart Slideshow System**
- **Background operation**: Runs as daemon thread
- **Graceful shutdown**: Handles system signals properly
- **Random rotation**: Shuffles wallpapers for variety
- **Error recovery**: Continues operation despite individual failures

### **Autostart Integration**
Creates XDG-compliant `.desktop` entries in `~/.config/autostart/` for seamless integration with all desktop environments.

## 📁 File Organization

### **Default Structure**
```
~/Pictures/WallPimp/
├── anime/                    # Anime wallpapers by category
├── nature/                   # Nature photography
├── minimalist/               # Clean, minimal designs
├── .wallpimp_cache.json      # Smart cache system
└── wallpimp.log             # Comprehensive logging
```

### **Autostart Configuration**
```
~/.config/autostart/
└── wallpimp-slideshow.desktop # XDG autostart entry
```

## 🔍 Troubleshooting

### **Desktop Environment Issues**
```bash
# Check detected desktop environment
python3 wallpimp.py --setup

# Test wallpaper setting manually
python3 wallpimp.py --static --dir ~/Pictures
```

### **Dependency Problems**
```bash
# Manual dependency check
python3 -c "import requests, tqdm, PIL, colorama; print('All dependencies OK')"

# Force dependency installation
python3 wallpimp.py --list  # Triggers auto-installation
```

### **Slideshow Not Working**
```bash
# Verify wallpaper directory has images
ls ~/Pictures/*.{jpg,png,jpeg} 2>/dev/null | wc -l

# Test with shorter interval
python3 wallpimp.py --slideshow --dir ~/Pictures --interval 10s

# Check autostart entry
ls ~/.config/autostart/wallpimp-slideshow.desktop
```

### **Performance Optimization**
```bash
# Reduce workers for slower systems
python3 wallpimp.py --repo anime --workers 2

# Use local directory for faster access
python3 wallpimp.py --slideshow --dir /home/user/Pictures --interval 1m
```

## 🤝 Contributing

### **Adding New Repositories**
1. Verify repository contains high-quality wallpapers
2. Check proper licensing for redistribution  
3. Add entry to `REPOSITORIES` dictionary
4. Include emoji, description, and default branch
5. Test functionality with WallPimp Enhanced

### **Desktop Environment Support**
1. Add detection logic to `DesktopEnvironmentManager`
2. Implement wallpaper setting commands
3. Test on actual desktop environment
4. Update documentation

## 📄 License

MIT License - Individual wallpapers retain their original licensing terms from respective repositories.

## 💬 Support & Tips

### **Getting Help**
- Check `wallpimp.log` in download directory for detailed errors
- Use `--setup` for guided configuration
- Verify internet connectivity and GitHub access
- Try `--cleanup` for cache-related issues

### **Pro Tips**
- **First time?** Start with `--setup` for guided configuration
- **Testing?** Use `--interval 30s` for quick slideshow testing  
- **Slow connection?** Reduce workers: `--workers 2`
- **Storage conscious?** Download specific repos instead of `--all`
- **Multiple monitors?** Most desktop environments handle this automatically
- **Custom timing?** Use precise intervals: `--interval "1h 15m 30s"`

## 🎉 What's New in Enhanced

- ✅ **Universal Linux slideshow support**
- ✅ **Interactive setup wizard** 
- ✅ **Autostart integration**
- ✅ **Flexible time parsing**
- ✅ **Desktop environment auto-detection**
- ✅ **Graceful shutdown handling**
- ✅ **Background slideshow operation**
- ✅ **Enhanced error recovery**

---

**Ready to transform your desktop?** Start with `python3 wallpimp.py --setup` and enjoy endless beautiful wallpapers! 🚀
