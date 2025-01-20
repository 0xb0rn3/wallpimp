# WallPimp

A streamlined wallpaper management tool that helps you build your collection from curated GitHub repositories. WallPimp automatically downloads, organizes, and deduplicates wallpapers while providing a smooth, interactive experience.


## Features

- Downloads wallpapers from curated GitHub repositories
- Removes duplicate wallpapers using SHA256 hashing
- Interactive progress display with server connection checks
- Automatic retry mechanism for failed downloads
- Cross-platform support (Linux/Unix and Windows)
- Simple, user-friendly interface

## Quick Start

### Windows (PowerShell)

One-line installation using PowerShell:
```powershell
irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp.ps1 | iex
```

Or download and run manually:
1. Download `wallpimp.ps1`
2. Open PowerShell and navigate to the download location
3. Enable script execution (if needed):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
4. Run the script:
```powershell
.\wallpimp.ps1
```

### Linux/Unix (Bash)

One-line installation using curl:
```bash
curl -sSL https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp | bash
```

Or download and run manually:
1. Download `wallpimp`
2. Make it executable:
```bash
chmod +x wallpimp
```
3. Run the script:
```bash
./wallpimp
```

## Prerequisites

### Windows Requirements
- Windows PowerShell 5.0 or higher (pre-installed on Windows 10 and later)
- Git for Windows ([Download Here](https://git-scm.com/download/win))

### Linux/Unix Requirements
- Bash shell (pre-installed on most distributions)
- Git (`sudo apt install git` for Debian/Ubuntu)
- curl (for one-line installation)

## Installation Options

### Method 1: Direct Download
1. Visit the [WallPimp Repository](https://github.com/0xb0rn3/wallpimp)
2. Download the appropriate script:
   - Windows: `wallpimp.ps1`
   - Linux/Unix: `wallpimp`

### Method 2: Git Clone
```bash
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp
```

### Method 3: One-Line Installation
Choose the appropriate command for your system from the Quick Start section above.

## Usage

1. Run the script using the appropriate method for your system
2. When prompted, enter your preferred save location or press Enter to use the default:
   - Windows default: `%USERPROFILE%\Pictures\Wallpapers`
   - Linux default: `$HOME/Pictures/Wallpapers`
3. The script will:
   - Check server connections
   - Download wallpapers
   - Remove duplicates
   - Show progress and results

## Understanding the Output

The script provides real-time feedback using the following indicators:
- `[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]` - Active download in progress
- `[✓]` - Successful operation
- `[✗]` - Failed operation

Example output:
```
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.4              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝

Starting downloads...

Server connection successful for walls [✓]
Downloading walls [✓]
Processed: 142 files

Download Summary:
✓ Successfully downloaded: 5 repositories
✗ Failed downloads: 0 repositories
✓ Total wallpapers processed: 142
✓ Duplicates skipped: 3
✓ Wallpapers saved to: C:\Users\YourUser\Pictures\Wallpapers
```

## Troubleshooting

### Windows Issues
1. "Running scripts is disabled on this system"
   - Solution: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. "Git is not recognized as a command"
   - Solution: Install Git for Windows and restart PowerShell

### Linux/Unix Issues
1. "Permission denied"
   - Solution: Run `chmod +x wallpimp`

2. "git: command not found"
   - Solution: Install Git using your package manager

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## Author

- **0xb0rn3** - *Initial work* - [GitHub Profile](https://github.com/0xb0rn3)

## Acknowledgments

- Thanks to all wallpaper repository maintainers
- Special thanks to the GitHub community for hosting the wallpaper collections

## Support

If you encounter any issues or have questions, please:
1. Check the [Issues](https://github.com/0xb0rn3/wallpimp/issues) page
2. Create a new issue if needed
3. Include your system information and error messages

---
Created with ♥ by [0xb0rn3](https://github.com/0xb0rn3)
