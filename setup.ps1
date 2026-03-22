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
#
#  PATCH: Assert-VCRedist rewritten to download directly from Microsoft
#         instead of using winget — fixes install failure on QEMU/KVM VMs
#         where winget cannot install Microsoft.VCRedist.2015+.x64.
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

    # ── Python — full clean reinstall with tkinter guaranteed ─────────────────
    $script:PythonCmd     = $null
    $script:PythonVersion = $null

    function Test-Tkinter {
        if (-not $script:PythonCmd) { return $false }
        Invoke-Native { & $script:PythonCmd -c "import tkinter" 2>&1 } | Out-Null
        return ($LASTEXITCODE -eq 0)
    }

    function Find-PythonCmd {
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
        foreach ($id in @(
            "Python.Python.3.13","Python.Python.3.12","Python.Python.3.11",
            "Python.Python.3.10","Python.Python.3.9","Python.Python.3.8"
        )) {
            Invoke-Native {
                winget uninstall --id $id --silent --accept-source-agreements 2>&1
            } | Out-Null
        }
        $storePkg = Get-AppxPackage -Name "PythonSoftwareFoundation.Python*" -ErrorAction SilentlyContinue
        if ($storePkg) {
            Write-Step "Removing Microsoft Store Python ..."
            $storePkg | Remove-AppxPackage -ErrorAction SilentlyContinue
        }
        Refresh-Path
        Write-OK "Existing Python removed (or was not present)."
    }

    function Install-PythonOfficial {
        $pyVer         = "3.12.9"
        $arch          = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
        $installerName = "python-$pyVer-$arch.exe"
        $url           = "https://www.python.org/ftp/python/$pyVer/$installerName"
        $tmpPath       = Join-Path $env:TEMP $installerName

        Write-Step "Downloading Python $pyVer ($arch) from python.org ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing -TimeoutSec 180
        } catch {
            Abort "Failed to download Python installer: $_"
        }

        Write-Step "Installing Python $pyVer (all features, including tcl/tk) ..."
        $proc = Start-Process -FilePath $tmpPath -Wait -PassThru -ArgumentList @(
            "/quiet", "InstallAllUsers=0", "PrependPath=1",
            "Include_tcltk=1", "Include_pip=1", "Include_launcher=1",
            "Include_symbols=0", "Include_debug=0"
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
        if (Find-PythonCmd) {
            if (Test-Tkinter) {
                Write-OK "Python $script:PythonVersion found with tkinter. No reinstall needed."
                return
            }
            Write-Info "Python $script:PythonVersion found but tkinter is broken — reinstalling ..."
        } else {
            Write-Info "Python 3.10+ not found. Installing ..."
        }
        Uninstall-AllPython
        Install-PythonOfficial
        if (-not (Find-PythonCmd)) {
            Abort "Python not found on PATH after install. Open a new terminal and re-run."
        }
        if (-not (Test-Tkinter)) {
            Abort "tkinter still not importable after fresh Python install."
        }
        Write-OK "Python $script:PythonVersion ready with tkinter."
    }

    # ── Go — always direct MSI from go.dev, never winget ─────────────────────
    # winget's GoLang.Go fails silently on VMs, fresh installs, and machines
    # with stale winget source indexes. Direct MSI is always reliable.
    function Install-GoOfficial {
        $goVer   = "1.22.5"
        $arch    = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
        $msiName = "go$goVer.windows-$arch.msi"
        $url     = "https://go.dev/dl/$msiName"
        $tmpPath = Join-Path $env:TEMP $msiName
        $logPath = Join-Path $env:TEMP "wallpimp-go-install.log"

        Write-Step "Downloading Go $goVer ($arch) from go.dev ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing -TimeoutSec 180
        } catch {
            Abort "Failed to download Go installer: $_"
        }
        if (-not (Test-Path $tmpPath) -or (Get-Item $tmpPath).Length -lt 1MB) {
            Abort "Go installer download appears incomplete. Check your connection and re-run."
        }

        Write-Step "Installing Go $goVer ..."
        # 0 = success, 3010 = success + reboot pending (safe to ignore)
        $proc = Start-Process -FilePath "msiexec.exe" -Wait -PassThru `
            -ArgumentList @("/i", $tmpPath, "/quiet", "/norestart", "/l*v", $logPath)
        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -notin @(0, 3010)) {
            Abort "Go MSI exited $($proc.ExitCode). Log: $logPath"
        }

        # MSI writes Go's bin dir to the Machine PATH — pull into current session.
        Refresh-Path

        # Belt-and-suspenders: inject known default bin dirs if go.exe still invisible.
        foreach ($dir in @("C:\Program Files\Go\bin", "C:\Go\bin")) {
            if (-not (Test-Command "go") -and (Test-Path $dir)) {
                $env:PATH = "$dir;$env:PATH"
            }
        }
        Write-OK "Go $goVer installed."
    }

    function Assert-Go {
        $minVer = [version]"1.21.0"
        if (Test-Command "go") {
            $raw = Invoke-Native { go version 2>&1 }
            $ver = Get-SemVer ($raw -join "")
            if ($ver -and $ver -ge $minVer) {
                Write-OK "Go $ver found."
                return
            }
            Write-Step "Go $ver is older than 1.21 — reinstalling ..."
        } else {
            Write-Step "Go not found — installing ..."
        }
        Install-GoOfficial
        Refresh-Path
        if (-not (Test-Command "go")) {
            Abort "Go not on PATH after install. Open a new PowerShell window and re-run setup."
        }
        Write-OK "Go ready: $(Invoke-Native { go version })"
    }

    # ── Git ───────────────────────────────────────────────────────────────────
    # Downloads the official Git for Windows installer directly — same reason
    # as Go: winget silently fails on fresh/VM Windows installs.
    function Install-GitOfficial {
        # Portable EXE installer from the official Git for Windows release.
        $gitVer  = "2.45.2"
        $arch    = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        $exeName = "Git-$gitVer-$arch.exe"
        $url     = "https://github.com/git-for-windows/git/releases/download/v$gitVer.windows.1/$exeName"
        $tmpPath = Join-Path $env:TEMP $exeName

        Write-Step "Downloading Git $gitVer ($arch) from github.com/git-for-windows ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing
        } catch {
            Abort "Failed to download Git installer: $_"
        }

        Write-Step "Installing Git $gitVer ..."
        # SILENT install flags for Git for Windows NSIS installer:
        #   /VERYSILENT   — no UI at all
        #   /NORESTART    — never reboot
        #   /NOCANCEL     — no cancel button (not relevant but safe)
        #   /SP-          — skip the "This will install..." prompt
        #   /COMPONENTS   — only install core + cmd integration
        $proc = Start-Process -FilePath $tmpPath -Wait -PassThru -ArgumentList @(
            "/VERYSILENT",
            "/NORESTART",
            "/NOCANCEL",
            "/SP-",
            "/COMPONENTS=icons,ext`neg\shellhere,assoc,assoc_sh"
        )
        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -ne 0) {
            Abort "Git installer exited with code $($proc.ExitCode)."
        }

        # Git installs to C:\Program Files\Git\cmd by default.
        Refresh-Path
        if (-not (Test-Command "git")) {
            $gitDefault = "C:\Program Files\Git\cmd"
            if (Test-Path $gitDefault) {
                $env:PATH = "$gitDefault;$env:PATH"
            }
        }

        Write-OK "Git $gitVer installed."
    }

    function Assert-Git {
        if (Test-Command "git") { Write-OK "Git found."; return }
        Write-Step "Git not found — installing ..."
        Install-GitOfficial
        if (-not (Test-Command "git")) {
            Abort "Git not found on PATH after install. Open a new terminal and re-run."
        }
        Write-OK "Git ready."
    }

    # ── Visual C++ Redistributable ────────────────────────────────────────────
    # PATCHED: Downloads directly from Microsoft aka.ms redirect instead of
    # using winget, which fails on QEMU/KVM VMs and restricted environments.
    # Exit codes: 0 = success, 3010 = success + reboot pending (safe to ignore).
    function Install-VCRedistDirect {
        param(
            [string]$Arch   # "x64" or "x86"
        )

        $urls = @{
            "x64" = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
            "x86" = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        }

        $url     = $urls[$Arch]
        $tmpPath = Join-Path $env:TEMP "vc_redist.$Arch.exe"

        Write-Step "Downloading VC++ Redistributable ($Arch) from Microsoft ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing -TimeoutSec 120
        } catch {
            Abort "Failed to download VC++ Redistributable ($Arch): $_"
        }

        Write-Step "Installing VC++ Redistributable ($Arch) ..."
        $proc = Start-Process -FilePath $tmpPath -Wait -PassThru -ArgumentList @(
            "/install", "/quiet", "/norestart"
        )
        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -notin @(0, 3010)) {
            Abort "VC++ Redistributable ($Arch) installer exited with code $($proc.ExitCode)."
        }
        Write-OK "VC++ Redistributable ($Arch) installed."
    }

    function Assert-VCRedist {
        Write-Step "Checking Visual C++ Redistributable ..."

        # Check registry for any VC++ 2015+ runtime (version >= 14.0)
        $installed = Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\*\VC\Runtimes\*" `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.Version -ge "14.0" }

        if ($installed) {
            Write-OK "Visual C++ Redistributable already installed."
            return
        }

        Write-Step "Installing Visual C++ 2015-2022 Redistributable ..."
        Install-VCRedistDirect -Arch "x64"

        # Also install x86 on 32-bit systems
        if (-not [System.Environment]::Is64BitOperatingSystem) {
            Install-VCRedistDirect -Arch "x86"
        }
    }

    # ── pip ───────────────────────────────────────────────────────────────────
    function Assert-Pip {
        Write-Step "Checking pip ..."
        Invoke-Native { & $script:PythonCmd -m pip --version 2>&1 } | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK "pip found."; return }

        Write-Step "pip not found — running ensurepip ..."
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
        param([string[]]$PipArgs)
        $logFile = Join-Path $env:TEMP "wallpimp-pip.log"
        $proc = Start-Process `
            -FilePath $script:PythonCmd `
            -ArgumentList (@("-m", "pip") + $PipArgs) `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError  "$logFile.err"
        Remove-Item $logFile, "$logFile.err" -ErrorAction SilentlyContinue
        return $proc.ExitCode
    }

    function Install-PythonDeps {
        Write-Step "Checking Python packages (requests, tqdm) ..."
        $missing = @()
        foreach ($pkg in @("requests", "tqdm")) {
            Invoke-Native { & $script:PythonCmd -m pip show $pkg 2>&1 } | Out-Null
            if ($LASTEXITCODE -ne 0) { $missing += $pkg }
        }
        if ($missing.Count -eq 0) {
            Write-OK "Python packages already installed."
            return
        }
        Write-Step "Installing: $($missing -join ', ') ..."
        $pipArgs = @("install", "--quiet", "--upgrade", "--no-warn-script-location") + $missing
        $code = Invoke-Pip $pipArgs
        if ($code -ne 0) {
            Abort "pip install failed (exit $code). Run manually: pip install $($missing -join ' ')"
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

        $srcDir = Join-Path $repoDir "src"

        # If no go.mod exists in src, try the repo root
        if (-not (Test-Path (Join-Path $srcDir "go.mod"))) {
            if (Test-Path (Join-Path $repoDir "go.mod")) {
                $srcDir = $repoDir
                Write-Info "go.mod found at repo root — building from there."
            }
        }

        Push-Location $srcDir
        try {
            # Fetch/tidy modules before building — required on first clone
            Write-Step "Fetching Go module dependencies ..."
            $modOut = Invoke-Native { go mod tidy 2>&1 }
            if ($LASTEXITCODE -ne 0) {
                Write-Info "go mod tidy warning (non-fatal): $modOut"
            }

            $dlOut = Invoke-Native { go mod download 2>&1 }
            if ($LASTEXITCODE -ne 0) {
                Write-Info "go mod download warning (non-fatal): $dlOut"
            }

            Write-Step "Compiling Go engine ..."
            # Use a temp log file to capture stderr separately — Invoke-Native
            # collapses stdout+stderr which can drop error lines.
            $buildLog = Join-Path $env:TEMP "wallpimp-gobuild.log"
            $proc = Start-Process -FilePath "go" `
                -ArgumentList @("build", "-v", "-o", (Join-Path $repoDir "wallpimp-engine.exe"), ".") `
                -Wait -PassThru -NoNewWindow `
                -RedirectStandardError $buildLog

            $buildErr = if (Test-Path $buildLog) {
                Get-Content $buildLog -Raw
                Remove-Item $buildLog -Force -ErrorAction SilentlyContinue
            } else { "" }

            if ($proc.ExitCode -ne 0) {
                Abort "go build failed:`n$buildErr"
            }
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

    Write-Host "  Checking prerequisites ..." -ForegroundColor DarkGray
    Write-Spacer

    Assert-Winget
    Assert-Python        # validates tkinter; full reinstall from python.org if broken
    Assert-Go            # direct MSI from go.dev — never winget
    Assert-Git
    Assert-VCRedist      # PATCHED: direct download from aka.ms — never winget

    Write-Spacer
    Write-Host "  Setting up Python environment ..." -ForegroundColor DarkGray
    Write-Spacer

    Assert-Pip
    Install-PythonDeps

    Write-Spacer
    Write-Host "  Setting up WallPimp ..." -ForegroundColor DarkGray
    Write-Spacer

    Get-WallPimp  -installDir $InstallDir
    Build-Engine  -repoDir    $InstallDir

    Invoke-LaunchChooser -repoDir $InstallDir

    Write-DoneBox
}
