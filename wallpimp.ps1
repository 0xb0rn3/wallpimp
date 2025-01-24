# WallPimp - Advanced Wallpaper Collection Script
# Version 1.3
# Developed to automate wallpaper collection from multiple GitHub repositories

# Script Parameters
param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",  # Default save location
    [switch]$NoDownload = $false,                                # Option to disable downloading
    [switch]$FilterByResolution = $true,                         # Enable resolution filtering
    [int]$MinResolutionWidth = 1920,                             # Minimum wallpaper width
    [int]$MinResolutionHeight = 1080,                            # Minimum wallpaper height
    [int]$MaxParallelRepos = 3,                                  # Maximum parallel repository processing
    [int]$CloneTimeoutSeconds = 60,                              # Timeout for repository cloning
    [string[]]$ExcludeRepositories = @(),                        # Repositories to exclude
    [ValidateSet('Silent', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'                                 # Logging verbosity
)

# Load .NET Image Processing Assembly
Add-Type -AssemblyName System.Drawing

# Enhanced Logging Function
function Write-EnhancedLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][ConsoleColor]$Color = 'White',
        [Parameter(Mandatory=$false)][ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal',
        [switch]$Important
    )
    
    # Log level filtering
    if ($LogLevel -eq 'Silent' -and $Level -ne 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPrefix = if ($Important) { "🌟 " } else { "➤ " }
    
    # Console output
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    
    # Log file management with rotation
    $logFile = Join-Path $SavePath "wallpimp_log.txt"
    $maxLogSize = 10MB
    if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt $maxLogSize)) {
        Move-Item $logFile ($logFile -replace '\.txt$', "_$(Get-Date -Format 'yyyyMMddHHmmss').txt")
    }
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile
}

# Network Connectivity Check
function Test-NetworkConnection {
    param([string]$Url)
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = 5000  # 5-second timeout
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        Write-EnhancedLog "Network connectivity issue: $Url" -Color Red -Level Verbose
        return $false
    }
}

# Dependency Installation Function
function Install-WallpimpDependencies {
    $dependencies = @{
        'git' = @{
            CheckCommand = { Get-Command git -ErrorAction SilentlyContinue }
            InstallUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
        }
    }

    foreach ($dep in $dependencies.Keys) {
        if (-not ($dependencies[$dep].CheckCommand.Invoke())) {
            Write-EnhancedLog "$dep not found. Attempting installation..." -Color Yellow

            try {
                $installerPath = Join-Path $env:TEMP "${dep}_installer.exe"
                Invoke-WebRequest -Uri $dependencies[$dep].InstallUrl -OutFile $installerPath
                Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait
                
                Write-EnhancedLog "$dep installed successfully!" -Color Green
            }
            catch {
                Write-EnhancedLog "$dep installation failed: $_" -Color Red -Important
                return $false
            }
        }
    }
    return $true
}

# Image Quality Verification Function
function Test-ImageQuality {
    param(
        [string]$ImagePath,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080,
        [bool]$CheckUnique = $true
    )

    try {
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        
        # Resolution validation
        $meetsResolution = ($image.Width -ge $MinWidth -and $image.Height -ge $MinHeight)
        
        # Duplicate detection
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
        Write-EnhancedLog "Image processing error: $ImagePath" -Color Red
        return $false
    }
}

