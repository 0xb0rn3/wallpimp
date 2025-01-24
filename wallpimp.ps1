param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",
    [switch]$NoDownload = $false,
    [switch]$FilterByResolution = $false,
    [int]$MinResolutionWidth = 1920,
    [int]$MinResolutionHeight = 1080
)

# Load .NET Image Processing
Add-Type -AssemblyName System.Drawing

# Enhanced Logging Function
function Write-WallpimpLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][ConsoleColor]$Color = 'White',
        [switch]$Important
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPrefix = if ($Important) { "🌟 " } else { "➤ " }
    
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    
    # Optional: Log to file
    $logFile = Join-Path $SavePath "wallpimp_log.txt"
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile
}

# Dependency Installation Function
function Install-WallpimpDependencies {
    # Check for Git
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-WallpimpLog "Git not found. Installing..." -Color Yellow
        
        try {
            # Determine system architecture
            $arch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
            $gitUrl = if ($arch -eq "64-bit") {
                "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
            } else {
                "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-32-bit.exe"
            }

            $tempInstaller = Join-Path $env:TEMP "git_installer.exe"
            Write-WallpimpLog "Downloading Git from $gitUrl" -Color Cyan
            
            Invoke-WebRequest -Uri $gitUrl -OutFile $tempInstaller
            
            Start-Process -FilePath $tempInstaller -ArgumentList "/SILENT" -Wait
            
            Write-WallpimpLog "Git installed successfully!" -Color Green
        }
        catch {
            Write-WallpimpLog "Git installation failed: $_" -Color Red -Important
            return $false
        }
        finally {
            if (Test-Path $tempInstaller) {
                Remove-Item $tempInstaller -Force
            }
        }
    }
    return $true
}

# Image Quality Check Function
function Test-ImageQuality {
    param(
        [string]$ImagePath,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080,
        [bool]$CheckUnique = $true
    )

    try {
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        
        # Resolution Check
        $meetsResolution = ($image.Width -ge $MinWidth -and $image.Height -ge $MinHeight)
        
        # Duplicate Detection (Optional)
        $unique = $true
        if ($CheckUnique) {
            $hash = (Get-FileHash -Algorithm SHA256 -Path $ImagePath).Hash
            $existing = Get-ChildItem $SavePath | Where-Object { 
                (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash -eq $hash 
            }
            $unique = ($existing.Count -eq 0)
        }

        $image.Dispose()
        return ($meetsResolution -and $unique)
    }
    catch {
        Write-WallpimpLog "Image processing error: $ImagePath" -Color Red
        return $false
    }
}

# Wallpaper Download Function
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories,
        [bool]$FilterResolution = $false,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080
    )

    # Ensure save directory exists
    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath | Out-Null
    }

    $stats = @{
        TotalRepos = $Repositories.Count
        SuccessfulRepos = 0
        FailedRepos = 0
        ProcessedWallpapers = 0
        SavedWallpapers = 0
    }

    # Temporary cloning directory
    $tempDir = Join-Path $env:TEMP "WallPimp_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    foreach ($repo in $Repositories) {
        try {
            Write-WallpimpLog "Processing Repository: $($repo.Url)" -Color Yellow

            $repoName = ($repo.Url -split '/')[-1]
            $clonePath = Join-Path $tempDir $repoName

            # Shallow clone to reduce bandwidth and time
            git clone --depth 1 --branch $repo.Branch $repo.Url $clonePath

            # Find image files with broader extension support
            $imageFiles = Get-ChildItem $clonePath -Recurse -Include @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp") 

            foreach ($image in $imageFiles) {
                $stats.ProcessedWallpapers++

                # Apply resolution and uniqueness filtering
                if (Test-ImageQuality -ImagePath $image.FullName -MinWidth $MinWidth -MinHeight $MinHeight) {
                    # Generate unique filename with hash
                    $hash = (Get-FileHash -Algorithm SHA256 -Path $image.FullName).Hash
                    $newFilename = "$hash$($image.Extension)"
                    $destinationPath = Join-Path $SavePath $newFilename

                    Copy-Item -Path $image.FullName -Destination $destinationPath -Force
                    $stats.SavedWallpapers++
                }
            }

            $stats.SuccessfulRepos++
            Write-WallpimpLog "Successfully processed: $($repo.Url)" -Color Green
        }
        catch {
            $stats.FailedRepos++
            Write-WallpimpLog "Failed to process repository: $($repo.Url)" -Color Red -Important
        }
    }

    # Clean up temporary directory
    Remove-Item $tempDir -Recurse -Force

    return $stats
}

# Main Script Execution Function
function Start-WallPimp {
    # Display Header
    Write-Host @"
╔════════════════════════════════════╗
║        WallPimp Ver:1.2           ║
║   Advanced Wallpaper Collector    ║
╚════════════════════════════════════╝
"@ -ForegroundColor Cyan

    # User Configurations
    if ($NoDownload) {
        Write-WallpimpLog "No-Download mode enabled. Exiting." -Color Yellow
        return
    }

    # Dependency Check
    if (-not (Install-WallpimpDependencies)) {
        Write-WallpimpLog "Dependency installation failed. Cannot proceed." -Color Red -Important
        return
    }

    # User Input for Save Location
    $userSavePath = Read-Host "Enter wallpaper save location (press Enter for default: $SavePath)"
    if ($userSavePath) {
        $SavePath = $userSavePath
    }

    # Download Wallpapers
    $results = Invoke-WallpaperDownload -SavePath $SavePath `
        -Repositories $Repositories `
        -FilterResolution:$FilterByResolution `
        -MinWidth $MinResolutionWidth `
        -MinHeight $MinResolutionHeight

    # Display Comprehensive Summary
    Write-Host @"
╔════════ Wallpaper Collection Summary ════════╗
║ Repositories Processed: $($results.TotalRepos)
║ Successful Repos: $($results.SuccessfulRepos)
║ Failed Repos: $($results.FailedRepos)
║ Total Wallpapers Processed: $($results.ProcessedWallpapers)
║ Wallpapers Saved: $($results.SavedWallpapers)
║ Save Location: $SavePath
╚══════════════════════════════════════════════╝
"@ -ForegroundColor Green

    # Optional: Open save location
    Invoke-Item $SavePath
}

# Extensive Repositories Configuration
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
    }
)

# Run Script
Start-WallPimp
