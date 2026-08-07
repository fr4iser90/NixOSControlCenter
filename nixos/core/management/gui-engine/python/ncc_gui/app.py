"""QApplication bootstrap for NCC GUIs."""

from __future__ import annotations

import signal
import sys

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication


def ensure_app(argv: list[str] | None = None) -> QApplication:
    existing = QApplication.instance()
    if existing is not None:
        return existing  # type: ignore[return-value]
    return QApplication(argv if argv is not None else sys.argv)


def run_window(window_factory, argv: list[str] | None = None) -> int:
    app = ensure_app(argv)

    # Ctrl+C in the terminal should quit the Qt event loop
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    # Let the Python interpreter run periodically so SIGINT is delivered
    _keepalive = QTimer()
    _keepalive.start(200)
    _keepalive.timeout.connect(lambda: None)

    win = window_factory()
    win.show()
    return app.exec()
