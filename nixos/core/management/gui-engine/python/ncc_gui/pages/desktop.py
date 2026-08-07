"""Desktop domain — show current desktop module settings."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.remote import run_ncc
from ncc_gui.target_bar import TargetBar
from ncc_gui.theme import APP_STYLE


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


class DesktopPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("Desktop")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel(
            "Current desktop module settings from systemConfig. "
            "Change them in systemConfig and rebuild — editing in-GUI comes later."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        self.target = TargetBar()
        self.target.targetChanged.connect(lambda _t: self.reload())
        root.addWidget(self.target)

        row = QHBoxLayout()
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.reload)
        row.addWidget(refresh)
        row.addStretch(1)
        root.addLayout(row)

        box = QGroupBox("Settings")
        self.form = QFormLayout(box)
        self._fields: dict[str, QLabel] = {}
        for key, label in (
            ("enable", "Enabled"),
            ("environment", "Environment"),
            ("display.manager", "Display manager"),
            ("display.server", "Display server"),
            ("display.session", "Session"),
            ("theme.dark", "Dark theme"),
            ("pinnedAppsAuto", "Auto pin apps"),
            ("pinnedAppsForce", "Force re-pin"),
        ):
            lab = QLabel("—")
            self._fields[key] = lab
            self.form.addRow(label, lab)
        root.addWidget(box)

        self.raw = QTextEdit()
        self.raw.setObjectName("nccActivityLog")
        self.raw.setReadOnly(True)
        self.raw.setMaximumHeight(140)
        root.addWidget(self.raw)
        root.addStretch(1)
        self.reload()

    def reload(self) -> None:
        proc = run_ncc("desktop", "status", target=self.target.current_target())
        text = ((proc.stdout or "") + (proc.stderr or "")).strip()
        self.raw.setPlainText(text or "(empty)")
        kv = _parse_kv(proc.stdout or "")
        for key, lab in self._fields.items():
            lab.setText(kv.get(key, "—"))


def create_page() -> QWidget:
    return DesktopPage()


Page = DesktopPage
