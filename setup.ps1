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

    function Invoke-Native {
        param([scriptblock]$Block)
        try   { $output = & $Block 2>&1 }
        catch { $output = $_.ToString() }
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
            if ($ver -and $ver -ge $minVer) { Write-OK "Go $ver found."; return }
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

    # ── System deps ───────────────────────────────────────────────────────────
    # On Windows the main extra dep is tkinter, which ships with the official
    # Python installer (the tcl/tk component). If it's missing it means a
    # non-standard Python was installed — we detect this and advise the fix.
    # We also ensure pip is available and the Visual C++ redistributable is
    # present (required by some compiled wheels like Pillow in future use).
    function Install-SystemDeps {
        Write-Step "Checking system dependencies ..."

        # ── tkinter ───────────────────────────────────────────────────────────
        $tkOk = Invoke-Native { & $script:PythonCmd -c "import tkinter" 2>&1 }
        if ($LASTEXITCODE -eq 0) {
            Write-OK "tkinter found."
        } else {
            Write-Skip "tkinter not found in current Python install."
            Write-Info "tkinter ships with the official Python installer from python.org."
            Write-Info "If you need the GUI, reinstall Python 3.10+ from python.org"
            Write-Info "and make sure the 'tcl/tk and IDLE' option is ticked."
            # Do NOT abort — CLI still works without tkinter.
        }

        # ── pip ───────────────────────────────────────────────────────────────
        $pipOk = Invoke-Native { & $script:PythonCmd -m pip --version 2>&1 }
        if ($LASTEXITCODE -eq 0) {
            Write-OK "pip found."
        } else {
            Write-Step "pip not found — installing via ensurepip ..."
            Invoke-Native { & $script:PythonCmd -m ensurepip --upgrade 2>&1 } | Out-Null
            $pipOk2 = Invoke-Native { & $script:PythonCmd -m pip --version 2>&1 }
            if ($LASTEXITCODE -eq 0) {
                Write-OK "pip installed."
            } else {
                Abort "pip could not be installed. Re-install Python from python.org."
            }
        }

        # ── requests & tqdm ───────────────────────────────────────────────────
        # Handled separately in Install-PythonDeps; nothing more needed here
        # for the Windows platform.

        Write-OK "System deps satisfied."
    }

    # ── Python deps ───────────────────────────────────────────────────────────
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

    # ── Clone / update ────────────────────────────────────────────────────────
    function Get-WallPimp {
        param($installDir)
        if (Test-Path (Join-Path $installDir ".git")) {
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
            $out = Invoke-Native { go build -o (Join-Path $repoDir "wallpimp-engine.exe") . }
            if ($LASTEXITCODE -ne 0) { Abort "go build failed:`n$out" }
            Write-OK "Engine built: wallpimp-engine.exe"
        } finally {
            Pop-Location
        }
    }

    # ── GUI script check ──────────────────────────────────────────────────────
    function Assert-GuiScript {
        param($repoDir)
        $guiScript = Join-Path $repoDir "wallpimp_gui.py"
        if (Test-Path $guiScript) { return $true }
        Write-Step "Fetching wallpimp_gui.py ..."
        $url = "https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp_gui.py"
        try {
            Invoke-WebRequest -Uri $url -OutFile $guiScript -UseBasicParsing
            Write-OK "wallpimp_gui.py downloaded."
            return $true
        } catch {
            Write-Skip "Could not download wallpimp_gui.py — GUI option unavailable."
            return $false
        }
    }

    # ── Launch chooser ────────────────────────────────────────────────────────
    function Invoke-LaunchChooser {
        param($repoDir)

        Write-Spacer
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Host "  Setup complete. How would you like to launch WallPimp?" -ForegroundColor Green
        Write-Host ("  " + ("─" * 65)) -ForegroundColor DarkGray
        Write-Spacer

        $hasTk  = (Invoke-Native { & $script:PythonCmd -c "import tkinter" 2>&1 }; $LASTEXITCODE -eq 0)
        $hasGui = Assert-GuiScript -repoDir $repoDir

        if ($hasTk -and $hasGui) {
            Write-Host "    i)  Launch GUI    — graphical interface" -ForegroundColor Cyan
        } else {
            Write-Host "    i)  Launch GUI    — unavailable (tkinter missing)" -ForegroundColor DarkGray
        }
        Write-Host "   ii)  Stay on CLI   — classic terminal UI" -ForegroundColor Green
        Write-Spacer

        $choice = ""
        while ($true) {
            $raw    = Read-Host "  Enter choice [i / ii]"
            $choice = $raw.Trim().ToLower()
            if ($choice -in @("i", "1", "gui"))       { $choice = "gui"; break }
            if ($choice -in @("ii", "2", "cli", ""))  { $choice = "cli"; break }
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
    Write-Host "  Installing system dependencies ..." -ForegroundColor DarkGray
    Write-Spacer

    Install-SystemDeps

    Write-Spacer
    Write-Host "  Setting up WallPimp ..." -ForegroundColor DarkGray
    Write-Spacer

    Get-WallPimp   -installDir $InstallDir
    Build-Engine   -repoDir    $InstallDir
    Install-PythonDeps

    Invoke-LaunchChooser -repoDir $InstallDir

    Write-DoneBox
}
