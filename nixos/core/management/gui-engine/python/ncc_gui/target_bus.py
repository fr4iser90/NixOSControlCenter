"""Qt signal bus for global target / session changes."""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal


class TargetBus(QObject):
    """Fleet chrome signals.

    - ``changed(str|None)`` — connected host (None = this machine)
    - ``sessionChanged(TargetSession)`` — gate / probe snapshot
    - ``navigate(str)`` — shell should open a domain (install|system|…)
    """

    changed = Signal(object)
    sessionChanged = Signal(object)
    navigate = Signal(str)
    # System page: run a named action (e.g. ``migrate-config``) after navigate.
    systemAction = Signal(str)
    # SSH client page: open edit modal for ``user@host`` (or empty = current selection).
    sshClientEdit = Signal(object)


_bus: TargetBus | None = None


def bus() -> TargetBus:
    global _bus
    if _bus is None:
        _bus = TargetBus()
    return _bus
