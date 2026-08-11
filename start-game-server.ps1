<#
.SYNOPSIS
    Starts a local HTTP server and opens Phone Breaker Extreme in the browser.

.DESCRIPTION
    Tries to serve the game using Python 3's built-in http.server module.
    Falls back to the pure-PowerShell listener (rdp-server\server.ps1) when
    Python is not found on the PATH.

.PARAMETER Port
    TCP port to listen on.  Defaults to 8080.

.PARAMETER NoBrowser
    When set, the script starts the server but does NOT open the browser.

.EXAMPLE
    # Start on the default port and open the browser automatically:
    .\start-game-server.ps1

.EXAMPLE
    # Start on a custom port without opening the browser:
    .\start-game-server.ps1 -Port 9090 -NoBrowser
#>

[CmdletBinding()]
param(
    [int]   $Port      = 8080,
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameDir   = $ScriptDir   # index.html lives in the repo root

# ── Sanity check ──────────────────────────────────────────────────────────────
if (-not (Test-Path (Join-Path $GameDir "index.html"))) {
    Write-Error "index.html not found in '$GameDir'. Run this script from the repository root."
    exit 1
}

$Url = "http://localhost:$Port"

function Open-Browser([string]$url) {
    try { Start-Process $url } catch { <# ignore #> }
}

# ── Try Python 3 ──────────────────────────────────────────────────────────────
$python = Get-Command "python" -ErrorAction SilentlyContinue

if ($python) {
    $verText = & python --version 2>&1
    Write-Host ""
    Write-Host "  Phone Breaker Extreme – Game Server" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ("  Runtime : {0}" -f $verText)      -ForegroundColor White
    Write-Host ("  URL     : {0}" -f $Url)           -ForegroundColor Green
    Write-Host "  Press Ctrl+C to stop."             -ForegroundColor Yellow
    Write-Host ""

    if (-not $NoBrowser) { Open-Browser $Url }

    Push-Location $GameDir
    try {
        & python -m http.server $Port
    } finally {
        Pop-Location
    }
    exit 0
}

# ── Fall back to PowerShell HTTP listener ────────────────────────────────────
$fallback = Join-Path $ScriptDir "rdp-server\server.ps1"
if (Test-Path $fallback) {
    Write-Host ""
    Write-Host "  Python not found – using PowerShell HTTP listener." -ForegroundColor Yellow
    Write-Host ("  URL : {0}" -f $Url) -ForegroundColor Green
    Write-Host ""

    if (-not $NoBrowser) { Open-Browser $Url }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
                     -File $fallback `
                     -GameDir $GameDir `
                     -Port $Port
    exit 0
}

# ── No server available ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "  [ERROR] No suitable web server found." -ForegroundColor Red
Write-Host ""
Write-Host "  Install Python 3.11.9 by running (as Administrator):" -ForegroundColor Yellow
Write-Host "    .\install-python.ps1" -ForegroundColor White
Write-Host ""
Write-Host "  Alternatively, open index.html directly in your browser." -ForegroundColor DarkGray
Write-Host ""
exit 1
