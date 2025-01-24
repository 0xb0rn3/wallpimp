# WallPimp - Advanced Wallpaper Collection Script
# Version 1.4
# Developed to automate wallpaper collection from multiple GitHub repositories

param (
    [string]$SavePath = "$env:USERPROFILE\Pictures\Wallpapers",
    [switch]$NoDownload = $false,
    [switch]$FilterByResolution = $true,
    [int]$MinResolutionWidth = 1920,
    [int]$MinResolutionHeight = 1080,
    [int]$MaxParallelRepos = 3,
    [string[]]$ExcludeRepositories = @(),
    [ValidateSet('Silent', 'Normal', 'Verbose')]
    [string]$LogLevel = 'Normal'
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
    
    # Console and file logging
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    
    $logFile = Join-Path $SavePath "wallpimp_log.txt"
    "[$timestamp] $Message" | Out-File -Append -FilePath $logFile
}

# Network Connectivity Check
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

# Dependency Installation Function
function Install-WallpimpDependencies {
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-EnhancedLog "Git not found. Attempting installation..." -Color Yellow

        try {
            $installerPath = Join-Path $env:TEMP "git_installer.exe"
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
            
            Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath
            Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait
            
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

    $repos = $Repositories | Where-Object { $_.Url -notin $ExcludeRepos }
    $stats = @{
        TotalRepos = $repos.Count
        SuccessfulRepos = 0
        FailedRepos = 0
        ProcessedWallpapers = 0
        SavedWallpapers = 0
        RepoStats = @{}
    }

    # Job script block
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

            # Shallow clone
            $cloneResult = git clone --depth 1 --branch $repo.Branch $repo.Url $clonePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Git clone failed: $cloneResult"
            }

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
            # Clean up clone directory
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

        # Limit concurrent jobs
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

    # Handle remaining jobs
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

# Repository Configuration (same as previous script)
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
