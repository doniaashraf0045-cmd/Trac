# Phone Breaker Extreme 💥

A stress-relief game where you perform super attacks on a virtual mobile phone
and track its destruction stats.

Built in **pure Python** (standard library only) — runs on any VPS, RDP session,
or local desktop with Python 3.7+.

---

## Features

- 6 unique attacks: Smash, Stomp, Throw, Hammer, Explosion, Laser
- HP bar, destruction percentage, and per-part damage tracking
- ASCII-art phone that visually degrades as you attack
- Critical-hit system (10% chance, 1.5× damage)
- Live session stats: total attacks, total damage, critical hits, phones destroyed, elapsed time
- Single-file GUI using **tkinter** — no external dependencies

---

## Requirements

- Python 3.7 or higher
- `tkinter` (bundled with the standard Python installer on Windows/macOS;
  on Ubuntu/Debian: `sudo apt-get install python3-tk`)

---

## Running on a VPS / RDP Server

Because the GUI uses **tkinter** (the standard Python GUI toolkit), it works
out of the box over any Remote Desktop (RDP) or VNC session — no extra
display server configuration is needed.

```bash
# 1. Clone the repository
git clone https://github.com/doniaashraf0045-cmd/Trac.git
cd Trac

# 2. (Optional) Create a virtual environment
python -m venv .venv
source .venv/bin/activate          # Linux / macOS
.venv\Scripts\activate             # Windows

# 3. Run the game
python main.py
```

On a headless Linux server without RDP, forward the display via SSH X11:

```bash
ssh -X user@your-vps-ip
python main.py
```

---

## Running Tests

```bash
pip install pytest
python -m pytest test_game.py -v
```

---

## Project Structure

| File | Purpose |
|------|---------|
| `main.py` | Entry point — checks environment and launches the GUI |
| `game.py` | Core game engine: `Phone`, `GameSession`, attack definitions |
| `ui.py` | Tkinter GUI (`PhoneBreakerApp`) |
| `test_game.py` | Pytest test suite for the game engine |
| `requirements.txt` | Optional dev dependency (pytest) |
