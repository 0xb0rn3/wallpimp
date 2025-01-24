# WallPimp 🎮️ - Cross-Platform Wallpaper Collection Assistant

## 🌟 Overview

WallPimp is a versatile wallpaper collection tool designed for both Windows and Linux users. It allows you to automatically download and organize high-quality wallpapers from curated GitHub repositories. Whether you're on a Windows PC or a Linux distribution, WallPimp makes building your perfect wallpaper collection simple and efficient.

---

## 🚀 Features

- **Multi-Platform Support**: Runs on Windows (PowerShell script) and Linux (Bash executable).
- **Curated Repositories**: Sources wallpapers from multiple high-quality GitHub repositories.
- **Intelligent Filtering**:
  - Minimum resolution: 1920x1080
  - Supports 20+ image formats, including JPG, PNG, WEBP, RAW, and more.
  - Prevents duplicate downloads using SHA256 hashing.
- **Custom Save Locations**: Choose your wallpaper destination or use the default folder.
- **Logging and Statistics**: Provides comprehensive download and filtering logs.
- **Diverse Wallpaper Styles**:
  - Minimalist and aesthetic designs
  - Nature and abstract art
  - Scenic landscapes
  - Anime and digital art

---

## 🔠 Requirements

### For Windows
- Windows 10 or Windows 11
- PowerShell 5.1+ (pre-installed on most systems)
- Git for Windows

### For Linux
- `bash`
- `git`
- `file`
- `find`

Recommended Linux Distributions:
- Ubuntu/Debian
- Fedora
- Arch Linux
- Other systemd-based distributions

---

## 📋 Installation Steps

### On Windows
1. **Downlaod the wallpimp.ps1 file to your desired location example C:\Downloads**:

   then
    
3. **Set PowerShell Execution Policy**:
   - Open PowerShell as Administrator.
   - Copy Paste and Run: `Set-ExecutionPolicy RemoteSigned`

4. **Right-click `wallpimp.ps1`.**
5. **Select "Run with PowerShell."**
6. **Choose the wallpaper save location when prompted.** 

### On Linux
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/0xb0rn3/wallpimp.git
   cd wallpimp
   ```
2. **Make the Script Executable**:
   ```bash
   chmod +x run
   ```
3. **Run the script with**
   ```bash
   ./run

```
When prompted, choose your wallpaper save location (default: `~/Pictures/Wallpapers`).

---

## 🔍 How It Works

1. Verifies necessary dependencies (Git, PowerShell/bash).
2. Clones curated GitHub repositories.
3. Filters images based on resolution and format.
4. Prevents duplicate wallpapers using SHA256 hashes.
5. Saves unique wallpapers to the specified directory.
6. Provides a summary of downloads and operations.

---

## 🔧 Troubleshooting

### Common Issues on Windows
- **Git Not Installed**: Download [Git for Windows](https://git-scm.com/download/win).
- **PowerShell Execution Policy Blocked**:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
- **No Wallpapers Downloaded**: Check your internet connection or repository accessibility.

### Common Issues on Linux
- **Missing Dependencies**: Install `git`, `file`, or `find` via your package manager.
- **Permission Issues**: Ensure the script has executable permissions with `chmod +x run`.

---

## 📦 Included Repositories

WallPimp currently sources wallpapers from:
- Minimalist and aesthetic wallpaper collections.
- Nature and abstract art repositories.
- Scenic landscapes and cityscapes.
- Anime and digital art collections.

---

## 🤝 Contributing

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.


---

## 👨‍💻 Created By

- **Developer**: [0xb0rn3](https://github.com/0xb0rn3)
- **Version**:
  - Windows Edition: v1.0
  - Linux Edition: v0.3 (Stable)

---

**Happy Wallpaper Hunting!** 🎮️🎨

