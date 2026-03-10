@echo off
:: ============================================================
::  start-game-server.bat
::  Starts a local HTTP server and opens Phone Breaker Extreme
::  in the default browser.
::
::  Supported web-server back-ends (tried in order):
::    1. Python 3  (python -m http.server)
::    2. Python 2  (python -m SimpleHTTPServer)
::    3. PowerShell built-in HTTP listener (rdp-server\server.ps1)
:: ============================================================

setlocal enabledelayedexpansion

set PORT=8080
set SCRIPT_DIR=%~dp0

echo.
echo  =====================================================
echo   Phone Breaker Extreme -- Game Server Launcher
echo  =====================================================
echo.

:: ── Locate project root (folder containing index.html) ──────────────────────
if exist "%SCRIPT_DIR%index.html" (
    set GAME_DIR=%SCRIPT_DIR%
) else (
    echo  [ERROR] index.html not found in %SCRIPT_DIR%
    echo  Please run this script from the repository root.
    pause
    exit /b 1
)

:: ── Try Python 3 ─────────────────────────────────────────────────────────────
python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
    echo  [INFO] Found Python !PYVER! -- using python -m http.server
    echo  [INFO] Game available at: http://localhost:%PORT%
    echo  [INFO] Press Ctrl+C to stop the server.
    echo.
    start "" "http://localhost:%PORT%"
    cd /d "%GAME_DIR%"
    python -m http.server %PORT%
    goto :eof
)

:: ── Try Python 2 ─────────────────────────────────────────────────────────────
python2 --version >nul 2>&1
if %errorlevel% equ 0 (
    echo  [INFO] Found Python 2 -- using SimpleHTTPServer
    echo  [INFO] Game available at: http://localhost:%PORT%
    echo  [INFO] Press Ctrl+C to stop the server.
    echo.
    start "" "http://localhost:%PORT%"
    cd /d "%GAME_DIR%"
    python2 -m SimpleHTTPServer %PORT%
    goto :eof
)

:: ── Fall back to PowerShell HTTP listener ────────────────────────────────────
where powershell >nul 2>&1
if %errorlevel% equ 0 (
    echo  [INFO] Python not found -- using PowerShell HTTP listener
    echo  [INFO] Game available at: http://localhost:%PORT%
    echo  [INFO] Close the PowerShell window to stop the server.
    echo.
    start "" "http://localhost:%PORT%"
    powershell.exe -NoProfile -ExecutionPolicy Bypass ^
        -File "%SCRIPT_DIR%rdp-server\server.ps1" ^
        -GameDir "%GAME_DIR%" ^
        -Port %PORT%
    goto :eof
)

:: ── No suitable server found ─────────────────────────────────────────────────
echo  [ERROR] No suitable web server found.
echo.
echo  To serve the game, install one of the following:
echo    * Python 3: https://www.python.org/downloads/
echo    * Python 2: https://www.python.org/downloads/release/python-2718/
echo.
echo  Alternatively, open index.html directly in your browser
echo  (some browser features may be limited without a server).
echo.
pause
exit /b 1
