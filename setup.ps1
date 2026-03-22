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

    # PS 7.3+ throws NativeCommandError on non-zero exit codes. Suppress it —
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

    # ── Core helpers ──────────────────────────────────────────────────────────
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

    # Invoke-Native: run a command block, swallow all errors, return output.
    # Callers always check $LASTEXITCODE themselves.
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

    # ── winget ────────────────────────────────────────────────────────────────
    function Assert-Winget {
        if (Test-Command "winget") { Write-OK "winget found."; return }
        Write-Fail "winget not found."
        Write-Host "  Get it from the Microsoft Store:" -ForegroundColor DarkYellow
        Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ForegroundColor DarkYellow
        Abort "winget is required. Install it then re-run this script."
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

    # ── Python — full clean reinstall ─────────────────────────────────────────
    #
    # Strategy:
    #   1. Check if Python 3.10+ exists AND tkinter imports cleanly  → done
    #   2. Otherwise:
    #      a. Uninstall every Python found via winget + the Microsoft Store
    #         variant (Python.Python.3.*) and the legacy store app
    #      b. Remove any stale python/python3/py shims from PATH
    #      c. Download the official python.org installer (3.12.x) directly
    #      d. Run it silently with ALL features including tcl/tk forced on
    #      e. Verify tkinter imports
    #
    # We use the official .exe installer rather than winget because winget's
    # Python package occasionally omits the tcl/tk optional feature depending
    # on the machine's existing state. The official installer lets us set
    # Include_tcltk=1 explicitly, which is guaranteed to include tkinter.

    $script:PythonCmd     = $null
    $script:PythonVersion = $null

    function Test-Tkinter {
        if (-not $script:PythonCmd) { return $false }
        Invoke-Native { & $script:PythonCmd -c "import tkinter" 2>&1 } | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    function Find-PythonCmd {
        # Returns the first python command that is 3.10+ and sets $script:PythonCmd
        foreach ($cmd in @("python", "python3", "py")) {
            if (-not (Test-Command $cmd)) { continue }
            $raw = Invoke-Native { & $cmd --version 2>&1 }
            $ver = Get-SemVer ($raw -join "")
            if ($ver -and $ver -ge [version]"3.10.0") {
                $script:PythonCmd     = $cmd
                $script:PythonVersion = $ver
                return $true
            }
        }
        return $false
    }

    function Uninstall-AllPython {
        Write-Step "Removing existing Python installations ..."

        # 1. winget uninstall — covers Python.Python.3.x (all minor versions)
        $wingetIds = @(
            "Python.Python.3.13", "Python.Python.3.12", "Python.Python.3.11",
            "Python.Python.3.10", "Python.Python.3.9",  "Python.Python.3.8"
        )
        foreach ($id in $wingetIds) {
            Invoke-Native {
                winget uninstall --id $id --silent --accept-source-agreements 2>&1
            } | Out-Null
            # exit code 0 = uninstalled, non-zero = wasn't installed — both fine
        }

        # 2. Microsoft Store Python (shows up as a different package family)
        $storePkg = Get-AppxPackage -Name "PythonSoftwareFoundation.Python*" -ErrorAction SilentlyContinue
        if ($storePkg) {
            Write-Step "Removing Microsoft Store Python ..."
            $storePkg | Remove-AppxPackage -ErrorAction SilentlyContinue
        }

        # 3. Kill any stale shims sitting in PATH (Python Launcher py.exe etc.)
        #    These live in %LOCALAPPDATA%\Programs\Python or similar.
        #    We'll let the fresh installer overwrite them — no manual removal needed.

        # 4. Refresh PATH so old python.exe is no longer visible
        Refresh-Path

        Write-OK "Existing Python removed (or was not present)."
    }

    function Install-PythonOfficial {
        # Download the official CPython 3.12.x installer from python.org
        # and run it with every feature enabled including tcl/tk.
        $pyVer      = "3.12.9"
        $arch       = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
        $installerName = "python-$pyVer-$arch.exe"
        $url        = "https://www.python.org/ftp/python/$pyVer/$installerName"
        $tmpPath    = Join-Path $env:TEMP $installerName

        Write-Step "Downloading Python $pyVer ($arch) from python.org ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing
        } catch {
            Abort "Failed to download Python installer: $_"
        }

        Write-Step "Installing Python $pyVer (all features, including tcl/tk) ..."
        # Install flags:
        #   /quiet               — no UI
        #   InstallAllUsers=0    — per-user install, no UAC needed
        #   PrependPath=1        — add to PATH automatically
        #   Include_tcltk=1      — force tcl/tk (tkinter) inclusion
        #   Include_pip=1        — include pip
        #   Include_launcher=1   — include py.exe launcher
        #   Include_symbols=0    — skip debug symbols (saves ~50MB)
        #   Include_debug=0      — skip debug binaries
        $proc = Start-Process -FilePath $tmpPath -Wait -PassThru -ArgumentList @(
            "/quiet",
            "InstallAllUsers=0",
            "PrependPath=1",
            "Include_tcltk=1",
            "Include_pip=1",
            "Include_launcher=1",
            "Include_symbols=0",
            "Include_debug=0"
        )

        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -ne 0) {
            Abort "Python installer exited with code $($proc.ExitCode)."
        }

        Refresh-Path
        Write-OK "Python $pyVer installed."
    }

    function Assert-Python {
        Write-Step "Checking Python 3.10+ with tkinter ..."

        # Fast path: existing Python is good AND tkinter works
        if (Find-PythonCmd) {
            if (Test-Tkinter) {
                Write-OK "Python $script:PythonVersion found with tkinter. No reinstall needed."
                return
            }
            Write-Info "Python $script:PythonVersion found but tkinter is broken or missing."
            Write-Info "Performing a clean reinstall to fix it ..."
        } else {
            Write-Info "Python 3.10+ not found. Installing ..."
        }

        # Slow path: remove everything, install fresh from python.org
        Uninstall-AllPython
        Install-PythonOfficial

        # Re-discover the new python command
        if (-not (Find-PythonCmd)) {
            Abort "Python not found on PATH after install. Open a new terminal and re-run."
        }

        # Final tkinter verification
        if (-not (Test-Tkinter)) {
            Abort "tkinter still not importable after fresh Python install. Check Windows Event Log."
        }

        Write-OK "Python $script:PythonVersion ready with tkinter."
    }

    # ── Go ────────────────────────────────────────────────────────────────────
    function Assert-Go {
        $minVer = [version]"1.21.0"
        if (Test-Command "go") {
            $raw = Invoke-Native { go version 2>&1 }
            $ver = Get-SemVer ($raw -join "")
            if ($ver -and $ver -ge $minVer) {
                Write-OK "Go $ver found."
                return
            }
            Write-Step "Go $ver is older than 1.21 — upgrading ..."
        } else {
            Write-Step "Go not found — installing ..."
        }
        Install-WithWinget "GoLang.Go" "Go 1.21+"
        Refresh-Path
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

    # ── Visual C++ Redistributable ────────────────────────────────────────────
    # Required by compiled Python packages (e.g. Pillow, lxml, cryptography).
    # The Python installer usually pulls this in, but installing it explicitly
    # ensures it's present even on stripped-down Windows installs.
    function Assert-VCRedist {
        Write-Step "Checking Visual C++ Redistributable ..."
        $installed = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\*\VC\Runtimes\*" `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -ge "14.0" }
        if ($installed) {
            Write-OK "Visual C++ Redistributable already installed."
            return
        }
        Write-Step "Installing Visual C++ 2015-2022 Redistributable ..."
        Install-WithWinget "Microsoft.VCRedist.2015+.x64" "VC++ Redistributable x64"
        if ([System.Environment]::Is64BitOperatingSystem -eq $false) {
            Install-WithWinget "Microsoft.VCRedist.2015+.x86" "VC++ Redistributable x86"
        }
    }

    # ── pip + Python packages ─────────────────────────────────────────────────
    function Assert-Pip {
        Write-Step "Checking pip ..."
        Invoke-Native { & $script:PythonCmd -m pip --version 2>&1 } | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK "pip found."; return }

        Write-Step "pip not found — running ensurepip via Start-Process ..."
        $epProc = Start-Process `
            -FilePath $script:PythonCmd `
            -ArgumentList @("-m", "ensurepip", "--upgrade") `
            -Wait -PassThru -NoNewWindow
        Invoke-Native { & $script:PythonCmd -m pip --version 2>&1 } | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Abort "pip could not be installed (ensurepip exit $($epProc.ExitCode)). Re-run setup."
        }
        Write-OK "pip installed."
    }

    function Invoke-Pip {
        # Run a pip command robustly, bypassing PowerShell remoting exceptions.
        # Uses Start-Process so the child process runs in its own context —
        # avoids system.Management.Automation.RemoteException when elevated.
        param([string[]]$PipArgs)
        $logFile = Join-Path $env:TEMP "wallpimp-pip.log"
        $proc = Start-Process `
            -FilePath $script:PythonCmd `
            -ArgumentList (@("-m", "pip") + $PipArgs) `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError  "$logFile.err"
        $exitCode = $proc.ExitCode
        Remove-Item $logFile, "$logFile.err" -ErrorAction SilentlyContinue
        return $exitCode
    }

    function Install-PythonDeps {
        Write-Step "Checking Python packages (requests, tqdm) ..."
        $missing = @()
        foreach ($pkg in @("requests", "tqdm")) {
            # Use Invoke-Native for show — it's read-only and safe inline
            Invoke-Native { & $script:PythonCmd -m pip show $pkg 2>&1 } | Out-Null
            if ($LASTEXITCODE -ne 0) { $missing += $pkg }
        }
        if ($missing.Count -eq 0) {
            Write-OK "Python packages already installed."
            return
        }
        Write-Step "Installing: $($missing -join ', ') ..."
        # Use Invoke-Pip (Start-Process) to avoid RemoteException when running
        # as Administrator — inline & calls can throw through PS remoting layer.
        $pipArgs = @("install", "--quiet", "--upgrade", "--no-warn-script-location") + $missing
        $code = Invoke-Pip $pipArgs
        if ($code -ne 0) {
            Abort "pip install failed (exit $code).`nRun manually:  pip install $($missing -join ' ')"
        }
        Write-OK "Python packages installed."
    }

    # ── Clone / update repo ───────────────────────────────────────────────────
    function Get-WallPimp {
        param($installDir)
        if (Test-Path (Join-Path $installDir ".git")) {
            Write-Skip "Repo already present — pulling latest ..."
            Push-Location $installDir
            try {
                Invoke-Native { git pull --quiet 2>&1 } | Out-Null
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
            git clone --depth 1 --quiet "https://github.com/0xb0rn3/wallpimp.git" $installDir 2>&1
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
            $out = Invoke-Native { go build -o (Join-Path $repoDir "wallpimp-engine.exe") . 2>&1 }
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
        if (Test-Path $guiScript) {
            Write-OK "wallpimp_gui.py present."
            return $true
        }
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

        $hasTk  = Test-Tkinter
        $hasGui = Assert-GuiScript -repoDir $repoDir

        if ($hasTk -and $hasGui) {
            Write-Host "    i)   Launch GUI  — graphical interface" -ForegroundColor Cyan
        } else {
            Write-Host "    i)   Launch GUI  — unavailable (tkinter missing)" -ForegroundColor DarkGray
        }
        Write-Host "   ii)   Stay on CLI — classic terminal UI" -ForegroundColor Green
        Write-Spacer

        $choice = ""
        while ($true) {
            $raw    = Read-Host "  Enter choice [i / ii]"
            $choice = $raw.Trim().ToLower()
            if ($choice -in @("i", "1", "gui"))      { $choice = "gui"; break }
            if ($choice -in @("ii", "2", "cli", "")) { $choice = "cli"; break }
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

    # ══════════════════════════════════════════════════════════════════════════
    #  Entry point
    # ══════════════════════════════════════════════════════════════════════════
    $InstallDir = Join-Path $env:USERPROFILE "wallpimp"

    Write-Header
    Write-Info "Install location: $InstallDir"
    Write-Spacer

    # ── Step 1: prerequisites ─────────────────────────────────────────────────
    Write-Host "  Checking prerequisites ..." -ForegroundColor DarkGray
    Write-Spacer

    Assert-Winget
    Assert-Python        # always validates tkinter; reinstalls if broken
    Assert-Go
    Assert-Git
    Assert-VCRedist

    Write-Spacer

    # ── Step 2: Python runtime deps ───────────────────────────────────────────
    Write-Host "  Setting up Python environment ..." -ForegroundColor DarkGray
    Write-Spacer

    Assert-Pip
    Install-PythonDeps

    Write-Spacer

    # ── Step 3: WallPimp ──────────────────────────────────────────────────────
    Write-Host "  Setting up WallPimp ..." -ForegroundColor DarkGray
    Write-Spacer

    Get-WallPimp  -installDir $InstallDir
    Build-Engine  -repoDir    $InstallDir

    # ── Step 4: Launch ────────────────────────────────────────────────────────
    Invoke-LaunchChooser -repoDir $InstallDir

    Write-DoneBox
}
