# Enable error handling
$ErrorActionPreference = "Stop"

# Visual elements for the UI
function Show-Banner {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════╗"
    Write-Host "║         WallPimp Ver:0.2              ║"
    Write-Host "║    Wallpaper Download Assistant       ║"
    Write-Host "╚═══════════════════════════════════════╝"
}

# Spinner animation for loading states
function Spinner {
    param (
        [int]$pid
    )
    $spinStr = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    $delay = 0.1
    while (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
        $temp = $spinStr.Substring(1) + $spinStr.Substring(0,1)
        Write-Host -NoNewline " [$($spinStr[0])] "
        $spinStr = $temp
        Start-Sleep -Seconds $delay
        Write-Host -NoNewline "`b`b`b`b`b`b"
    }
    Write-Host -NoNewline "    `b`b`b`b"
}

# Wallpaper Repositories
$WALLPAPER_REPOS = @(
    "https://github.com/dharmx/walls",
    "https://github.com/FrenzyExists/wallpapers",
    "https://github.com/Dreamer-Paul/Anime-Wallpaper",
    "https://github.com/michaelScopic/Wallpapers",
    "https://github.com/ryan4yin/wallpapers",
    "https://github.com/HENTAI-CODER/Anime-Wallpaper",
    "https://github.com/port19x/Wallpapers",
    "https://github.com/k1ng440/Wallpapers",
    "https://github.com/vimfn/walls",
    "https://github.com/expandpi/wallpapers",
    "https://github.com/polluxau/linuxnext-wallpapers",
    "https://github.com/port19x/Wallpapers",
    "https://github.com/k1ng440/Wallpapers",
    "https://github.com/HENTAI-CODER/Anime-Wallpaper",
    "https://github.com/rubenswebdev/wallpapers",
    "https://github.com/vimfn/walls",
    "https://github.com/IcePocket/Wallpapers",
    "https://github.com/expandpi/wallpapers",
    "https://github.com/logicyugi/Backgrounds",
    "https://github.com/PlannerPlus/Anime-Wallpapers",
    "https://github.com/Samyc2002/Anime-Wallpapers",
    "https://github.com/KaikSelhorst/WallpaperPack",
    "https://github.com/erickmartin890/Anime-Wallpapers",
    "https://github.com/Motif23/Wallpapers-Anime",
    "https://github.com/TherryHilaire/anime",
    "https://github.com/anmac/Wallpapers",
    "https://github.com/Fuj3l/Wallpaper",
    "https://github.com/Aluize/animewallpapers"
)

# Configuration
$SUPPORTED_FORMATS = @("img", "jpg", "jpeg", "png", "gif", "webp")
$MAX_RETRIES = 3
$TEMP_DIR = "$env:TEMP\wallpimp_$($PID)"
$DEFAULT_OUTPUT_DIR = "$env:USERPROFILE\Pictures\Wallpapers"

# Function to handle repository download with retries
function Download-Repo {
    param (
        [string]$repo,
        [string]$target_dir
    )
    $attempt = 1
    while ($attempt -le $MAX_RETRIES) {
        try {
            git clone --depth 1 $repo $target_dir
            return $true
        } catch {
            $attempt++
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

# Function to process and deduplicate files
function Process-Files {
    param (
        [string]$output_dir
    )
    $file_hashes = @{}

    foreach ($format in $SUPPORTED_FORMATS) {
        Get-ChildItem -Recurse -Path $TEMP_DIR -Filter "*.$format" | ForEach-Object {
            $file = $_
            $hash = Get-FileHash $file.FullName -Algorithm SHA256
            if (-not $file_hashes.ContainsKey($hash.Hash)) {
                $filename = ($file.Name -replace ' ', '_') -replace '[^\w\._-]', ''
                $target = "$output_dir\$filename"
                
                # Handle filename collisions
                if (Test-Path $target) {
                    $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                    $ext = $file.Extension
                    $counter = 1
                    while (Test-Path $target) {
                        $target = "$output_dir\$base" + "_$counter$ext"
                        $counter++
                    }
                }
                
                Copy-Item -Path $file.FullName -Destination $target
                $file_hashes[$hash.Hash] = $target
            }
        }
    }
}

# Main function
function Main {
    Show-Banner
    
    # Get output directory from user or use default
    $output_dir = Read-Host "Wallpaper save location [$DEFAULT_OUTPUT_DIR]"
    $output_dir = if ($output_dir) { $output_dir } else { $DEFAULT_OUTPUT_DIR }
    
    # Create directories
    New-Item -ItemType Directory -Force -Path $output_dir, $TEMP_DIR

    # Show initial progress
    Write-Host "Downloading wallpapers..."

    $failed_repos = 0
    $jobs = @()

    foreach ($repo in $WALLPAPER_REPOS) {
        $target_dir = "$TEMP_DIR\$(Split-Path -Leaf $repo)"
        $jobs += Start-Job -ScriptBlock {
            param ($repo, $target_dir)
            if (-not (Download-Repo $repo $target_dir)) {
                $failed_repos++
            }
        } -ArgumentList $repo, $target_dir
    }

    # Wait for all jobs to complete
    $jobs | ForEach-Object {
        $pid = $_.Id
        Spinner $pid
        Receive-Job -Job $_
        Remove-Job -Job $_
    }

    # Process and deduplicate files
    Write-Host "Processing wallpapers..."
    Process-Files -output_dir $output_dir

    # Final cleanup
    Remove-Item -Recurse -Force $TEMP_DIR

    # Show completion message
    $total_files = (Get-ChildItem $output_dir -File).Count
    Write-Host "✓ Downloaded wallpapers: $total_files"
    Write-Host "✓ Save location: $output_dir"
    if ($failed_repos -gt 0) {
        Write-Host "! Some repositories failed to download ($failed_repos)"
    }
}

# Run main function
Main
