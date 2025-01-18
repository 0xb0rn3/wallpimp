#Requires -Version 5.0
[CmdletBinding()]
param()

# Script version for tracking
$SCRIPT_VERSION = "2.4.0"
$MIN_PYTHON_VERSION = "3.6.0"
$MIN_GIT_VERSION = "2.0.0"

# Error action preference
$ErrorActionPreference = "Stop"

# Function to compare version numbers
function Compare-Versions {
    param(
        [string]$Version1,
        [string]$Version2
    )
    
    $v1 = [version]$Version1
    $v2 = [version]$Version2
    return $v1.CompareTo($v2)
}

# Function to check if running as administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check system requirements
function Test-SystemRequirements {
    Write-Progress -Activity "Checking System Requirements" -Status "Verifying system compatibility..." -PercentComplete 0
    
    # Check Windows version
    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        throw "Windows 10 or higher is required"
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        throw "PowerShell 5.0 or higher is required"
    }
    
    # Check available disk space (minimum 1GB)
    $drive = Get-PSDrive -Name ($env:USERPROFILE[0])
    $freeSpace = $drive.Free / 1GB
    if ($freeSpace -lt 1) {
        throw "Insufficient disk space. At least 1GB required"
    }
    
    Write-Progress -Activity "Checking System Requirements" -Status "System requirements met" -PercentComplete 100
}

