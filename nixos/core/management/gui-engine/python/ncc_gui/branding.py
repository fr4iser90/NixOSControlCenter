"""NCC brand assets (icon paths for Qt / desktop)."""

from __future__ import annotations

import os
from pathlib import Path

from PySide6.QtGui import QIcon, QPixmap


def _candidates() -> list[Path]:
    env = (os.environ.get("NCC_GUI_ICON") or "").strip()
    here = Path(__file__).resolve().parent
    # package layout: …/ncc_gui/branding.py  and  …/ncc_gui/assets/…
    # or assets next to ncc_gui: …/assets/ncc-icon.png
    roots = [
        Path(env) if env else None,
        here / "assets" / "ncc-icon.png",
        here / "assets" / "ncc-icon.svg",
        here.parent / "assets" / "ncc-icon.png",
        here.parent / "assets" / "ncc-icon.svg",
    ]
    return [p for p in roots if p is not None]


def icon_path() -> Path | None:
    for p in _candidates():
        if p.is_file():
            return p
    return None


def app_icon() -> QIcon:
    path = icon_path()
    if path is None:
        return QIcon()
    icon = QIcon(str(path))
    if icon.isNull():
        # SVG/PNG fallback via pixmap
        pix = QPixmap(str(path))
        if not pix.isNull():
            return QIcon(pix)
    return icon
