# WallPimp PowerShell Edition
# Requires PowerShell 5.0 or higher and Git for Windows

# Error handling preferences
$ErrorActionPreference = "Stop"

# Repository list - same as bash version
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

# Show animated loader with message
function Show-Loader {
    param (
        [string]$Message,
        [scriptblock]$ScriptBlock
    )
    
    $symbols = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    $job = Start-Job -ScriptBlock $ScriptBlock
    
    Write-Host "$Message " -NoNewline
    
    while ($job.State -eq "Running") {
        foreach ($symbol in $symbols) {
            Write-Host "`r$Message [$symbol]" -NoNewline
            Start-Sleep -Milliseconds 100
        }
    }
    
    $result = Receive-Job -Job $job
    Remove-Job -Job $job
    
    Write-Host "`r$Message [✓]"
    return $result
}

# Download repository with retry mechanism
function Get-Repository {
    param (
        [string]$RepoUrl,
        [string]$TargetPath,
        [int]$MaxRetries = 3
    )
    
    $retry = 0
    while ($retry -lt $MaxRetries) {
        try {
            git clone --depth 1 $RepoUrl $TargetPath 2>&1 | Out-Null
            return $true
        }
        catch {
            $retry++
            if ($retry -lt $MaxRetries) {
                Write-Host "`rRetrying download... (Attempt $($retry + 1)/$MaxRetries)" -NoNewline
                Start-Sleep -Seconds 2
            }
        }
    }
    return $false
}

# Calculate file hash
function Get-Sha256Hash {
    param ([string]$FilePath)
    
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# Main function
function Start-WallpaperDownload {
    # Clear screen and show banner
    Clear-Host
    Write-Host "╔═══════════════════════════════════════╗"
    Write-Host "║         WallPimp Ver:0.4              ║"
    Write-Host "║    Wallpaper Download Assistant       ║"
    Write-Host "╚═══════════════════════════════════════╝"
    
    # Set up directories
    $defaultDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
    Write-Host "`nWhere would you like to save wallpapers? [$defaultDir]: " -NoNewline
    $saveDir = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($saveDir)) {
        $saveDir = $defaultDir
    }
    
    # Create temporary and save directories
    $tempDir = Join-Path $env:TEMP "wallpaper_download_$([Guid]::NewGuid().ToString())"
    New-Item -ItemType Directory -Force -Path $saveDir | Out-Null
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Download repositories
    $successful = 0
    $failed = 0
    
    Write-Host "`nStarting downloads...`n"
    
    foreach ($repo in $Repos) {
        $repoName = Split-Path $repo -Leaf
        Write-Host "Pinging server for $repoName... " -NoNewline
        
        # Test server connection
        try {
            git ls-remote $repo 2>&1 | Out-Null
            Write-Host "`rServer connection successful for $repoName [✓]"
        }
        catch {
            Write-Host "`rServer check failed for $repoName [✗]"
            $failed++
            continue
        }
        
        # Download repository
        $targetPath = Join-Path $tempDir $repoName
        Write-Host "Downloading $repoName... " -NoNewline
        
        $downloadResult = Show-Loader -Message "Downloading $repoName" -ScriptBlock {
            param($repo, $target)
            Get-Repository -RepoUrl $repo -TargetPath $target
        } -ArgumentList $repo, $targetPath
        
        if ($downloadResult) {
            $successful++
        }
        else {
            Write-Host "`rDownload failed for $repoName [✗]"
            $failed++
        }
    }
    
    # Process and deduplicate wallpapers
    Write-Host "`nProcessing wallpapers..."
    
    $totalProcessed = 0
    $duplicates = 0
    $extensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp")
    
    # Get all image files
    $files = Get-ChildItem -Path $tempDir -Recurse -Include $extensions
    
    foreach ($file in $files) {
        $hash = Get-Sha256Hash -FilePath $file.FullName
        $newFileName = "${hash}_$($file.Name)"
        $targetPath = Join-Path $saveDir $newFileName
        
        # Check if file with same hash exists
        $existingFile = Get-ChildItem -Path $saveDir -File | Where-Object {
            (Get-Sha256Hash -FilePath $_.FullName) -eq $hash
        }
        
        if (-not $existingFile) {
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            $totalProcessed++
            Write-Host "`rProcessed: $totalProcessed files" -NoNewline
        }
        else {
            $duplicates++
        }
    }
    
    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    # Show final summary
    Write-Host "`n`nDownload Summary:"
    Write-Host "✓ Successfully downloaded: $successful repositories"
    Write-Host "✗ Failed downloads: $failed repositories"
    Write-Host "✓ Total wallpapers processed: $totalProcessed"
    Write-Host "✓ Duplicates skipped: $duplicates"
    Write-Host "✓ Wallpapers saved to: $saveDir"
}

# Check for Git installation
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is not installed or not in PATH. Please install Git for Windows first."
    Write-Host "You can download it from: https://git-scm.com/download/win"
    exit 1
}

# Run the script
try {
    Start-WallpaperDownload
}
catch {
    Write-Host "`nAn error occurred: $_"
    exit 1
}
