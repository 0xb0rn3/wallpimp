# WallPimp - Advanced Wallpaper Collection Script
# Version 2.0
# Enhanced with better error handling and performance

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
$ProgressPreference = 'SilentlyContinue'
$env:GIT_TERMINAL_PROMPT = 0
$env:GCM_INTERACTIVE = 'Never'

# Image Processing Configuration
Add-Type -AssemblyName System.Drawing
$validExtensions = @('.jpg', '.jpeg', '.png', '.bmp', '.webp')

class WallpaperProcessor {
    [string]$SavePath
    [int]$MinWidth
    [int]$MinHeight
    [hashtable]$Stats
    [System.Collections.Concurrent.ConcurrentDictionary[string,int]]$Hashes

    WallpaperProcessor([string]$path, [int]$w, [int]$h) {
        $this.SavePath = $path
        $this.MinWidth = $w
        $this.MinHeight = $h
        $this.Stats = @{
            Processed = 0
            Saved = 0
            Errors = 0
        }
        $this.Hashes = [System.Collections.Concurrent.ConcurrentDictionary[string,int]]::new()
    }

    [void] ProcessImage([string]$path) {
        try {
            $this.Stats.Processed++
            
            $extension = [System.IO.Path]::GetExtension($path).ToLower()
            if ($extension -eq '.svg') { return }  # Skip vector graphics
            
            $img = [System.Drawing.Image]::FromFile($path)
            if ($img.Width -ge $this.MinWidth -and $img.Height -ge $this.MinHeight) {
                $hash = (Get-FileHash -Path $path -Algorithm SHA256).Hash
                
                if ($this.Hashes.TryAdd($hash, 1)) {
                    $dest = Join-Path $this.SavePath "$hash$extension"
                    Copy-Item -Path $path -Destination $dest -Force
                    $this.Stats.Saved++
                }
            }
            $img.Dispose()
        }
        catch {
            $this.Stats.Errors++
            Write-EnhancedLog "Error processing $path : $_" -Color Red -Level Verbose
        }
    }
}

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
    $logEntry = "[$timestamp] $Message"
    
    Write-Host $logEntry -ForegroundColor $Color
    $logEntry | Out-File -Append -FilePath (Join-Path $SavePath "wallpimp.log")
}

function Initialize-Environment {
    param($path)
    
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required but not found. Install from https://git-scm.com/"
    }
}

function Get-Repositories {
    @(
        "https://github.com/dharmx/walls",
        "https://github.com/linuxdotexe/wallpapers",
        "https://github.com/D3Ext/aesthetic-wallpapers",
        "https://github.com/notlmn/wallpapers"
    ) | Where-Object { $_ -notin $ExcludeRepositories }
}

function Invoke-RepositoryProcessing {
    param(
        [string]$repoUrl,
        [WallpaperProcessor]$processor
    )
    
    $tempDir = Join-Path $env:TEMP "wallpimp-$(Get-Random)"
    try {
        git clone --depth 1 --quiet $repoUrl $tempDir 2>$null
        
        Get-ChildItem -Path $tempDir -Recurse -Include $validExtensions | ForEach-Object {
            $processor.ProcessImage($_.FullName)
        }
    }
    catch {
        Write-EnhancedLog "Failed to process $repoUrl : $_" -Color Red
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-WallPimp {
    Write-Host @"
╔════════════════════════════════════╗
║        WallPimp Ver:2.0            ║
║   Next-Gen Wallpaper Collector     ║
╚════════════════════════════════════╝
"@ -ForegroundColor Cyan

    try {
        Initialize-Environment $SavePath
        
        $processor = [WallpaperProcessor]::new(
            $SavePath,
            $MinResolutionWidth,
            $MinResolutionHeight
        )
        
        $repos = Get-Repositories
        
        $repos | ForEach-Object -Parallel {
            $repo = $_
            $processor = $using:processor
            
            try {
                Invoke-RepositoryProcessing $repo $processor
            }
            catch {
                Write-EnhancedLog "Parallel processing error: $_" -Color Red
            }
        } -ThrottleLimit $MaxParallelRepos

        Write-Host @"
╔═════════ Collection Summary ═════════╗
║ Total Processed: $($processor.Stats.Processed)
║ High-Quality Saved: $($processor.Stats.Saved)
║ Errors Encountered: $($processor.Stats.Errors)
║ Unique Wallpapers: $($processor.Hashes.Count)
╚══════════════════════════════════════╝
"@ -ForegroundColor Green

        Invoke-Item $SavePath
    }
    catch {
        Write-EnhancedLog "Fatal error: $_" -Color Red
        exit 1
    }
}

# Main execution
if (-not $NoDownload) {
    Start-WallPimp
}
