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
        tip = (
            f"NCC AI — {state}"
            + (f" · {pending} pending" if pending else "")
            + (" · DISABLED" if disabled else "")
        )
        try:
            from .focus import peek_pending_nudge
            from .preferences import get_doomscroll_enable

            if get_doomscroll_enable() and peek_pending_nudge():
                tip += " · doomscroll!"
        except Exception:
            pass
        tray.setToolTip(tip)

    def _focus_tick() -> None:
        try:
            from .focus import tick
            from .preferences import get_doomscroll_enable

            if get_doomscroll_enable():
                result = tick()
                if result.get("intervened"):
                    tray.showMessage(
                        "NCC · Doomscroll interrupt",
                        str(result.get("message") or "Leave the feed."),
                        QSystemTrayIcon.MessageIcon.Warning,
                        10_000,
                    )
        except Exception:
            pass
        _refresh_title()

    act_pause = QAction("Pause agent (playing / DND)")
    act_resume = QAction("Resume agent (available)")
    act_pending = QAction("Show pending approvals")
    act_snooze = QAction("Snooze doomscroll 30 min")
    act_open = QAction("Open NCC AI")
    act_companion = QAction("Open companion")
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

    def on_snooze() -> None:
        try:
            from .focus import snooze

            snooze(30)
            tray.showMessage(
                "NCC AI",
                "Doomscroll watchdog snoozed 30 min.",
                QSystemTrayIcon.MessageIcon.Information,
            )
        except Exception as exc:
            QMessageBox.warning(None, "NCC AI", str(exc))
        _refresh_title()

    def on_open() -> None:
        from .gui import run_gui

        run_gui()

    def on_companion() -> None:
        import shutil

        from PySide6.QtCore import QProcess

        bin_path = shutil.which("ncc-assistant-companion") or shutil.which(
            "ncc-assistant"
        )
        if bin_path and bin_path.endswith("companion"):
            QProcess.startDetached(bin_path, [])
        elif bin_path:
            QProcess.startDetached(bin_path, ["companion"])
        else:
            from .companion import run_companion

            run_companion()

    act_pause.triggered.connect(on_pause)
    act_resume.triggered.connect(on_resume)
    act_pending.triggered.connect(on_pending)
    act_snooze.triggered.connect(on_snooze)
    act_open.triggered.connect(on_open)
    act_companion.triggered.connect(on_companion)
    act_quit.triggered.connect(app.quit)

    menu.addAction(act_pause)
    menu.addAction(act_resume)
    menu.addSeparator()
    menu.addAction(act_pending)
    menu.addAction(act_snooze)
    menu.addAction(act_open)
    menu.addAction(act_companion)
    menu.addSeparator()
    menu.addAction(act_quit)
    tray.setContextMenu(menu)
    tray.show()
    _refresh_title()

    timer = QTimer()
    timer.timeout.connect(_focus_tick)
    timer.start(15_000)

    return int(app.exec())
