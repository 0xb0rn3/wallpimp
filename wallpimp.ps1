# WallPimp - Advanced Wallpaper Collection Script
# Version 1.4
# Developed to automate wallpaper collection from multiple GitHub repositories

param (
    # Default save path for wallpapers in the user's Pictures directory
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",
    
    # Flag to disable downloading (useful for testing)
    [switch]$NoDownload = $false,
    
    # Enable/disable resolution filtering
    [switch]$FilterByResolution = $true,
    
    # Minimum width requirement for wallpapers
    [int]$MinResolutionWidth = 1920,
    
    # Minimum height requirement for wallpapers
    [int]$MinResolutionHeight = 1080,
    
    # Maximum number of repositories to process in parallel
    [int]$MaxParallelRepos = 3,
    
    # List of repositories to exclude from downloading
    [string[]]$ExcludeRepositories = @(),
    
    # Logging verbosity levels
    [ValidateSet('Silent', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'
)

# Load .NET Image Processing Assembly for image validation
Add-Type -AssemblyName System.Drawing

# Enhanced Logging Function
# Provides flexible logging with color and importance options
function Write-EnhancedLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$false)][ConsoleColor]$Color = 'White',
        [Parameter(Mandatory=$false)][ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal',
        [switch]$Important
    )
    
    # Log level filtering to control verbosity
    if ($LogLevel -eq 'Silent' -and $Level -ne 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    # Generate timestamp for logging
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Use different prefixes for standard and important messages
    $logPrefix = if ($Important) { "🌟 " } else { "➤ " }
    
    # Display message in console with color
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    
    # Log to file for persistent record
    $logFile = Join-Path $SavePath "wallpimp_log.txt"
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile
}

# Network Connectivity Check
# Verifies if a given URL is reachable
function Test-NetworkConnection {
    param([string]$Url)
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        Write-EnhancedLog "Network connectivity issue: $Url" -Color Red -Level Verbose
        return $false
    }
}

# Enhanced Dependency Installation Function
# Provides robust Git detection and installation
function Install-WallpimpDependencies {
    # Comprehensive Git detection
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-EnhancedLog "Git not found. Enhanced detection and installation..." -Color Yellow

        # Check potential installation paths
        $potentialGitPaths = @(
            "C:\Program Files\Git\cmd\git.exe",
            "C:\Program Files (x86)\Git\cmd\git.exe",
            "$env:USERPROFILE\AppData\Local\Programs\Git\cmd\git.exe"
        )

        $gitPath = $potentialGitPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($gitPath) {
            # Add Git to current session PATH
            $env:Path += ";$(Split-Path $gitPath)"
            Write-EnhancedLog "Git found at $gitPath" -Color Green
            return $true
        }

        try {
            $installerPath = Join-Path $env:TEMP "git_installer.exe"
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
            
            # Download Git installer
            Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath
            
            # Silent installation with specific directory
            Start-Process -FilePath $installerPath -ArgumentList "/SILENT /SUPPRESSMSGBOXES /NORESTART /DIR=C:\Program Files\Git" -Wait
            
            # Explicitly update system PATH
            $env:Path += ";C:\Program Files\Git\cmd"
            
            Write-EnhancedLog "Git installed successfully!" -Color Green
        }
        catch {
            Write-EnhancedLog "Git installation failed: $_" -Color Red -Important
            return $false
        }
    }
    return $true
}

