"""QApplication bootstrap for NCC GUIs."""

from __future__ import annotations

import signal
import sys

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication

from ncc_gui.branding import app_icon


def ensure_app(argv: list[str] | None = None) -> QApplication:
    """Create the shared QApplication and install the generation watcher once.

    Every NCC Qt GUI that goes through ``ensure_app`` automatically soft/hard
    reloads on system switch — no per-window wiring.
    """
    existing = QApplication.instance()
    if existing is not None:
        try:
            from ncc_gui.reload import install_generation_watcher

            install_generation_watcher(parent=existing)
        except Exception:
            pass
        return existing  # type: ignore[return-value]
    app = QApplication(argv if argv is not None else sys.argv)
    app.setApplicationName("NixOS Control Center")
    app.setDesktopFileName("ncc")
    icon = app_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)
    try:
        from ncc_gui.reload import install_generation_watcher

        install_generation_watcher(parent=app)
    except Exception:
        # Off NixOS / missing /run — GUI still works
        pass
    return app


def run_window(window_factory, argv: list[str] | None = None) -> int:
    app = ensure_app(argv)

    # Ctrl+C in the terminal should quit the Qt event loop
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    # Let the Python interpreter run periodically so SIGINT is delivered
    _keepalive = QTimer()
    _keepalive.start(200)
    _keepalive.timeout.connect(lambda: None)

    win = window_factory()
    icon = app.windowIcon()
    if not icon.isNull():
        win.setWindowIcon(icon)
    win.show()
    return app.exec()
