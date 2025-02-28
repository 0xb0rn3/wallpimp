# WallPimp - Intelligent Wallpaper Collector
WallPimp is an automated tool designed to collect high-quality wallpapers from curated repositories. It is cross-platform, featuring implementations in Bash for Linux and PowerShell for Windows. The tool filters wallpapers by resolution, detects duplicates using SHA-256 hashing, and optimizes images for quality and storage efficiency.

## Features
Cross-platform support (Linux and Windows)
Interactive repository selection with an "all" option
Download controls: pause, stop, or continue
Duplicate detection using SHA-256 hashing
Resolution filtering (default: 1920x1080)
Storage space check (requires ~3.5GB)
Progress feedback with bars and loaders
Displays total unique wallpapers downloaded

## Installation:

# Linux (Bash)
Download the script:
```bash
>>  curl -O https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/run
```
# Make it executable:
```bash
chmod +x run
```
# Run it:
```bash
./run
```
# Windows (PowerShell)
Run directly from GitHub: (Copy & Paste this code in powershell)
# step.1 
Windows button + X (Click open powershell as admin)
# Step.2
COPY & PASTE code i & ii into powershell and click ENTER after copying and pasting each
# Code (i) Copy,Paste & Enter
```Powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
# Code (ii) Copy,Paste & Enter
```
irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/run.ps1 | iex
```
# Follow the prompts:
Specify a save directory (default: ~/Pictures/Wallpapers).
Select repositories by number or type "all".
During downloads, press:
```
p to pause
c to continue
s to stop
```
# Results:
Wallpapers are saved to the chosen directory.
Total unique wallpapers are displayed at the end.

## Configuration
Repositories:
# Bash: Hardcoded in the REPOS array within run.
# PowerShell: Fetched from a remote config.ini file at:
```
https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/config.ini
```
# Config Format (for PowerShell):
```
[Repositories]
repo_name = url | branch
```
# Customization:
Edit config.ini on GitHub (PowerShell) or modify the REPOS array in run (Bash) to add or change sources.
# Dependencies
# Linux (Bash)
Git: For cloning repositories (auto-installed if missing on supported distributions like Ubuntu, Debian, Fedora, Arch).

ImageMagick: For image processing (auto-installed on supported distributions).
# Windows (PowerShell)
# Git: For cloning repositories. Install via:
```
winget install Git.Git
```
# ImageMagick: For image optimization. Install via: (COPY,PASTE & ENTER)
```
winget install ImageMagick.ImageMagick
```
# Troubleshooting
# "Permission Error":
Run with sudo: 
```
sudo ./run
```
# "Git not found": 
Install Git manually and ensure it’s in your PATH.
# "ImageMagick missing": 
Install it manually if auto-install fails.
# Insufficient Space: 
Requires ~3.5GB free; the script will warn if space is low.
# Interactive Issues: 
For PowerShell, run the script in a terminal to ensure input works with irm | iex.

# Contributing
Fork the repository at github.com/0xb0rn3/wallpimp.
Create a branch for your changes.
Submit a pull request with a detailed description of your contributions.
