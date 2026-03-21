# =============================================================================
#  WallPimp — Setup & Launcher
#  by 0xb0rn3 | github.com/0xb0rn3/wallpimp
#
#  Run from PowerShell (Windows 10+):
#
#    irm https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/setup.ps1 | iex
#
#  Or download and run locally:
#
#    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
#    .\setup.ps1
# =============================================================================

& {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    # ── Output helpers ────────────────────────────────────────────────────────
    function Write-Header {
        Clear-Host
        Write-Host ""
        Write-Host "  ██╗    ██╗ █████╗ ██╗     ██╗     ██████╗ ██╗███╗   ███╗██████╗ " -ForegroundColor Cyan
        Write-Host "  ██║    ██║██╔══██╗██║     ██║     ██╔══██╗██║████╗ ████║██╔══██╗" -ForegroundColor Cyan
        Write-Host "  ██║ █╗ ██║███████║██║     ██║     ██████╔╝██║██╔████╔██║██████╔╝" -ForegroundColor Cyan
        Write-Host "  ██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ " -ForegroundColor Cyan
        Write-Host "  ╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║██║ ╚═╝ ██║██║     " -ForegroundColor Cyan
        Write-Host "   ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     " -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Wallpaper Manager  —  Setup & Launcher" -ForegroundColor DarkGray
        Write-Host "  by 0xb0rn3  |  github.com/0xb0rn3/wallpimp" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "  ║  ⚠  DO NOT CLOSE THIS WINDOW  ⚠                             ║" -ForegroundColor Yellow
        Write-Host "  ║     Setup is running. Closing now may leave your system      ║" -ForegroundColor Yellow
        Write-Host "  ║     in a partially installed state.                          ║" -ForegroundColor Yellow
        Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
    }

    function Write-Step   { param($msg) Write-Host "  [ .. ] $msg" -ForegroundColor DarkGray }
    function Write-OK     { param($msg) Write-Host "  [ OK ] $msg" -ForegroundColor Green }
    function Write-Skip   { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor Yellow }
    function Write-Fail   { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
    function Write-Info   { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Cyan }
    function Write-Spacer { Write-Host "" }

    function Write-DoneWarning {
        Write-Spacer
        Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║  ✔  Setup complete — you may now close this window.          ║" -ForegroundColor Green
        Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Spacer
    }

    # ── Helpers ───────────────────────────────────────────────────────────────
    function Refresh-Path {
        $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        $userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $env:PATH    = "$machinePath;$userPath"
    }

    function Test-Command { param($cmd) return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

    function Get-SemVer {
        param($verString)
        if ($verString -match '(\d+)\.(\d+)\.(\d+)') {
            return [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
        }
        return $null
    }

    function Abort {
        param($msg)
        Write-Spacer
        Write-Fail $msg
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║  ✘  Setup failed. You can safely close this window.          ║" -ForegroundColor Red
        Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Spacer
        throw $msg
    }

    function Install-WithWinget {
        param($packageId, $label)
        Write-Step "Installing $label via winget ..."
        $result = winget install --id $packageId `
                    --accept-package-agreements `
                    --accept-source-agreements `
                    --silent 2>&1
        if ($LASTEXITCODE -ne 0) {
            Abort "$label install failed. Install manually: https://winget.run/pkg/$packageId"
        }
        Refresh-Path
        Write-OK "$label installed."
    }

    # ── winget guard ──────────────────────────────────────────────────────────
    function Assert-Winget {
        if (-not (Test-Command "winget")) {
            Write-Fail "winget not found."
            Write-Host "  Get it from the Microsoft Store:" -ForegroundColor DarkYellow
            Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ForegroundColor DarkYellow
            Abort "winget is required. Install it then re-run this script."
        }
        Write-OK "winget found."
    }

    # ── Python ────────────────────────────────────────────────────────────────
    function Assert-Python {
        $minVer = [version]"3.10.0"

        foreach ($cmd in @("python", "python3", "py")) {
            if (Test-Command $cmd) {
                $ver = Get-SemVer (& $cmd --version 2>&1)
                if ($ver -and $ver -ge $minVer) {
                    Write-OK "Python $ver found ($cmd)."
                    $script:PythonCmd = $cmd
                    return
                }
            }
        }

        Write-Step "Python 3.10+ not found — installing Python 3.12 ..."
        Install-WithWinget "Python.Python.3.12" "Python 3.12"

        foreach ($cmd in @("python", "python3", "py")) {
            if (Test-Command $cmd) { $script:PythonCmd = $cmd; return }
        }
        Abort "Python not on PATH after install. Open a new terminal and re-run."
    }

    # ── Go ────────────────────────────────────────────────────────────────────
    function Assert-Go {
        $minVer = [version]"1.21.0"

        if (Test-Command "go") {
            $ver = Get-SemVer (& go version 2>&1)
            if ($ver -and $ver -ge $minVer) {
                Write-OK "Go $ver found."
                return
            }
            Write-Step "Go $ver < 1.21 — upgrading ..."
        } else {
            Write-Step "Go not found — installing ..."
        }

        Install-WithWinget "GoLang.Go" "Go 1.21+"

        if (-not (Test-Command "go")) {
            Abort "Go not on PATH after install. Open a new terminal and re-run."
        }
        Write-OK "Go is ready."
    }

    # ── Git ───────────────────────────────────────────────────────────────────
    function Assert-Git {
        if (Test-Command "git") {
            Write-OK "Git found."
            return
        }
        Write-Info "Git not found — installing (needed to clone the repo) ..."
        Install-WithWinget "Git.Git" "Git"
        Refresh-Path
        if (-not (Test-Command "git")) {
            Abort "Git not on PATH after install. Open a new terminal and re-run."
        }
        Write-OK "Git ready."
    }

    # ── Clone / update ────────────────────────────────────────────────────────
    function Get-WallPimp {
        param($installDir)

        if (Test-Path (Join-Path $installDir "wallpimp")) {
            Write-Skip "Repo already present — pulling latest ..."
            Push-Location $installDir
            try {
                git pull --quiet 2>&1 | Out-Null
                Write-OK "Repository up to date."
            } catch {
                Write-Skip "Pull failed — continuing with existing files."
            } finally {
                Pop-Location
            }
            return
        }

        Write-Step "Cloning wallpimp into $installDir ..."
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        git clone --depth 1 --quiet "https://github.com/0xb0rn3/wallpimp.git" $installDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Abort "git clone failed. Check your internet connection." }
        Write-OK "Repository cloned."
    }

    # ── Build Go engine ───────────────────────────────────────────────────────
    function Build-Engine {
        param($repoDir)

        $enginePath = Join-Path $repoDir "wallpimp-engine.exe"

        if (Test-Path $enginePath) {
            $engineTime = (Get-Item $enginePath).LastWriteTime
            $srcNewer   = Get-ChildItem (Join-Path $repoDir "src") -Filter "*.go" -Recurse |
                          Where-Object { $_.LastWriteTime -gt $engineTime }
            if (-not $srcNewer) {
                Write-Skip "Go engine already built and up to date."
                return
            }
            Write-Step "Source updated — rebuilding engine ..."
        } else {
            Write-Step "Building Go engine ..."
        }

        Push-Location (Join-Path $repoDir "src")
        try {
            $out = & go build -o (Join-Path $repoDir "wallpimp-engine.exe") . 2>&1
            if ($LASTEXITCODE -ne 0) { Abort "go build failed:`n$out" }
            Write-OK "Engine built: wallpimp-engine.exe"
        } finally {
            Pop-Location
        }
    }

    # ── Python deps ───────────────────────────────────────────────────────────
    function Install-PythonDeps {
        Write-Step "Checking Python deps (requests, tqdm) ..."
        $missing = @()
        foreach ($pkg in @("requests", "tqdm")) {
            & $script:PythonCmd -c "import $pkg" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $missing += $pkg }
        }
        if ($missing.Count -eq 0) { Write-OK "Python deps already installed."; return }

        Write-Step "Installing: $($missing -join ', ') ..."
        & $script:PythonCmd -m pip install --quiet @missing
        if ($LASTEXITCODE -ne 0) { Abort "pip install failed. Run: pip install $($missing -join ' ')" }
        Write-OK "Python deps installed."
    }

    # ── Launch ────────────────────────────────────────────────────────────────
    function Start-WallPimp {
        param($repoDir)
        Write-Spacer
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Host "  All set. Launching WallPimp ..." -ForegroundColor Green
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Spacer
        Push-Location $repoDir
        try { & $script:PythonCmd (Join-Path $repoDir "wallpimp") }
        finally { Pop-Location }
    }

    # ── Entry point ───────────────────────────────────────────────────────────
    $script:PythonCmd = $null
    $InstallDir       = Join-Path $env:USERPROFILE "wallpimp"

    Write-Header
    Write-Info "Install location: $InstallDir"
    Write-Spacer

    Write-Host "  Checking requirements ..." -ForegroundColor DarkGray
    Write-Spacer

    Assert-Winget
    Assert-Python
    Assert-Go
    Assert-Git

    Write-Spacer
    Write-Host "  Setting up WallPimp ..." -ForegroundColor DarkGray
    Write-Spacer

    Get-WallPimp      -installDir $InstallDir
    Build-Engine      -repoDir    $InstallDir
    Install-PythonDeps

    Write-DoneWarning
    Start-WallPimp    -repoDir    $InstallDir
}
