# WallPimp - Ultimate Wallpaper Collection Script
# Version 2.2
# Complete Repository Integration

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

# Environment Configuration
$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = 0
$env:GCM_INTERACTIVE = 'Never'
Add-Type -AssemblyName System.Drawing

# ASCII Banner
$banner = @"
╔══════════════════════════════════════════╗
║ ██╗    ██╗ █████╗ ██╗     ██╗  ██╗██████╗ ║
║ ██║    ██║██╔══██╗██║     ██║ ██╔╝██╔══██╗║
║ ██║ █╗ ██║███████║██║     █████╔╝ ██████╔╝║
║ ██║███╗██║██╔══██║██║     ██╔═██╗ ██╔═══╝ ║
║ ╚███╔███╔╝██║  ██║███████╗██║  ██╗██║     ║
║  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ║
╠══════════════════════════════════════════╣
║          Version 2.2 | 0xB0RN3           ║
╚══════════════════════════════════════════╝
"@

# Comprehensive Repository List
$Repositories = @(
    @{ Url = "https://github.com/dharmx/walls"; Branch = "main"; Description = "Minimalist designs" },
    @{ Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Branch = "main"; Description = "Anime collection" },
    @{ Url = "https://github.com/FrenzyExists/wallpapers"; Branch = "main"; Description = "Nature/abstract" },
    @{ Url = "https://github.com/michaelScopic/Wallpapers"; Branch = "main"; Description = "Scenic landscapes" },
    @{ Url = "https://github.com/ryan4yin/wallpapers"; Branch = "main"; Description = "Digital art" },
    @{ Url = "https://github.com/port19x/Wallpapers"; Branch = "main"; Description = "Clean minimalism" },
    @{ Url = "https://github.com/D3Ext/aesthetic-wallpapers"; Branch = "main"; Description = "Artistic styles" },
    @{ Url = "https://github.com/Dreamer-Paul/Anime-Wallpaper"; Branch = "main"; Description = "Anime focus" },
    @{ Url = "https://github.com/polluxau/linuxnext-wallpapers"; Branch = "main"; Description = "Linux themes" },
    @{ Url = "https://github.com/makccr/wallpapers"; Branch = "main"; Description = "Mixed collection" },
    @{ Url = "https://github.com/linuxdotexe/wallpapers"; Branch = "main"; Description = "Photography" },
    @{ Url = "https://github.com/satyawrat/WallPapers"; Branch = "main"; Description = "Diverse styles" },
    @{ Url = "https://github.com/lxndrblz/animeWallpapers"; Branch = "main"; Description = "Anime archive" },
    @{ Url = "https://github.com/notlmn/wallpapers"; Branch = "main"; Description = "Modern art" },
    @{ Url = "https://github.com/minhonna/background-collection"; Branch = "main"; Description = "Abstract art" },
    @{ Url = "https://github.com/Axlefublr/wallpapers"; Branch = "main"; Description = "Curated selection" },
    @{ Url = "https://github.com/wallpaperhub-app/wallpapers"; Branch = "main"; Description = "Premium collection" }
)

function Write-EnhancedLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ConsoleColor]$Color = 'White',
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal',
        [switch]$Important
    )
    
    if ($LogLevel -eq 'Silent' -and $Level -ne 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logPrefix = if ($Important) { "✨ " } else { "▷ " }
    
    Write-Host "[$timestamp] $logPrefix$Message" -ForegroundColor $Color
    "$(Get-Date -Format o) - $Message" | Out-File -Append -FilePath (Join-Path $SavePath "wallpimp.log")
}

function Test-NetworkConnection {
    try {
        $testUrl = "https://github.com"
        $request = [System.Net.WebRequest]::Create($testUrl)
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        Write-EnhancedLog "Network connection failed" -Color Red -Important
        return $false
    }
}

function Install-WallpimpDependencies {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-EnhancedLog "Git not found. Installing..." -Color Yellow -Important
        try {
            winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
            $env:Path += ";C:\Program Files\Git\cmd"
            Write-EnhancedLog "Git installed successfully" -Color Green
        }
        catch {
            Write-EnhancedLog "Git installation failed: $_" -Color Red -Important
            exit 1
        }
    }
}

function Test-ImageQuality {
    param(
        [string]$ImagePath,
        [int]$MinWidth = 1920,
        [int]$MinHeight = 1080
    )

    try {
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        $isValid = $image.Width -ge $MinWidth -and $image.Height -ge $MinHeight
        $image.Dispose()
        return $isValid
    }
    catch {
        Write-EnhancedLog "Invalid image file: $ImagePath" -Color Yellow -Level Verbose
        return $false
    }
}

function Invoke-WallpaperDownload {
    $totalRepos = $Repositories.Count
    $processed = 0
    $uniqueWallpapers = @{}
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($repo in $Repositories | Where-Object { $_.Url -notin $ExcludeRepositories }) {
        $processed++
        try {
            Write-EnhancedLog "Processing ($processed/$totalRepos): $($repo.Description)" -Color Cyan
            
            $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
            $null = New-Item -Path $tempDir -ItemType Directory -Force

            git clone --depth 1 --quiet $repo.Url $tempDir 2>$null

            Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png | ForEach-Object {
                if (Test-ImageQuality $_.FullName $MinResolutionWidth $MinResolutionHeight) {
                    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
                    if (-not $uniqueWallpapers.ContainsKey($hash)) {
                        $targetPath = Join-Path $SavePath "$hash$($_.Extension)"
                        Copy-Item $_.FullName $targetPath -Force
                        $uniqueWallpapers[$hash] = $targetPath
                    }
                }
            }
        }
        catch {
            Write-EnhancedLog "Error processing $($repo.Url): $_" -Color Red -Level Verbose
        }
        finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $stopwatch.Stop()
    Write-EnhancedLog "Operation completed in $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -Color Green -Important
    Write-EnhancedLog "Collected $($uniqueWallpapers.Count) unique wallpapers" -Color Green -Important
}

function Start-WallPimp {
    Write-Host $banner -ForegroundColor Magenta

    if (-not (Test-NetworkConnection)) {
        Write-EnhancedLog "No internet connection available" -Color Red -Important
        exit 1
    }

    Install-WallpimpDependencies

    if (-not $NoDownload) {
        if (-not (Test-Path $SavePath)) {
            $null = New-Item -Path $SavePath -ItemType Directory -Force
        }

        Invoke-WallpaperDownload
        Invoke-Item $SavePath
    }
    else {
        Write-EnhancedLog "No-download mode activated" -Color Yellow
    }
}

# Main execution
Start-WallPimp
