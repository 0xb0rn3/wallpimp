# WallPimp - Intelligent Wallpaper Collector
# Version 2.4
# Developer: 0xB0RN3

param (
    [string]$ConfigUrl = "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/config.ini",
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

# Enhanced Configuration Loader
function Load-Configuration {
    [CmdletBinding()]
    param(
        [string]$ConfigUrl
    )

    try {
        # Attempt to download configuration
        $configContent = Invoke-WebRequest -Uri $ConfigUrl -ErrorAction Stop
        $repositories = @()

        # Parse INI-like configuration
        $configContent.Content -split '\r?\n' | Where-Object { $_ -match '^\s*([^=\s]+)\s*=\s*(.+)$' } | ForEach-Object {
            $parts = $matches[2] -split '\|'
            if ($parts.Length -ge 3) {
                $repositories += @{
                    Url = $parts[1].Trim()
                    Description = $parts[2].Trim()
                    Icon = $parts[0].Trim()
                }
            }
        }

        return $repositories
    }
    catch {
        Write-Warning "Failed to load remote configuration. Falling back to default repositories."
        return @(
            @{ Url = "https://github.com/dharmx/walls"; Description = "Minimalist designs" },
            @{ Url = "https://github.com/HENTAI-CODER/Anime-Wallpaper"; Description = "Anime collection" },
            @{ Url = "https://github.com/FrenzyExists/wallpapers"; Description = "Nature/abstract" }
        )
    }
}

# Security and Dependency Check
function Confirm-Dependencies {
    # Check for Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "🔧 Git not found. Attempting installation..." -ForegroundColor Yellow
        try {
            # Cross-platform Git installation attempt
            if ($IsWindows -or $env:OS) {
                winget install --id Git.Git -e
            }
            elseif ($IsLinux) {
                sudo apt-get update
                sudo apt-get install -y git
            }
            elseif ($IsMacOS) {
                brew install git
            }
            else {
                throw "Unsupported platform"
            }
        }
        catch {
            Write-Host "❌ Automatic Git installation failed. Please install Git manually." -ForegroundColor Red
            exit 1
        }
    }

    # Recommend PowerShell 7
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "⚠️ Recommended: Upgrade to PowerShell 7 for enhanced performance" -ForegroundColor Yellow
        Write-Host "   Install via: winget install Microsoft.PowerShell" -ForegroundColor Cyan
    }
}

# Primary Execution Function
function Start-WallPimp {
    # Banner and Initialization
    $banner = @"
╔══════════════════════════════════════════╗
║ ██╗    ██╗ █████╗ ██╗     ██╗  ██╗██████╗ ║
║ ██║    ██║██╔══██╗██║     ██║ ██╔╝██╔══██╗║
║ ██║ █╗ ██║███████║██║     █████╔╝ ██████╔╝║
║ ██║███╗██║██╔══██║██║     ██╔═██╗ ██╔═══╝ ║
║ ╚███╔███╔╝██║  ██║███████╗██║  ██╗██║     ║
║  ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ║
╠══════════════════════════════════════════╣
║          WallPimp v2.4 | 0xb0rn3         ║
╚══════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor Magenta

    # Repository Loading
    $Repositories = Load-Configuration -ConfigUrl $ConfigUrl
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
    $filteredRepos = $Repositories | Where-Object { $_.Url -notin $ExcludeRepositories }
    $repoCount = $filteredRepos.Count

    # Assign index to each repository
    $indexedRepos = $filteredRepos | ForEach-Object -Begin { $i = 1 } -Process {
        $_ | Add-Member -NotePropertyName 'Index' -NotePropertyValue $i++
        $_
    }

    if ($isPwsh7) {
        # PowerShell 7 Optimized Parallel Download
        $indexedRepos | ForEach-Object -Parallel {
            $repo = $_
            Write-EnhancedLog "[$($repo.Index)/$($using:repoCount)] Downloading $($repo.Description)" -Color Yellow

            $tempDir = Join-Path $env:TEMP "wallpimp-$(New-Guid)"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            
            try {
                git clone --depth 1 --quiet $repo.Url $tempDir 2>$null
                Get-ChildItem $tempDir -Recurse -Include *.jpg, *.jpeg, *.png | ForEach-Object {
                    try {
                        $image = [System.Drawing.Image]::FromFile($_.FullName)
                        if ($image.Width -ge $using:MinResolutionWidth -and $image.Height -ge $using:MinResolutionHeight) {
                            $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
                            $uniqueWallpapers = $using:uniqueWallpapers

                            $lock = [System.Threading.Mutex]::new($false, "WallpaperLock")
                            $lock.WaitOne() | Out-Null
                            try {
                                if (-not $uniqueWallpapers.ContainsKey($hash)) {
                                    $targetPath = Join-Path $using:SavePath "$hash$($_.Extension)"
                                    Copy-Item $_.FullName $targetPath -Force
                                    $uniqueWallpapers[$hash] = $targetPath
                                }
                            }
                            finally {
                                $lock.ReleaseMutex()
                                $lock.Dispose()
                            }
                        }
                        $image.Dispose()
                    }
                    catch { Write-EnhancedLog "Error processing $($_.Name)" -Color Red }
                }
            }
            catch { Write-EnhancedLog "Error processing $($repo.Url) : $_" -Color Red }
            finally { Remove-Item $tempDir -Recurse -Force }
        } -ThrottleLimit $using:MaxParallelRepos
    }
    else {
        # Windows PowerShell Sequential Download
        foreach ($repo in $filteredRepos) {
            try {
                Write-EnhancedLog "[$($repo.Index)/$repoCount] Downloading $($repo.Description)" -Color Yellow
                
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
    Confirm-Dependencies
    if (-not $NoDownload) { Start-WallPimp }
}
catch {
    Write-Host "`n❌ Fatal error: $_" -ForegroundColor Red
    exit 1
}
