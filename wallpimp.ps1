# WallPimp - Intelligent Wallpaper Collector
# Version 2.4
# Developer: 0xB0RN3

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

# Version Detection
$isPwsh7 = $PSVersionTable.PSVersion.Major -ge 7
$banner = @"
╔══════════════════════════════════════════╗
║ ██╗    ██╗ █████╗ ██╗     ██╗  ██╗██████╗ ║
║ ██║    ██║██╔══██╗██║     ██║ ██╔╝██╔══██╗║
║ ██║ █╗ ██║███████║██║     █████╔╝ ██████╔╝║
║ ██║███╗██║██╔══██║██║     ██╔═██╗ ██╔═══╝ ║
║ ╚███╔███╔╝██║  ██║███████╗██║  ██╗██║     ║
║  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ║
╠══════════════════════════════════════════╣
║          WallPimp v2.4 | 0xB0RN3         ║
╚══════════════════════════════════════════╝
"@

# Version Warning System
if (-not $isPwsh7) {
    Write-Host "`n⚠️ WARNING: Running in Windows PowerShell" -ForegroundColor Yellow
    Write-Host "  - Performance will be limited" -ForegroundColor Yellow
    Write-Host "  - Parallel downloads disabled" -ForegroundColor Yellow
    Write-Host "  - Recommended: Install PowerShell 7" -ForegroundColor Cyan
    Write-Host "    winget install Microsoft.PowerShell`n" -ForegroundColor White
}

# Repository List
$Repositories = @(
    @{ Url = "https://github.com/dharmx/walls"; Description = "Minimalist designs" },
    @{ Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Description = "Anime collection" },
    @{ Url = "https://github.com/FrenzyExists/wallpapers"; Description = "Nature/abstract" },
    @{ Url = "https://github.com/michaelScopic/Wallpapers"; Description = "Scenic landscapes" },
    @{ Url = "https://github.com/D3Ext/aesthetic-wallpapers"; Description = "Artistic styles" },
    @{ Url = "https://github.com/linuxdotexe/wallpapers"; Description = "Photography" }
)

function Write-EnhancedLog {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White',
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal'
    )
    
    if ($LogLevel -eq 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Start-WallPimp {
    Write-Host $banner -ForegroundColor Magenta

    # Interactive Setup
    if (-not $NoDownload) {
        $defaultPath = "$env:USERPROFILE\Pictures\Wallpapers"
        $userPath = Read-Host "Enter save directory [Default: $defaultPath]"
        $SavePath = if ($userPath) { $userPath } else { $defaultPath }
        
        if (-not (Test-Path $SavePath)) {
            New-Item -Path $SavePath -ItemType Directory -Force | Out-Null
            Write-EnhancedLog "Created directory: $SavePath" -Color Green
        }
    }

    # Core Download Logic
    $uniqueWallpapers = @{}
    $repoCount = $Repositories.Count
    $processed = 0

    if ($isPwsh7) {
        # PowerShell 7 Optimized Parallel Download
        $Repositories | Where-Object { $_.Url -notin $ExcludeRepositories } | ForEach-Object -Parallel {
            $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            
            try {
                $using:processed++
                Write-EnhancedLog "[$($using:processed)/$($using:repoCount)] Downloading $($_.Description)" -Color Yellow
                
                git clone --depth 1 --quiet $_.Url $tempDir 2>$null
                Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png | ForEach-Object {
                    try {
                        $image = [System.Drawing.Image]::FromFile($_.FullName)
                        if ($image.Width -ge $using:MinResolutionWidth -and $image.Height -ge $using:MinResolutionHeight) {
                            $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
                            if (-not $using:uniqueWallpapers.ContainsKey($hash)) {
                                $lock = [System.Threading.Mutex]::new($false, "WallpaperLock")
                                $lock.WaitOne() | Out-Null
                                try {
                                    $targetPath = Join-Path $using:SavePath "$hash$($_.Extension)"
                                    Copy-Item $_.FullName $targetPath -Force
                                    $using:uniqueWallpapers[$hash] = $targetPath
                                }
                                finally {
                                    $lock.ReleaseMutex()
                                    $lock.Dispose()
                                }
                            }
                        }
                        $image.Dispose()
                    }
                    catch { Write-EnhancedLog "Error processing $($_.Name)" -Color Red }
                }
            }
            catch { Write-EnhancedLog "Error processing $($_.Url) : $_" -Color Red }
            finally { Remove-Item $tempDir -Recurse -Force }
        } -ThrottleLimit $MaxParallelRepos
    }
    else {
        # Windows PowerShell Sequential Download
        foreach ($repo in $Repositories | Where-Object { $_.Url -notin $ExcludeRepositories }) {
            $processed++
            try {
                Write-EnhancedLog "[$processed/$repoCount] Downloading $($repo.Description)" -Color Yellow
                
                $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

                git clone --depth 1 --quiet $repo.Url $tempDir 2>$null
                Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png | ForEach-Object {
                    try {
                        $image = [System.Drawing.Image]::FromFile($_.FullName)
                        if ($image.Width -ge $MinResolutionWidth -and $image.Height -ge $MinResolutionHeight) {
                            $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
                            if (-not $uniqueWallpapers.ContainsKey($hash)) {
                                $targetPath = Join-Path $SavePath "$hash$($_.Extension)"
                                Copy-Item $_.FullName $targetPath -Force
                                $uniqueWallpapers[$hash] = $targetPath
                            }
                        }
                        $image.Dispose()
                    }
                    catch { Write-EnhancedLog "Error processing $($_.Name)" -Color Red }
                }
            }
            catch { Write-EnhancedLog "Error processing $($repo.Url) : $_" -Color Red }
            finally { Remove-Item $tempDir -Recurse -Force }
        }
    }

    # Final Report
    Write-EnhancedLog "`n✅ Operation completed" -Color Green
    Write-EnhancedLog "💾 Saved $($uniqueWallpapers.Count) unique wallpapers" -Color Green
    Write-EnhancedLog "📁 Location: $SavePath" -Color Cyan
    
    if (-not $NoDownload) { Invoke-Item $SavePath }
}

# Main Execution
try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is required. Installing..." -ForegroundColor Yellow
        winget install --id Git.Git -e
        $env:Path += ";C:\Program Files\Git\cmd"
    }

    if (-not $NoDownload) { Start-WallPimp }
}
catch {
    Write-Host "`n❌ Fatal error: $_" -ForegroundColor Red
    exit 1
}
