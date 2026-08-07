"""Network domain page with WiFi connect form."""

from __future__ import annotations

import subprocess

from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.pages.base import DomainActionsPage
from ncc_gui.theme import APP_STYLE


class NetworkPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        actions = DomainActionsPage(
            "network",
            "Network",
            [
                ("WiFi status", ("wifi", "status")),
                ("Scan networks", ("wifi", "scan")),
                ("Saved networks", ("wifi", "list")),
                ("Disconnect", ("wifi", "disconnect")),
            ],
            subtitle="Check status or connect to a wireless network.",
            confirm_labels=("Disconnect",),
        )
        layout.addWidget(actions)

        # Connect form sits under actions; re-parent into page after actions stretch
        box = QGroupBox("Connect to WiFi")
        form = QFormLayout(box)
        self.ssid = QLineEdit()
        self.ssid.setPlaceholderText("Network name (SSID)")
        self.psk = QLineEdit()
        self.psk.setEchoMode(QLineEdit.EchoMode.Password)
        self.psk.setPlaceholderText("Password")
        form.addRow("Network", self.ssid)
        form.addRow("Password", self.psk)
        row = QHBoxLayout()
        connect_btn = QPushButton("Connect")
        connect_btn.clicked.connect(self._connect)
        row.addWidget(connect_btn)
        row.addStretch(1)
        form.addRow(row)
        # Insert before stretch: add to outer layout
        actions.layout().insertWidget(actions.layout().count() - 1, box)

    def _connect(self) -> None:
        ssid = self.ssid.text().strip()
        psk = self.psk.text()
        if not ssid:
            info(self, "Connect", "Enter a network name.")
            return
        if len(psk) < 8 or len(psk) > 63:
            info(self, "Connect", "Password must be 8–63 characters.")
            return
        if not confirm(self, "Connect", f"Connect to “{ssid}”?"):
            return
        proc = subprocess.run(
            ["ncc", "network", "wifi", "connect", ssid, "--psk", psk],
            capture_output=True,
            text=True,
        )
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Could not connect", out or "Connection failed.")
        else:
            info(self, "Connected", out or f"Connected to {ssid}.")
            self.psk.clear()


def create_page(parent=None):
    return NetworkPage(parent)
