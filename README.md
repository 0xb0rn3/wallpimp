WallPimp - Intelligent Wallpaper Collector
Welcome to WallPimp, your go-to tool for collecting stunning, high-quality wallpapers from curated repositories! Whether you’re on Linux, Windows, or beyond, WallPimp has you covered with implementations in Python (cross-platform, recommended for Linux) and PowerShell (tailored for Windows). This tool automates the heavy lifting—filtering by resolution, detecting duplicates with SHA-256 hashing, and optimizing your collection—all while keeping you in control.

Features
WallPimp packs a punch with these awesome capabilities:

Cross-platform support: Python for Linux (and adaptable elsewhere), PowerShell for Windows.
Interactive repository selection: Choose by number or grab "all" with detailed descriptions and icons.
Download controls: Pause (p), continue (c), or stop (s) at your command.
Duplicate detection: Uses SHA-256 hashing to keep your collection unique.
Resolution filtering: Defaults to 1920x1080, adjustable as needed.
Storage check: Warns if you’re low on space (needs ~3.5GB free).
Progress feedback: Animated spinners and progress bars keep you in the loop.
Parallel processing (Python only): Enable "Crazy Mode" for lightning-fast downloads.
Stats: Displays total unique wallpapers downloaded.
Installation
WallPimp offers two flavors—Python and PowerShell. Here’s how to get started with each.

Python Version (Recommended for Linux)
The Python version is versatile, built for Linux but adaptable to other platforms (yes, even Windows!). It shines with features like optional parallel processing.

Prerequisites
Python 3.x: The backbone of the script.
Git: For cloning repositories.
ImageMagick: For image optimization.
Python Libraries: requests, pillow, tqdm, configparser, colorama.

Steps
Install System Dependencies:

Ubuntu/Debian:
sudo apt-get install git imagemagick

Arch:
sudo pacman -S git imagemagick

Windows: Install Git (winget install Git.Git) and ImageMagick (winget install ImageMagick.ImageMagick).

Install Python Libraries:
pip install requests pillow tqdm configparser colorama

Fedora:
sudo dnf install git ImageMagick

Download the Script:
Grab run from the GitHub repository.

Run the Script:
i) Launch it with:
chmod +x ./run
./run
Follow the Prompts:
Set a save directory (default: ~/Pictures/Wallpapers).
Pick repositories by number or type "all".
Opt for "y" on Crazy Mode for parallel downloads.
Control downloads: p (pause), c (continue), s (stop).
PowerShell Version (For Windows)
The PowerShell version is a Windows-native experience—simple, direct, and powerful.

Steps
Run Directly from GitHub:
Open PowerShell as Administrator:
Hit Windows + X, choose "Windows PowerShell (Admin)".

Run these commands one at a time:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/run.ps1 | iex

Follow the Prompts:

Choose a save directory (default: ~/Pictures/Wallpapers).
Select repositories by number or type "all".
Manage downloads: p (pause), c (continue), s (stop).

Dependencies:

Git: Install with:
winget install Git.Git

ImageMagick: Get it via:
winget install ImageMagick.ImageMagick

Note: If dependencies aren’t in your PATH, install them manually and verify with git --version and magick --version.

Configuration
Both versions fetch repository details from a central config file:

Source: https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/config.ini.
Fallback: Hardcoded defaults kick in if the fetch fails.
Customization: Edit config.ini on GitHub to tweak repository sources.
Troubleshooting
Run into a snag? Here’s how to fix common issues:

"Permission Error":
Linux: Use sudo.
Windows: Run PowerShell as Administrator.

"Git not found":
Install Git and ensure it’s in your PATH.

"ImageMagick missing":
Install manually if auto-install fails.

Insufficient Space:
Free up ~3.5GB; the script will warn you if space is tight.

Interactive Issues (PowerShell):
Run in a terminal to ensure inputs work with irm | iex.

Contributing
Love WallPimp? Help make it better!

Fork the repo at github.com/0xb0rn3/wallpimp.
Branch off for your changes.
Submit a pull request with a clear rundown of your tweaks.
