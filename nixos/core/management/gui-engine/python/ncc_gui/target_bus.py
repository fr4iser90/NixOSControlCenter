"""Qt signal bus for global target changes."""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal


class TargetBus(QObject):
    """Emits changed(str|None) when the fleet target updates."""

    changed = Signal(object)


_bus: TargetBus | None = None


def bus() -> TargetBus:
    global _bus
    if _bus is None:
        _bus = TargetBus()
    return _bus
