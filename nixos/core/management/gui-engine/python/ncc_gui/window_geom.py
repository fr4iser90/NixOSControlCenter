"""Window geometry helpers — restore last size; never open cramped."""

from __future__ import annotations

from PySide6.QtCore import QByteArray, QSettings, QSize
from PySide6.QtWidgets import QWidget

_ORG = "NixOSControlCenter"
_APP = "ncc-gui"


def _qs() -> QSettings:
    return QSettings(_ORG, _APP)


def restore_window(
    win: QWidget,
    key: str,
    *,
    default: QSize,
    minimum: QSize | None = None,
) -> None:
    """Restore saved geometry, else ``default``. Always enforce ``minimum``."""
    if minimum is not None:
        win.setMinimumSize(minimum)
    else:
        win.setMinimumSize(default)
    raw = _qs().value(key)
    if isinstance(raw, QByteArray) and win.restoreGeometry(raw):
        # Grow if a previous tiny save still clips content
        if minimum is not None:
            cur = win.size()
            if cur.width() < minimum.width() or cur.height() < minimum.height():
                win.resize(
                    max(cur.width(), minimum.width()),
                    max(cur.height(), minimum.height()),
                )
        return
    win.resize(default)


def persist_window(win: QWidget, key: str) -> None:
    _qs().setValue(key, win.saveGeometry())
