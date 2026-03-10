#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes all existing Python installations and installs Python 3.11.9.

.DESCRIPTION
    This script:
      1. Discovers every installed Python version via the registry and
         uninstalls each one silently.
      2. Removes leftover Python files from common install locations
         (%ProgramFiles%, %ProgramFiles(x86)%, %LocalAppData%, %AppData%).
      3. Downloads the official Python 3.11.9 installer from python.org.
      4. Installs Python 3.11.9 for all users with pip and the py launcher.
      5. Adds Python to the system PATH if not already present.
      6. Verifies the final installation by printing the version.

.PARAMETER InstallDir
    Where Python 3.11.9 will be installed.
    Defaults to "C:\Python311".

.PARAMETER SkipDownload
    If specified, skip the download step and expect the installer to already
    exist at "%TEMP%\python-3.11.9-amd64.exe".

.EXAMPLE
    # Standard install:
    .\install-python.ps1

.EXAMPLE
    # Install to a custom directory:
    .\install-python.ps1 -InstallDir "D:\Python311"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallDir   = "C:\Python311",
    [switch]$SkipDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PythonVersion  = "3.11.9"
$InstallerName  = "python-${PythonVersion}-amd64.exe"
$InstallerUrl   = "https://www.python.org/ftp/python/${PythonVersion}/${InstallerName}"
$InstallerPath  = Join-Path $env:TEMP $InstallerName

function Write-Step([string]$msg) {
    Write-Host "`n>>> $msg" -ForegroundColor Cyan
}

# ── Helper: silently uninstall a product by its MSI ProductCode ──────────────
function Uninstall-ByProductCode([string]$code) {
    $args = @("/x", $code, "/quiet", "/norestart")
    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $args `
                          -Wait -PassThru -NoNewWindow
    return $proc.ExitCode
}

# ── Helper: silently uninstall via an EXE uninstaller string ─────────────────
function Uninstall-ByString([string]$uninstallString) {
    # Split "C:\path\uninstall.exe" /S  →  exe + args
    if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
        $exe  = $Matches[1]
        $rest = $Matches[2]
    } elseif ($uninstallString -match '^(\S+)\s*(.*)$') {
        $exe  = $Matches[1]
        $rest = $Matches[2]
    } else {
        return 1
    }
    $rest = "$rest /quiet /uninstall".Trim()
    $proc = Start-Process -FilePath $exe -ArgumentList $rest `
                          -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
    return if ($proc) { $proc.ExitCode } else { 1 }
}

# ── 1. Uninstall existing Python versions ────────────────────────────────────
Write-Step "Scanning for installed Python versions..."

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$pythonEntries = foreach ($path in $regPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match "Python \d" }
}

