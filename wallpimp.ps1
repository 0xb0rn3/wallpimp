# WallPimp - Advanced Wallpaper Collection Script
# Version 1.4
# Comprehensive GitHub Wallpaper Collector

# Script Parameters - Configurable Options
param (
    # Default save location for downloaded wallpapers
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",
    
    # Option to skip downloading (for testing)
    [switch]$NoDownload = $false,
    
    # Toggle resolution filtering
    [switch]$FilterByResolution = $true,
    
    # Minimum acceptable wallpaper width
    [int]$MinResolutionWidth = 1920,
    
    # Minimum acceptable wallpaper height
    [int]$MinResolutionHeight = 1080,
    
    # Maximum number of repositories to process simultaneously
    [int]$MaxParallelRepos = 3,
    
    # Repositories to skip during download
    [string[]]$ExcludeRepositories = @(),
    
    # Logging verbosity control
    [ValidateSet('Silent', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'
)

# Prevent Git authentication popups
$env:GIT_TERMINAL_PROMPT = 0
$env:GCM_INTERACTIVE = 'Never'

# Load .NET image processing capabilities
Add-Type -AssemblyName System.Drawing

# Enhanced Logging Function
function Write-EnhancedLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ConsoleColor]$Color = 'White',
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal',
        [switch]$Important
    )
    
    # Log level filtering logic
    if ($LogLevel -eq 'Silent' -and $Level -ne 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPrefix = if ($Important) { "🌟 " } else { "➤ " }
    
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    
    # Log to file for persistent record
    $logFile = Join-Path $SavePath "wallpimp_log.txt"
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile
}

# Network Connectivity Verification
function Test-NetworkConnection {
    param([string]$Url)
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = 10000  # 10-second timeout
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        Write-EnhancedLog "Network connectivity issue: $Url" -Color Red -Level Verbose
        return $false
    }
}

# Dependency Management Function
function Install-WallpimpDependencies {
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-EnhancedLog "Git not found. Initiating installation..." -Color Yellow

        $potentialGitPaths = @(
            "C:\Program Files\Git\cmd\git.exe",
            "C:\Program Files (x86)\Git\cmd\git.exe",
            "$env:USERPROFILE\AppData\Local\Programs\Git\cmd\git.exe"
        )

        $gitPath = $potentialGitPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($gitPath) {
            $env:Path += ";$(Split-Path $gitPath)"
            Write-EnhancedLog "Git found at $gitPath" -Color Green
            return $true
        }

        try {
            $installerPath = Join-Path $env:TEMP "git_installer.exe"
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
            
            Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath
            
            Start-Process -FilePath $installerPath -ArgumentList "/SILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
            
            $env:Path += ";C:\Program Files\Git\cmd"
            
            Write-EnhancedLog "Git installed successfully!" -Color Green
            return $true
        }
        catch {
            Write-EnhancedLog "Git installation failed: $_" -Color Red -Important
            return $false
        }
    }
    return $true
}

# Image Quality Validation Function
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
        
        # Resolution check
        $meetsResolution = ($image.Width -ge $MinWidth -and $image.Height -ge $MinHeight)
        
        # Duplicate prevention
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

