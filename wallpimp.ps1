#Requires -Version 5.0

# Enable verbose output and strict error handling for better debugging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Function to write timestamped log messages
function Write-Log {
    param($Message)
    Write-Verbose "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

# Display the application banner
function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.2              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# Animated spinner to show progress during long operations
function Show-Spinner {
    param (
        [int]$PID,
        [string]$Activity = "Processing"
    )
    try {
        $spinstr = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        while (Get-Process -Id $PID -ErrorAction SilentlyContinue) {
            foreach ($char in $spinstr.ToCharArray()) {
                Write-Host -NoNewline "`r$Activity [$char] "
                Start-Sleep -Milliseconds 100
            }
        }
        Write-Host -NoNewline "`r$Activity [✓] `n"
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

# Repository list
$WallpaperRepos = @(
    "https://github.com/dharmx/walls"
    "https://github.com/FrenzyExists/wallpapers"
    "https://github.com/Dreamer-Paul/Anime-Wallpaper"
    # Add more repositories as needed
)

# Verify Git is available and properly configured
function Test-GitAvailable {
    try {
        $gitVersion = git --version
        Write-Log "Git version: $gitVersion"
        return $true
    }
    catch {
        Write-Host "Error: Git is not installed or not in PATH. Please install Git first." -ForegroundColor Red
        return $false
    }
}

# Download a single repository with retry logic
function Download-Repo {
    param (
        [string]$Repo,
        [string]$TargetDir,
        [string]$TempPath
    )
    
    Write-Log "Starting download of repo: $Repo"
    
    try {
        Push-Location $TempPath
        
        $attempt = 1
        while ($attempt -le $MaxRetries) {
            try {
                Write-Log "Attempt $attempt of $MaxRetries"
                $output = git clone --depth 1 $Repo $TargetDir 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Successfully cloned $Repo"
                    return $true
                }
                Write-Log "Git clone failed with exit code $LASTEXITCODE: $output"
            }
            catch {
                Write-Log "Error during clone attempt $attempt: $_"
            }
            $attempt++
            if ($attempt -le $MaxRetries) {
                Start-Sleep -Seconds 2
            }
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Log "Failed to clone $Repo after $MaxRetries attempts"
    return $false
}

# Process and deduplicate downloaded files
function Process-Files {
    param (
        [string]$OutputDir,
        [string]$TempPath
    )
    
    Write-Log "Processing files from $TempPath to $OutputDir"
    $fileHashes = @{}
    $processedCount = 0
    
    foreach ($format in $SupportedFormats) {
        Write-Log "Searching for *.$format files"
        try {
            Get-ChildItem -Path $TempPath -Recurse -Filter "*.$format" -ErrorAction Stop | 
            ForEach-Object {
                try {
                    $file = $_.FullName
                    $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
                    
                    if (-not $fileHashes.ContainsKey($hash)) {
                        $fileName = $_.Name -replace '\s+', '_' -replace '[^A-Za-z0-9._-]', ''
                        $targetPath = Join-Path $OutputDir $fileName
                        
                        # Handle filename collisions
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
                        $processedCount++
                        Write-Log "Processed: $targetPath"
                    }
                }
                catch {
                    Write-Log "Error processing file $($_.Name): $_"
                }
            }
        }
        catch {
            Write-Log "Error searching for $format files: $_"
        }
    }
    
    return $processedCount
}

# Main execution function
function Main {
    try {
        Write-Log "Script started"
        
        # Verify Git installation
        if (-not (Test-GitAvailable)) {
            return
        }
        
        Show-Banner
        
        # Get output directory from user
        Write-Host "`nWallpaper save location [$DefaultOutputDir]: " -NoNewline
        $OutputDir = Read-Host
        if ([string]::IsNullOrWhiteSpace($OutputDir)) {
            $OutputDir = $DefaultOutputDir
        }
        Write-Log "Output directory set to: $OutputDir"
        
        # Create necessary directories
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        Write-Log "Created directories: Output=$OutputDir, Temp=$TempDir"
        
        Write-Host "`nDownloading wallpapers..."
        
        # Download and process repositories
        $failedRepos = 0
        foreach ($repo in $WallpaperRepos) {
            $repoName = [System.IO.Path]::GetFileNameWithoutExtension($repo)
            $targetDir = Join-Path $TempDir $repoName
            
            Write-Host "Downloading $repoName... " -NoNewline
            
            try {
                $scriptBlock = {
                    param($repo, $targetDir, $tempDir)
                    . $using:MyInvocation.MyCommand.Path
                    Download-Repo -Repo $repo -TargetDir $targetDir -TempPath $tempDir
                }
                
                $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $repo, $targetDir, $TempDir
                
                if ($job.State -eq 'Running') {
                    Show-Spinner -PID $job.ChildJobs[0].ProcessId -Activity "Downloading $repoName"
                }
                
                $result = Receive-Job -Job $job -Wait
                if (-not $result) {
                    Write-Host "Failed!" -ForegroundColor Red
                    $failedRepos++
                }
            }
            catch {
                Write-Log "Error downloading $repo: $_"
                Write-Host "Failed!" -ForegroundColor Red
                $failedRepos++
            }
            finally {
                if ($job) {
                    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        Write-Host "`nProcessing wallpapers..."
        $processedFiles = Process-Files -OutputDir $OutputDir -TempPath $TempDir
        
        # Cleanup
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up temporary directory"
        
        # Display results
        Write-Host "`n✓ Downloaded wallpapers: $processedFiles"
        Write-Host "✓ Save location: $OutputDir"
        if ($failedRepos -gt 0) {
            Write-Host "! Some repositories failed to download ($failedRepos)" -ForegroundColor Yellow
        }
        
        Write-Log "Script completed successfully"
    }
    catch {
        Write-Log "Fatal error in main function: $_"
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        Write-Host "`nPress Enter to exit..."
        Read-Host
    }
}

# Execute the script with comprehensive error handling
try {
    Main
}
catch {
    Write-Host "`nScript failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "`nPress Enter to exit..."
    Read-Host
}
