# WallPimp 🖼️

**The Ultimate Wallpaper Manager**

WallPimp is a powerful, cross-platform wallpaper downloader and manager that automatically fetches high-quality wallpapers from curated GitHub repositories. With intelligent caching, parallel downloads, and organized storage, WallPimp makes building your wallpaper collection effortless.

## Features ✨

**Smart Repository Management**
- 12+ curated wallpaper repositories covering diverse styles
- Support for any public GitHub repository
- Automatic recursive directory traversal
- Branch-specific downloads (main, dev, etc.)

**Intelligent Download System**
- Multi-threaded parallel downloads for speed
- Smart caching prevents duplicate downloads
- Automatic image validation and corruption detection
- Resume capability for interrupted downloads

**Cross-Platform Compatibility**
- Works on Linux, macOS, and Windows
- Automatic dependency installation with multiple fallback strategies
- Handles system package manager differences gracefully

**User-Friendly Interface**
- Colorful terminal output with progress bars
- Detailed statistics and error reporting
- Organized folder structure by repository
- Comprehensive logging system

## Installation 🚀

WallPimp automatically handles dependency installation, but you can install manually if needed:

### Automatic Installation (Recommended)
```bash
# Clone the repository
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp

# Run WallPimp - it will install dependencies automatically
python3 wallpimp.py --list
```

### Manual Installation
```bash
# For Arch Linux
sudo pacman -S python-requests python-tqdm python-pillow python-colorama

# For Ubuntu/Debian
sudo apt install python3-requests python3-tqdm python3-pil python3-colorama

# For Fedora
sudo dnf install python3-requests python3-tqdm python3-pillow python3-colorama

# Via pip (if system allows)
pip3 install requests tqdm Pillow colorama
```

## Quick Start 🏃‍♂️

**View available repositories:**
```bash
python3 wallpimp.py --list
```

**Download from a curated repository:**
```bash
python3 wallpimp.py --repo anime
```

**Download from all curated repositories:**
```bash
python3 wallpimp.py --all
```

**Download from any GitHub repository:**
```bash
python3 wallpimp.py --url https://github.com/username/wallpapers
```

## Curated Repositories 🎨

WallPimp includes carefully selected repositories covering various aesthetic preferences:

| Repository | Theme | Description |
|------------|--------|-------------|
| 🖼️ **minimalist** | Clean Design | Minimalist and clean aesthetic wallpapers |
| 🌸 **anime** | Anime/Manga | High-quality anime and manga artwork |
| 🌿 **nature** | Landscapes | Beautiful nature and landscape photography |
| 🏞️ **scenic** | Vistas | Breathtaking scenic vistas and panoramas |
| 🎨 **artistic** | Art Styles | Diverse artistic styles and digital art |
| 🎎 **anime_pack** | Curated Anime | Carefully curated anime wallpaper collection |
| 🐧 **linux** | Linux Themes | Linux desktop and distribution-themed art |
| 🌟 **mixed** | Diverse | Mixed collection of various styles |
| 💻 **desktop** | Desktop Focus | Minimalist desktop-oriented wallpapers |
| 🎮 **gaming** | Gaming | Gaming-inspired artwork and screenshots |
| 📷 **photos** | Photography | Professional photography and artistic shots |
| 🖥️ **digital** | Digital Art | Modern digital creations and computer art |

## Usage Examples 💡

**Basic Downloads:**
```bash
# List all available curated repositories
python3 wallpimp.py --list

# Download anime wallpapers
python3 wallpimp.py --repo anime

# Download nature wallpapers with custom directory
python3 wallpimp.py --repo nature --dir ~/MyWallpapers
```

**Advanced Usage:**
```bash
# Download with 8 parallel workers for faster speeds
python3 wallpimp.py --repo minimalist --workers 8

# Download from specific branch
python3 wallpimp.py --url https://github.com/user/walls --branch development

# Download everything from all curated repositories
python3 wallpimp.py --all --workers 6
```

**Maintenance:**
```bash
# Clean up cache and remove orphaned entries
python3 wallpimp.py --cleanup
```

## Command Line Options 🛠️

```
Options:
  --dir DIR          Download directory (default: ~/Pictures/WallPimp)
  --repo REPO        Download from specific curated repository
  --url URL          Download from any GitHub repository URL
  --branch BRANCH    Repository branch to use (default: main)
  --list             List all available curated repositories
  --all              Download from all curated repositories
  --workers N        Number of download workers (default: 4)
  --cleanup          Clean up cache and remove orphaned entries
  --help             Show help message and exit
```

## How It Works 🔧

**Repository Discovery:**
WallPimp uses the GitHub API to recursively traverse repository structures, identifying all image files regardless of their location within the repository. This ensures comprehensive coverage of wallpaper collections.

**Smart Caching:**
The tool maintains a cache file (`.wallpimp_cache.json`) in your download directory to track previously downloaded files. This prevents unnecessary re-downloads and enables efficient incremental updates.

**File Organization:**
Downloaded wallpapers are organized into folders named after their source repositories, maintaining any subdirectory structure from the original repository. This creates a clean, browsable collection.

**Image Validation:**
Every downloaded file undergoes validation using PIL (Python Imaging Library) to ensure image integrity. Corrupted or invalid files are automatically removed and marked as failed downloads.

## Configuration 📁

**Default Download Location:**
- Linux/macOS: `~/Pictures/WallPimp/`
- Windows: `%USERPROFILE%\Pictures\WallPimp\`

**File Structure:**
```
WallPimp/
├── anime/              # Anime wallpapers
├── nature/             # Nature wallpapers
├── minimalist/         # Minimalist wallpapers
├── .wallpimp_cache.json # Cache file
└── wallpimp.log        # Log file
```

**Cache Management:**
The cache system tracks downloaded files and prevents duplicates. Use `--cleanup` to remove entries for files that no longer exist on disk.

## Troubleshooting 🔍

**Dependency Installation Issues:**
WallPimp tries multiple installation strategies automatically. If automatic installation fails, install dependencies manually using your system's package manager as shown in the installation section.

**Permission Errors:**
If you encounter permission errors, try:
- Using `--dir` to specify a different download directory
- Running with appropriate permissions for your system
- Checking that the target directory is writable

**Network Issues:**
- Ensure stable internet connection
- GitHub API has rate limits; WallPimp includes respectful delays
- Use fewer workers (`--workers 2`) if experiencing connection issues

**Storage Space:**
- Check available disk space before running `--all`
- Monitor the statistics output for download progress
- Use `--cleanup` to remove orphaned cache entries

## Contributing 🤝

We welcome contributions to expand the curated repository collection! To add a new repository:

1. Ensure the repository contains high-quality wallpapers
2. Verify it has proper licensing for redistribution
3. Add an entry to the `REPOSITORIES` dictionary in `wallpimp.py`
4. Include an appropriate emoji, description, and default branch
5. Test the repository works correctly with WallPimp

## License 📄

This project is open source and available under the MIT License. Individual wallpapers downloaded through WallPimp retain their original licensing terms from their respective repositories.

## Support 💬

If you encounter issues or have suggestions:
- Check the log file in your download directory for detailed error information
- Ensure all dependencies are properly installed
- Verify your internet connection and GitHub accessibility
- Use the `--cleanup` option to resolve cache-related issues

**Pro Tips:**
- Start with a single repository to test your setup
- Use `--workers 2` on slower connections to avoid timeouts
- The `--list` command helps you discover new wallpaper styles
- Cache files make subsequent runs much faster by skipping duplicates

Happy wallpaper collecting! 🎉
