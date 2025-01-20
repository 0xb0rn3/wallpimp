# WallPimp PowerShell Edition
# Requires PowerShell 5.1 or higher and Git for Windows

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration variables
$script:SupportedFormats = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp")
$script:MaxRetries = 3
$script:DefaultOutputDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
$script:OrganizedDirs = @("abstract", "anime", "nature", "minimal", "art", "other")
$script:TempDir = Join-Path $env:TEMP "wallpimp_$([System.Guid]::NewGuid().ToString())"

# Repository list - same as bash version
$script:WallpaperRepos = @(
    "https://github.com/dharmx/walls",
    "https://github.com/FrenzyExample/wallpapers",
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

# Function to show the banner
function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.3              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@
}

# Function to show a spinning progress indicator
function Show-SpinnerProgress {
    param(
        [string]$Activity,
        [int]$DurationMs = 100
    )
    
    $spinner = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    $i = 0
    
    Write-Host "`r$Activity " -NoNewline
    $spinner[$i]
    Start-Sleep -Milliseconds $DurationMs
    $i = ($i + 1) % $spinner.Length
    Write-Host "`r" -NoNewline
}

# Function to show progress bar
function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity
    )
    
    $percentComplete = [math]::Round(($Current / $Total) * 100)
    Write-Progress -Activity $Activity -Status "$percentComplete% Complete" -PercentComplete $percentComplete
}

# Function to create organized directory structure
function Initialize-DirectoryStructure {
    param([string]$BaseDir)
    
    foreach ($dir in $script:OrganizedDirs) {
        $path = Join-Path $BaseDir $dir
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

# Function to download repository with retries
function Get-Repository {
    param(
        [string]$RepoUrl,
        [string]$TargetDir
    )
    
    $attempt = 1
    while ($attempt -le $script:MaxRetries) {
        try {
            Write-Host "Downloading $(Split-Path $RepoUrl -Leaf) (Attempt $attempt/$script:MaxRetries)" -NoNewline
            git clone --depth 1 $RepoUrl $TargetDir 2>&1 | Out-Null
            Write-Host "`rDownload successful!                            "
            return $true
        }
        catch {
            Write-Host "`rRetrying..." -NoNewline
            $attempt++
            Start-Sleep -Seconds 2
        }
    }
    Write-Host "`rFailed to download repository                    "
    return $false
}

# Function to categorize wallpapers
function Get-WallpaperCategory {
    param([string]$FileName)
    
    $fileName = $FileName.ToLower()
    
    if ($fileName -match "(abstract|geometry|pattern)") { return "abstract" }
    elseif ($fileName -match "(anime|manga|character)") { return "anime" }
    elseif ($fileName -match "(nature|landscape|mountain|forest)") { return "nature" }
    elseif ($fileName -match "(minimal|simple|clean)") { return "minimal" }
    elseif ($fileName -match "(art|painting|digital)") { return "art" }
    else { return "other" }
}

# Function to process and organize files
function Process-Wallpapers {
    param([string]$OutputDir)
    
    $fileHashes = @{}
    $totalFiles = 0
    $processedFiles = 0
    
    # Count total files
    $script:SupportedFormats | ForEach-Object {
        $totalFiles += (Get-ChildItem -Path $script:TempDir -Recurse -Filter $_).Count
    }
    
    Write-Host "`nProcessing $totalFiles files..."
    
    # Process each file
    foreach ($format in $script:SupportedFormats) {
        Get-ChildItem -Path $script:TempDir -Recurse -Filter $format | ForEach-Object {
            $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            
            if (-not $fileHashes.ContainsKey($hash)) {
                $safeName = $_.Name -replace '[^\w\-\.]', '_'
                $category = Get-WallpaperCategory -FileName $safeName
                $targetPath = Join-Path $OutputDir $category $safeName
                
                # Handle filename collisions
                if (Test-Path $targetPath) {
                    $basename = [System.IO.Path]::GetFileNameWithoutExtension($safeName)
                    $extension = [System.IO.Path]::GetExtension($safeName)
                    $counter = 1
                    while (Test-Path $targetPath) {
                        $targetPath = Join-Path $OutputDir $category "$basename`_$counter$extension"
                        $counter++
                    }
                }
                
                Copy-Item $_.FullName -Destination $targetPath
                $fileHashes[$hash] = $targetPath
            }
            
            $processedFiles++
            Show-ProgressBar -Current $processedFiles -Total $totalFiles -Activity "Organizing wallpapers"
        }
    }
}

# Main function
function Start-WallpaperDownload {
    Show-Banner
    
    # Get output directory
    Write-Host "`nWallpaper save location [$script:DefaultOutputDir]: " -NoNewline
    $outputDir = Read-Host
    if ([string]::IsNullOrWhiteSpace($outputDir)) {
        $outputDir = $script:DefaultOutputDir
    }
    
    # Create directories
    Initialize-DirectoryStructure -BaseDir $outputDir
    New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null
    
    Write-Host "`nInitiating wallpaper download..."
    
    # Download repositories
    $totalRepos = $script:WallpaperRepos.Count
    $successfulRepos = 0
    $failedRepos = 0
    
    for ($i = 0; $i -lt $totalRepos; $i++) {
        $repo = $script:WallpaperRepos[$i]
        Show-ProgressBar -Current $i -Total $totalRepos -Activity "Downloading repositories"
        
        $targetDir = Join-Path $script:TempDir (Split-Path $repo -Leaf)
        if (Get-Repository -RepoUrl $repo -TargetDir $targetDir) {
            $successfulRepos++
        }
        else {
            $failedRepos++
        }
    }
    
    # Process files
    Process-Wallpapers -OutputDir $outputDir
    
    # Cleanup
    Write-Host "`nCleaning up temporary files..."
    Remove-Item -Path $script:TempDir -Recurse -Force
    
    # Show summary
    $totalFiles = (Get-ChildItem -Path $outputDir -Recurse -File).Count
    Write-Host "`n✓ Download Summary:"
    Write-Host "  - Total wallpapers: $totalFiles"
    Write-Host "  - Successful downloads: $successfulRepos repositories"
    Write-Host "  - Failed downloads: $failedRepos repositories"
    Write-Host "  - Save location: $outputDir"
    
    Write-Host "`n✓ Wallpapers organized into categories:"
    foreach ($dir in $script:OrganizedDirs) {
        $count = (Get-ChildItem -Path (Join-Path $outputDir $dir) -File).Count
        Write-Host "  - $dir`: $count files"
    }
}

# Run the script
try {
    # Check if Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Git is not installed or not in PATH. Please install Git for Windows first."
        exit 1
    }
    
    Start-WallpaperDownload
}
catch {
    Write-Host "An error occurred: $_"
    if (Test-Path $script:TempDir) {
        Remove-Item -Path $script:TempDir -Recurse -Force
    }
    exit 1
}
