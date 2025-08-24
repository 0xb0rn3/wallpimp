# WallPimp 🎨

**Universal Linux Wallpaper Manager**

WallPimp is a comprehensive wallpaper management solution that combines powerful downloading capabilities with universal Linux slideshow functionality. Automatically fetch high-quality wallpapers from curated GitHub repositories and enjoy seamless slideshow experiences across all desktop environments.

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
- **Interactive menu system**: Easy-to-use interface for all operations

### 🔧 **Cross-Platform Compatibility**
- Universal Linux distribution support
- Automatic dependency installation with multiple fallback strategies
- Handles system package manager differences gracefully
- Fallback wallpaper setters for window managers

### 🎯 **User-Friendly Interface**
- Interactive menu for effortless navigation
- Colorful terminal output with progress bars
- First-run setup with update checking
- Comprehensive error handling and recovery

## 🚀 Installation & Usage

### Quick Start
```bash
# Clone the repository
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp

# Make executable and run
chmod +x run
./run
```

### First Run
On first execution, WallPimp will:
- Automatically install required dependencies
- Check for updates (with user consent)
- Launch interactive setup wizard
- Create configuration files

## 🏃‍♂️ Interactive Menu

WallPimp features a comprehensive interactive menu system:

```
🎨 WallPimp Interactive Menu
==================================================
1. Download wallpapers from repository
2. Download from all repositories  
3. Download from custom URL
4. Set static wallpaper
5. Start carousel mode
6. Enable autostart carousel
7. Disable autostart
8. Clean cache
9. View repositories
10. Check for updates
0. Exit
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

### **Interactive Mode (Recommended)**
```bash
# Launch interactive menu
./run

# First-time users get guided setup
./run  # Will trigger first-run setup automatically
```

### **Command Line Mode**
```bash
# Download operations
./run --repo anime                    # Download anime wallpapers
./run --all --workers 8              # Download all with 8 workers
./run --url https://github.com/user/wallpapers --branch main

# Wallpaper management
./run --static --dir ~/Pictures      # Set random wallpaper
./run --carousel --dir ~/Pictures --interval 5m  # Start 5-minute slideshow
./run --setup                         # Interactive configuration

# Autostart management  
./run --enable-autostart --dir ~/Pictures --interval 10m
./run --disable-autostart

# Maintenance
./run --cleanup                       # Clean cache
./run --list                         # View repositories
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

WallPimp supports flexible time interval formats:

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

## 🛠️ Command Line Reference

### **Download Options**
```
--list                     List all curated repositories
--repo REPO               Download from specific repository
--url URL                 Download from GitHub repository URL
--branch BRANCH           Repository branch (default: main)
--all                     Download from all repositories
--dir DIR                 Download directory (default: ~/Pictures)
--workers N               Parallel workers (default: 4)
--cleanup                 Clean cache and orphaned entries
```

### **Wallpaper Management**
```
--setup                   Interactive configuration wizard
--static                  Set random static wallpaper
--carousel                Start slideshow mode
--interval TIME          Slideshow interval (30s, 5m, 1h, "1h 30m")
--image PATH             Specific image for static mode
```

### **Autostart Management**
```
--enable-autostart       Enable autostart functionality
--disable-autostart      Disable autostart functionality
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

### **Update System**
- **Automatic checking**: Optional update checking on startup
- **GitHub integration**: Checks latest releases from repository
- **User consent**: Always asks before checking for updates
- **Manual checking**: Available through interactive menu

## 📁 File Organization

### **Default Structure**
```
~/Pictures/
├── wallpaper1.jpg            # Downloaded wallpapers (flattened)
├── wallpaper2.png            # All images in root directory
├── wallpaper3.jpg            # Perfect for slideshow usage
├── .wallpimp_cache.json      # Smart cache system
└── wallpimp.log             # Comprehensive logging
```

### **Configuration Files**
```
~/.config/wallpimp/
└── config.json              # User configuration

~/.config/autostart/
└── wallpimp-carousel.desktop # XDG autostart entry
```

## 🔍 Troubleshooting

### **First Run Issues**
```bash
# If dependencies fail to install automatically
sudo pacman -S python-requests python-tqdm python-pillow python-colorama  # Arch
sudo apt install python3-requests python3-tqdm python3-pil python3-colorama  # Ubuntu/Debian
sudo dnf install python3-requests python3-tqdm python3-pillow python3-colorama  # Fedora

# Make script executable
chmod +x run
```

### **Desktop Environment Issues**
```bash
# Check detected desktop environment - run interactive mode
./run
# Select option 4 (Set static wallpaper) to test detection

# Manual wallpaper setting test
feh --bg-fill ~/Pictures/somewallpaper.jpg  # Universal fallback
```

### **Slideshow Not Working**
```bash
# Verify wallpaper directory has images
ls ~/Pictures/*.{jpg,png,jpeg} 2>/dev/null | wc -l

# Test with shorter interval
./run --carousel --dir ~/Pictures --interval 10s

# Check autostart entry
cat ~/.config/autostart/wallpimp-carousel.desktop
```

### **Network/Download Issues**
```bash
# Test with fewer workers
./run --repo anime --workers 2

# Clean cache if issues persist
./run --cleanup

# Check GitHub connectivity
curl -I https://api.github.com/repos/0xb0rn3/wallpimp
```

## 👨‍💻 Developer Info

**Developer**: 0xb0rn3  
**Email**: q4n0@proton.me  
**Discord**: 0xbv1  
**Twitter**: 0xbv1  
**Instagram**: theehiv3  
**Repository**: https://github.com/0xb0rn3/wallpimp

## 🤝 Contributing

### **Adding New Repositories**
1. Verify repository contains high-quality wallpapers
2. Check proper licensing for redistribution  
3. Add entry to `rainbow_repositories` dictionary in code
4. Include emoji, description, and default branch
5. Test functionality with WallPimp

### **Desktop Environment Support**
1. Add detection logic to `PaintbrushEnvironmentWizard`
2. Implement wallpaper setting commands
3. Test on actual desktop environment
4. Update documentation

## 📄 License

MIT License - Individual wallpapers retain their original licensing terms from respective repositories.

## 💬 Support & Tips

### **Getting Help**
- Use interactive mode: `./run` for guided experience
- Check `wallpimp.log` in your directory for detailed errors
- Use `--cleanup` for cache-related issues
- Verify internet connectivity and GitHub access

### **Pro Tips**
- **First time?** Just run `./run` - the interactive menu guides you through everything
- **Testing slideshow?** Use `--interval 30s` for quick testing  
- **Slow connection?** Reduce workers: `--workers 2`
- **Storage conscious?** Download specific repos instead of `--all`
- **Multiple monitors?** Most desktop environments handle this automatically
- **Custom timing?** Use precise intervals: `--interval "1h 15m 30s"`
- **Autostart setup?** Use the interactive menu option 6 for guided setup

## 🎯 Key Features Summary

- ✅ **Interactive menu system** for easy navigation
- ✅ **Universal Linux slideshow support** across all DE/WM
- ✅ **First-run setup** with dependency management
- ✅ **Update checking** with user consent
- ✅ **Autostart integration** via XDG standards
- ✅ **Flexible time parsing** for precise intervals
- ✅ **Smart caching** prevents re-downloads
- ✅ **Graceful error handling** and recovery
- ✅ **Command-line compatibility** for automation

---

**Ready to transform your desktop?** Simply run `./run` and let the interactive menu guide you! 🚀
