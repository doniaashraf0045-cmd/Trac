# Phone Breaker Extreme

A stress-relief game where you perform super attacks on a virtual mobile phone and track its destruction stats.

---

## Playing the Game

Open `index.html` in any modern browser — no build step required.

---

## Windows RDP Server Setup

The scripts in this repository let you host the game on a **Windows VPS / RDP server** so
multiple players can access it from any device with a browser or an RDP client.

### Files

| File | Purpose |
|------|---------|
| `setup-windows-rdp.ps1` | Enables Windows RDP, configures firewall rules, and optionally creates a dedicated user account |
| `start-game-server.bat` | Starts a local HTTP server (Python or PowerShell) and opens the game in the browser |
| `rdp-server/server.ps1` | Pure-PowerShell HTTP file server (fallback when Python is not available) |

### Quick-start (server side — run once)

1. **Open PowerShell as Administrator** on your Windows server.

2. **Enable RDP and configure firewall rules:**

   ```powershell
   # Allow execution of the setup script
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

   # Basic setup (uses existing user accounts)
   .\setup-windows-rdp.ps1

   # Or create a dedicated RDP user at the same time
   .\setup-windows-rdp.ps1 -RdpUser "gamer" -RdpPassword "P@ssw0rd!"
   ```

3. **Start the game web server:**

   ```bat
   start-game-server.bat
   ```

   The game will be available at `http://<server-ip>:8080`.

### Connecting via RDP (client side)

| Operating System | Steps |
|---|---|
| **Windows** | Start → Remote Desktop Connection → enter server IP → Connect |
| **macOS** | Install [Microsoft Remote Desktop](https://apps.apple.com/app/microsoft-remote-desktop/id1295203466) → add PC → enter server IP |
| **Linux** | `xfreerdp /v:<server-ip> /u:<username>` |
| **Android / iOS** | Microsoft Remote Desktop app → add PC → enter server IP |

Once connected via RDP, open the browser on the server and navigate to `http://localhost:8080`.

### Requirements

- Windows Server 2016 / 2019 / 2022 **or** Windows 10 / 11 Pro (RDP host)
- PowerShell 5.1 or later (included in all supported Windows versions)
- Python 3 *(optional — recommended for the HTTP server)*
- Administrator privileges (for `setup-windows-rdp.ps1` only)

### Firewall ports

| Port | Protocol | Service |
|------|----------|---------|
| `3389` | TCP | Windows Remote Desktop (RDP) |
| `8080` | TCP | Phone Breaker Extreme web server |

> **Tip:** If your server is behind a cloud firewall (AWS Security Groups, Azure NSG, GCP
> Firewall Rules, etc.) make sure to open ports **3389** and **8080** in the cloud console as
> well.

---

## License

MIT