# Function to verify and install Python
function Install-PythonIfNeeded {
    Write-Progress -Activity "Setting up Python" -Status "Checking Python installation..." -PercentComplete 0
    
    try {
        $pythonVersion = (python --version 2>&1).ToString().Split(" ")[1]
        if (Compare-Versions $pythonVersion $MIN_PYTHON_VERSION -ge 0) {
            Write-Host "✓ Python $pythonVersion is already installed" -ForegroundColor Green
            return
        }
    } catch {
        Write-Host "Python not found or version check failed" -ForegroundColor Yellow
    }
    
    try {
        Write-Host "Downloading Python installer..." -ForegroundColor Cyan
        $pythonUrl = "https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe"
        $installerPath = Join-Path $env:TEMP "python_installer.exe"
        
        # Download with progress bar
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($pythonUrl, $installerPath)
        
        Write-Host "Installing Python..." -ForegroundColor Cyan
        $arguments = "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_pip=1"
        Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait
        
        # Verify installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + 
                    [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        
        $pythonVersion = (python --version 2>&1).ToString().Split(" ")[1]
        if (Compare-Versions $pythonVersion $MIN_PYTHON_VERSION -lt 0) {
            throw "Python installation failed or version is too old"
        }
        
        Write-Host "✓ Python $pythonVersion installed successfully" -ForegroundColor Green
        
    } catch {
        throw "Failed to install Python: $_"
    } finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
}

# Function to verify and install Git
function Install-GitIfNeeded {
    Write-Progress -Activity "Setting up Git" -Status "Checking Git installation..." -PercentComplete 0
    
    try {
        $gitVersion = (git --version 2>&1).ToString().Split(" ")[2]
        if (Compare-Versions $gitVersion $MIN_GIT_VERSION -ge 0) {
            Write-Host "✓ Git $gitVersion is already installed" -ForegroundColor Green
            return
        }
    } catch {
        Write-Host "Git not found or version check failed" -ForegroundColor Yellow
    }
    
    try {
        Write-Host "Downloading Git installer..." -ForegroundColor Cyan
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.35.1.windows.2/Git-2.35.1.2-64-bit.exe"
        $installerPath = Join-Path $env:TEMP "git_installer.exe"
        
        # Download with progress bar
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($gitUrl, $installerPath)
        
        Write-Host "Installing Git..." -ForegroundColor Cyan
        $arguments = "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS"
        Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait
        
        # Verify installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + 
                    [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        
        $gitVersion = (git --version 2>&1).ToString().Split(" ")[2]
        if (Compare-Versions $gitVersion $MIN_GIT_VERSION -lt 0) {
            throw "Git installation failed or version is too old"
        }
        
        Write-Host "✓ Git $gitVersion installed successfully" -ForegroundColor Green
        
    } catch {
        throw "Failed to install Git: $_"
    } finally {
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force
        }
    }
}

# Function to set up WallPimp
function Install-WallPimp {
    Write-Progress -Activity "Installing WallPimp" -Status "Setting up directories..." -PercentComplete 0
    
    # Create installation directory
    $installDir = Join-Path $env:USERPROFILE "WallPimp"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir | Out-Null
    }
    Set-Location $installDir
    
    Write-Progress -Activity "Installing WallPimp" -Status "Cloning repository..." -PercentComplete 33
    
    # Clone or update repository
    try {
        if (Test-Path "wallpimp") {
            Write-Host "Updating existing WallPimp installation..." -ForegroundColor Yellow
            Set-Location wallpimp
            git pull
        } else {
            Write-Host "Cloning WallPimp repository..." -ForegroundColor Cyan
            git clone https://github.com/0xb0rn3/wallpimp.git
            Set-Location wallpimp
        }
    } catch {
        throw "Failed to clone/update repository: $_"
    }
    
    Write-Progress -Activity "Installing WallPimp" -Status "Installing Python dependencies..." -PercentComplete 66
    
    # Install Python dependencies
    try {
        python -m pip install --upgrade pip
        python -m pip install Pillow tqdm
    } catch {
        throw "Failed to install Python dependencies: $_"
    }
    
    Write-Progress -Activity "Installing WallPimp" -Status "Creating shortcuts..." -PercentComplete 90
    
    # Create desktop shortcut
    try {
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\WallPimp.lnk")
        $Shortcut.TargetPath = "cmd.exe"
        $Shortcut.Arguments = "/c python `"$installDir\wallpimp\wallpimp.py`" && pause"
        $Shortcut.WorkingDirectory = "$installDir\wallpimp"
        $Shortcut.Save()
    } catch {
        Write-Warning "Failed to create desktop shortcut: $_"
    }
    
    Write-Progress -Activity "Installing WallPimp" -Status "Installation complete" -PercentComplete 100
}

# Main installation process
function Start-Installation {
    $startTime = Get-Date
    $success = $false
    $errorMessage = $null
    
    try {
        Write-Host "`nWallPimp Setup Script v$SCRIPT_VERSION" -ForegroundColor Cyan
        Write-Host "================================`n" -ForegroundColor Cyan
        
        # Check if running as admin
        if (-not (Test-Administrator)) {
            Write-Host "Note: Script is running without admin privileges. Some features may be limited.`n" -ForegroundColor Yellow
        }
        
        # Run installation steps
        Test-SystemRequirements
        Install-PythonIfNeeded
        Install-GitIfNeeded
        Install-WallPimp
        
        $success = $true
        
    } catch {
        $errorMessage = $_
        Write-Host "`n❌ Error: $errorMessage" -ForegroundColor Red
    } finally {
        if ($success) {
            $duration = (Get-Date) - $startTime
            Write-Host "`n✓ WallPimp installation completed successfully!" -ForegroundColor Green
            Write-Host "Installation time: $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Cyan
            Write-Host "`nInstallation Details:" -ForegroundColor Cyan
            Write-Host "- Installation Directory: $installDir"
            Write-Host "- Desktop shortcut created"
            Write-Host "- Python packages installed"
            
            Write-Host "`nTo run WallPimp, either:" -ForegroundColor Yellow
            Write-Host "1. Double-click the WallPimp shortcut on your desktop"
            Write-Host "2. Open Command Prompt and run: cd $installDir\wallpimp && python wallpimp.py"
            
            # Offer to run WallPimp
            $runNow = Read-Host "`nWould you like to run WallPimp now? (y/n)"
            if ($runNow -eq 'y') {
                Write-Host "`nStarting WallPimp..." -ForegroundColor Green
                Set-Location $installDir\wallpimp
                python wallpimp.py
            }
        } else {
            Write-Host "`nInstallation failed. Please check the error message above and try again." -ForegroundColor Red
            Write-Host "If the problem persists, please report this issue on GitHub." -ForegroundColor Yellow
        }
    }
}

# Start the installation
Start-Installation
