"""QApplication bootstrap for NCC GUIs."""

from __future__ import annotations

import signal
import sys

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication

from ncc_gui.branding import app_icon


def ensure_app(argv: list[str] | None = None) -> QApplication:
    existing = QApplication.instance()
    if existing is not None:
        return existing  # type: ignore[return-value]
    app = QApplication(argv if argv is not None else sys.argv)
    app.setApplicationName("NixOS Control Center")
    app.setDesktopFileName("ncc")
    icon = app_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)
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
