#Requires -Version 5.0

# Enable verbose output for debugging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Add logging function to help us track script execution
function Write-Log {
    param($Message)
    Write-Verbose "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.2              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

function Show-Spinner {
    param (
        [int]$PID
    )
    try {
        $spinstr = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        $delay = 100
        
        while (Get-Process -Id $PID -ErrorAction SilentlyContinue) {
            foreach ($char in $spinstr.ToCharArray()) {
                Write-Host -NoNewline (" [$char] ")
                Start-Sleep -Milliseconds $delay
                Write-Host -NoNewline "`b`b`b`b`b`b"
            }
        }
        Write-Host -NoNewline "    `b`b`b`b"
    }
    catch {
        Write-Log "Spinner error: $_"
    }
}

# Configuration variables
$SupportedFormats = @("img", "jpg", "jpeg", "png", "gif", "webp")
$MaxRetries = 3
$TempDir = Join-Path $env:TEMP "wallpimp_$([System.Guid]::NewGuid().Guid)"
$DefaultOutputDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
$WallpaperRepos = @(
    "https://github.com/dharmx/walls"
    "https://github.com/FrenzyExists/wallpapers"
    "https://github.com/Dreamer-Paul/Anime-Wallpaper"
)

function Test-GitAvailable {
    try {
        $null = git --version
        return $true
    }
    catch {
        Write-Host "Git is not installed or not in PATH. Please install Git first." -ForegroundColor Red
        return $false
    }
}

function Download-Repo {
    param (
        [string]$Repo,
        [string]$TargetDir
    )
    
    Write-Log "Attempting to download repo: $Repo to $TargetDir"
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Download attempt $attempt of $MaxRetries"
            git clone --depth 1 $Repo $TargetDir 2>&1 | Write-Log
            Write-Log "Download successful"
            return $true
        }
        catch {
            Write-Log "Download attempt $attempt failed: $_"
            $attempt++
            Start-Sleep -Seconds 2
        }
    }
    Write-Log "All download attempts failed for $Repo"
    return $false
}

function Process-Files {
    param (
        [string]$OutputDir
    )
    
    Write-Log "Starting file processing. Output directory: $OutputDir"
    $fileHashes = @{}
    
    foreach ($format in $SupportedFormats) {
        Write-Log "Processing files with format: $format"
        try {
            Get-ChildItem -Path $TempDir -Recurse -Filter "*.$format" -ErrorAction Stop | 
            ForEach-Object {
                try {
                    $file = $_.FullName
                    Write-Log "Processing file: $file"
                    
                    $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
                    if (-not $fileHashes.ContainsKey($hash)) {
                        $fileName = $_.Name -replace '\s+', '_' -replace '[^A-Za-z0-9._-]', ''
                        $targetPath = Join-Path $OutputDir $fileName
                        
                        if (Test-Path $targetPath) {
                            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                            $ext = [System.IO.Path]::GetExtension($fileName)
                            $counter = 1
                            
                            while (Test-Path $targetPath) {
                                $targetPath = Join-Path $OutputDir "${baseName}_${counter}${ext}"
                                $counter++
                            }
                        }
                        
                        Copy-Item -Path $file -Destination $targetPath -ErrorAction Stop
                        $fileHashes[$hash] = $targetPath
                        Write-Log "Successfully copied file to: $targetPath"
                    }
                }
                catch {
                    Write-Log "Error processing individual file: $_"
                }
            }
        }
        catch {
            Write-Log "Error processing format $format: $_"
        }
    }
}

function Main {
    try {
        Write-Log "Script started"
        
        # Check if Git is available
        if (-not (Test-GitAvailable)) {
            return
        }
        
        Show-Banner
        Write-Log "Banner displayed"
        
        Write-Host "`nWallpaper save location [$DefaultOutputDir]: " -NoNewline
        $OutputDir = Read-Host
        if ([string]::IsNullOrWhiteSpace($OutputDir)) {
            $OutputDir = $DefaultOutputDir
        }
        Write-Log "Output directory set to: $OutputDir"
        
        # Create directories
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        Write-Log "Directories created: Output=$OutputDir, Temp=$TempDir"
        
        Write-Host "`nDownloading wallpapers..."
        
        $failedRepos = 0
        foreach ($repo in $WallpaperRepos) {
            Write-Log "Processing repository: $repo"
            $targetDir = Join-Path $TempDir ([System.IO.Path]::GetFileNameWithoutExtension($repo))
            
            try {
                $scriptBlock = {
                    param($repo, $targetDir)
                    Set-Location $using:TempDir
                    git clone --depth 1 $repo $targetDir
                }
                
                $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $repo, $targetDir
                Show-Spinner -PID $job.ChildJobs[0].ProcessId
                
                $null = Wait-Job $job
                if ($job.State -eq 'Failed') {
                    Write-Log "Job failed for repo: $repo"
                    $failedRepos++
                }
            }
            catch {
                Write-Log "Error processing repo $repo: $_"
                $failedRepos++
            }
            finally {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "`nProcessing wallpapers..."
        Process-Files -OutputDir $OutputDir
        
        # Cleanup
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Temporary directory cleaned up"
        
        # Final status
        $totalFiles = (Get-ChildItem -Path $OutputDir -File -Recurse).Count
        Write-Host "`n✓ Downloaded wallpapers: $totalFiles"
        Write-Host "✓ Save location: $OutputDir"
        if ($failedRepos -gt 0) {
            Write-Host "! Some repositories failed to download ($failedRepos)" -ForegroundColor Yellow
        }
        
        Write-Log "Script completed successfully"
    }
    catch {
        Write-Log "Fatal error in main function: $_"
        Write-Host "An error occurred. Check the verbose output for details." -ForegroundColor Red
        throw
    }
}

# Run main function with error handling
try {
    Main
}
catch {
    Write-Host "Script failed: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
