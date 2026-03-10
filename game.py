"""Core game engine for Phone Breaker Extreme."""

import random
import time


ATTACKS = {
    "Smash": {"damage": (15, 30), "description": "A powerful smash with your fist!", "emoji": "👊"},
    "Stomp": {"damage": (20, 40), "description": "Stomp it into the ground!", "emoji": "🦶"},
    "Throw": {"damage": (25, 50), "description": "Hurl it against the wall!", "emoji": "🚀"},
    "Hammer": {"damage": (30, 60), "description": "Strike it with a hammer!", "emoji": "🔨"},
    "Explosion": {"damage": (40, 80), "description": "Blow it up!", "emoji": "💥"},
    "Laser": {"damage": (35, 70), "description": "Zap it with a laser!", "emoji": "🔆"},
}


class Phone:
    """Represents the virtual phone being destroyed."""

    def __init__(self):
        self.max_hp = 500
        self.hp = self.max_hp
        self.cracks = 0
        self.broken_parts = []
        self.is_destroyed = False

    @property
    def destruction_percent(self):
        return max(0, round((1 - self.hp / self.max_hp) * 100, 1))

    @property
    def condition(self):
        pct = self.destruction_percent
        if pct == 0:
            return "Brand New"
        elif pct < 20:
            return "Slightly Scratched"
        elif pct < 40:
            return "Cracked"
        elif pct < 60:
            return "Heavily Damaged"
        elif pct < 80:
            return "Barely Holding Together"
        elif pct < 100:
            return "Nearly Destroyed"
        else:
            return "COMPLETELY DESTROYED"

    def take_damage(self, attack_name):
        """Apply an attack and return result info."""
        if self.is_destroyed:
            return None

        attack = ATTACKS[attack_name]
        min_dmg, max_dmg = attack["damage"]
        damage = random.randint(min_dmg, max_dmg)

        # Critical hit chance (10%)
        critical = random.random() < 0.10
        if critical:
            damage = int(damage * 1.5)

        self.hp = max(0, self.hp - damage)
        self.cracks += 1

        # Track broken parts
        part = self._pick_broken_part()
        if part and part not in self.broken_parts:
            self.broken_parts.append(part)

        if self.hp == 0:
            self.is_destroyed = True

        return {
            "attack": attack_name,
            "emoji": attack["emoji"],
            "description": attack["description"],
            "damage": damage,
            "critical": critical,
            "hp_remaining": self.hp,
            "destruction_percent": self.destruction_percent,
        }

    def _pick_broken_part(self):
        all_parts = [
            "Screen", "Battery", "Camera", "Speaker",
            "Charging Port", "Back Cover", "SIM Tray",
            "Volume Buttons", "Power Button",
        ]
        remaining = [p for p in all_parts if p not in self.broken_parts]
        if not remaining:
            return None
        threshold = self.destruction_percent / 100
        if random.random() < threshold:
            return random.choice(remaining)
        return None

    def get_visual(self):
        """Return an ASCII art representation of the phone's state."""
        pct = self.destruction_percent
        if pct == 0:
            return (
                "┌──────────┐\n"
                "│  ██████  │\n"
                "│  ██████  │\n"
                "│  ██████  │\n"
                "│  ██████  │\n"
                "│    ○     │\n"
                "└──────────┘"
            )
        elif pct < 40:
            return (
                "┌──────────┐\n"
                "│ /██████  │\n"
                "│  ██/███  │\n"
                "│  ██████/ │\n"
                "│  ██/███  │\n"
                "│    ○     │\n"
                "└──────────┘"
            )
        elif pct < 70:
            return (
                "┌─/──/─────┐\n"
                "│ /██\\███  │\n"
                "│  ██/███  │\n"
                "│ /██████/ │\n"
                "│  ██\\███  │\n"
                "│    ○     │\n"
                "└──────/───┘"
            )
        elif pct < 100:
            return (
                "┌─/──\\─────┐\n"
                "│ /██\\███  │\n"
                "│  ##/###  │\n"
                "│ /######/ │\n"
                "│  ##\\###  │\n"
                "│    ○     │\n"
                "└──/───/───┘"
            )
        else:
            return (
                " ___________\n"
                "  # # # # # \n"
                "  # # # # # \n"
                "  # # # # # \n"
                "  # # # # # \n"
                "  # # # # # \n"
                " ─────────── "
            )


class GameSession:
    """Tracks stats for the entire game session."""

    def __init__(self):
        self.phones_destroyed = 0
        self.total_damage = 0
        self.total_attacks = 0
        self.attack_counts = {name: 0 for name in ATTACKS}
        self.critical_hits = 0
        self.session_start = time.time()
        self.current_phone = Phone()

    @property
    def elapsed_time(self):
        return int(time.time() - self.session_start)

    def record_hit(self, result):
        if result is None:
            return
        self.total_damage += result["damage"]
        self.total_attacks += 1
        self.attack_counts[result["attack"]] += 1
        if result["critical"]:
            self.critical_hits += 1

    def next_phone(self):
        if self.current_phone.is_destroyed:
            self.phones_destroyed += 1
        self.current_phone = Phone()

    def get_stats_summary(self):
        elapsed = self.elapsed_time
        minutes, seconds = divmod(elapsed, 60)
        return {
            "phones_destroyed": self.phones_destroyed,
            "total_damage": self.total_damage,
            "total_attacks": self.total_attacks,
            "critical_hits": self.critical_hits,
            "elapsed": f"{minutes:02d}:{seconds:02d}",
            "attack_counts": dict(self.attack_counts),
            "favorite_attack": max(self.attack_counts, key=self.attack_counts.get)
            if self.total_attacks > 0 else "None",
        }
