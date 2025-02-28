# WallPimp - Intelligent Wallpaper Collector
# Version 0.2
# Developer: 0xB0RN3

param (
    [string]$ConfigUrl = "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/config.ini",
    [switch]$NoDownload = $false,
    [int]$MinResolutionWidth = 1920,
    [int]$MinResolutionHeight = 1080,
    [int]$MaxParallelRepos = 3
)

# Load configuration from URL or use defaults
function Load-Configuration {
    param([string]$ConfigUrl)
    try {
        $configContent = Invoke-WebRequest -Uri $ConfigUrl -ErrorAction Stop
        $repositories = @()
        $configContent.Content -split '\r?\n' | Where-Object { $_ -match '^\s*([^=\s]+)\s*=\s*(.+)$' } | ForEach-Object {
            $parts = $matches[2] -split '\|'
            if ($parts.Length -ge 2) {
                $repositories += @{ Url = $parts[0].Trim(); Branch = $parts[1].Trim(); Name = $matches[1].Trim() }
            }
        }
        return $repositories
    }
    catch {
        Write-Host "Failed to load config. Using defaults." -ForegroundColor Yellow
        return @(
            @{ Url = "https://github.com/dharmx/walls"; Branch = "main"; Name = "Minimalist" },
            @{ Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Branch = "main"; Name = "Anime" },
            @{ Url = "https://github.com/FrenzyExists/wallpapers"; Branch = "main"; Name = "Nature" },
            @{ Url = "https://github.com/michaelScopic/Wallpapers"; Branch = "main"; Name = "Scenic" },
            @{ Url = "https://github.com/D3Ext/aesthetic-wallpapers"; Branch = "main"; Name = "Artistic" },
            @{ Url = "https://github.com/Dreamer-Paul/Anime-Wallpaper"; Branch = "main"; Name = "Anime Pack" },
            @{ Url = "https://github.com/polluxau/linuxnext-wallpapers"; Branch = "main"; Name = "Linux" },
            @{ Url = "https://github.com/makccr/wallpapers"; Branch = "main"; Name = "Mixed" },
            @{ Url = "https://github.com/port19x/Wallpapers"; Branch = "main"; Name = "Desktop" },
            @{ Url = "https://github.com/ryan4yin/wallpapers"; Branch = "main"; Name = "Gaming" },
            @{ Url = "https://github.com/linuxdotexe/wallpapers"; Branch = "main"; Name = "Photos" },
            @{ Url = "https://github.com/0xb0rn3/wallpapers"; Branch = "main"; Name = "Digital" }
        )
    }
}

# Check and install dependencies
function Confirm-Dependencies {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "🔧 Git not found. Attempting installation..." -ForegroundColor Yellow
        try {
            winget install --id Git.Git -e --silent
            Write-Host "✓ Git installed." -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to install Git. Please install manually." -ForegroundColor Red
            exit 1
        }
    }
    if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
        Write-Host "🔧 ImageMagick not found. Please install manually." -ForegroundColor Yellow
        # Note: Manual installation recommended as winget may not always work reliably
    }
}

