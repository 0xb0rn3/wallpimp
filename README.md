# WallPimp - Wallpaper Download Assistant

WallPimp is a powerful script that helps you build an extensive wallpaper collection from curated GitHub repositories. Available for both PowerShell and Bash environments, it automatically handles downloading, deduplication, and organization of wallpapers.

## Features

- Automatic downloading from multiple curated wallpaper repositories
- Intelligent deduplication using SHA256 hashing
- Progress visualization with spinner animation
- Support for multiple image formats (jpg, jpeg, png, gif, webp)
- Automatic Git installation (PowerShell version)
- Customizable save location
- Automatic cleanup of temporary files
- Detailed progress and completion reporting

## Quick Start

### PowerShell Version (Windows)

One-line installation and execution:
```powershell
iwr -useb https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp.ps1 | iex
```

Or download and run manually:
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp.ps1" -OutFile "wallpimp.ps1"

# Execute the script
.\wallpimp.ps1
```

### Bash Version (Linux/MacOS)

One-line installation and execution:
```bash
curl -sSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp | bash
```

Or download and run manually:
```bash
# Download the script
curl -O https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp

# Make it executable
chmod +x wallpimp

# Run the script
./wallpimp
```

## Requirements

### PowerShell Version
- Windows PowerShell 5.1+ or PowerShell Core 6.0+
- Git (automatically installed if missing)
- Administrator privileges (only needed if Git installation is required)

### Bash Version
- Bash shell
- Git
- curl or wget (for downloading)
- Standard Unix utilities (sha256sum, find, etc.)

## Installation

### Method 1: Git Clone
```bash
# Clone the repository
git clone https://github.com/0xb0rn3/wallpimp.git

# Navigate to the directory
cd wallpimp

# Run the appropriate version for your system
# For Windows:
.\wallpimp.ps1

# For Linux/MacOS:
./wallpimp
```

### Method 2: Direct Download
Download the script directly from the releases page or use the one-line installation commands provided in the Quick Start section.

## Usage

1. Run the script using one of the methods described above
2. When prompted, enter your preferred save location or press Enter to use the default
   - Windows default: `%USERPROFILE%\Pictures\Wallpapers`
   - Linux/MacOS default: `$HOME/Pictures/Wallpapers`
3. The script will automatically:
   - Check for and install Git (PowerShell version only)
   - Download wallpapers from all repositories
   - Remove duplicates
   - Organize files in your chosen directory
   - Clean up temporary files

## Configuration

Both versions of the script include configurable variables at the top:

```powershell
# PowerShell Version
$SUPPORTED_FORMATS = @("*.img", "*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp")
$MAX_RETRIES = 3
$DEFAULT_OUTPUT_DIR = [System.IO.Path]::Combine($env:USERPROFILE, "Pictures", "Wallpapers")
```

```bash
# Bash Version
SUPPORTED_FORMATS=("img" "jpg" "jpeg" "png" "gif" "webp")
MAX_RETRIES=3
DEFAULT_OUTPUT_DIR="$HOME/Pictures/Wallpapers"
```

## Repository List

The script includes a curated list of wallpaper repositories. You can modify the `WALLPAPER_REPOS` array in the script to add or remove repositories according to your preferences.

## Troubleshooting

### PowerShell Version
- If you encounter execution policy errors:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
  ```
- If Git installation fails:
  - Download and install Git manually from https://git-scm.com/download/win
  - Run the script again

### Bash Version
- If you encounter permission errors:
  ```bash
  chmod +x wallpimp
  ```
- If Git is missing:
  ```bash
  # Debian/Ubuntu
  sudo apt-get install git

  # Fedora
  sudo dnf install git

  # macOS
  brew install git
  ```

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m 'Add some AmazingFeature'`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Thanks to all the wallpaper repository maintainers
- Inspired by various wallpaper collection scripts in the community
- Built with ❤️ by the open-source community

## Version History

- 0.2.0
  - Added PowerShell version with automatic Git installation
  - Improved error handling and progress reporting
  - Added automatic cleanup
- 0.1.0
  - Initial release with Bash version
  - Basic functionality implemented

## Contact

Project Link: [https://github.com/0xb0rn3/wallpimp](https://github.com/0xb0rn3/wallpimp)

## Security

If you discover any security-related issues, please email the project maintainer instead of using the issue tracker. All security vulnerabilities will be promptly addressed.

