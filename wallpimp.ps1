#Requires -Version 5.0

function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════╗
║         WallPimp Ver:0.2              ║
║    Wallpaper Download Assistant       ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

function Spinner {
    param (
        [int]$PID
    )
    $spinstr = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    $delay = 100  # Milliseconds
    while (Get-Process -Id $PID -ErrorAction SilentlyContinue) {
        for ($i = 0; $i -lt $spinstr.Length; $i++) {
            Write-Host -NoNewline (" [$($spinstr[$i])] ")
            Start-Sleep -Milliseconds $delay
            Write-Host -NoNewline "`b`b`b`b"
        }
    }
    Write-Host -NoNewline "    `b`b`b`b"
}

$WallpaperRepos = @(
    "https://github.com/dharmx/walls",
    "https://github.com/FrenzyExists/wallpapers",
    "https://github.com/Dreamer-Paul/Anime-Wallpaper",
    "https://github.com/michaelScopic/Wallpapers",
    "https://github.com/ryan4yin/wallpapers",
    "https://github.com/HENTAI-CODER/Anime-Wallpaper",
    "https://github.com/port19x/Wallpapers",
    "https://github.com/k1ng440/Wallpapers",
    "https://github.com/vimfn/walls",
    "https://github.com/expandpi/wallpapers",
    "https://github.com/polluxau/linuxnext-wallpapers",
    "https://github.com/port19x/Wallpapers",
    "https://github.com/k1ng440/Wallpapers",
    "https://github.com/HENTAI-CODER/Anime-Wallpaper",
    "https://github.com/rubenswebdev/wallpapers",
    "https://github.com/vimfn/walls",
    "https://github.com/IcePocket/Wallpapers",
    "https://github.com/expandpi/wallpapers",
    "https://github.com/logicyugi/Backgrounds",
    "https://github.com/PlannerPlus/Anime-Wallpapers",
    "https://github.com/Samyc2002/Anime-Wallpapers",
    "https://github.com/KaikSelhorst/WallpaperPack",
    "https://github.com/erickmartin890/Anime-Wallpapers",
    "https://github.com/Motif23/Wallpapers-Anime",
    "https://github.com/TherryHilaire/anime",
    "https://github.com/anmac/Wallpapers",
    "https://github.com/Fuj3l/Wallpaper",
    "https://github.com/Aluize/animewallpapers"
)

$SupportedFormats = @("jpg", "jpeg", "png", "gif", "webp")
$MaxRetries = 3
$TempDir = "$env:TEMP\wallpimp_$([System.Guid]::NewGuid().Guid)"
$DefaultOutputDir = "$env:USERPROFILE\Pictures\Wallpapers"

function Download-Repo {
    param (
        [string]$Repo,
        [string]$TargetDir
    )
    for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {
        try {
            git clone --depth 1 $Repo $TargetDir | Out-Null
            return $true
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Process-Files {
    param (
        [string]$OutputDir
    )
    $HashSet = @{}
    foreach ($Format in $SupportedFormats) {
        Get-ChildItem -Path $TempDir -Recurse -Filter "*.$Format" | ForEach-Object {
            $File = $_.FullName
            $Hash = (Get-FileHash -Path $File -Algorithm SHA256).Hash
            if (-not $HashSet.ContainsKey($Hash)) {
                $FileName = $_.Name -replace '\s+', '_' -replace '[^A-Za-z0-9._-]', ''
                $TargetPath = Join-Path -Path $OutputDir -ChildPath $FileName

                # Handle duplicates
                $Counter = 1
                while (Test-Path $TargetPath) {
                    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
                    $Extension = [System.IO.Path]::GetExtension($FileName)
                    $TargetPath = Join-Path $OutputDir "${BaseName}_$Counter$Extension"
                    $Counter++
                }

                Copy-Item -Path $File -Destination $TargetPath
                $HashSet[$Hash] = $true
            }
        }
    }
}

function Main {
    Show-Banner

    $OutputDir = Read-Host "Wallpaper save location [$DefaultOutputDir]"
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = $DefaultOutputDir
    }

    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    Write-Host "`nDownloading wallpapers..."

    $FailedRepos = 0
    foreach ($Repo in $WallpaperRepos) {
        $TargetDir = Join-Path $TempDir ([System.IO.Path]::GetFileNameWithoutExtension($Repo))
        $Job = Start-Job -ScriptBlock {
            param ($Repo, $TargetDir)
            Download-Repo -Repo $Repo -TargetDir $TargetDir
        } -ArgumentList $Repo, $TargetDir

        Spinner -PID $Job.Id
        $JobResult = Receive-Job -Job $Job -Wait
        if (-not $JobResult) {
            $FailedRepos++
        }
    }

    Write-Host "`nProcessing wallpapers..."
    Process-Files -OutputDir $OutputDir

    Remove-Item -Path $TempDir -Recurse -Force

    $TotalFiles = (Get-ChildItem -Path $OutputDir -File).Count
    Write-Host "`n✓ Downloaded wallpapers: $TotalFiles"
    Write-Host "✓ Save location: $OutputDir"
    if ($FailedRepos -gt 0) {
        Write-Host "! Some repositories failed to download ($FailedRepos)" -ForegroundColor Yellow
    }
}

Main
