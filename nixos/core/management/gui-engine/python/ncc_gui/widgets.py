"""Shared NCC GUI widgets — prefer these over raw QLabel in forms."""

from __future__ import annotations

import os
import sys

from PySide6.QtCore import QSize, Qt
from PySide6.QtWidgets import QLabel, QSizePolicy, QWidget


class FormValueLabel(QLabel):
    """Wrapping body/status text that sizes its height correctly.

    **Not** applied automatically to every ``QLabel`` in the app. Use this
    class (or ``DomainPage.add_form_value``) whenever text may wrap. Raw
    ``QLabel(wordWrap=True)`` often keeps a one-line height and clips.
    """

    def __init__(self, text: str = "—", parent: QWidget | None = None) -> None:
        super().__init__(text, parent)
        self.setObjectName("nccFormValue")
        self.setWordWrap(True)
        self.setAlignment(
            Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop
        )
        self.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse
        )
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Minimum,
        )

    def hasHeightForWidth(self) -> bool:  # noqa: N802 — Qt API
        return True

    def heightForWidth(self, width: int) -> int:  # noqa: N802
        w = max(int(width), 80)
        # margins / padding headroom
        return int(self.fontMetrics().boundingRect(
            0, 0, w, 0, int(Qt.TextFlag.TextWordWrap), self.text() or " "
        ).height()) + 6

    def sizeHint(self) -> QSize:  # noqa: N802
        w = self.width()
        if w < 40:
            w = 280
        return QSize(w, self.heightForWidth(w))

    def minimumSizeHint(self) -> QSize:  # noqa: N802
        return QSize(40, self.heightForWidth(280))

    def setText(self, text: str) -> None:  # noqa: N802
        super().setText(text if text is not None else "")
        self.updateGeometry()


def layout_debug_enabled() -> bool:
    return os.environ.get("NCC_GUI_LAYOUT_DEBUG", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def audit_wrapping_labels(root: QWidget, *, context: str = "") -> list[str]:
    """Return issues where word-wrapped labels are shorter than needed.

    Set ``NCC_GUI_LAYOUT_DEBUG=1`` to print findings to stderr.
    """
    issues: list[str] = []
    for lab in root.findChildren(QLabel):
        if not lab.wordWrap():
            continue
        w = lab.width()
        if w < 40:
            continue
        need = lab.heightForWidth(w) if lab.hasHeightForWidth() else 0
        if need <= 0:
            # Estimate for plain QLabel
            need = lab.fontMetrics().boundingRect(
                0, 0, w, 0, int(Qt.TextFlag.TextWordWrap), lab.text() or " "
            ).height()
        got = lab.height()
        if need > got + 4:
            msg = (
                f"clipped wrap: {context or root.__class__.__name__} "
                f"objectName={lab.objectName()!r} "
                f"need≈{need}px got={got}px text={lab.text()[:48]!r}"
            )
            issues.append(msg)
            if layout_debug_enabled():
                print(f"ncc-gui layout: {msg}", file=sys.stderr)
    return issues
