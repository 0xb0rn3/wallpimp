# WallPimp v2.1 🖼️

A sophisticated cross-platform wallpaper collection tool that automatically fetches high-quality wallpapers from curated GitHub repositories. WallPimp helps you build an extensive wallpaper collection while handling duplicates, ensuring quality, and providing clear feedback throughout the process.

## Features

WallPimp comes packed with powerful features to enhance your wallpaper collection experience:

- Automatic fetching from multiple curated GitHub repositories
- Duplicate detection using SHA-256 hashing
- Image validation to ensure quality and appropriate file sizes
- Multi-threaded downloading for optimal performance
- Progress tracking with detailed status updates
- Cross-platform support (Windows, Linux, macOS)
- Configurable image format and size constraints
- Elegant error handling and retry mechanisms

## Installation

### Prerequisites

Before installing WallPimp, ensure you have the following installed:
- Python 3.8 or higher
- Git
- ImageMagick (optional, for custom icon creation)

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp
```

2. Make the script executable:
```bash
chmod +x wallpimp
```

3. Run WallPimp:
```bash
./wallpimp
```

### Building the Windows Executable

To create a standalone Windows executable:

1. Set up a Python virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Linux/macOS
venv\Scripts\activate     # On Windows
```

2. Run the build script:
```bash
./build.py
```

The executable will be created in the `dist` folder.

## Usage

WallPimp is designed to be simple to use while offering powerful functionality. Simply run the script, and it will:

1. Create a `WallPimp` folder in your Pictures directory
2. Download and process wallpapers from curated repositories
3. Show progress with a dynamic progress bar
4. Provide status updates for each repository
5. Display a summary when complete

### Default Save Location

- Windows: `%USERPROFILE%\Pictures\WallPimp`
- Linux: `~/Pictures/WallPimp`
- macOS: `~/Pictures/WallPimp`

### Configuration

WallPimp comes with sensible defaults that you can modify in the script:

```python
# Supported image formats
IMAGE_FORMATS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg', '.heic'}

# Size constraints
MAX_IMAGE_SIZE = 50 * 1024 * 1024  # 50MB maximum file size
MIN_IMAGE_SIZE = 10 * 1024         # 10KB minimum file size

# Download settings
MAX_RETRIES = 3                    # Maximum retry attempts
CLONE_TIMEOUT = 180                # Repository clone timeout in seconds
```

## Troubleshooting

### Common Issues

1. **Git not found error**
   - Ensure Git is installed and accessible from the command line
   - Verify Git installation: `git --version`

2. **Permission denied errors**
   - Check write permissions in the Pictures directory
   - Run with appropriate permissions for your system

3. **Network-related issues**
   - Verify your internet connection
   - Check if you can access GitHub
   - Consider using a VPN if GitHub is blocked in your region

4. **Build script errors**
   - Ensure you're using a virtual environment
   - Verify Python version compatibility
   - Install required build dependencies

### Getting Help

If you encounter any issues:
1. Check the existing issues on GitHub
2. Provide detailed error messages when reporting problems
3. Include your system information and WallPimp version

## Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch: `git checkout -b new-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin new-feature`
5. Submit a Pull Request

Please ensure your code follows the existing style and includes appropriate tests.

## Credits

WallPimp was developed by ソロックス (oxborn3) and is maintained by the community. Special thanks to all the wallpaper repository maintainers who make their collections available.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Version History

- v2.1: Added multi-threading, improved error handling, enhanced progress tracking
- v2.0: Major rewrite with cross-platform support and automated building
- v1.0: Initial release

---

Developed with ❤️ by [ソロックス (oxborn3)](https://github.com/0xb0rn3)
