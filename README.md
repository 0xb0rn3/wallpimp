# WallPimp 🖼️

## Overview

WallPimp is an advanced wallpaper collection tool designed to automatically download and organize high-quality wallpapers from curated GitHub repositories. With support for multiple image formats and intelligent duplicate prevention, WallPimp makes building your perfect wallpaper collection effortless.

![WallPimp Banner](https://via.placeholder.com/800x200.png?text=WallPimp+Wallpaper+Downloader)

## 🌟 Features

- **Multi-Repository Support**: Automatically downloads wallpapers from multiple carefully selected GitHub repositories
- **Comprehensive Format Support**: Handles 20+ image formats including JPG, PNG, WEBP, RAW, SVG, and more
- **Intelligent Duplicate Prevention**: Uses SHA256 hashing to avoid redundant downloads
- **Flexible Save Location**: Choose your preferred wallpaper destination
- **Detailed Logging**: Provides comprehensive download statistics
- **Cross-Distribution Compatibility**: Works on major Linux distributions

## 🛠 Requirements

### Supported Systems
- Linux distributions with:
  - `bash`
  - `git`
  - `file`
  - `find`

### Recommended Distributions
- Ubuntu/Debian
- Fedora
- Arch Linux
- Other systemd-based Linux distributions

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp
```

### 2. Make Script Executable
```bash
chmod +x run
```

## 🖥️ Usage

```bash
./run
```

When prompted, choose your wallpaper save location (default is `~/Pictures/Wallpapers`).

## 🔍 How It Works

1. Checks system dependencies
2. Clones curated wallpaper repositories
3. Processes images with intelligent filtering
4. Saves unique wallpapers to your specified directory

## 📦 Included Repositories

WallPimp currently downloads from these high-quality wallpaper repositories:

- **dharmx/walls**: Minimal and aesthetic wallpapers
- **FrenzyExists/wallpapers**: Nature and abstract art
- **michaelScopic/Wallpapers**: Scenic landscapes
- **ryan4yin/wallpapers**: Anime and digital art
- **port19x/Wallpapers**: Minimalist designs
- **D3Ext/aesthetic-wallpapers**: Artistic collections
- **makccr/wallpapers**: Mixed high-quality wallpapers

## 🔧 Customization

### Adding Repositories
Edit the `REPOS` array in the script to add or modify repository sources.

Repository format:
```bash
"https://github.com/username/repo,branch,description"
```

## 📊 Version

- **Current Version**: 0.3 Stable
- **Developer**: 0xb0rn3
- **GitHub**: https://github.com/0xb0rn3

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

## 🐛 Issues

Report issues on the GitHub Issues page: https://github.com/0xb0rn3/wallpimp/issues

## 💖 Support the Project

If you find WallPimp useful, consider:
- ⭐ Starring the repository
- 🐦 Following the developer on GitHub
- 💡 Suggesting improvements or new features

---

**Disclaimer**: Wallpapers are downloaded from public repositories. Ensure you respect the original artists' rights and licensing.
