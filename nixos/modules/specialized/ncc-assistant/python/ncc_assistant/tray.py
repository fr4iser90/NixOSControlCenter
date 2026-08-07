"""System tray daemon: presence + pending approvals without main window."""

from __future__ import annotations

import sys

from PySide6.QtCore import QTimer
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import (
    QApplication,
    QMenu,
    QMessageBox,
    QSystemTrayIcon,
)

from .notifications import DecisionService
from .paths import is_disabled
from .presence import get_presence, set_presence


def run_tray() -> int:
    app = QApplication.instance() or QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName("NCC AI Tray")

    if not QSystemTrayIcon.isSystemTrayAvailable():
        print("System tray is not available on this desktop.", file=sys.stderr)
        return 1

    tray = QSystemTrayIcon()
    tray.setIcon(QIcon.fromTheme("help-about", QIcon.fromTheme("application-x-executable")))
    tray.setToolTip("NCC AI Assistant")

    menu = QMenu()

    def _refresh_title() -> None:
        presence = get_presence()
        state = presence.state
        pending = len(DecisionService().list_pending())
        disabled = is_disabled()
        tray.setToolTip(
            f"NCC AI — {state}"
            + (f" · {pending} pending" if pending else "")
            + (" · DISABLED" if disabled else "")
        )

    act_pause = QAction("Pause agent (playing / DND)")
    act_resume = QAction("Resume agent (available)")
    act_pending = QAction("Show pending approvals")
    act_open = QAction("Open NCC AI")
    act_quit = QAction("Quit tray")

    def on_pause() -> None:
        set_presence("paused", reason="tray")
        _refresh_title()
        tray.showMessage(
            "NCC AI",
            "Agent paused — mutating tools blocked.",
            QSystemTrayIcon.MessageIcon.Information,
        )

    def on_resume() -> None:
        set_presence("available", reason="tray")
        _refresh_title()
        tray.showMessage("NCC AI", "Agent available.", QSystemTrayIcon.MessageIcon.Information)

    def on_pending() -> None:
        pending = DecisionService().list_pending()
        if not pending:
            QMessageBox.information(None, "NCC AI", "No pending approvals.")
            return
        lines = []
        for p in pending[:20]:
            lines.append(f"{p.id}: {p.summary or p.title or p.tool or ''}")
        QMessageBox.information(None, "Pending approvals", "\n".join(lines))

    def on_open() -> None:
        from .gui import run_gui

        run_gui()

    act_pause.triggered.connect(on_pause)
    act_resume.triggered.connect(on_resume)
    act_pending.triggered.connect(on_pending)
    act_open.triggered.connect(on_open)
    act_quit.triggered.connect(app.quit)

    menu.addAction(act_pause)
    menu.addAction(act_resume)
    menu.addSeparator()
    menu.addAction(act_pending)
    menu.addAction(act_open)
    menu.addSeparator()
    menu.addAction(act_quit)
    tray.setContextMenu(menu)
    tray.show()
    _refresh_title()

    timer = QTimer()
    timer.timeout.connect(_refresh_title)
    timer.start(5000)

    return int(app.exec())