# Wallpaper Download Core Function
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

    $ErrorActionPreference = 'Stop'

    # Git configuration to prevent authentication issues
    git config --global url."https://".insteadOf git://
    $env:GIT_TERMINAL_PROMPT = 0

    $repos = $Repositories | Where-Object { $_.Url -notin $ExcludeRepos }
    
    $stats = @{
        TotalRepos = $repos.Count
        SuccessfulRepos = 0
        FailedRepos = 0
        ProcessedWallpapers = 0
        SavedWallpapers = 0
        RepoStats = @{}
    }

    $jobScript = {
        param($repo, $SavePath, $MinWidth, $MinHeight)
        
        $repoStats = @{
            Processed = 0
            Saved = 0
            ErrorMessage = $null
        }

        try {
            $repoName = ($repo.Url -split '/')[-1] -replace '[^a-zA-Z0-9]', '_'
            $uniqueClonePath = Join-Path $SavePath "$($repoName)_$(Get-Random)"

            New-Item -ItemType Directory -Path $uniqueClonePath | Out-Null

            $gitParams = @(
                'clone', 
                '--depth', '1', 
                '--single-branch',
                '--no-tags',
                '--config', 'http.sslVerify=false',
                $repo.Url, 
                $uniqueClonePath
            )

            $process = Start-Process git -ArgumentList $gitParams -PassThru -Wait -NoNewWindow -RedirectStandardError "$uniqueClonePath\clone_error.txt"

            if ($process.ExitCode -ne 0) {
                $errorDetails = Get-Content "$uniqueClonePath\clone_error.txt"
                throw "Git clone failed: $errorDetails"
            }

            $imageFiles = Get-ChildItem $uniqueClonePath -Recurse -Include @(
                "*.jpg", "*.jpeg", "*.png", "*.gif", 
                "*.webp", "*.bmp", "*.tiff", "*.svg"
            ) 

            foreach ($image in $imageFiles) {
                $repoStats.Processed++

                if ((Test-ImageQuality -ImagePath $image.FullName -MinWidth $MinWidth -MinHeight $MinHeight -SavePath $SavePath)) {
                    $hash = (Get-FileHash -Algorithm SHA256 -Path $image.FullName).Hash
                    $newFilename = "$hash$($image.Extension)"
                    $destinationPath = Join-Path $SavePath $newFilename

                    Copy-Item -Path $image.FullName -Destination $destinationPath -Force
                    $repoStats.Saved++
                }
            }
        }
        catch {
            $repoStats.ErrorMessage = $_.Exception.Message
        }
        finally {
            if (Test-Path $uniqueClonePath) {
                Remove-Item $uniqueClonePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        return $repoStats
    }

    $jobs = @()
    foreach ($repo in $repos) {
        $job = Start-Job -ScriptBlock $jobScript -ArgumentList $repo, $SavePath, $MinWidth, $MinHeight
        $jobs += $job

        if ($jobs.Count -ge $MaxJobs) {
            $jobs | Wait-Job
            foreach ($job in $jobs) {
                $result = Receive-Job $job
                $stats.ProcessedWallpapers += $result.Processed
                $stats.SavedWallpapers += $result.Saved

                if ($result.ErrorMessage) {
                    $stats.FailedRepos++
                    Write-EnhancedLog "Repository processing error: $($result.ErrorMessage)" -Color Red -Important
                }
                else {
                    $stats.SuccessfulRepos++
                }
            }
            $jobs | Remove-Job
            $jobs = @()
        }
    }

    if ($jobs.Count -gt 0) {
        $jobs | Wait-Job
        foreach ($job in $jobs) {
            $result = Receive-Job $job
            $stats.ProcessedWallpapers += $result.Processed
            $stats.SavedWallpapers += $result.Saved

            if ($result.ErrorMessage) {
                $stats.FailedRepos++
                Write-EnhancedLog "Repository processing error: $($result.ErrorMessage)" -Color Red -Important
            }
            else {
                $stats.SuccessfulRepos++
            }
        }
        $jobs | Remove-Job
    }

    return $stats
}

# Curated Wallpaper Repositories
$Repositories = @(
    @{ Url = "https://github.com/dharmx/walls"; Branch = "main"; Description = "Minimal wallpapers" },
    @{ Url = "https://github.com/port19x/Wallpapers"; Branch = "main"; Description = "Minimalist wallpapers" },
    @{ Url = "https://github.com/Axlefublr/wallpapers"; Branch = "main"; Description = "Curated wallpapers" },
    @{ Url = "https://github.com/FrenzyExists/wallpapers"; Branch = "main"; Description = "Nature wallpapers" },
    @{ Url = "https://github.com/michaelScopic/Wallpapers"; Branch = "main"; Description = "Scenic wallpapers" },
    @{ Url = "https://github.com/linuxdotexe/wallpapers"; Branch = "main"; Description = "Photography wallpapers" },
    @{ Url = "https://github.com/ryan4yin/wallpapers"; Branch = "main"; Description = "Anime wallpapers" },
    @{ Url = "https://github.com/satyawrat/WallPapers"; Branch = "main"; Description = "Diverse wallpapers" },
    @{ Url = "https://github.com/lxndrblz/animeWallpapers"; Branch = "main"; Description = "Anime collection" },
    @{ Url = "https://github.com/D3Ext/aesthetic-wallpapers"; Branch = "main"; Description = "Aesthetic wallpapers" },
    @{ Url = "https://github.com/notlmn/wallpapers"; Branch = "main"; Description = "Artistic wallpapers" },
    @{ Url = "https://github.com/minhonna/background-collection"; Branch = "main"; Description = "Abstract wallpapers" }
)

# Main Execution Function
function Start-WallPimp {
    Write-Host @"
╔════════════════════════════════════╗
║        WallPimp Ver:1.4            ║
║   Advanced Wallpaper Collector     ║
╚════════════════════════════════════╝
"@ -ForegroundColor Cyan

    if (-not (Install-WallpimpDependencies)) {
        Write-EnhancedLog "Critical dependency check failed." -Color Red -Important
        return
    }

    if ($NoDownload) {
        Write-EnhancedLog "No-Download mode enabled. Exiting." -Color Yellow
        return
    }

    $userSavePath = Read-Host "Enter wallpaper save location (press Enter for default: $SavePath)"
    if ($userSavePath) {
        $SavePath = $userSavePath
    }

    if (!(Test-Path $SavePath)) {
        New-Item -ItemType Directory -Path $SavePath | Out-Null
    }

    $results = Invoke-WallpaperDownload -SavePath $SavePath `
        -Repositories $Repositories `
        -FilterResolution:$FilterByResolution `
        -MinWidth $MinResolutionWidth `
        -MinHeight $MinResolutionHeight `
        -MaxJobs $MaxParallelRepos `
        -ExcludeRepos $ExcludeRepositories

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

    Invoke-Item $SavePath
}

# Script Execution Trigger
Start-WallPimp
