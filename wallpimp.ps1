param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers"
)

# Determine System Architecture
function Get-SystemArchitecture {
    $osArchitecture = $env:PROCESSOR_ARCHITECTURE

    # Mapping architectures for precise matching
    switch ($osArchitecture) {
        "AMD64" { return "64-bit" }
        "x86" { return "32-bit" }
        default { 
            Write-Warning "Unsupported architecture detected: $osArchitecture"
            return "64-bit"  # Default to 64-bit if uncertain
        }
    }
}

# Dynamic Dependency Configuration
function Get-DependencyConfig {
    $architecture = Get-SystemArchitecture
    
    return @{
        Git = @{
            Name = "git"
            DownloadUrl = if ($architecture -eq "64-bit") {
                "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
            } else {
                "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-32-bit.exe"
            }
            InstallerType = "exe"
            # Comprehensive installation components
            InstallArgs = "/SILENT /COMPONENTS='icons,ext,ext\shellhere,ext\guihere,assoc,assoc_sh'"
        }
        SevenZip = @{
            Name = "7z"
            DownloadUrl = if ($architecture -eq "64-bit") {
                "https://www.7-zip.org/a/7z2201-x64.exe"
            } else {
                "https://www.7-zip.org/a/7z2201-x86.exe"
            }
            InstallerType = "exe"
            InstallArgs = "/S"
        }
    }
}

