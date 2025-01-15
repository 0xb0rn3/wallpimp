# WallPimp v2.3

WallPimp is a sophisticated cross-platform automated wallpaper collection tool that efficiently fetches and organizes high-quality wallpapers from curated GitHub repositories. The tool is designed to handle large repositories with precision, providing robust error handling and detailed progress tracking.

## Features

### Advanced Download Management
- Supports repositories up to 1GB in size per file
- Intelligent handling of partial downloads and interruptions
- Resume capability for interrupted operations
- Automatic duplicate detection with interactive resolution
- Precise file verification and integrity checks

### Smart File Processing
- Validates image quality and resolution requirements
- Supports multiple image formats (JPG, PNG, GIF, BMP, WebP, TIFF)
- Ensures minimum resolution of 1280x720 (HD)
- Maintains original image metadata
- Implements efficient file deduplication using SHA-256 hashing

### Progress Tracking and Feedback
- Real-time progress indication for both repository and file operations
- Detailed statistics about downloaded content
- Comprehensive logging system
- Clear error reporting and status updates
- Interactive handling of duplicate files

### System Integration
- Cross-platform compatibility (Windows, macOS, Linux)
- Efficient resource utilization
- Automatic cleanup of temporary files
- Proper handling of system signals
- Integration with system picture directories

## Requirements

### System Requirements
- Python 3.7 or higher
- Git (must be installed and accessible from command line)
- At least 2GB of free RAM
- Sufficient disk space for downloaded wallpapers

### Python Dependencies
```bash
pip install pillow requests tqdm
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp
```

2. Install required dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage
Simply run the script from your terminal:
```bash
python wallpimp.py
```

The tool will automatically:
- Create necessary directories
- Download wallpapers from configured repositories
- Handle duplicates and errors
- Provide progress updates
- Save wallpapers to your Pictures directory

### Output Location
Wallpapers are saved in your system's Pictures directory:
- Windows: `%USERPROFILE%\Pictures\WallPimp`
- macOS: `~/Pictures/WallPimp`
- Linux: `~/Pictures/WallPimp` or `$XDG_PICTURES_DIR/WallPimp`

### Configuring Sources
The default configuration includes several curated wallpaper repositories. You can modify the `WALLPAPER_REPOS` list in the script to add or remove sources.

Example of adding a new repository:
```python
WALLPAPER_REPOS = [
    "https://github.com/your-repo-here",
    # ... existing repositories ...
]
```

### Configuration Options
You can customize various settings by modifying the constants at the beginning of the script:

```python
IMAGE_FORMATS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff'}
MAX_IMAGE_SIZE = 1024 * 1024 * 1024  # 1GB maximum file size
MIN_IMAGE_SIZE = 1 * 1024            # 1KB minimum file size
MIN_RESOLUTION = (1280, 720)         # Minimum resolution (HD)
```

## Error Handling and Recovery

### Interruption Recovery
If the download process is interrupted, WallPimp will:
- Save the current progress
- Remember successfully downloaded files
- Allow resuming from the last successful point
- Avoid re-downloading existing files

### Duplicate Handling
When duplicates are detected, WallPimp will:
1. Show the paths of both files
2. Display file information
3. Ask whether to keep or replace the existing file
4. Remember your choice for the session

### Error Logging
Detailed logs are maintained in:
- Location: `<output_directory>/wallpimp.log`
- Contains: Download attempts, errors, and operations
- Helps in troubleshooting issues

## Contributing

We welcome contributions to WallPimp! Here's how you can help:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

Please ensure your code:
- Follows the existing style
- Includes appropriate comments
- Adds tests for new features
- Updates documentation as needed

## Troubleshooting

### Common Issues

1. Git Not Found
```bash
Error: Missing required dependencies:
  - git
```
Solution: Install Git from https://git-scm.com/

2. Python Dependencies Missing
```bash
Error: Missing required dependencies:
  - pillow
  - requests
  - tqdm
```
Solution: Run `pip install -r requirements.txt`

3. Permission Denied
```bash
Error: Permission denied when creating directory
```
Solution: Run with appropriate permissions or modify output directory

### Getting Help
- Check the wallpimp.log file for detailed error information
- Open an issue on GitHub with:
  - Your system information
  - Error messages
  - Log file contents
  - Steps to reproduce the issue

## Credits

Developed by ソロックス (oxborn3)  
GitHub: https://github.com/0xb0rn3

### Contributing Repositories
Special thanks to the maintainers of the wallpaper repositories used in this tool:
- dharmx/walls
- FrenzyExists/wallpapers
- Dreamer-Paul/Anime-Wallpaper
- michaelScopic/Wallpapers
- ryan4yin/wallpapers
- And others listed in the source code

## Version History

### v2.3 (Current)
- Added support for large repositories up to 1GB
- Implemented download resume capability
- Enhanced error handling and recovery
- Added detailed progress tracking
- Improved duplicate detection

### v2.2
- Added file integrity verification
- Improved cross-platform compatibility
- Enhanced error logging
- Added support for more image formats

### v2.1
- Initial public release
- Basic wallpaper downloading functionality
- Support for multiple repositories
- v2.0: Major rewrite with cross-platform support and automated building
- v1.0: Initial release

---

Developed with ❤️ by [ソロックス (oxborn3)](https://github.com/0xb0rn3)
