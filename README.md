# WallPimp: Ultimate Wallpaper Downloader 🖼️

## 🖥️ Windows Users: Getting Started (Recommended First Read)

### 🛡️ Understanding Windows Security & Execution Policies

#### What is an Execution Policy?
Think of an execution policy like a security guard for your computer. It decides which scripts can run and helps protect you from potentially harmful code. WallPimp needs you to slightly adjust these settings to work smoothly.

### 🚀 Quick Installation Methods for Windows

#### Method 1: One-Click Magical Installation (Recommended)
1. Open PowerShell as Administrator
   - Press Windows Key
   - Type "PowerShell"
   - Right-click and choose "Run as Administrator"

2. Paste ENTIRE command (copy carefully):
```powershell
irm https://raw.githubusercontent.com/0xb0rn3/WallPimp/main/wallpimp.ps1 | iex
```

#### Method 2: Execution Policy Configuration
```powershell
# Run this in Administrator PowerShell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Method 3: Manual Download
1. Visit [WallPimp GitHub Releases](https://github.com/0xb0rn3/WallPimp/releases)
2. Download `wallpimp.ps1`
3. Right-click → Run with PowerShell

   Flexible Command-Line Parameters

- # Standard usage
.\WallPimp.ps1

# Skip downloads
.\WallPimp.ps1 -NoDownload

# Filter by high-resolution images (4K)
.\WallPimp.ps1 -FilterByResolution -MinResolutionWidth 3840 -MinResolutionHeight 2160

### 🛠️ Windows System Requirements
- Windows 10 or 11
- PowerShell 5.1+
- Minimum 2GB free disk space
- Stable internet connection

## 🐧 Linux Users: Comprehensive Installation Guide

### Dependency Preparation
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3 python3-pip git

# Fedora
sudo dnf install python3 python3-pip git

# Arch Linux
sudo pacman -S python python-pip git
```

### Installation Methods

#### Method 1: Direct Repository Clone
```bash
# Clone WallPimp Repository
git clone https://github.com/0xb0rn3/WallPimp.git
cd WallPimp

# Install Python Dependencies
pip3 install --user pillow rich aiohttp

# Make Script Executable
chmod +x run.py

# Run WallPimp
./run.py
```

#### Method 2: Quick Installation Script
```bash
# Download and Execute (Advanced Users)
curl -sSL https://raw.githubusercontent.com/0xb0rn3/WallPimp/main/install.sh | bash
```

### 🐧 Linux System Requirements
- Python 3.7+
- Supported Distributions:
  - Ubuntu
  - Debian
  - Fedora
  - Arch Linux
  - Most modern Linux distributions

## 🖼️ What WallPimp Does

### Intelligent Wallpaper Curation
- Downloads from 18+ curated GitHub repositories
- Supports multiple themes:
  - Minimalist Designs
  - Nature Landscapes
  - Digital Art
  - Anime Aesthetics
  - Urban Photography
  - Space & Sci-Fi Concepts

### Image Quality Filtering
- Minimum resolution: 1920x1080
- Duplicate image detection
- Supports formats:
  - JPEG
  - PNG
  - WebP
  - GIF
  - BMP

## 🔒 Security & Privacy

### Safety Principles
- Open-source project
- No personal data collection
- Minimal system modifications
- Transparent dependency management

### Recommended Precautions
- Review script contents
- Use updated antivirus
- Install in controlled environments

## 🛠️ Customization Options

### Adding Custom Repositories
- Edit `REPOS` list in script
- Ensure repository contains image files
- Verify repository accessibility

## 🐛 Troubleshooting

### Windows Common Issues
- Execution policy restrictions
- Antivirus interference
- Connectivity problems

### Linux Common Challenges
- Python package conflicts
- Permission issues
- Repository access problems

## 🤝 Contribution Guidelines

### How to Contribute
1. Fork the repository
2. Create feature branch
3. Implement changes
4. Submit pull request

### Contribution Areas
- Repository source expansion
- Image processing enhancements
- Cross-platform compatibility
- Bug fixes and optimization

## 📊 Project Metadata

### Versions
- **Windows Version**: 1.2
- **Linux Version**: 0.4 Stable
- **Last Updated**: January 2024

### Licensing
- MIT License
- Free for personal and commercial use

## 📞 Support Channels

### Community Support
- [GitHub Issues Tracker](https://github.com/0xb0rn3/WallPimp/issues)
- Developer: [0xb0rn3 on GitHub](https://github.com/0xb0rn3)

## 🌟 Final Thoughts

WallPimp isn't just a wallpaper downloader—it's a gateway to digital aesthetic exploration. Whether you're a design enthusiast, photography lover, or art collector, WallPimp brings the world's most captivating visuals to your desktop.

### 🎨 Happy Wallpaper Hunting! 🖥️

**Remember**: Great digital spaces begin with inspiring wallpapers. Enjoy your visual journey!
