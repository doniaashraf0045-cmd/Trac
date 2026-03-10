#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Sets up a Windows RDP server with a local HTTP game server for Phone Breaker Extreme.

.DESCRIPTION
    This script:
      1. Enables Remote Desktop (RDP) on the local Windows machine.
      2. Opens TCP port 3389 in Windows Firewall for RDP connections.
      3. Opens TCP port 8080 in Windows Firewall for the game web server.
      4. Optionally creates a dedicated local user account for RDP access.
      5. Prints the machine's IP address so clients can connect.

.PARAMETER RdpUser
    (Optional) Name of a new local user account to create for RDP access.
    If omitted, no new user is created and existing accounts are used.

.PARAMETER RdpPassword
    (Optional) Password for the new RDP user.  Required when -RdpUser is supplied.

.PARAMETER GamePort
    Port on which the HTTP game server will listen.  Defaults to 8080.

.EXAMPLE
    # Enable RDP only (use existing accounts):
    .\setup-windows-rdp.ps1

.EXAMPLE
    # Enable RDP and create a dedicated user:
    .\setup-windows-rdp.ps1 -RdpUser "gamer" -RdpPassword "P@ssw0rd!"
#>

[CmdletBinding()]
param(
    [string]$RdpUser     = "",
    [string]$RdpPassword = "",
    [int]   $GamePort    = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) {
    Write-Host "`n>>> $msg" -ForegroundColor Cyan
}

# ── 1. Enable Remote Desktop ──────────────────────────────────────────────────
Write-Step "Enabling Remote Desktop..."

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
                 -Name "fDenyTSConnections" -Value 0

# Allow Network Level Authentication (recommended)
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
                 -Name "UserAuthentication" -Value 1

Write-Host "  Remote Desktop enabled." -ForegroundColor Green

# ── 2. Configure Windows Firewall for RDP (port 3389) ────────────────────────
Write-Step "Configuring firewall rule for RDP (TCP 3389)..."

$rdpRule = Get-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)" -ErrorAction SilentlyContinue
if ($rdpRule) {
    Enable-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)"
    Write-Host "  Built-in RDP firewall rule enabled." -ForegroundColor Green
} else {
    New-NetFirewallRule -DisplayName "Phone Breaker RDP" `
                        -Direction Inbound `
                        -Protocol TCP `
                        -LocalPort 3389 `
                        -Action Allow `
                        -Profile Any | Out-Null
    Write-Host "  New RDP firewall rule created." -ForegroundColor Green
}

# ── 3. Configure Windows Firewall for game HTTP server ───────────────────────
Write-Step "Configuring firewall rule for game server (TCP $GamePort)..."

$gameRuleName = "Phone Breaker Game Server (TCP $GamePort)"
$existingGameRule = Get-NetFirewallRule -DisplayName $gameRuleName -ErrorAction SilentlyContinue
if (-not $existingGameRule) {
    New-NetFirewallRule -DisplayName $gameRuleName `
                        -Direction Inbound `
                        -Protocol TCP `
                        -LocalPort $GamePort `
                        -Action Allow `
                        -Profile Any | Out-Null
}
Write-Host "  Game server firewall rule configured on port $GamePort." -ForegroundColor Green

# ── 4. (Optional) Create a dedicated local RDP user ──────────────────────────
if ($RdpUser -ne "") {
    Write-Step "Creating local user account '$RdpUser'..."

    if (-not $RdpPassword) {
        throw "You must supply -RdpPassword when -RdpUser is specified."
    }

    $securePass = ConvertTo-SecureString $RdpPassword -AsPlainText -Force
    $existing   = Get-LocalUser -Name $RdpUser -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  User '$RdpUser' already exists – updating password." -ForegroundColor Yellow
        Set-LocalUser -Name $RdpUser -Password $securePass
    } else {
        New-LocalUser -Name $RdpUser `
                      -Password $securePass `
                      -FullName "Phone Breaker RDP User" `
                      -Description "Dedicated account for Phone Breaker Extreme RDP access" `
                      -PasswordNeverExpires | Out-Null
        Write-Host "  User '$RdpUser' created." -ForegroundColor Green
    }

    # Add to Remote Desktop Users group
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $RdpUser -ErrorAction SilentlyContinue
    Write-Host "  '$RdpUser' added to 'Remote Desktop Users' group." -ForegroundColor Green
}

# ── 5. Print connection info ─────────────────────────────────────────────────
Write-Step "Setup complete!"

$ipAddresses = (Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.IPAddress -ne "127.0.0.1" } |
                Select-Object -ExpandProperty IPAddress)

Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │         Windows RDP Server is ready          │" -ForegroundColor White
Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor White
foreach ($ip in $ipAddresses) {
    Write-Host ("  │  RDP   : {0,-36}│" -f "rdp://${ip}:3389") -ForegroundColor Green
    Write-Host ("  │  Game  : {0,-36}│" -f "http://${ip}:${GamePort}") -ForegroundColor Green
}
Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""
Write-Host "  To start the game web server, run:" -ForegroundColor Yellow
Write-Host "    .\start-game-server.ps1" -ForegroundColor White
Write-Host ""
Write-Host "  RDP clients can now connect using one of the IP addresses above." -ForegroundColor Yellow
