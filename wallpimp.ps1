# WallPimp - Ultimate Wallpaper Collection Script
# Version 2.3
# Now with Speed Optimization

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

$banner = @"
╔══════════════════════════════════════════╗
║ ██╗    ██╗ █████╗ ██╗     ██╗  ██╗██████╗ ║
║ ██║    ██║██╔══██╗██║     ██║ ██╔╝██╔══██╗║
║ ██║ █╗ ██║███████║██║     █████╔╝ ██████╔╝║
║ ██║███╗██║██╔══██║██║     ██╔═██╗ ██╔═══╝ ║
║ ╚███╔███╔╝██║  ██║███████╗██║  ██╗██║     ║
║  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ║
╠══════════════════════════════════════════╣
║          Version 2.3 | 0xB0RN3           ║
╚══════════════════════════════════════════╝
"@

$Repositories = @(
    @{ Url = "https://github.com/dharmx/walls"; Description = "Minimalist designs" },
    @{ Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Description = "Anime collection" },
    @{ Url = "https://github.com/FrenzyExists/wallpapers"; Description = "Nature/abstract" },
    @{ Url = "https://github.com/michaelScopic/Wallpapers"; Description = "Scenic landscapes" },
    @{ Url = "https://github.com/ryan4yin/wallpapers"; Description = "Digital art" },
    @{ Url = "https://github.com/port19x/Wallpapers"; Description = "Clean minimalism" },
    @{ Url = "https://github.com/D3Ext/aesthetic-wallpapers"; Description = "Artistic styles" },
    @{ Url = "https://github.com/Dreamer-Paul/Anime-Wallpaper"; Description = "Anime focus" },
    @{ Url = "https://github.com/polluxau/linuxnext-wallpapers"; Description = "Linux themes" },
    @{ Url = "https://github.com/makccr/wallpapers"; Description = "Mixed collection" },
    @{ Url = "https://github.com/linuxdotexe/wallpapers"; Description = "Photography" },
    @{ Url = "https://github.com/satyawrat/WallPapers"; Description = "Diverse styles" },
    @{ Url = "https://github.com/lxndrblz/animeWallpapers"; Description = "Anime archive" },
    @{ Url = "https://github.com/notlmn/wallpapers"; Description = "Modern art" },
    @{ Url = "https://github.com/minhonna/background-collection"; Description = "Abstract art" }
)

function Write-EnhancedLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ConsoleColor]$Color = 'White',
        [ValidateSet('Silent', 'Normal', 'Verbose')]
        [string]$Level = 'Normal'
    )
    
    if ($LogLevel -eq 'Silent') { return }
    if ($LogLevel -eq 'Normal' -and $Level -eq 'Verbose') { return }
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
    "$(Get-Date -Format o) - $Message" | Out-File -Append -FilePath (Join-Path $SavePath "wallpimp.log")
}

function Get-UserSpeedPreference {
    if ($MaxParallelRepos -ne 3) { return $MaxParallelRepos } # Respect parameter
    
    Write-Host "`n⚡ Download Speed Optimization ⚡" -ForegroundColor Cyan
    Write-Host "1. Normal Mode (3 parallel downloads) [Recommended]"
    Write-Host "2. Turbo Mode (6 parallel downloads) - Fast but resource-heavy"
    Write-Host "3. Extreme Mode (10 parallel downloads) - Unstable connections not recommended"
    
    do {
        $choice = Read-Host "`nChoose download speed (1-3)"
    } while ($choice -notmatch '^[1-3]$')

    switch ($choice) {
        '1' { return 3 }
        '2' { return 6 }
        '3' { return 10 }
    }
}

function Invoke-TurboDownload {
    param(
        [string]$repoUrl,
        [string]$tempDir,
        [hashtable]$uniqueWallpapers
    )
    
    try {
        git clone --depth 1 --quiet $repoUrl $tempDir 2>$null
        $wallpapers = Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png

        $wallpapers | ForEach-Object {
            if (Test-ImageQuality $_.FullName) {
                $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
                if (-not $uniqueWallpapers.ContainsKey($hash)) {
                    $lock = [System.Threading.Mutex]::new($false, "WallpaperLock")
                    $lock.WaitOne() | Out-Null
                    try {
                        $targetPath = Join-Path $SavePath "$hash$($_.Extension)"
                        Copy-Item $_.FullName $targetPath -Force
                        $uniqueWallpapers[$hash] = $targetPath
                    }
                    finally {
                        $lock.ReleaseMutex()
                        $lock.Dispose()
                    }
                }
            }
        }
    }
    catch {
        Write-EnhancedLog "Error processing $repoUrl : $_" -Color Red -Level Verbose
    }
}

function Start-WallPimp {
    Write-Host $banner -ForegroundColor Magenta

    # Interactive setup
    if (-not $NoDownload) {
        $defaultPath = "$env:USERPROFILE\Pictures\Wallpapers"
        $userPath = Read-Host "Enter save directory [Default: $defaultPath]"
        $SavePath = if ($userPath) { $userPath } else { $defaultPath }
        
        if (-not (Test-Path $SavePath)) {
            New-Item -Path $SavePath -ItemType Directory -Force | Out-Null
            Write-EnhancedLog "Created directory: $SavePath" -Color Green
        }

        $MaxParallelRepos = Get-UserSpeedPreference
        Write-EnhancedLog "Parallel downloads set to: $MaxParallelRepos" -Color Cyan
    }

    # Core functionality
    $uniqueWallpapers = @{}
    $repoCount = $Repositories.Count
    $processed = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $Repositories | Where-Object { $_.Url -notin $ExcludeRepositories } | ForEach-Object -Parallel {
        $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        try {
            $using:processed++
            Write-EnhancedLog "[$($using:processed)/$($using:repoCount)] Downloading $($_.Description)" -Color Yellow
            
            Invoke-TurboDownload $_.Url $tempDir $using:uniqueWallpapers
        }
        finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } -ThrottleLimit $MaxParallelRepos

    $stopwatch.Stop()
    
    # Final report
    Write-EnhancedLog "`n✅ Operation completed in $($stopwatch.Elapsed.ToString('mm\:ss'))" -Color Green
    Write-EnhancedLog "💾 Saved $($uniqueWallpapers.Count) unique wallpapers" -Color Green
    Write-EnhancedLog "📁 Location: $SavePath" -Color Cyan
    
    if (-not $NoDownload) {
        Invoke-Item $SavePath
    }
}

# Main execution
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is required. Installing..." -ForegroundColor Yellow
    winget install --id Git.Git -e
    $env:Path += ";C:\Program Files\Git\cmd"
}

if (-not $NoDownload) {
    Start-WallPimp
}
