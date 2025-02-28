# WallPimp - Intelligent Wallpaper Collector
# Version 0.1
# Developer: 0xB0RN3

param (
    [string]$ConfigUrl = "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/config.ini",
    [switch]$NoDownload = $false,
    [int]$MinResolutionWidth = 1920,
    [int]$MinResolutionHeight = 1080,
    [int]$MaxParallelRepos = 3
)

# Load configuration from URL
function Load-Configuration {
    param([string]$ConfigUrl)
    try {
        $configContent = Invoke-WebRequest -Uri $ConfigUrl -ErrorAction Stop
        $repositories = @()
        $configContent.Content -split '\r?\n' | Where-Object { $_ -match '^\s*([^=\s]+)\s*=\s*(.+)$' } | ForEach-Object {
            $parts = $matches[2] -split '\|'
            if ($parts.Length -ge 3) {
                $repositories += @{ Icon = $parts[0].Trim(); Url = $parts[1].Trim(); Branch = $parts[2].Trim(); Description = $parts[3].Trim() }
            }
        }
        return $repositories
    }
    catch {
        Write-Host "Failed to load config. Using defaults." -ForegroundColor Yellow
        return @(
            @{ Icon = "🖼️"; Url = "https://github.com/dharmx/walls"; Branch = "main"; Description = "Clean minimalist designs" },
            @{ Icon = "🌸"; Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Branch = "main"; Description = "Anime & manga artwork" }
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
    # Note: ImageMagick installation is manual due to PowerShell’s reliance on System.Drawing
}

# Main function
function Start-WallPimp {
    $banner = @"
    ██╗    ██╗ █████╗ ██╗     ██╗     ██████╗ ██╗███╗   ███╗██████╗ 
    ██║    ██║██╔══██╗██║     ██║     ██╔══██╗██║████╗ ████║██╔══██╗
    ██║ █╗ ██║███████║██║     ██║     ██████╔╝██║██╔████╔██║██████╔╝
    ██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ 
    ╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║██║ ╚═╝ ██║██║     
     ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     
                    
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
    Write-Host "Select repositories to download (enter numbers separated by spaces, e.g., '1 3 5'):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Repositories.Count; $i++) {
        Write-Host "$($i+1). $($Repositories[$i].Icon) $($Repositories[$i].Description)"
    }
    $selection = Read-Host "Your selection"
    $selectedIndices = $selection -split ' ' | ForEach-Object { [int]$_ - 1 }
    $selectedRepos = $Repositories[$selectedIndices]
    if ($selectedRepos.Count -eq 0) {
        Write-Host "No repositories selected. Exiting." -ForegroundColor Red
        return
    }

    # Download logic
    $uniqueWallpapers = @{}
    $repoCount = $selectedRepos.Count
    $currentRepo = 0

    foreach ($repo in $selectedRepos) {
        $currentRepo++
        Write-Host "[$currentRepo/$repoCount] Downloading $($repo.Description)..." -ForegroundColor Yellow
        $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        try {
            git clone --depth 1 --quiet --branch $repo.Branch $repo.Url $tempDir 2>$null
            $images = Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png, *.webp
            $totalImages = $images.Count
            $processedImages = 0

            foreach ($img in $images) {
                $processedImages++
                try {
                    $image = [System.Drawing.Image]::FromFile($img.FullName)
                    if ($image.Width -ge $MinResolutionWidth -and $image.Height -ge $MinResolutionHeight) {
                        $hash = (Get-FileHash $img.FullName -Algorithm SHA256).Hash
                        if (-not $uniqueWallpapers.ContainsKey($hash)) {
                            $targetPath = Join-Path $SavePath "$($hash.Substring(0,16)).jpg"
                            & magick convert $img.FullName -strip -quality 95 $targetPath 2>$null
                            $uniqueWallpapers[$hash] = $targetPath
                        }
                    }
                    $image.Dispose()
                }
                catch { Write-Host "Error processing $($img.Name)" -ForegroundColor Red }
                Write-Progress -Activity "Processing $($repo.Description)" -Status "$processedImages of $totalImages" -PercentComplete (($processedImages / $totalImages) * 100)
            }
        }
        catch { Write-Host "Error downloading $($repo.Url): $_" -ForegroundColor Red }
        finally { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # Final report
    Write-Host "`n✅ Operation completed" -ForegroundColor Green
    Write-Host "💾 Saved $($uniqueWallpapers.Count) unique wallpapers" -ForegroundColor Green
    Write-Host "📁 Location: $SavePath" -ForegroundColor Cyan
    Invoke-Item $SavePath
}

# Execute
try {
    Confirm-Dependencies
    if (-not $NoDownload) { Start-WallPimp }
}
catch {
    Write-Host "`n❌ Fatal error: $_" -ForegroundColor Red
    exit 1
}
