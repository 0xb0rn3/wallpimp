param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",
    [switch]$InstallDependencies = $false
)

# Dependency Configuration
$Dependencies = @{
    Git = @{
        Name = "Git"
        DownloadUrl = "https://git-scm.com/download/win"
        InstallerType = "exe"
        InstallArgs = "/SILENT"
    }
    SevenZip = @{
        Name = "7-Zip"
        DownloadUrl = "https://www.7-zip.org/a/7z2201-x64.exe"
        InstallerType = "exe"
        InstallArgs = "/S"
    }
}

# Logging and UI Functions
function Write-WallpimpHeader {
    Write-Host @"
╔═══════════════════════════════════════╗
║      WallPimp Ver:0.1 Windows         ║
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
╚══════════════════════════════════════╝
"@ -ForegroundColor Green
}

# Advanced Dependency Management
function Install-WallpimpDependency {
    param([hashtable]$Dependency)

    # Check if dependency is already installed
    $installedCheck = Get-Command $Dependency.Name -ErrorAction SilentlyContinue
    if ($installedCheck) {
        Write-Host "$($Dependency.Name) is already installed." -ForegroundColor Green
        return $true
    }

    Write-Host "Installing $($Dependency.Name)..." -ForegroundColor Yellow

    try {
        $tempDownloadPath = Join-Path $env:TEMP "$($Dependency.Name)_installer.$($Dependency.InstallerType)"
        
        # Download Installer
        Invoke-WebRequest -Uri $Dependency.DownloadUrl -OutFile $tempDownloadPath

        # Install with appropriate method
        if ($Dependency.InstallerType -eq 'exe') {
            Start-Process -FilePath $tempDownloadPath -ArgumentList $Dependency.InstallArgs -Wait
        }
        elseif ($Dependency.InstallerType -eq 'msi') {
            Start-Process msiexec.exe -ArgumentList "/i `"$tempDownloadPath`" /qn" -Wait
        }

        # Clean up installer
        Remove-Item $tempDownloadPath -Force

        Write-Host "$($Dependency.Name) installed successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to install $($Dependency.Name). Error: $_" -ForegroundColor Red
        return $false
    }
}

function Test-WallpimpDependencies {
    # Dynamic dependency check and optional installation
    $missingDependencies = @()

    foreach ($depName in $Dependencies.Keys) {
        $dep = $Dependencies[$depName]
        $installedCheck = Get-Command $dep.Name -ErrorAction SilentlyContinue

        if (!$installedCheck) {
            $missingDependencies += $dep
        }
    }

    # If dependencies are missing and installation flag is set
    if ($missingDependencies.Count -gt 0 -and $InstallDependencies) {
        Write-Host "Installing missing dependencies..." -ForegroundColor Yellow
        
        foreach ($dep in $missingDependencies) {
            $result = Install-WallpimpDependency -Dependency $dep
            if (!$result) {
                Write-Host "Could not install $($dep.Name). Manual installation recommended." -ForegroundColor Red
                return $false
            }
        }
    }
    elseif ($missingDependencies.Count -gt 0) {
        Write-Host "Missing dependencies: $($missingDependencies.Name -join ', ')" -ForegroundColor Red
        Write-Host "Run script with -InstallDependencies to auto-install" -ForegroundColor Cyan
        return $false
    }

    return $true
}

# Repositories for wallpapers (Enhanced from previous version)
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

# Image Processing Function (Unchanged from previous version)
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

# Main Downloading Function (Mostly unchanged)
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories
    )

    # Previous implementation remains the same
    # ... (no changes needed)
}

# Main Script Execution
function Start-WallPimp {
    # Display Header
    Write-WallpimpHeader

    # Check and Optionally Install Dependencies
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
