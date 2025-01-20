# WallPimp PowerShell Edition
# Requires PowerShell 5.0 or higher and Git for Windows

# Ensure we stop on errors but don't exit immediately
$ErrorActionPreference = "Stop"

# Repository list
$Repos = @(
    "https://github.com/dharmx/walls",
    "https://github.com/FrenzyExists/wallpapers",
    "https://github.com/Dreamer-Paul/Anime-Wallpaper",
    "https://github.com/michaelScopic/Wallpapers",
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

# Improved loader function that maintains script execution
function Show-Loader {
    param (
        [string]$Message,
        [scriptblock]$ScriptBlock
    )
    
    $symbols = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    $job = Start-Job -ScriptBlock $ScriptBlock
    
    $spinIndex = 0
    Write-Host "$Message " -NoNewline
    
    do {
        $symbol = $symbols[$spinIndex]
        Write-Host "`r$Message [$symbol]" -NoNewline
        Start-Sleep -Milliseconds 100
        $spinIndex = ($spinIndex + 1) % $symbols.Length
        $jobStatus = $job.State
    } while ($jobStatus -eq "Running")
    
    # Ensure we get the job result before cleaning up
    $result = Receive-Job -Job $job -Wait
    Remove-Job -Job $job -Force
    
    if ($job.State -eq "Completed") {
        Write-Host "`r$Message [✓]"
    } else {
        Write-Host "`r$Message [✗]"
    }
    
    return $result
}

# Improved repository download function
function Get-Repository {
    param (
        [string]$RepoUrl,
        [string]$TargetPath,
        [int]$MaxRetries = 3
    )
    
    $retry = 0
    while ($retry -lt $MaxRetries) {
        try {
            # Use Start-Process to ensure Git execution completes
            $processInfo = Start-Process -FilePath "git" -ArgumentList @(
                "clone",
                "--depth", "1",
                $RepoUrl,
                $TargetPath
            ) -NoNewWindow -Wait -PassThru
            
            if ($processInfo.ExitCode -eq 0) {
                return $true
            }
        }
        catch {
            Write-Verbose "Download attempt $($retry + 1) failed: $_"
        }
        
        $retry++
        if ($retry -lt $MaxRetries) {
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

# Main function with improved error handling
function Start-WallpaperDownload {
    try {
        Clear-Host
        Write-Host "╔═══════════════════════════════════════╗"
        Write-Host "║         WallPimp Ver:0.4              ║"
        Write-Host "║    Wallpaper Download Assistant       ║"
        Write-Host "╚═══════════════════════════════════════╝"
        
        # Set up directories with error checking
        $defaultDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
        Write-Host "`nWhere would you like to save wallpapers? [$defaultDir]: " -NoNewline
        $saveDir = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($saveDir)) {
            $saveDir = $defaultDir
        }
        
        # Create directories with verification
        $tempDir = Join-Path $env:TEMP "wallpaper_download_$([Guid]::NewGuid().ToString())"
        
        if (-not (Test-Path $saveDir)) {
            New-Item -ItemType Directory -Force -Path $saveDir | Out-Null
            Write-Host "Created directory: $saveDir"
        }
        
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        }
        
        $successful = 0
        $failed = 0
        
        Write-Host "`nStarting downloads...`n"
        
        # Download repositories with improved state management
        foreach ($repo in $Repos) {
            $repoName = Split-Path $repo -Leaf
            Write-Host "Pinging server for $repoName... " -NoNewline
            
            # Test connection with timeout
            $connectionTest = {
                param($repo)
                try {
                    $null = git ls-remote $repo 2>&1
                    return $true
                }
                catch {
                    return $false
                }
            }
            
            $connected = Show-Loader -Message "Checking connection for $repoName" -ScriptBlock {
                param($repo)
                & $using:connectionTest $repo
            } -ArgumentList $repo
            
            if (-not $connected) {
                Write-Host "`rServer check failed for $repoName [✗]"
                $failed++
                continue
            }
            
            $targetPath = Join-Path $tempDir $repoName
            
            # Download with state preservation
            $downloadBlock = {
                param($repo, $target)
                Get-Repository -RepoUrl $repo -TargetPath $target
            }
            
            $downloadSuccess = Show-Loader -Message "Downloading $repoName" -ScriptBlock {
                param($repo, $target)
                & $using:downloadBlock $repo $target
            } -ArgumentList $repo, $targetPath
            
            if ($downloadSuccess) {
                $successful++
            }
            else {
                $failed++
            }
        }
        
        # Process files with progress tracking
        Write-Host "`nProcessing wallpapers..."
        
        $totalProcessed = 0
        $duplicates = 0
        $extensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp")
        
        # Get all files and show progress
        $files = Get-ChildItem -Path $tempDir -Recurse -Include $extensions
        $fileCount = $files.Count
        
        foreach ($file in $files) {
            $totalProcessed++
            Write-Progress -Activity "Processing Files" -Status "$totalProcessed of $fileCount" -PercentComplete (($totalProcessed / $fileCount) * 100)
            
            $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash.ToLower()
            $newFileName = "${hash}_$($file.Name)"
            $targetPath = Join-Path $saveDir $newFileName
            
            if (-not (Test-Path $targetPath)) {
                Copy-Item -Path $file.FullName -Destination $targetPath -Force
            }
            else {
                $duplicates++
            }
        }
        
        Write-Progress -Activity "Processing Files" -Completed
        
        # Cleanup with verification
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Show final summary
        Write-Host "`nDownload Summary:"
        Write-Host "✓ Successfully downloaded: $successful repositories"
        Write-Host "✗ Failed downloads: $failed repositories"
        Write-Host "✓ Total wallpapers processed: $totalProcessed"
        Write-Host "✓ Duplicates skipped: $duplicates"
        Write-Host "✓ Wallpapers saved to: $saveDir"
        
        # Keep window open
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        Write-Host "`nAn error occurred: $_" -ForegroundColor Red
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Verify Git installation
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is not installed or not in PATH. Please install Git for Windows first."
    Write-Host "You can download it from: https://git-scm.com/download/win"
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Run the script with error handling
try {
    Start-WallpaperDownload
}
catch {
    Write-Host "`nA critical error occurred: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
