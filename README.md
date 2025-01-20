# Wallpaper Downloader (WallPimp Python Edition)

WallPimp is a powerful wallpaper management tool that automatically downloads and organizes high-quality wallpapers from curated GitHub repositories. It features duplicate detection, quality filtering, and efficient parallel downloads.

## Features

This Python implementation includes several advanced capabilities:
- Asynchronous downloading for improved performance
- Automatic duplicate detection using SHA-256 hashing
- Quality filtering (minimum 1920x1080 resolution)
- Format conversion and optimization
- Beautiful progress indicators and status updates
- Cross-platform compatibility (Windows, macOS, Linux)

## Installation Guide

### Prerequisites

You'll need Python 3.8 or newer installed on your system. Here's how to check your Python version:

```bash
python --version
# or
python3 --version
```

If you need to install Python:

#### Windows
1. Visit the official Python website (https://www.python.org/downloads/)
2. Download the latest Python installer for Windows
3. Run the installer
4. Important: Check "Add Python to PATH" during installation
5. Click "Install Now"

#### macOS
Using Homebrew (recommended):
```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python
```

Alternatively, download the installer from python.org.

#### Linux
Ubuntu/Debian:
```bash
sudo apt update
sudo apt install python3 python3-pip git
```

Fedora:
```bash
sudo dnf install python3 python3-pip git
```

Arch Linux:
```bash
sudo pacman -S python python-pip git
```

### Installing WallPimp

1. Download the script:
```bash
# Create a directory for the script
mkdir wallpimp
cd wallpimp

# Download the script (replace with actual URL or copy manually)
curl -O https://github.com/0xb0rn3/wallpimp/blob/main/wallpimp

# Make the script executable
chmod +x wallpimp
```

2. Install required Python packages:

```bash
# Using pip (Windows)
pip install pillow rich aiohttp

# Using pip (macOS/Linux)
pip3 install pillow rich aiohttp
```

## Usage Instructions

1. Open your terminal or command prompt

2. Navigate to the script directory:
```bash
cd path/to/wallpimp
```

3. Run the script:
```bash
# Windows
python wallpimp

# macOS/Linux
./wallpimp
# or
python3 wallpimp
```

4. When prompted, enter the desired save location for your wallpapers, or press Enter to use the default location:
   - Windows: `C:\Users\YourUsername\Pictures\Wallpapers`
   - macOS: `/Users/YourUsername/Pictures/Wallpapers`
   - Linux: `/home/YourUsername/Pictures/Wallpapers`

5. The script will:
   - Check and install any missing dependencies
   - Download wallpapers from the configured repositories
   - Process and optimize the images
   - Skip any duplicates
   - Show progress in real-time
   - Display a summary when finished

## Troubleshooting

### Common Issues and Solutions

#### Permission Errors

Windows:
- Run Command Prompt as Administrator
- Check antivirus settings
- Ensure you have write permission to the save directory

macOS/Linux:
```bash
# Fix permission issues
sudo chown -R $USER:$USER ~/Pictures/Wallpapers
chmod 755 wallpimp
```

#### Network Issues
- Check your internet connection
- If behind a proxy, set the appropriate environment variables:
```bash
# Windows (PowerShell)
$env:HTTP_PROXY="http://proxy.example.com:8080"
$env:HTTPS_PROXY="http://proxy.example.com:8080"

# macOS/Linux
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
```

#### Package Installation Failures

Windows:
```bash
# Try using --user flag
pip install --user pillow rich aiohttp
```

macOS/Linux:
```bash
# Update pip first
python3 -m pip install --upgrade pip
# Then install packages
python3 -m pip install --user pillow rich aiohttp
```

### Getting Help

If you encounter any issues:
1. Check that all prerequisites are installed
2. Verify your Python version is 3.8 or newer
3. Ensure you have a stable internet connection
4. Check system permissions
5. Look for error messages in the output

## Customization

The script includes several repositories by default, but you can modify the `REPOS` list in the script to add or remove sources. Each repository entry should include:
- `url`: The GitHub repository URL
- `branch`: The branch to download (usually "main" or "master")
- `description`: A brief description of the wallpaper collection

Example of adding a new repository:
```python
REPOS = [
    {
        "url": "https://github.com/yournewrepo/wallpapers",
        "branch": "main",
        "description": "Your collection description"
    },
    # ... existing repositories ...
]
```

## Performance Tips

1. For faster downloads:
   - Use a wired internet connection when possible
   - Close other bandwidth-intensive applications
   - Run during off-peak hours

2. For better processing:
   - Close memory-intensive applications
   - Ensure adequate free disk space
   - Use an SSD for the temporary directory if possible

## Technical Details

The script uses:
- `asyncio` for concurrent downloads
- `aiohttp` for efficient HTTP requests
- `PIL` (Python Imaging Library) for image processing
- `rich` for terminal output formatting
- SHA-256 for duplicate detection
- ThreadPoolExecutor for parallel image processing

Memory usage scales with the number of concurrent downloads and image processing tasks. On a typical system, expect to use:
- 100-200MB base memory
- Additional 50-100MB per concurrent download
- Temporary disk space approximately equal to the size of downloaded repositories

## License

This software is provided as-is under the MIT License. Feel free to modify and distribute according to your needs.
