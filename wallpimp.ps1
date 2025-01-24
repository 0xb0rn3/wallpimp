# WallPimp - Windows Wallpaper Downloader
# Version 1.0
# Compatible with PowerShell 5.1+

param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers"
)

# Repositories for wallpapers
$Repositories = @(
    @{
        Url = "https://github.com/dharmx/walls"
        Branch = "main"
        Description = "Minimal and aesthetic wallpapers"
    },
    @{
        Url = "https://github.com/FrenzyExists/wallpapers"
        Branch = "main"
        Description = "Nature and abstract art wallpapers"
    },
    @{
        Url = "https://github.com/michaelScopic/Wallpapers"
        Branch = "main"
        Description = "Scenic and landscape wallpapers"
    },
    @{
        Url = "https://github.com/ryan4yin/wallpapers"
        Branch = "main"
        Description = "Anime and digital art wallpapers"
    },
    @{
        Url = "https://github.com/port19x/Wallpapers"
        Branch = "main"
        Description = "Minimalist desktop wallpapers"
    }
)

# Logging and UI Functions
function Write-WallpimpHeader {
    Write-Host @"
╔═══════════════════════════════════════╗
║      WallPimp Ver:1.0 Windows         ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

function Write-WallpimpSummary {
    param(
        [int]$SuccessfulRepos,
        [int]$FailedRepos,
        [int]$TotalWallpapers,
        [string]$SavePath
    )

    Write-Host @"
╔════════ Download Summary ════════╗
║ Successfully downloaded: $SuccessfulRepos repos
║ Failed downloads: $FailedRepos repos
║ Total wallpapers processed: $TotalWallpapers
║ Wallpapers saved to: $SavePath
╚══════════════════════════════════╝
"@ -ForegroundColor Green
}

# Dependency Checks
function Test-WallpimpDependencies {
    # Check Git installation
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Please install Git from https://git-scm.com" -ForegroundColor Red
        return $false
    }

    return $true
}

# Image Processing Function
function Test-ImageQuality {
    param([string]$ImagePath)

    try {
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        
        # Minimum resolution check (1920x1080)
        if ($image.Width -lt 1920 -or $image.Height -lt 1080) {
            $image.Dispose()
            return $false
        }

        $image.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

# Main Downloading Function
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories
    )

    # Ensure save path exists
    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath | Out-Null
    }

    $successCount = 0
    $failCount = 0
    $totalWallpapers = 0

    # Temporary directory for cloning
    $tempDir = Join-Path $env:TEMP "WallPimp_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    foreach ($repo in $Repositories) {
        try {
            $repoName = ($repo.Url -split '/')[-1]
            $clonePath = Join-Path $tempDir $repoName

            Write-Host "Cloning: $($repo.Url)" -ForegroundColor Yellow

            # Clone repository
            git clone --depth 1 --branch $repo.Branch $repo.Url $clonePath

            # Find and process image files
            $imageFiles = Get-ChildItem $clonePath -Recurse -Include @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp") 

            foreach ($image in $imageFiles) {
                if (Test-ImageQuality -ImagePath $image.FullName) {
                    # Generate unique filename
                    $hash = (Get-FileHash -Algorithm SHA256 -Path $image.FullName).Hash
                    $newFilename = "$hash$($image.Extension)"
                    $destinationPath = Join-Path $SavePath $newFilename

                    Copy-Item -Path $image.FullName -Destination $destinationPath -Force
                    $totalWallpapers++
                }
            }

            $successCount++
        }
        catch {
            Write-Host "Failed to process repository: $($repo.Url)" -ForegroundColor Red
            $failCount++
        }
    }

    # Clean up temporary directory
    Remove-Item $tempDir -Recurse -Force

    return @{
        SuccessfulRepos = $successCount
        FailedRepos = $failCount
        TotalWallpapers = $totalWallpapers
    }
}

# Main Script Execution
function Start-WallPimp {
    # Display Header
    Write-WallpimpHeader

    # Check Dependencies
    if (!(Test-WallpimpDependencies)) {
        return
    }

    # Prompt for save location
    $userSavePath = Read-Host "Enter wallpaper save location (press Enter for default: $SavePath)"
    if ($userSavePath) {
        $SavePath = $userSavePath
    }

    # Download Wallpapers
    $results = Invoke-WallpaperDownload -SavePath $SavePath -Repositories $Repositories

    # Display Summary
    Write-WallpimpSummary `
        -SuccessfulRepos $results.SuccessfulRepos `
        -FailedRepos $results.FailedRepos `
        -TotalWallpapers $results.TotalWallpapers `
        -SavePath $SavePath
}

# Load .NET Image Processing
Add-Type -AssemblyName System.Drawing

# Run Script
Start-WallPimp
