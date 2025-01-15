# WallPimp 🖼️

A cross-platform automated wallpaper collection tool that fetches high-quality wallpapers from curated GitHub repositories.

```
╔══════════════════════════════════════════════════╗
║                 WallPimp v2.1                    ║
║        Developed by ソロックス (oxborn3)          ║
║        https://github.com/0xb0rn3               ║
╚══════════════════════════════════════════════════╝
```

## Features

- 🚀 Fast parallel downloading with smart retry mechanism
- 🖼️ Support for multiple image formats (JPG, PNG, GIF, BMP, WEBP, TIFF, SVG, HEIC)
- 🔄 Automatic duplicate detection using SHA-256 hashing
- 📁 Organized output with repository-based naming
- ⚡ Minimal UI with real-time progress tracking
- 🛡️ Built-in safety checks for file size and format validation
- 💻 Cross-platform support (Windows, Linux, macOS)

## Installation

### Option 1: Running from Source

1. Ensure you have Python 3.6+ and Git installed
2. Clone this repository:
   ```bash
   git clone https://github.com/0xb0rn3/wallpimp.git
   cd wallpimp
   ```
3. Install required packages:
   ```bash
   pip install tqdm
   ```
4. Make the script executable (Linux/macOS):
   ```bash
   chmod +x wallpimp
   ```

### Option 2: Windows Executable

1. Download the latest release from the releases page
2. Extract the ZIP file
3. Run `wallpimp.exe` in dist folder

## Building the Windows Executable

To create the executable yourself:

1. Install PyInstaller:
   ```bash
   pip install pyinstaller
   ```

2. Build the executable:
   ```bash
   pyinstaller --onefile --icon=icon.ico wallpimp
   ```
   The executable will be created in the `dist` directory.

## Usage

Simply run the script:
```bash
# Linux/macOS
./wallpimp

# Windows
wallpimp.exe
```

The tool will:
1. Create a `WallPimp` folder in your Pictures directory
2. Download and process wallpapers from curated repositories
3. Show real-time progress and status updates
4. Clean up temporary files automatically

## Configuration

The script includes several configurable parameters:

- `MAX_IMAGE_SIZE`: Maximum allowed image size (default: 50MB)
- `MIN_IMAGE_SIZE`: Minimum allowed image size (default: 10KB)
- `MAX_RETRIES`: Number of retry attempts for failed downloads (default: 3)
- `CLONE_TIMEOUT`: Repository clone timeout in seconds (default: 180)

## Contributing

Contributions are welcome! Feel free to:
- Add new wallpaper repositories to the collection
- Improve error handling and performance
- Add new features
- Report bugs or suggest improvements

## License

MIT License - See LICENSE file for details

## Credits

Developed by ソロックス (oxborn3)  
GitHub: [@0xb0rn3](https://github.com/0xb0rn3)

Special thanks to the maintainers of the wallpaper repositories used in this tool.
