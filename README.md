# WallPimp 🎨

WallPimp is a cross-platform automated wallpaper collection tool that fetches high-quality wallpapers from curated GitHub repositories. It streamlines the process of building your wallpaper collection by automatically downloading and organizing images from multiple sources.

## Features

WallPimp comes packed with features to make wallpaper collection efficient and hassle-free:

- Cross-platform support (Windows, Linux, macOS)
- Automated collection from multiple curated repositories
- Support for various image formats (JPG, PNG, WebP, TIFF, SVG, etc.)
- Smart file organization with repository-based naming
- User-friendly interface for choosing save locations
- Progress tracking and detailed status updates
- Efficient downloading with shallow git clones
- Automatic cleanup of temporary files

## Installation

### Prerequisites

Before installing WallPimp, ensure you have the following installed on your system:

#### Windows:
1. Python 3.6 or higher
   - Download from [Python's official website](https://www.python.org/downloads/)
   - During installation, make sure to check "Add Python to PATH"

2. Git for Windows
   - Download from [Git's official website](https://git-scm.com/download/windows)
   - Choose "Use Git from the Windows Command Prompt" during installation

#### Linux:
Most Linux distributions come with Python pre-installed. If not, install the requirements:

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install python3 python3-pip git

# Fedora
sudo dnf install python3 python3-pip git

# Arch Linux
sudo pacman -S python python-pip git
```

### Setup

#### Windows:
1. Download the repository:
   - Option 1: Using Git Bash or Command Prompt
     ```bash
     git clone https://github.com/0xb0rn3/wallpimp.git
     ```
   - Option 2: Download ZIP from GitHub and extract it

2. Navigate to the directory:
   ```cmd
   cd wallpimp
   pip install tqdm
   ```

3. Make sure the script is executable:
   ```cmd
   python -m pip install --user pathlib
   ```

#### Linux:
1. Clone the repository:
   ```bash
   git clone https://github.com/0xb0rn3/wallpimp.git
   ```

2. Navigate to the directory:
   ```bash
   cd wallpimp
   pip install tqdm
   ```

3. Make the script executable:
   ```bash
   chmod +x wallpimp
   ```

## Usage

### Windows:
Run WallPimp using either:
```cmd
python wallpimp
```
or by double-clicking `wallpimp` in File Explorer

### Linux:
Run WallPimp using:
```bash
./wallpimp
```
or
```bash
python3 wallpimp
```

The tool will then:
1. Present you with options for where to save the wallpapers
2. Begin downloading from the curated repository list
3. Show progress for each repository being processed
4. Provide a summary of all wallpapers collected

### Save Location Options

WallPimp offers two options for saving wallpapers:

#### Windows:
1. Default location: `C:\Users\YourUsername\Pictures`
2. Custom location of your choice (e.g., `D:\Wallpapers`)

#### Linux:
1. Default location: `~/Pictures` or `/home/username/Pictures`
2. Custom location of your choice (e.g., `/media/wallpapers`)

## Default Save Locations by Platform

WallPimp automatically detects your operating system and uses the appropriate default paths:

Windows:
```
C:\Users\YourUsername\Pictures\
```

Linux:
```
/home/username/Pictures/
```

## Included Repositories

WallPimp currently fetches wallpapers from these curated sources:

- dharmx/walls
- FrenzyExists/wallpapers
- Dreamer-Paul/Anime-Wallpaper
- michaelScopic/Wallpapers
- ryan4yin/wallpapers
- HENTAI-CODER/Anime-Wallpaper
- port19x/Wallpapers
- k1ng440/Wallpapers
- vimfn/walls
- expandpi/wallpapers

## Supported Image Formats

WallPimp supports a wide range of image formats:

- JPEG/JPG
- PNG
- GIF
- BMP
- WebP
- TIFF
- SVG
- HEIC
- ICO

All formats are supported in both lowercase and uppercase variants.

## Troubleshooting

### Windows:
1. If Python is not recognized:
   - Ensure Python is added to PATH during installation
   - Try running `py` instead of `python`

2. If Git is not recognized:
   - Reinstall Git and select "Use Git from the Windows Command Prompt"
   - Restart your computer after installation

3. Permission errors:
   - Run Command Prompt as Administrator
   - Check antivirus settings

### Linux:
1. If the script won't execute:
   ```bash
   pip install tqdm
   chmod +x wallpimp
   ```

2. If Python is not found:
   ```bash
   which python3
   ```
   Ensure Python is installed and in your PATH

3. Permission errors:
   ```bash
   sudo chown -R $USER:$USER ~/Pictures
   ```

## Contributing

Contributions are welcome! If you'd like to contribute:

1. Fork the repository
2. Create a new branch for your feature
3. Commit your changes
4. Push to your branch
5. Open a Pull Request

## Known Issues

- Large repositories may take longer to process
- Some repositories might be temporarily unavailable
- Duplicate images across repositories will be renamed
- Windows Defender might scan downloads, causing slight delays

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Developed by [0xb0rn3](https://github.com/0xb0rn3)

## Acknowledgments

Special thanks to all the wallpaper repository maintainers who make their collections available to the community.
