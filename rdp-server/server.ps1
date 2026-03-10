<#
.SYNOPSIS
    Lightweight PowerShell HTTP server that serves the Phone Breaker Extreme game.

.DESCRIPTION
    Uses System.Net.HttpListener to serve static files from the game directory.
    This is the fallback web server used by start-game-server.ps1 when Python
    is not available.

.PARAMETER GameDir
    Path to the directory containing index.html and all game assets.
    Defaults to the parent directory of this script.

.PARAMETER Port
    TCP port to listen on.  Defaults to 8080.

.EXAMPLE
    # Start with defaults (serves parent directory on port 8080):
    .\server.ps1

.EXAMPLE
    # Specify a custom game directory and port:
    .\server.ps1 -GameDir "C:\Games\PhoneBreaker" -Port 9090
#>

[CmdletBinding()]
param(
    [string]$GameDir = (Split-Path -Parent $PSScriptRoot),
    [int]   $Port    = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── MIME type map ─────────────────────────────────────────────────────────────
$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".mjs"  = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
    ".txt"  = "text/plain; charset=utf-8"
}

function Get-MimeType([string]$ext) {
    $mime = $MimeTypes[$ext.ToLower()]
    if ($mime) { return $mime }
    return "application/octet-stream"
}

function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]   $StatusCode,
        [string]$ContentType,
        [byte[]]$Body
    )
    $Response.StatusCode  = $StatusCode
    $Response.ContentType = $ContentType
    if ($Body -and $Body.Length -gt 0) {
        $Response.ContentLength64 = $Body.Length
        $Response.OutputStream.Write($Body, 0, $Body.Length)
    }
    $Response.OutputStream.Close()
}

function Send-TextResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]   $StatusCode,
        [string]$Text
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Send-Response -Response $Response -StatusCode $StatusCode `
                  -ContentType "text/html; charset=utf-8" -Body $bytes
}

# ── Validate game directory ───────────────────────────────────────────────────
$GameDir = (Resolve-Path $GameDir).Path
if (-not (Test-Path (Join-Path $GameDir "index.html"))) {
    Write-Error "index.html not found in '$GameDir'. Check -GameDir parameter."
    exit 1
}

# ── Start HTTP listener ───────────────────────────────────────────────────────
$prefix  = "http://+:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Error ("Failed to start HTTP listener on port $Port. " +
                 "Try running as Administrator or choose a different port.`n$_")
    exit 1
}

Write-Host ""
Write-Host "  Phone Breaker Extreme – HTTP Server" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ("  Serving : {0}" -f $GameDir)         -ForegroundColor White
Write-Host ("  URL     : http://localhost:{0}/"  -f $Port) -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop."               -ForegroundColor Yellow
Write-Host ""

# ── Request loop ──────────────────────────────────────────────────────────────
try {
    while ($listener.IsListening) {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        $rawPath = $request.Url.AbsolutePath

        # Decode percent-encoded characters
        $decodedPath = [Uri]::UnescapeDataString($rawPath)

        # Default to index.html
        if ($decodedPath -eq "/" -or $decodedPath -eq "") {
            $decodedPath = "/index.html"
        }

        # Prevent path traversal attacks
        $safePath   = $decodedPath.TrimStart("/").Replace("/", [IO.Path]::DirectorySeparatorChar)
        $fullPath   = [IO.Path]::GetFullPath((Join-Path $GameDir $safePath))

        if (-not $fullPath.StartsWith($GameDir, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Host ("  [403] {0}" -f $rawPath) -ForegroundColor Red
            Send-TextResponse -Response $response -StatusCode 403 -Text "403 Forbidden"
            continue
        }

        if (-not (Test-Path $fullPath -PathType Leaf)) {
            Write-Host ("  [404] {0}" -f $rawPath) -ForegroundColor DarkYellow
            Send-TextResponse -Response $response -StatusCode 404 `
                              -Text "<h1>404 Not Found</h1><p>$rawPath</p>"
            continue
        }

        $ext      = [IO.Path]::GetExtension($fullPath)
        $mime     = Get-MimeType $ext
        $content  = [IO.File]::ReadAllBytes($fullPath)

        Write-Host ("  [200] {0}" -f $rawPath) -ForegroundColor DarkGray
        Send-Response -Response $response -StatusCode 200 `
                      -ContentType $mime -Body $content
    }
} catch [System.Net.HttpListenerException] {
    # Listener was stopped (Ctrl+C) – exit cleanly
} finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "`n  Server stopped." -ForegroundColor Yellow
}
