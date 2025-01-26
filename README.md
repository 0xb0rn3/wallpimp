# Wallpimp 🖼️

A cross-platform wallpaper manager that automatically collects high-quality wallpapers from curated GitHub repositories. Features intelligent duplicate detection and resolution filtering.

## Features ✨

- **Multi-Platform Support**
  - Linux (Python 3.8+)
  - Windows (PowerShell 5.1+/7+)
- **Smart Collection**
  - Automated repository cloning
  - SHA-256 duplicate detection
  - Resolution filtering (default 1920x1080+)
- **Performance Optimized**
  - Parallel processing (PowerShell 7)
  - Async I/O (Python implementation)
  - Temp file cleanup
- **Customizable**
  - Multiple repository sources
  - Custom save paths
  - Repository exclusion list

## Installation ⚙️

### Linux
```bash
git clone https://github.com/0xb0rn3/wallpimp.git
cd wallpimp
pip install -r requirements.txt
```
### Windows
```
Install PowerShell 5+ 
or
use Windows terminal click WINDOWS + X select Terminal 
```
Install dependencies:
winget install Git.Git
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

### Usage 🚀
Linux (Python)
# Basic usage
chmod +x run 
./run

# Custom save location
```
./run --path ~/my_wallpapers
```
# Exclude specific repositories
```
./run --exclude dharmx/walls FrenzyExists/wallpapers
```
### Windows (PowerShell)
# Basic usage
Copy paste this code below into WINDOWS TERMINAL / POWERSHELL 
```
irm https://raw.githubusercontent.com/0xb0rn3/WallPimp/main/wallpimp.ps1 | iex
```
### Parameter	Description	Default Value
```
-SavePath	Custom save directory	$env:USERPROFILE\Pictures\Wallpapers
-MinResolutionWidth	Minimum width requirement	1920
-MaxParallelRepos	Maximum parallel downloads (PS7+)	3
-ExcludeRepositories	Repositories to skip	Empty array
Supported Repositories 📚
Repository	Description
dharmx/walls	Minimalist designs
HENTAI-CODER/Anime-Wallpaper	Anime collection
FrenzyExists/wallpapers	Nature/abstract art
D3Ext/aesthetic-wallpapers	Artistic styles
[See full list in code]	Additional curated sources
Platform Differences 🖥️
Feature	Linux (Python)	Windows (PowerShell)
Parallel Processing	Async I/O with asyncio	PowerShell 7 parallel jobs
Image Handling	PIL (Python Imaging Library)	.NET System.Drawing
Dependency Management	Automatic package installation	Manual Git installation
Temp Files	Automatic cleanup	GUID-named temp directories
```
### Troubleshooting 🔧
Common Issues:

Git not found:
winget install Git.Git (Windows)
sudo apt install git (Linux)

Low-resolution images collected:
Adjust minimum resolution parameters:
-MinResolutionWidth 2560 (Windows)
--min-width 2560 (Linux)

PS7 parallel issues:
Reduce -MaxParallelRepos or use -ThrottleLimit

### Contributing 🤝
Fork the repository

Add new wallpaper repositories to REPOS lists

Maintain cross-platform compatibility

Submit a pull request


### Acknowledgments 🙏
All included wallpaper repository maintainers

Python and PowerShell communities

GitHub for repository hosting

