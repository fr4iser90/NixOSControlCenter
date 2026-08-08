"""Restart NCC GUI after a NixOS generation switch (post-rebuild).

Page Python lives in the store; a running process keeps the old code.
When ``/run/current-system`` changes, re-exec via the new ``ncc`` on PATH
so kit + domain pages load from the new generation.
"""

from __future__ import annotations

import os
import shutil
import sys
from collections.abc import Callable, Sequence
from pathlib import Path

from PySide6.QtCore import QObject, QTimer
from PySide6.QtWidgets import QApplication, QWidget

SYSTEM_LINK = Path("/run/current-system")
POLL_MS = 2000
RESTART_DELAY_MS = 900
RESUME_DOMAIN_ENV = "NCC_GUI_RESUME_DOMAIN"


def current_generation() -> str | None:
    try:
        if not SYSTEM_LINK.exists():
            return None
        return str(SYSTEM_LINK.resolve())
    except OSError:
        return None


def resolve_ncc() -> str:
    """Prefer the active system profile so we pick up the post-switch binary."""
    for candidate in (
        "/run/current-system/sw/bin/ncc",
        shutil.which("ncc") or "",
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return "ncc"


def pop_resume_domain() -> str | None:
    val = os.environ.pop(RESUME_DOMAIN_ENV, "").strip()
    return val or None


def root_relaunch_argv(*, domain_id: str | None = None) -> list[str]:
    argv = [resolve_ncc(), "gui"]
    if domain_id:
        os.environ[RESUME_DOMAIN_ENV] = domain_id
    return argv


def domain_relaunch_argv(domain_id: str) -> list[str]:
    return [resolve_ncc(), domain_id, "--gui"]


def reexec(argv: Sequence[str]) -> None:
    """Replace this process with a fresh NCC GUI (does not return)."""
    if not argv:
        return
    program = argv[0]
    # Drop store PYTHONPATH from the old generation; the new wrapper sets it.
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)
    try:
        os.execve(program, list(argv), env)
    except OSError as exc:
        print(f"ncc-gui: reload failed ({program}): {exc}", file=sys.stderr)


class GenerationWatcher(QObject):
    """Poll ``/run/current-system`` and re-exec when the generation changes."""

    def __init__(
        self,
        *,
        relaunch_argv: Sequence[str] | Callable[[], Sequence[str]],
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._relaunch = relaunch_argv
        self._seen = current_generation()
        self._restarting = False
        self._timer = QTimer(self)
        self._timer.setInterval(POLL_MS)
        self._timer.timeout.connect(self._tick)
        if self._seen is not None:
            self._timer.start()

    def _tick(self) -> None:
        if self._restarting:
            return
        now = current_generation()
        if now is None:
            return
        if self._seen is None:
            self._seen = now
            return
        if now == self._seen:
            return
        self._seen = now
        self._schedule_restart()

    def _schedule_restart(self) -> None:
        self._restarting = True
        self._timer.stop()
        app = QApplication.instance()
        if app is not None:
            for w in app.topLevelWidgets():
                if isinstance(w, QWidget) and w.isVisible():
                    w.setWindowTitle(f"{w.windowTitle()} — reloading…")
        QTimer.singleShot(RESTART_DELAY_MS, self._restart)

    def _restart(self) -> None:
        argv = self._relaunch() if callable(self._relaunch) else list(self._relaunch)
        reexec(argv)


def install_generation_watcher(
    *,
    relaunch_argv: Sequence[str] | Callable[[], Sequence[str]],
    parent: QObject | None = None,
) -> GenerationWatcher | None:
    """Start watching; no-op when not on NixOS (no ``/run/current-system``)."""
    if current_generation() is None:
        return None
    return GenerationWatcher(relaunch_argv=relaunch_argv, parent=parent)
