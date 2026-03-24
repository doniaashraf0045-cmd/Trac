"""Phone Breaker Extreme — entry point.

Run this script to start the game:
    python main.py

The game uses only Python's standard library (tkinter) so it runs
on any VPS or RDP environment that has Python 3.7+ installed.
"""

import sys


def _check_python():
    if sys.version_info < (3, 7):
        sys.exit("Python 3.7 or higher is required.")


def _check_tkinter():
    try:
        import tkinter  # noqa: F401
    except ImportError:
        sys.exit(
            "tkinter is not available.\n"
            "On Linux/Ubuntu, install it with:\n"
            "    sudo apt-get install python3-tk\n"
            "On Windows it is bundled with the standard Python installer."
        )


def main():
    _check_python()
    _check_tkinter()

    from ui import PhoneBreakerApp
    app = PhoneBreakerApp()
    app.mainloop()


if __name__ == "__main__":
    main()
