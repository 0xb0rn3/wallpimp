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

    # PS 7.3+ throws NativeCommandError on any non-zero native exit code,
    # even with ErrorActionPreference = SilentlyContinue. Suppress globally —
    # we check $LASTEXITCODE ourselves everywhere it matters.
    if ($PSVersionTable.PSVersion -ge [version]"7.3") {
        $PSNativeCommandErrorActionPreference = "Ignore"
    }

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

    function Write-DoneBox {
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

    # Invoke-Native: run a native command, capture output, never throw —
    # regardless of exit code or PS version. Callers check $LASTEXITCODE.
    function Invoke-Native {
        param([scriptblock]$Block)
        try {
            $output = & $Block 2>&1
        } catch {
            $output = $_.ToString()
        }
        return $output
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
        Invoke-Native {
            winget install --id $packageId `
                --accept-package-agreements `
                --accept-source-agreements `
                --silent
        } | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Abort "$label install failed. Install manually: https://winget.run/pkg/$packageId"
        }
        Refresh-Path
        Write-OK "$label installed."
    }

    # ── winget ────────────────────────────────────────────────────────────────
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
                $raw = Invoke-Native { & $cmd --version }
                $ver = Get-SemVer ($raw -join "")
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
            $raw = Invoke-Native { go version }
            $ver = Get-SemVer ($raw -join "")
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
        if (Test-Command "git") { Write-OK "Git found."; return }
        Write-Step "Git not found — installing ..."
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
                Invoke-Native { git pull --quiet } | Out-Null
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
        Invoke-Native {
            git clone --depth 1 --quiet "https://github.com/0xb0rn3/wallpimp.git" $installDir
        } | Out-Null
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
            $out = Invoke-Native {
                go build -o (Join-Path $repoDir "wallpimp-engine.exe") .
            }
            if ($LASTEXITCODE -ne 0) { Abort "go build failed:`n$out" }
            Write-OK "Engine built: wallpimp-engine.exe"
        } finally {
            Pop-Location
        }
    }

    # ── Python deps ───────────────────────────────────────────────────────────
    # Uses `pip show <pkg>` instead of `python -c "import <pkg>"`.
    # pip show exits 0 if installed, 1 if not — clean, no tracebacks,
    # no NativeCommandError risk from Python's own error output.
    function Install-PythonDeps {
        Write-Step "Checking Python deps (requests, tqdm) ..."
        $missing = @()
        foreach ($pkg in @("requests", "tqdm")) {
            Invoke-Native { & $script:PythonCmd -m pip show $pkg } | Out-Null
            if ($LASTEXITCODE -ne 0) { $missing += $pkg }
        }
        if ($missing.Count -eq 0) {
            Write-OK "Python deps already installed."
            return
        }
        Write-Step "Installing: $($missing -join ', ') ..."
        $out = Invoke-Native { & $script:PythonCmd -m pip install --quiet $missing }
        if ($LASTEXITCODE -ne 0) {
            Abort "pip install failed. Run manually: pip install $($missing -join ' ')"
        }
        Write-OK "Python deps installed."
    }

    # ── Tkinter check ─────────────────────────────────────────────────────────
    # tkinter ships with the official Python Windows installer. This just
    # verifies it's importable before we offer the GUI option.
    function Test-Tkinter {
        $out = Invoke-Native {
            & $script:PythonCmd -c "import tkinter" 2>&1
        }
        return ($LASTEXITCODE -eq 0)
    }

    # ── GUI dep: ensure wallpimp_gui.py is present ────────────────────────────
    function Assert-GuiScript {
        param($repoDir)
        $guiScript = Join-Path $repoDir "wallpimp_gui.py"
        if (-not (Test-Path $guiScript)) {
            # Try to download directly from the repo
            Write-Step "Fetching wallpimp_gui.py ..."
            $url = "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp_gui.py"
            try {
                Invoke-WebRequest -Uri $url -OutFile $guiScript -UseBasicParsing
                Write-OK "wallpimp_gui.py downloaded."
            } catch {
                Write-Skip "Could not download wallpimp_gui.py — GUI option unavailable."
                return $false
            }
        }
        return $true
    }

    # ── Launch chooser ────────────────────────────────────────────────────────
    # Shown after all setup steps complete. Lets the user pick GUI or CLI.
    function Invoke-LaunchChooser {
        param($repoDir)

        Write-Spacer
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Host "  Setup complete. How would you like to launch WallPimp?" -ForegroundColor Green
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Spacer

        $hasTk  = Test-Tkinter
        $hasGui = Assert-GuiScript -repoDir $repoDir

        if ($hasTk -and $hasGui) {
            Write-Host "    i)  Launch GUI    — graphical interface" -ForegroundColor Cyan
            Write-Host "   ii)  Stay on CLI   — classic terminal UI" -ForegroundColor DarkGray
        } else {
            if (-not $hasTk) {
                Write-Info "tkinter not found — GUI option unavailable."
                Write-Info "To enable GUI: reinstall Python 3.10+ from python.org (tick 'tcl/tk' option)."
            }
            Write-Host "    ii)  Stay on CLI   — classic terminal UI" -ForegroundColor DarkGray
        }

        Write-Spacer

        $choice = ""
        while ($true) {
            $raw = Read-Host "  Enter choice [i / ii]"
            $choice = $raw.Trim().ToLower()
            if ($choice -in @("i", "1", "gui"))        { $choice = "gui"; break }
            if ($choice -in @("ii", "2", "cli", ""))   { $choice = "cli"; break }
            Write-Host "  Please enter  i  for GUI or  ii  for CLI." -ForegroundColor Yellow
        }

        Write-Spacer
        Push-Location $repoDir

        try {
            if ($choice -eq "gui" -and $hasTk -and $hasGui) {
                Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
                Write-Host "  Launching WallPimp GUI ..." -ForegroundColor Cyan
                Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
                Write-Spacer
                & $script:PythonCmd (Join-Path $repoDir "wallpimp_gui.py")
            } else {
                Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
                Write-Host "  Launching WallPimp CLI ..." -ForegroundColor Green
                Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
                Write-Spacer
                & $script:PythonCmd (Join-Path $repoDir "wallpimp")
            }
        } finally {
            Pop-Location
        }
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

    Get-WallPimp   -installDir $InstallDir
    Build-Engine   -repoDir    $InstallDir
    Install-PythonDeps

    # ── Launch chooser (GUI vs CLI) ───────────────────────────────────────────
    Invoke-LaunchChooser -repoDir $InstallDir

    Write-DoneBox
}