# Main function
function Start-WallPimp {
    $banner = @"
    ██╗    ██╗ █████╗ ██╗     ██╗     ██████╗ ██╗███╗   ███╗██████╗ 
    ██║    ██║██╔══██╗██║     ██║     ██╔══██╗██║████╗ ████║██╔══██╗
    ██║ █╗ ██║███████║██║     ██║     ██████╔╝██║██╔████╔██║██████╔╝
    ██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ 
    ╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║██║ ╚═╝ ██║██║     
     ╚══╝╚══╝ ╚═╝  ╚═╝╚════==╝╚══════╝╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     
                    
    Ultimate Wallpaper Collector v2.5
    Created by 0xB0RN3
"@
    Write-Host $banner -ForegroundColor Magenta

    # Prompt for save directory
    $defaultPath = "$env:USERPROFILE\Pictures\Wallpapers"
    $SavePath = Read-Host "Enter directory to save wallpapers [default: $defaultPath]"
    $SavePath = if ($SavePath) { $SavePath } else { $defaultPath }
    if (-not (Test-Path $SavePath)) {
        New-Item -Path $SavePath -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created directory: $SavePath" -ForegroundColor Green
    }

    # Storage space check
    $requiredSpace = 3.5GB
    Write-Host "Estimated storage required: approximately 3.5GB" -ForegroundColor Cyan
    $drive = (Get-Item $SavePath).PSDrive.Name
    $driveInfo = [System.IO.DriveInfo]::new($drive)
    $availableSpace = $driveInfo.AvailableFreeSpace
    if ($availableSpace -lt $requiredSpace) {
        Write-Host "⚠ Warning: Only $($availableSpace / 1GB)GB available, need ~3.5GB" -ForegroundColor Yellow
        $proceed = Read-Host "Proceed anyway? (y/n)"
        if ($proceed -ne "y") { return }
    }

    # Load repositories
    $Repositories = Load-Configuration -ConfigUrl $ConfigUrl

    # Repository selection
    Write-Host "Select repositories to download (enter numbers separated by spaces, or 'all'):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Repositories.Count; $i++) {
        Write-Host "$($i+1). $($Repositories[$i].Name)"
    }
    $selection = Read-Host "Your selection"
    if ($selection -eq "all") {
        $selectedRepos = $Repositories
    } else {
        $selectedIndices = $selection -split ' ' | ForEach-Object { [int]$_ - 1 }
        $selectedRepos = $Repositories[$selectedIndices]
    }
    if ($selectedRepos.Count -eq 0) {
        Write-Host "No repositories selected. Exiting." -ForegroundColor Red
        return
    }

    # Download logic
    $uniqueWallpapers = @{}
    $repoCount = $selectedRepos.Count
    $currentRepo = 0
    $totalWallpapers = 0
    $paused = $false

    foreach ($repo in $selectedRepos) {
        $currentRepo++
        Write-Host "[$currentRepo/$repoCount] Downloading $($repo.Name)..." -ForegroundColor Yellow
        $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        try {
            git clone --depth 1 --quiet --branch $repo.Branch $repo.Url $tempDir 2>$null
            $images = Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png, *.webp
            $totalImages = $images.Count
            $processedImages = 0

            foreach ($img in $images) {
                $processedImages++
                # Check for pause
                while ($paused) {
                    Write-Host "`nDownload paused. Press 'c' to continue, 's' to stop:" -ForegroundColor Yellow
                    $key = [Console]::ReadKey($true).KeyChar
                    switch ($key) {
                        'c' { $paused = $false; Write-Host "Resuming..." }
                        's' { Write-Host "`nDownload stopped." -ForegroundColor Red; Write-Host "💾 Total unique wallpapers downloaded: $totalWallpapers" -ForegroundColor Green; Remove-Item $tempDir -Recurse -Force; return }
                    }
                }

                try {
                    $image = [System.Drawing.Image]::FromFile($img.FullName)
                    if ($image.Width -ge $MinResolutionWidth -and $image.Height -ge $MinResolutionHeight) {
                        $hash = (Get-FileHash $img.FullName -Algorithm SHA256).Hash
                        if (-not $uniqueWallpapers.ContainsKey($hash)) {
                            $targetPath = Join-Path $SavePath "$($hash.Substring(0,16)).jpg"
                            & magick convert $img.FullName -strip -quality 95 $targetPath 2>$null
                            $uniqueWallpapers[$hash] = $targetPath
                            $totalWallpapers++
                        }
                    }
                    $image.Dispose()
                }
                catch { Write-Host "Error processing $($img.Name)" -ForegroundColor Red }

                # Check for pause input
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true).KeyChar
                    if ($key -eq 'p') {
                        $paused = $true
                        Write-Host "`nPausing download..." -ForegroundColor Yellow
                    }
                }
                Write-Progress -Activity "Processing $($repo.Name)" -Status "$processedImages of $totalImages" -PercentComplete (($processedImages / $totalImages) * 100)
            }
        }
        catch { Write-Host "Error downloading $($repo.Url): $_" -ForegroundColor Red }
        finally { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # Final report
    Write-Host "`n✅ Operation completed" -ForegroundColor Green
    Write-Host "💾 Total unique wallpapers downloaded: $totalWallpapers" -ForegroundColor Green
    Write-Host "📁 Location: $SavePath" -ForegroundColor Cyan
    Invoke-Item $SavePath
}

# Execute
try {
    Confirm-Dependencies
    if (-not $NoDownload) {
        Write-Host "`nPress 'p' to pause during download." -ForegroundColor Cyan
        Start-WallPimp
    }
}
catch {
    Write-Host "`n❌ Fatal error: $_" -ForegroundColor Red
    exit 1
}
