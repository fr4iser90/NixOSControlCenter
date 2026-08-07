"""Reusable domain action page — end-user chrome (sections + activity log)."""

from __future__ import annotations

import subprocess
from collections.abc import Sequence

from PySide6.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.dialogs import confirm, error
from ncc_gui.theme import APP_STYLE


class DomainActionsPage(QWidget):
    def __init__(
        self,
        domain: str,
        title: str,
        actions: Sequence[tuple[str, tuple[str, ...]]],
        *,
        subtitle: str = "",
        confirm_labels: Sequence[str] | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.domain = domain
        self._confirm = set(confirm_labels or [])
        self.setStyleSheet(APP_STYLE)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)

        heading = QLabel(title)
        heading.setObjectName("nccPageTitle")
        layout.addWidget(heading)
        if subtitle:
            sub = QLabel(subtitle)
            sub.setObjectName("nccPageSubtitle")
            sub.setWordWrap(True)
            layout.addWidget(sub)

        box = QGroupBox("Actions")
        row = QHBoxLayout(box)
        for label, args in actions:
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, a=args, l=label: self._run(a, l))
            row.addWidget(btn)
        row.addStretch(1)
        layout.addWidget(box)

        log_box = QGroupBox("Activity")
        log_l = QVBoxLayout(log_box)
        hint = QLabel("Results appear here. You usually do not need the technical details.")
        hint.setObjectName("nccPageSubtitle")
        hint.setWordWrap(True)
        log_l.addWidget(hint)
        self.log = QTextEdit()
        self.log.setObjectName("nccActivityLog")
        self.log.setReadOnly(True)
        self.log.setMaximumHeight(180)
        log_l.addWidget(self.log)
        layout.addWidget(log_box)
        layout.addStretch(1)

    def _run(self, args: tuple[str, ...], label: str) -> None:
        if label in self._confirm:
            if not confirm(self, label, f"Run “{label}” now?"):
                return
        cmd = ["ncc", self.domain, *args]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        out = strip_ansi((proc.stdout or "") + (proc.stderr or ""))
        pretty = out.strip() or ("Done." if proc.returncode == 0 else "Something went wrong.")
        self.log.append(f"• {label}\n{pretty}\n")
        if proc.returncode != 0:
            error(self, label, pretty)
