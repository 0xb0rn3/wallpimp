#Requires -Version 5.0

# Enable error handling similar to bash's set -e
$ErrorActionPreference = 'Stop'

function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.2              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# Enhanced spinner that more closely matches the bash version's behavior
function Show-Spinner {
    param (
        [int]$PID
    )
    $spinstr = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    $delay = 100  # Milliseconds
    
    # Continue while process exists, similar to bash ps check
    while (Get-Process -Id $PID -ErrorAction SilentlyContinue) {
        $spinstr = $spinstr[1..$spinstr.Length] + $spinstr[0]
        Write-Host -NoNewline (" [$($spinstr[0])] ")
        Start-Sleep -Milliseconds $delay
        Write-Host -NoNewline "`b`b`b`b`b`b"
    }
    Write-Host -NoNewline "    `b`b`b`b"
}

# Repository list remains the same
$WallpaperRepos = @(
    "https://github.com/dharmx/walls",
    "https://github.com/FrenzyExists/wallpapers"
    "https://github.com/Dreamer-Paul/Anime-Wallpaper"
    "https://github.com/michaelScopic/Wallpapers"
    "https://github.com/ryan4yin/wallpapers"
    "https://github.com/HENTAI-CODER/Anime-Wallpaper"
    "https://github.com/port19x/Wallpapers"
    "https://github.com/k1ng440/Wallpapers"
    "https://github.com/vimfn/walls"
    "https://github.com/expandpi/wallpapers"
    "https://github.com/polluxau/linuxnext-wallpapers"
    "https://github.com/port19x/Wallpapers"
    "https://github.com/k1ng440/Wallpapers"
    "https://github.com/HENTAI-CODER/Anime-Wallpaper"
    "https://github.com/rubenswebdev/wallpapers"
    "https://github.com/vimfn/walls"
    "https://github.com/IcePocket/Wallpapers"
    "https://github.com/expandpi/wallpapers"
    "https://github.com/logicyugi/Backgrounds"
    "https://github.com/PlannerPlus/Anime-Wallpapers"
    "https://github.com/Samyc2002/Anime-Wallpapers"
    "https://github.com/KaikSelhorst/WallpaperPack"
    "https://github.com/erickmartin890/Anime-Wallpapers"
    "https://github.com/Motif23/Wallpapers-Anime"
    "https://github.com/TherryHilaire/anime"
    "https://github.com/anmac/Wallpapers"
    "https://github.com/Fuj3l/Wallpaper"
    "https://github.com/Aluize/animewallpapers"
)

# Configuration variables, matching bash script style
$SupportedFormats = @("img", "jpg", "jpeg", "png", "gif", "webp")
$MaxRetries = 3
$TempDir = Join-Path $env:TEMP "wallpimp_$([System.Guid]::NewGuid().Guid)"
$DefaultOutputDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"

function Download-Repo {
    param (
        [string]$Repo,
        [string]$TargetDir
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            # Redirect both stdout and stderr to null, matching bash behavior
            $null = git clone --depth 1 $Repo $TargetDir 2>&1
            return $true
        } catch {
            $attempt++
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

# Enhanced file processing to better match bash version's behavior
function Process-Files {
    param (
        [string]$OutputDir
    )
    
    $fileHashes = @{}
    
    foreach ($format in $SupportedFormats) {
        # Using Get-ChildItem with -Recurse for similar functionality to find
        Get-ChildItem -Path $TempDir -Recurse -Filter "*.$format" | ForEach-Object {
            $file = $_.FullName
            $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
            
            if (-not $fileHashes.ContainsKey($hash)) {
                $fileName = $_.Name -replace '\s+', '_' -replace '[^A-Za-z0-9._-]', ''
                $targetPath = Join-Path $OutputDir $fileName
                
                # Handle filename collisions more similarly to bash version
                if (Test-Path $targetPath) {
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                    $ext = [System.IO.Path]::GetExtension($fileName)
                    $counter = 1
                    
                    while (Test-Path $targetPath) {
                        $targetPath = Join-Path $OutputDir "${baseName}_${counter}${ext}"
                        $counter++
                    }
                }
                
                Copy-Item -Path $file -Destination $targetPath
                $fileHashes[$hash] = $targetPath
            }
        }
    }
}

function Main {
    Show-Banner
    
    # Get output directory with same prompt style as bash version
    Write-Host "`nWallpaper save location [$DefaultOutputDir]: " -NoNewline
    $OutputDir = Read-Host
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = $DefaultOutputDir
    }
    
    # Create directories
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    
    Write-Host "`nDownloading wallpapers..."
    
    # Download repositories with improved parallel processing
    $failedRepos = 0
    foreach ($repo in $WallpaperRepos) {
        $targetDir = Join-Path $TempDir ([System.IO.Path]::GetFileNameWithoutExtension($repo))
        
        # Using jobs for parallel processing, similar to bash background processes
        $job = Start-Job -ScriptBlock {
            param ($repo, $targetDir)
            . $using:MyInvocation.MyCommand.Path  # Import functions
            Download-Repo -Repo $repo -TargetDir $targetDir
        } -ArgumentList $repo, $targetDir
        
        Show-Spinner -PID $job.ChildJobs[0].ProcessId
        
        if (-not (Receive-Job -Job $job -Wait)) {
            $failedRepos++
        }
        Remove-Job -Job $job -Force
    }
    
    Write-Host "`nProcessing wallpapers..."
    $processJob = Start-Job -ScriptBlock {
        param($OutputDir, $TempDir, $SupportedFormats)
        . $using:MyInvocation.MyCommand.Path
        Process-Files -OutputDir $OutputDir
    } -ArgumentList $OutputDir, $TempDir, $SupportedFormats
    
    Show-Spinner -PID $processJob.ChildJobs[0].ProcessId
    Receive-Job -Job $processJob -Wait
    Remove-Job -Job $processJob -Force
    
    # Cleanup
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    # Final status report
    $totalFiles = (Get-ChildItem -Path $OutputDir -File -Recurse).Count
    Write-Host "`n✓ Downloaded wallpapers: $totalFiles"
    Write-Host "✓ Save location: $OutputDir"
    if ($failedRepos -gt 0) {
        Write-Host "! Some repositories failed to download ($failedRepos)" -ForegroundColor Yellow
    }
}

# Run main function
Main
