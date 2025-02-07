# WallPimp - Ultimate Wallpaper Collector

WallPimp is an elegant, automated wallpaper collection tool that seamlessly gathers high-quality wallpapers from curated repositories. With its beautiful visual interface and intelligent processing capabilities, WallPimp transforms the experience of building your wallpaper collection.

## Features

WallPimp combines powerful functionality with a delightful user experience:

### Core Features
- Automatic dependency management across major Linux distributions
- Smart duplicate detection using SHA-256 hashing
- Parallel download processing for optimal performance
- Intelligent image optimization with quality preservation
- Cross-platform compatibility across Linux environments

### Visual Experience
- Beautiful ASCII art interface
- Smooth progress animations
- Clean, color-coded status indicators
- Elegant loading animations
- Minimalist design philosophy

### Collection Sources
WallPimp curates wallpapers from carefully selected repositories:

- 🖼️ Minimalist Collection: Clean, minimal designs
- 🌸 Anime Collection: Curated anime and manga artwork
- 🌿 Nature Collection: Stunning natural landscapes
- 🏞️ Scenic Collection: Beautiful vista photographs
- 🎨 Artistic Collection: Creative artistic styles
- 🎎 Anime Pack: Premium anime artworks
- 🐧 Linux Collection: Linux-themed desktop art
- 🌟 Mixed Collection: Diverse wallpaper styles
- 💻 Desktop Collection: Minimalist desktop designs
- 🎮 Gaming Collection: Gaming-inspired artwork
- 📷 Photography Collection: Professional photographs
- 🖥️ Digital Collection: Digital art creations

## Installation

WallPimp is designed for seamless setup. Simply download and make the script executable:

```bash
# Download the script
curl -O https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/run
# Make it executable
chmod +x run
```

## Usage

Running WallPimp is straightforward:

```bash
./run
```

The script will:
1. Automatically detect your Linux distribution
2. Install any missing dependencies silently
3. Create a Wallpapers directory in your Pictures folder
4. Download and process wallpapers from all repositories
5. Remove duplicates automatically
6. Optimize all images for quality and size

### Output Location

Processed wallpapers are saved to:
```
~/Pictures/Wallpapers/
```

Each wallpaper is:
- Optimized for quality and file size
- Named using a unique hash to prevent duplicates
- Saved in high-quality JPEG format

## System Requirements

WallPimp is compatible with major Linux distributions including:
- Ubuntu/Debian
- Fedora
- Arch Linux
- Other major distributions with package managers

The script automatically handles dependencies including:
- Git (for repository cloning)
- ImageMagick (for image processing)

## Technical Details

### Image Processing

WallPimp processes images with specific criteria:
- Minimum resolution: 1920x1080
- Quality optimization: 85% JPEG quality
- Automatic format conversion to JPEG
- Metadata stripping for smaller file sizes

### Performance Optimization

The script implements several performance features:
- Parallel download processing
- Efficient hash-based deduplication
- Minimal disk usage through temporary directories
- Automatic cleanup of processing artifacts

## Troubleshooting

If you encounter issues:

1. Ensure you have internet connectivity
2. Verify you have sufficient disk space
3. Check if your system's package manager is functioning
4. Ensure you have proper permissions in the Pictures directory

For specific error messages, the script provides clear indicators of what went wrong and how to resolve it.

## Contributing

WallPimp welcomes contributions! If you'd like to:
- Add new wallpaper repositories
- Improve image processing
- Enhance the visual interface
- Fix bugs or add features

Please feel free to submit pull requests to the repository.

## Credits

WallPimp is developed by 0xB0RN3 and inspired by the wallpaper enthusiast community. Special thanks to all repository maintainers who curate the wonderful wallpaper collections.

## License

WallPimp is open-source software, available under the MIT license. Feel free to use, modify, and distribute it according to the license terms.

## Version History

- v0.5.0: Current release with full visual interface and automated dependency management
- Previous versions focused on core functionality development

## Support

For support, please:
1. Check the troubleshooting section
2. Review existing GitHub issues
3. Create a new issue if needed

We aim to respond to all issues and continue improving WallPimp for the community.