if ($pythonEntries) {
    Write-Host ("  Found {0} Python installation(s):" -f @($pythonEntries).Count) -ForegroundColor Yellow
    foreach ($entry in $pythonEntries) {
        Write-Host ("    - {0}  [{1}]" -f $entry.DisplayName, $entry.PSChildName) -ForegroundColor White
    }

    foreach ($entry in $pythonEntries) {
        $name = $entry.DisplayName
        Write-Host "  Uninstalling: $name ..." -ForegroundColor Yellow -NoNewline

        $exitCode = 0
        if ($entry.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$') {
            # MSI-based installer
            $exitCode = Uninstall-ByProductCode $entry.PSChildName
        } elseif ($entry.UninstallString) {
            $exitCode = Uninstall-ByString $entry.UninstallString
        }

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Host " done." -ForegroundColor Green
        } else {
            Write-Host (" exit code $exitCode – continuing.") -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "  No existing Python installations found." -ForegroundColor Green
}

# ── 2. Remove leftover Python directories ────────────────────────────────────
Write-Step "Removing leftover Python files and directories..."

$leftoverRoots = @(
    "$env:ProgramFiles\Python3*",
    "$env:ProgramFiles\Python*",
    "${env:ProgramFiles(x86)}\Python3*",
    "${env:ProgramFiles(x86)}\Python*",
    "$env:LocalAppData\Programs\Python\Python3*",
    "$env:LocalAppData\Programs\Python",
    "$env:AppData\Python"
)

foreach ($pattern in $leftoverRoots) {
    $resolved = Resolve-Path $pattern -ErrorAction SilentlyContinue
    if ($resolved) {
        foreach ($item in $resolved) {
            Write-Host "  Removing: $($item.Path)" -ForegroundColor Yellow
            Remove-Item -Path $item.Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Remove py launcher
$pyLauncher = Join-Path $env:windir "py.exe"
if (Test-Path $pyLauncher) {
    Write-Host "  Removing py launcher: $pyLauncher" -ForegroundColor Yellow
    Remove-Item $pyLauncher -Force -ErrorAction SilentlyContinue
}

Write-Host "  Leftover cleanup complete." -ForegroundColor Green

# ── 3. Remove old .bat files left by previous Python installers ───────────────
Write-Step "Removing Python-related batch (.bat) files..."

$batSearchRoots = @(
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    "$env:LocalAppData\Programs"
)

foreach ($root in $batSearchRoots) {
    if (-not (Test-Path $root)) { continue }
    $batFiles = Get-ChildItem -Path $root -Recurse -Filter "*.bat" -ErrorAction SilentlyContinue |
                Where-Object { $_.DirectoryName -match "(?i)python" }
    foreach ($bat in $batFiles) {
        Write-Host "  Removing: $($bat.FullName)" -ForegroundColor Yellow
        Remove-Item $bat.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "  Batch file cleanup complete." -ForegroundColor Green

# ── 4. Download Python 3.11.9 installer ──────────────────────────────────────
if (-not $SkipDownload) {
    Write-Step "Downloading Python ${PythonVersion} installer..."
    Write-Host "  Source : $InstallerUrl"
    Write-Host "  Target : $InstallerPath"

    $webClient = New-Object System.Net.WebClient
    try {
        $webClient.DownloadFile($InstallerUrl, $InstallerPath)
        Write-Host "  Download complete." -ForegroundColor Green
    } finally {
        $webClient.Dispose()
    }
} else {
    Write-Host "  -SkipDownload set – expecting installer at: $InstallerPath" -ForegroundColor Yellow
    if (-not (Test-Path $InstallerPath)) {
        throw "Installer not found at '$InstallerPath'. Remove -SkipDownload to download automatically."
    }
}

# ── 5. Install Python 3.11.9 ─────────────────────────────────────────────────
Write-Step "Installing Python ${PythonVersion} to '$InstallDir'..."

$installArgs = @(
    "/quiet",
    "InstallAllUsers=1",
    "TargetDir=$InstallDir",
    "PrependPath=1",
    "Include_pip=1",
    "Include_launcher=1",
    "Include_test=0",
    "Include_doc=0"
)

$proc = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs `
                      -Wait -PassThru -NoNewWindow

if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "Python installer exited with code $($proc.ExitCode)."
}
Write-Host "  Python ${PythonVersion} installed." -ForegroundColor Green

# Clean up downloaded installer
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

# ── 6. Refresh PATH in current session ───────────────────────────────────────
Write-Step "Refreshing PATH..."

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path    = "$machinePath;$userPath"

# ── 7. Verify installation ────────────────────────────────────────────────────
Write-Step "Verifying installation..."

$pyExe = Join-Path $InstallDir "python.exe"
if (Test-Path $pyExe) {
    $verOutput = & $pyExe --version 2>&1
    Write-Host ("  {0}" -f $verOutput) -ForegroundColor Green
} else {
    Write-Host "  python.exe not found at '$InstallDir' – check installation logs." -ForegroundColor Red
    exit 1
}

# ── 8. Summary ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │       Python ${PythonVersion} Ready                   │" -ForegroundColor White
Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor White
Write-Host ("  │  Install dir : {0,-29}│" -f $InstallDir)          -ForegroundColor Green
Write-Host ("  │  pip         : {0,-29}│" -f (Join-Path $InstallDir "Scripts\pip.exe")) -ForegroundColor Green
Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │  Next step: start the game server            │" -ForegroundColor Yellow
Write-Host "  │    .\start-game-server.ps1                   │" -ForegroundColor White
Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""