# Image Quality Verification Function
# Validates wallpaper based on resolution and uniqueness
function Test-ImageQuality {
    param(
        [string]$ImagePath,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080,
        [string]$SavePath,
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

# Wallpaper Download Function with Background Jobs
# Processes multiple repositories in parallel
function Invoke-WallpaperDownload {
    param(
        [string]$SavePath,
        [array]$Repositories,
        [bool]$FilterResolution = $true,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080,
        [int]$MaxJobs = 3,
        [string[]]$ExcludeRepos = @()
    )

    # Filter out excluded repositories
    $repos = $Repositories | Where-Object { $_.Url -notin $ExcludeRepos }
    
    # Initialize statistics tracking
    $stats = @{
        TotalRepos = $repos.Count
        SuccessfulRepos = 0
        FailedRepos = 0
        ProcessedWallpapers = 0
        SavedWallpapers = 0
        RepoStats = @{}
    }

    # Job script block for parallel repository processing
    $jobScript = {
        param($repo, $SavePath, $MinWidth, $MinHeight)
        
        $repoStats = @{
            Processed = 0
            Saved = 0
            ErrorMessage = $null
        }

        try {
            $repoName = ($repo.Url -split '/')[-1]
            $clonePath = Join-Path $SavePath $repoName

            # Shallow clone to minimize download size
            $cloneResult = git clone --depth 1 --branch $repo.Branch $repo.Url $clonePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Git clone failed: $cloneResult"
            }

            # Find all image files in the cloned repository
            $imageFiles = Get-ChildItem $clonePath -Recurse -Include @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp") 

            foreach ($image in $imageFiles) {
                $repoStats.Processed++

                # Apply image filtering
                if ((Test-ImageQuality -ImagePath $image.FullName -MinWidth $MinWidth -MinHeight $MinHeight -SavePath $SavePath)) {
                    $hash = (Get-FileHash -Algorithm SHA256 -Path $image.FullName).Hash
                    $newFilename = "$hash$($image.Extension)"
                    $destinationPath = Join-Path $SavePath $newFilename

                    Copy-Item -Path $image.FullName -Destination $destinationPath -Force
                    $repoStats.Saved++
                }
            }

            $repoStats.ErrorMessage = $null
        }
        catch {
            $repoStats.ErrorMessage = $_.Exception.Message
        }
        finally {
            # Clean up clone directory to save space
            if (Test-Path $clonePath) {
                Remove-Item $clonePath -Recurse -Force
            }
        }

        return $repoStats
    }

    # Create background jobs
    $jobs = @()
    foreach ($repo in $repos) {
        $job = Start-Job -ScriptBlock $jobScript -ArgumentList $repo, $SavePath, $MinWidth, $MinHeight
        $jobs += $job

        # Limit concurrent jobs to prevent overwhelming system
        if ($jobs.Count -ge $MaxJobs) {
            $jobs | Wait-Job
            foreach ($job in $jobs) {
                $result = Receive-Job $job
                $stats.ProcessedWallpapers += $result.Processed
                $stats.SavedWallpapers += $result.Saved
                $stats.RepoStats[$repo.Url] = $result

                if ($result.ErrorMessage) {
                    $stats.FailedRepos++
                    Write-EnhancedLog "Repository failed: $($repo.Url) - $($result.ErrorMessage)" -Color Red -Important
                }
                else {
                    $stats.SuccessfulRepos++
                }
            }
            $jobs | Remove-Job
            $jobs = @()
        }
    }

    # Handle any remaining jobs
    if ($jobs.Count -gt 0) {
        $jobs | Wait-Job
        foreach ($job in $jobs) {
            $result = Receive-Job $job
            $repoUrl = ($result.Url -split '/')[-1]
            $stats.ProcessedWallpapers += $result.Processed
            $stats.SavedWallpapers += $result.Saved
            $stats.RepoStats[$repoUrl] = $result

            if ($result.ErrorMessage) {
                $stats.FailedRepos++
                Write-EnhancedLog "Repository failed: $repoUrl - $($result.ErrorMessage)" -Color Red -Important
            }
            else {
                $stats.SuccessfulRepos++
            }
        }
        $jobs | Remove-Job
    }

    return $stats
}

# Repository Configuration
# List of GitHub repositories to download wallpapers from
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
# Orchestrates the entire wallpaper collection process
function Start-WallPimp {
    # Display welcome header
    Write-Host @"
╔════════════════════════════════════╗
║        WallPimp Ver:1.4           ║
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
        -MaxJobs $MaxParallelRepos `
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

    # Open save location
    Invoke-Item $SavePath
}

# Script Execution
Start-WallPimp
