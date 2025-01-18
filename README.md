# WallPimp v2.4

WallPimp is a sophisticated cross-platform wallpaper collection tool that automatically gathers and manages high-quality wallpapers from curated GitHub repositories. With its advanced file handling capabilities, intelligent duplicate detection, and robust error recovery mechanisms, WallPimp ensures a seamless wallpaper collection experience.

## Key Features

WallPimp offers a comprehensive set of features designed for reliable and efficient wallpaper collection:

- **Smart Duplicate Detection**: Uses SHA-256 hash verification to ensure you never download the same wallpaper twice
- **Quality Assurance**: Automatically filters wallpapers based on resolution (minimum 1280x720) and file integrity
- **Cross-Platform Support**: Runs seamlessly on Windows, macOS, and Linux
- **Intelligent Resume**: Remembers your progress and can continue from where it left off
- **Performance Optimized**: Uses parallel processing for faster downloads and repository scanning
- **Error Recovery**: Automatically retries failed downloads and handles network interruptions gracefully
- **Progress Tracking**: Provides detailed real-time progress information and download statistics

## System Requirements

### Base Requirements
- Python 3.6 or higher
- Git (must be accessible in system PATH)
- 1GB minimum free disk space (recommended: 10GB+)
- Active internet connection

### Platform-Specific Dependencies

#### Windows
- Visual C++ Redistributable (2015 or newer)
- Git for Windows
- PowerShell 5.0 or higher (for automated installation)

#### macOS
- Xcode Command Line Tools
- Homebrew (recommended for managing dependencies)

#### Linux
Required system libraries (automatically checked during installation):
- libjpeg
- zlib1g
- libpng

## Installation Guide

### Windows Installation

Windows users have two installation options:

#### Option 1: Automated Installation (Recommended)

1. Create a new folder for WallPimp
2. Save the provided PowerShell script as `windows.ps1` in that folder
3. Open PowerShell in that folder (Right-click → "Open PowerShell window here")
4. Run: `.\windows.ps1`

The script will:
- Check for required software
- Set up the necessary directories
- Install Python dependencies
- Create a convenient desktop shortcut
- Offer to run WallPimp immediately

#### Option 2: Manual Installation

1. Install Prerequisites:
   - Download Python from [python.org](https://www.python.org/downloads/windows/)
   - Install Git from [git-scm.com](https://git-scm.com/download/windows)
   - Install Visual C++ Redistributable if needed

2. Set Up WallPimp:
   ```bash
   # Create and enter installation directory
   mkdir C:\WallPimp
   cd C:\WallPimp

   # Clone the repository
   git clone https://github.com/0xb0rn3/wallpimp.git

   # Enter the wallpimp directory
   cd wallpimp

   # Install required Python packages
   pip install Pillow tqdm
   ```

### macOS Installation

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python and Git
brew install python git

# Clone WallPimp
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp

# Install Python dependencies
pip3 install Pillow tqdm
```

### Linux Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install python3 python3-pip git libjpeg-dev zlib1g-dev libpng-dev

# Clone WallPimp
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp

# Install Python dependencies
pip3 install Pillow tqdm
```

## Usage

1. Navigate to the WallPimp directory:
   ```bash
   cd wallpimp
   ```

2. Run WallPimp:
   ```bash
   python wallpimp.py
   ```

3. WallPimp will:
   - Create a wallpaper directory in your Pictures folder
   - Begin downloading and processing wallpapers
   - Show real-time progress and statistics
   - Handle any errors automatically

## Troubleshooting Guide

### Common Issues and Solutions

#### "Python is not recognized"
- Reinstall Python and ensure "Add Python to PATH" is checked
- Log out and log back in to refresh environment variables

#### "Git is not recognized"
- Reinstall Git
- Add Git to system PATH
- Restart your terminal/command prompt

#### "Permission denied"
- Run terminal/PowerShell as administrator
- Check folder permissions
- Ensure antivirus isn't blocking the script

#### "No module named 'PIL'"
- Run: `pip install Pillow`
- Try: `python -m pip install Pillow`
- If on Linux, install system dependencies first

#### Script appears frozen
- This is normal during repository cloning
- Large repositories may take time to process
- Check the progress indicator
- First run is typically slower due to initial downloads

## Advanced Configuration

WallPimp stores its configuration and state in the following locations:

- **Windows**: `%USERPROFILE%\WallPimp`
- **macOS**: `~/Pictures/WallPimp`
- **Linux**: `~/Pictures/WallPimp`

The `.wallpimp_state.json` file in this directory tracks download progress and can be safely deleted to start fresh.

## Support and Feedback

If you encounter issues:

1. Check the `wallpimp.log` file in your WallPimp directory
2. Review any error messages carefully
3. Try running the setup script again
4. If problems persist, create an issue on GitHub with:
   - Your operating system and version
   - Python version (`python --version`)
   - Git version (`git --version`)
   - The error message
   - The contents of wallpimp.log

Visit the [GitHub repository](https://github.com/0xb0rn3) for:
- Latest updates and releases
- Bug reports and feature requests
- Contributing guidelines
- Additional documentation

## Security

WallPimp includes several security features:

- File integrity verification using SHA-256 hashing
- Secure file handling with atomic operations
- Repository validation before processing
- Sanitized filename handling
- Resource usage limits and timeouts

## License

This project is available under the MIT License. See the LICENSE file for details.

## Acknowledgments

Special thanks to:
- The maintainers of the wallpaper repositories
- Contributors to the project
- The Python community for essential libraries

---
Developed by ソロックス (oxborn3) | [GitHub](https://github.com/0xb0rn3)