# Logging and UI Functions (Enhanced from previous versions)
function Write-WallpimpHeader {
    $architecture = Get-SystemArchitecture
    Write-Host @"
╔═══════════════════════════════════════╗
║      WallPimp Ver:1.2 ($architecture)  ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# Dependency Installation Function
function Install-WallpimpDependencies {
    $Dependencies = Get-DependencyConfig
    $missingDependencies = @()

    # Identify Missing Dependencies
    foreach ($depName in $Dependencies.Keys) {
        $dep = $Dependencies[$depName]
        $installedCheck = Get-Command $dep.Name -ErrorAction SilentlyContinue

        if (!$installedCheck) {
            $missingDependencies += $dep
        }
    }

    # Auto-Install Missing Dependencies
    if ($missingDependencies.Count -gt 0) {
        Write-Host "🔍 Detecting Missing Dependencies..." -ForegroundColor Yellow
        
        foreach ($dep in $missingDependencies) {
            try {
                Write-Host "Installing $($dep.Name)..." -ForegroundColor Cyan
                
                $tempInstaller = Join-Path $env:TEMP "$($dep.Name)_installer.exe"
                
                # Download Installer
                Write-Host "Downloading from $($dep.DownloadUrl)..." -ForegroundColor Green
                Invoke-WebRequest -Uri $dep.DownloadUrl -OutFile $tempInstaller

                # Install Silently
                Start-Process -FilePath $tempInstaller -ArgumentList $dep.InstallArgs -Wait

                # Verify Installation
                $verifyInstall = Get-Command $dep.Name -ErrorAction Stop
                Write-Host "✅ $($dep.Name) installed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Host "❌ Failed to install $($dep.Name). Error: $_" -ForegroundColor Red
                Write-Host "Recommendation: Manually download and install from $($dep.DownloadUrl)" -ForegroundColor Yellow
                return $false
            }
            finally {
                # Clean up installer
                if (Test-Path $tempInstaller) {
                    Remove-Item $tempInstaller -Force
                }
            }
        }
    }

    return $true
}

# Repositories Configuration (Unchanged)
$Repositories = @(
    # Minimalist & Aesthetic Collections
    @{
        Url = "https://github.com/dharmx/walls"
        Branch = "main"
        Description = "Minimal and aesthetic wallpapers with clean, sophisticated design"
    },
    @{
        Url = "https://github.com/port19x/Wallpapers"
        Branch = "main"
        Description = "Minimalist desktop wallpapers with subtle color palettes"
    },
    @{
        Url = "https://github.com/Axlefublr/wallpapers"
        Branch = "main"
        Description = "Curated minimalist and abstract wallpaper collection"
    },

    # Nature & Landscape Themes
    @{
        Url = "https://github.com/FrenzyExists/wallpapers"
        Branch = "main"
        Description = "Nature and abstract art wallpapers featuring scenic landscapes"
    },
    @{
        Url = "https://github.com/michaelScopic/Wallpapers"
        Branch = "main"
        Description = "Scenic and landscape wallpapers with breathtaking panoramas"
    },
    @{
        Url = "https://github.com/linuxdotexe/wallpapers"
        Branch = "main"
        Description = "High-resolution nature and earth photography wallpapers"
    },

    # Digital Art & Anime
    @{
        Url = "https://github.com/ryan4yin/wallpapers"
        Branch = "main"
        Description = "Anime and digital art wallpapers with vibrant styles"
    },
    @{
        Url = "https://github.com/satyawrat/WallPapers"
        Branch = "main"
        Description = "Diverse collection of anime and pop culture wallpapers"
    },
    @{
        Url = "https://github.com/lxndrblz/animeWallpapers"
        Branch = "main"
        Description = "Curated anime wallpapers with high-quality artwork"
    },

    # Abstract & Artistic
    @{
        Url = "https://github.com/D3Ext/aesthetic-wallpapers"
        Branch = "main"
        Description = "Abstract and aesthetic wallpapers with unique visual designs"
    },
    @{
        Url = "https://github.com/notlmn/wallpapers"
        Branch = "main"
        Description = "Artistic wallpapers with creative compositions and color schemes"
    },
    @{
        Url = "https://github.com/minhonna/background-collection"
        Branch = "main"
        Description = "Diverse abstract and geometric wallpaper designs"
    },

    # Space & Sci-Fi
    @{
        Url = "https://github.com/scientifichackers/wallpapers"
        Branch = "main"
        Description = "Space, astronomy, and sci-fi themed wallpapers"
    },
    @{
        Url = "https://github.com/satya164/sci-fi-wallpapers"
        Branch = "main"
        Description = "High-quality science fiction and cosmic landscape wallpapers"
    },

    # Urban & Architectural
    @{
        Url = "https://github.com/MichaelKim0721/wallpapers"
        Branch = "main"
        Description = "Urban landscapes and architectural photography wallpapers"
    },
    @{
        Url = "https://github.com/YashKumarVerma/wallpapers"
        Branch = "main"
        Description = "City skylines and modern architectural designs"
    },

    # Gaming & Pop Culture
    @{
        Url = "https://github.com/novatorem/Wallpapers"
        Branch = "main"
        Description = "Gaming-inspired and pop culture themed wallpapers"
    },
    @{
        Url = "https://github.com/BtbN/wallpapers"
        Branch = "main"
        Description = "Diverse collection of gaming and entertainment wallpapers"
    }
)
# Image Quality Check Function
function Test-ImageQuality {
    param([string]$ImagePath)

    try {
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        
        # Enhanced Resolution Check
        if ($image.Width -lt 1920 -or $image.Height -lt 1080) {
            $image.Dispose()
            return $false
        }

        $image.Dispose()
        return $true
    }
    catch {
        Write-Host "Image processing error: $ImagePath" -ForegroundColor Red
        return $false
    }
}

# Wallpaper Download Function (Mostly unchanged)
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories
    )

    # Ensure save directory exists
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
    # Display Header with Architecture
    Write-WallpimpHeader

    # Dependency Installation
    if (!(Install-WallpimpDependencies)) {
        Write-Host "❌ Dependency installation failed. Cannot proceed." -ForegroundColor Red
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
    Write-Host @"
╔════════ Download Summary ════════╗
║ Successfully downloaded: $($results.SuccessfulRepos) repos
║ Failed downloads: $($results.FailedRepos) repos
║ Total wallpapers processed: $($results.TotalWallpapers)
║ Wallpapers saved to: $SavePath
╚══════════════════════════════════╝
"@ -ForegroundColor Green
}

# Load .NET Image Processing
Add-Type -AssemblyName System.Drawing

# Run Script
Start-WallPimp
