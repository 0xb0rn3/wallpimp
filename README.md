# WallPimp: Automated Wallpaper Collection Tool

## 📖 Project Overview

WallPimp is a sophisticated, cross-platform wallpaper downloading utility designed to effortlessly curate high-quality wallpapers from multiple GitHub repositories. Developed by 0xb0rn3, this tool simplifies the process of building a diverse and visually stunning wallpaper collection.

## 🌟 Key Features

### Cross-Platform Compatibility
- **Linux**: Python-based implementation
- **Windows**: PowerShell script
- Consistent functionality across operating systems

### Advanced Image Curation
- Intelligent image filtering
- Minimum resolution check (1920x1080)
- Duplicate image removal
- Support for multiple image formats
- Automatic repository processing

### Diverse Wallpaper Sources
WallPimp aggregates wallpapers from multiple themed repositories:
- Minimalist & Aesthetic Designs
- Nature and Landscape Photography
- Digital Art and Anime
- Abstract and Artistic Compositions
- Space and Sci-Fi Themes
- Urban and Architectural Scenes
- Gaming and Pop Culture Imagery

## 🖥️ System Requirements

### Linux Requirements
- Python 3.7+
- Operating Systems:
  - Ubuntu
  - Fedora
  - Arch Linux
  - Other modern Linux distributions

#### Required Python Packages
- git
- pillow
- rich
- aiohttp

### Windows Requirements
- PowerShell 5.1+
- Windows 10 or 11
- Minimum 2GB free disk space
- Internet connection

## 🚀 Installation & Setup

### Linux Installation

#### Method 1: Direct Download
```bash
# Clone the repository
git clone https://github.com/0xb0rn3/WallPimp.git

# Navigate to project directory
cd WallPimp

# Make script executable
chmod +x run

# Install dependencies
pip install pillow rich aiohttp

# Run the script
./run
```

#### Method 2: Package Installation
```bash
# For Debian/Ubuntu
sudo apt-get update
sudo apt-get install python3-git python3-pillow python3-rich python3-aiohttp

# For Fedora
sudo dnf install python3-git python3-pillow python3-rich python3-aiohttp

# Clone and run
git clone https://github.com/0xb0rn3/WallPimp.git
cd WallPimp
./run
```

### Windows Installation

#### Method 1: PowerShell Direct Execution
1. Download `wallpimp.ps1` from GitHub releases
2. Open PowerShell as Administrator
3. Set execution policy:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
4. Navigate to script location
5. Run the script:
```powershell
.\wallpimp.ps1
```

#### Method 2: Git Clone
```powershell
# Clone repository
git clone https://github.com/0xb0rn3/WallPimp.git

# Navigate to directory
cd WallPimp

# Execute script
.\wallpimp.ps1
```

## 🔧 Usage Instructions

### Wallpaper Download Process
1. Script launches and displays welcome banner
2. Checks and installs necessary dependencies
3. Prompts for wallpaper save location
   - Default: 
     - Linux: `~/Pictures/Wallpapers`
     - Windows: `%USERPROFILE%\Pictures\Wallpapers`
4. Clones selected repositories
5. Processes and saves unique wallpapers

### Customization Options
- Edit repository list in source code
- Modify image processing criteria
- Add custom repository sources

## 🖼️ Image Quality Criteria

### Filtering Standards
- Minimum resolution: 1920x1080
- Unique content verification
- Hash-based duplicate detection
- Support for formats:
  - JPEG
  - PNG
  - WebP
  - GIF
  - BMP

## 🛡️ Security & Privacy

### Dependency Management
- Automatic dependency detection
- Secure, silent installations
- No personal data collection
- Open-source repositories only

### Execution Safety
- Limited system modifications
- Transparent dependency handling
- Optional manual repository review

## 🐛 Troubleshooting

### Common Linux Issues
- Ensure Python packages installed
- Check internet connectivity
- Verify GitHub repository access

### Common Windows Issues
- PowerShell execution policy
- Administrator privileges
- Antivirus interference

## 🤝 Contributing

### How to Contribute
1. Fork the repository
2. Create feature branch
3. Commit your changes
4. Push to branch
5. Create pull request

### Contribution Areas
- Additional repository sources
- Image processing improvements
- Cross-platform compatibility
- Bug fixes and optimizations

## 📊 Version Information
- **Linux Version**: 0.4 Stable
- **Windows Version**: 1.2
- **Last Updated**: January 2024
- **Platform Support**: Linux, Windows

## 📜 License
MIT License - Free for personal and commercial use

## 👥 Contact & Support
- **GitHub**: [0xb0rn3 on GitHub](https://github.com/0xb0rn3)
- **Issues**: [Project Issue Tracker](https://github.com/0xb0rn3/WallPimp/issues)

---

### 🎨 Enjoy Your New Wallpapers! 🖥️
