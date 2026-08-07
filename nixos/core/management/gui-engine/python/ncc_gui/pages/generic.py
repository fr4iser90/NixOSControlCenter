"""Generic domain page — desktop UI for any module without a custom page.

Shows useful domain verbs from the registry. Does not launch TUI/GUI
wrappers: this page is already the GUI.
"""

from __future__ import annotations

import subprocess

from PySide6.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.catalog import DomainAction, DomainInfo
from ncc_gui.dialogs import error
from ncc_gui.theme import APP_STYLE

# Launcher verbs — never show as primary GUI buttons
_SKIP = frozenset({"tui", "gui", "manager"})


def _desktop_actions(info: DomainInfo) -> list[DomainAction]:
    out: list[DomainAction] = []
    for action in info.actions:
        if not action.args:
            continue
        if action.args[0] in _SKIP:
            continue
        out.append(action)
    return out


class GenericDomainPage(QWidget):
    def __init__(self, info: DomainInfo, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.info = info
        self.setStyleSheet(APP_STYLE)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)

        title = QLabel(info.label)
        title.setObjectName("nccPageTitle")
        layout.addWidget(title)
        sub = QLabel(info.description or f"Manage “{info.id}”.")
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        layout.addWidget(sub)

        actions = _desktop_actions(info)
        if actions:
            box = QGroupBox("Actions")
            row = QHBoxLayout(box)
            for action in actions:
                btn = QPushButton(action.label)
                btn.clicked.connect(
                    lambda _=False, a=tuple(action.args), l=action.label: self._run(a, l)
                )
                row.addWidget(btn)
            row.addStretch(1)
            layout.addWidget(box)

            log_box = QGroupBox("Activity")
            log_l = QVBoxLayout(log_box)
            self.log = QTextEdit()
            self.log.setObjectName("nccActivityLog")
            self.log.setReadOnly(True)
            self.log.setMaximumHeight(180)
            log_l.addWidget(self.log)
            layout.addWidget(log_box)
        else:
            self.log = None
            hint = QLabel(
                "No desktop controls for this area yet — the page will fill in "
                "as module UIs are added.\n\n"
                f"For scripting you can use:  ncc {info.id} …"
            )
            hint.setObjectName("nccMuted")
            hint.setWordWrap(True)
            layout.addWidget(hint)

        layout.addStretch(1)

    def _run(self, args: tuple[str, ...], label: str) -> None:
        cmd = ["ncc", self.info.id, *args]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        pretty = out or ("Done." if proc.returncode == 0 else "Something went wrong.")
        if self.log is not None:
            self.log.append(f"• {label}\n{pretty}\n")
        if proc.returncode != 0:
            error(self, label, pretty)
