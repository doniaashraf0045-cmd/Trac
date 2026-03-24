"""Tkinter GUI for Phone Breaker Extreme — works over VPS/RDP."""

import time
import tkinter as tk
from tkinter import font as tkfont
import threading

from game import ATTACKS, GameSession


# ── Colour palette ──────────────────────────────────────────────
BG_DARK = "#1a1a2e"
BG_MID = "#16213e"
BG_CARD = "#0f3460"
ACCENT = "#e94560"
ACCENT2 = "#f5a623"
TEXT_LIGHT = "#eaeaea"
TEXT_DIM = "#a0a0b0"
GREEN = "#4caf50"
YELLOW = "#ffeb3b"
RED = "#f44336"
HP_BG = "#333355"


class PhoneBreakerApp(tk.Tk):
    """Main application window."""

    def __init__(self):
        super().__init__()
        self.title("Phone Breaker Extreme 💥")
        self.configure(bg=BG_DARK)
        self.resizable(True, True)
        self.minsize(720, 580)

        self.session = GameSession()

        self._build_fonts()
        self._build_layout()
        self._refresh_ui()
        self._start_timer()

    # ── Font setup ───────────────────────────────────────────────

    def _build_fonts(self):
        self.font_title = tkfont.Font(family="Helvetica", size=20, weight="bold")
        self.font_big = tkfont.Font(family="Helvetica", size=14, weight="bold")
        self.font_body = tkfont.Font(family="Courier", size=11)
        self.font_small = tkfont.Font(family="Helvetica", size=10)
        self.font_emoji = tkfont.Font(family="Helvetica", size=13)

    # ── Layout ───────────────────────────────────────────────────

    def _build_layout(self):
        # Title bar
        title_frame = tk.Frame(self, bg=BG_MID, pady=8)
        title_frame.pack(fill="x")
        tk.Label(
            title_frame,
            text="💥 PHONE BREAKER EXTREME 💥",
            font=self.font_title,
            fg=ACCENT,
            bg=BG_MID,
        ).pack()

        # Main content area
        content = tk.Frame(self, bg=BG_DARK)
        content.pack(fill="both", expand=True, padx=10, pady=8)

        # Left column: phone visual + hp
        left = tk.Frame(content, bg=BG_DARK)
        left.pack(side="left", fill="both", expand=True, padx=(0, 6))
        self._build_phone_panel(left)

        # Right column: attacks + log
        right = tk.Frame(content, bg=BG_DARK)
        right.pack(side="right", fill="both", expand=True, padx=(6, 0))
        self._build_attack_panel(right)
        self._build_log_panel(right)

        # Bottom stats bar
        self._build_stats_bar()

    def _build_phone_panel(self, parent):
        frame = tk.Frame(parent, bg=BG_CARD, bd=2, relief="ridge")
        frame.pack(fill="both", expand=True)

        tk.Label(
            frame, text="TARGET PHONE", font=self.font_big,
            fg=ACCENT2, bg=BG_CARD,
        ).pack(pady=(8, 0))

        # ASCII art phone display
        self.phone_art_var = tk.StringVar()
        self.phone_art_label = tk.Label(
            frame,
            textvariable=self.phone_art_var,
            font=self.font_body,
            fg=TEXT_LIGHT,
            bg=BG_CARD,
            justify="center",
        )
        self.phone_art_label.pack(pady=6)

        # Condition label
        self.condition_var = tk.StringVar()
        self.condition_label = tk.Label(
            frame,
            textvariable=self.condition_var,
            font=self.font_big,
            fg=YELLOW,
            bg=BG_CARD,
        )
        self.condition_label.pack()

        # HP bar
        hp_container = tk.Frame(frame, bg=BG_CARD)
        hp_container.pack(fill="x", padx=20, pady=(6, 2))

        self.hp_label = tk.Label(
            hp_container, text="HP: 500 / 500",
            font=self.font_small, fg=TEXT_LIGHT, bg=BG_CARD,
        )
        self.hp_label.pack(anchor="w")

        self.hp_canvas = tk.Canvas(hp_container, height=18, bg=HP_BG,
                                   highlightthickness=0)
        self.hp_canvas.pack(fill="x", pady=2)

        # Destruction % label
        self.dest_var = tk.StringVar()
        tk.Label(
            frame, textvariable=self.dest_var,
            font=self.font_small, fg=ACCENT, bg=BG_CARD,
        ).pack()

        # Broken parts list
        tk.Label(
            frame, text="Broken Parts:", font=self.font_small,
            fg=TEXT_DIM, bg=BG_CARD,
        ).pack(pady=(8, 0))
        self.parts_var = tk.StringVar()
        tk.Label(
            frame, textvariable=self.parts_var,
            font=self.font_small, fg=RED, bg=BG_CARD,
            wraplength=230, justify="center",
        ).pack()

        # New phone button (disabled until phone destroyed)
        self.new_phone_btn = tk.Button(
            frame,
            text="🔄  New Phone",
            font=self.font_big,
            bg=GREEN, fg="white",
            activebackground="#45a049",
            relief="flat",
            padx=12, pady=6,
            command=self._new_phone,
            state="disabled",
        )
        self.new_phone_btn.pack(pady=10)

    def _build_attack_panel(self, parent):
        frame = tk.Frame(parent, bg=BG_CARD, bd=2, relief="ridge")
        frame.pack(fill="x", pady=(0, 6))

        tk.Label(
            frame, text="CHOOSE YOUR ATTACK",
            font=self.font_big, fg=ACCENT2, bg=BG_CARD,
        ).pack(pady=(8, 4))

        btn_frame = tk.Frame(frame, bg=BG_CARD)
        btn_frame.pack(padx=10, pady=(0, 8))

        self.attack_buttons = {}
        colours = [ACCENT, "#9c27b0", "#2196f3", "#ff5722", "#009688", "#795548"]

        for i, (name, info) in enumerate(ATTACKS.items()):
            col = colours[i % len(colours)]
            btn = tk.Button(
                btn_frame,
                text=f"{info['emoji']}  {name}",
                font=self.font_emoji,
                bg=col,
                fg="white",
                activebackground=self._lighten(col),
                relief="flat",
                padx=10, pady=5,
                width=15,
                command=lambda n=name: self._do_attack(n),
            )
            btn.grid(row=i // 2, column=i % 2, padx=5, pady=4, sticky="ew")
            self.attack_buttons[name] = btn

        btn_frame.columnconfigure(0, weight=1)
        btn_frame.columnconfigure(1, weight=1)

    def _build_log_panel(self, parent):
        frame = tk.Frame(parent, bg=BG_CARD, bd=2, relief="ridge")
        frame.pack(fill="both", expand=True)

        tk.Label(
            frame, text="BATTLE LOG",
            font=self.font_big, fg=ACCENT2, bg=BG_CARD,
        ).pack(pady=(6, 2))

        self.log_text = tk.Text(
            frame,
            height=8,
            bg=BG_MID,
            fg=TEXT_LIGHT,
            font=self.font_small,
            state="disabled",
            relief="flat",
            wrap="word",
        )
        self.log_text.pack(fill="both", expand=True, padx=6, pady=(0, 6))

    def _build_stats_bar(self):
        frame = tk.Frame(self, bg=BG_MID, pady=4)
        frame.pack(fill="x", side="bottom")

        self.stats_labels = {}
        fields = [
            ("phones_destroyed", "📱 Destroyed"),
            ("total_attacks", "⚡ Attacks"),
            ("total_damage", "💢 Damage"),
            ("critical_hits", "🎯 Crits"),
            ("elapsed", "⏱ Time"),
        ]
        for key, label in fields:
            col = tk.Frame(frame, bg=BG_MID)
            col.pack(side="left", expand=True)
            tk.Label(col, text=label, font=self.font_small,
                     fg=TEXT_DIM, bg=BG_MID).pack()
            var = tk.StringVar(value="0")
            lbl = tk.Label(col, textvariable=var, font=self.font_big,
                           fg=ACCENT2, bg=BG_MID)
            lbl.pack()
            self.stats_labels[key] = var

    # ── Game actions ─────────────────────────────────────────────

    def _do_attack(self, attack_name):
        phone = self.session.current_phone
        if phone.is_destroyed:
            return

        result = phone.take_damage(attack_name)
        self.session.record_hit(result)
        self._refresh_ui()
        self._log_attack(result)

        if phone.is_destroyed:
            self._on_phone_destroyed()

    def _on_phone_destroyed(self):
        for btn in self.attack_buttons.values():
            btn.config(state="disabled")
        self.new_phone_btn.config(state="normal")
        self._log("🔥 PHONE COMPLETELY DESTROYED! 🔥", colour=ACCENT)

    def _new_phone(self):
        self.session.next_phone()
        for btn in self.attack_buttons.values():
            btn.config(state="normal")
        self.new_phone_btn.config(state="disabled")
        self._refresh_ui()
        phones = self.session.phones_destroyed
        self._log(f"📱 New phone #{phones + 1} is ready — destroy it!", colour=GREEN)

    # ── UI refresh ───────────────────────────────────────────────

    def _refresh_ui(self):
        phone = self.session.current_phone

        # Phone visual
        self.phone_art_var.set(phone.get_visual())
        self.condition_var.set(phone.condition)
        self.dest_var.set(f"Destruction: {phone.destruction_percent}%")

        # HP label + bar
        self.hp_label.config(text=f"HP: {phone.hp} / {phone.max_hp}")
        self._draw_hp_bar(phone.hp, phone.max_hp)

        # Broken parts
        parts_text = ", ".join(phone.broken_parts) if phone.broken_parts else "None"
        self.parts_var.set(parts_text)

        # Stats bar
        stats = self.session.get_stats_summary()
        for key, var in self.stats_labels.items():
            var.set(str(stats.get(key, "0")))

    def _draw_hp_bar(self, hp, max_hp):
        self.hp_canvas.update_idletasks()
        w = self.hp_canvas.winfo_width()
        if w < 2:
            w = 200
        ratio = hp / max_hp if max_hp else 0
        bar_w = int(w * ratio)

        if ratio > 0.6:
            colour = GREEN
        elif ratio > 0.3:
            colour = YELLOW
        else:
            colour = RED

        self.hp_canvas.delete("all")
        self.hp_canvas.create_rectangle(0, 0, bar_w, 18, fill=colour, outline="")

    # ── Battle log ───────────────────────────────────────────────

    def _log_attack(self, result):
        crit_str = " ✨ CRITICAL HIT!" if result["critical"] else ""
        msg = (
            f"{result['emoji']} {result['attack']}: "
            f"-{result['damage']} HP{crit_str} "
            f"[{result['hp_remaining']} left]"
        )
        self._log(msg)

    def _log(self, message, colour=None):
        self.log_text.config(state="normal")
        tag = f"tag_{id(message)}"
        self.log_text.insert("end", message + "\n", tag)
        if colour:
            self.log_text.tag_config(tag, foreground=colour)
        self.log_text.see("end")
        self.log_text.config(state="disabled")

    # ── Timer ────────────────────────────────────────────────────

    def _start_timer(self):
        def _tick():
            while True:
                time.sleep(1)
                try:
                    stats = self.session.get_stats_summary()
                    self.stats_labels["elapsed"].set(stats["elapsed"])
                except tk.TclError:
                    # Widget has been destroyed (app closed) — stop the timer.
                    break

        t = threading.Thread(target=_tick, daemon=True)
        t.start()

    # ── Helpers ──────────────────────────────────────────────────

    @staticmethod
    def _lighten(hex_color):
        """Return a slightly lighter version of a hex colour."""
        hex_color = hex_color.lstrip("#")
        r, g, b = (int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        r = min(255, r + 40)
        g = min(255, g + 40)
        b = min(255, b + 40)
        return f"#{r:02x}{g:02x}{b:02x}"