# Wallpaper Download Function with Parallel Processing
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories,
        [bool]$FilterResolution = $true,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080,
        [int]$MaxParallel = 3,
        [string[]]$ExcludeRepos = @()
    )

    $repos = $Repositories | Where-Object { $_.Url -notin $ExcludeRepos }
    $stats = @{
        TotalRepos = $repos.Count
        SuccessfulRepos = 0
        FailedRepos = 0
        ProcessedWallpapers = 0
        SavedWallpapers = 0
        RepoStats = @{}
    }

    # Parallel repository processing
    $repos | ForEach-Object -ThrottleLimit $MaxParallel -Parallel {
        $repo = $_
        $repoStats = @{
            Processed = 0
            Saved = 0
            ErrorMessage = $null
        }

        try {
            Write-EnhancedLog "Processing Repository: $($repo.Url)" -Color Yellow -Level Verbose

            # Network connectivity check
            if (-not (Test-NetworkConnection -Url $repo.Url)) {
                throw "Network connectivity issue"
            }

            $repoName = ($repo.Url -split '/')[-1]
            $clonePath = Join-Path $using:SavePath $repoName

            # Shallow clone process
            $cloneProcess = Start-Process git -ArgumentList "clone --depth 1 --branch $($repo.Branch) $($repo.Url) `"$clonePath`"" -PassThru -Wait -NoNewWindow

            if ($cloneProcess.ExitCode -ne 0) {
                throw "Git clone failed with exit code $($cloneProcess.ExitCode)"
            }

            $imageFiles = Get-ChildItem $clonePath -Recurse -Include @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp") 

            foreach ($image in $imageFiles) {
                $repoStats.Processed++

                # Apply image filtering
                if (Test-ImageQuality -ImagePath $image.FullName -MinWidth $using:MinWidth -MinHeight $using:MinHeight) {
                    $hash = (Get-FileHash -Algorithm SHA256 -Path $image.FullName).Hash
                    $newFilename = "$hash$($image.Extension)"
                    $destinationPath = Join-Path $using:SavePath $newFilename

                    Copy-Item -Path $image.FullName -Destination $destinationPath -Force
                    $repoStats.Saved++
                }
            }

            $stats.SuccessfulRepos++
            Write-EnhancedLog "Successfully processed: $($repo.Url)" -Color Green -Level Normal
        }
        catch {
            $repoStats.ErrorMessage = $_.Exception.Message
            $stats.FailedRepos++
            Write-EnhancedLog "Failed to process repository: $($repo.Url) - $($_.Exception.Message)" -Color Red -Important
        }
        finally {
            # Clean up temporary clone directory
            if (Test-Path $clonePath) {
                Remove-Item $clonePath -Recurse -Force
            }
        }

        # Thread-safe stats update
        $stats.ProcessedWallpapers += $repoStats.Processed
        $stats.SavedWallpapers += $repoStats.Saved
        $stats.RepoStats[$repo.Url] = $repoStats
    }

    return $stats
}

# Repository Configuration
$Repositories = @(
    @{
        Url = "https://github.com/dharmx/walls"
        Branch = "main"
        Description = "Minimal and aesthetic wallpapers with clean design"
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
        Url = "https://github.com/linuxdotexe/wallpapers"
        Branch = "main"
        Description = "High-resolution nature photography wallpapers"
    },
    @{
        Url = "https://github.com/ryan4yin/wallpapers"
        Branch = "main"
        Description = "Anime and digital art wallpapers"
    },
    @{
        Url = "https://github.com/satyawrat/WallPapers"
        Branch = "main"
        Description = "Diverse anime and pop culture wallpapers"
    },
    @{
        Url = "https://github.com/lxndrblz/animeWallpapers"
        Branch = "main"
        Description = "Curated anime wallpapers"
    },
    @{
        Url = "https://github.com/D3Ext/aesthetic-wallpapers"
        Branch = "main"
        Description = "Abstract and aesthetic wallpapers"
    },
    @{
        Url = "https://github.com/notlmn/wallpapers"
        Branch = "main"
        Description = "Artistic wallpapers with creative compositions"
    },
    @{
        Url = "https://github.com/minhonna/background-collection"
        Branch = "main"
        Description = "Diverse abstract and geometric wallpaper designs"
    }
)

# Main Execution Function
function Start-WallPimp {
    # Display header
    Write-Host @"
╔════════════════════════════════════╗
║        WallPimp Ver:1.3           ║
║   Advanced Wallpaper Collector    ║
╚════════════════════════════════════╝
"@ -ForegroundColor Cyan

    # Dependency checks
    if (-not (Install-WallpimpDependencies)) {
        Write-EnhancedLog "Critical dependency check failed." -Color Red -Important
        return
    }

    # No-download mode
    if ($NoDownload) {
        Write-EnhancedLog "No-Download mode enabled. Exiting." -Color Yellow
        return
    }

    # Save location configuration
    $userSavePath = Read-Host "Enter wallpaper save location (press Enter for default: $SavePath)"
    if ($userSavePath) {
        $SavePath = $userSavePath
    }

    # Ensure save directory exists
    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath | Out-Null
    }

    # Download wallpapers
    $results = Invoke-WallpaperDownload -SavePath $SavePath `
        -Repositories $Repositories `
        -FilterResolution:$FilterByResolution `
        -MinWidth $MinResolutionWidth `
        -MinHeight $MinResolutionHeight `
        -MaxParallel $MaxParallelRepos `
        -ExcludeRepos $ExcludeRepositories

    # Comprehensive summary
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

    # Detailed repository statistics
    foreach ($repoUrl in $results.RepoStats.Keys) {
        $repoStats = $results.RepoStats[$repoUrl]
        if ($repoStats.ErrorMessage) {
            Write-EnhancedLog "Repository: $repoUrl" -Color Yellow
            Write-EnhancedLog "  Processed Images: $($repoStats.Processed)" -Color Yellow
            Write-EnhancedLog "  Saved Images: $($repoStats.Saved)" -Color Yellow
            Write-EnhancedLog "  Error: $($repoStats.ErrorMessage)" -Color Red
        }
    }

    # Open save location
    Invoke-Item $SavePath
}

# Script Execution
Start-WallPimp
