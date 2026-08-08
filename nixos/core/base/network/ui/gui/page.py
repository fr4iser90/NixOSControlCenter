"""Network — DomainPage kit (WiFi status + connect form)."""

from __future__ import annotations

from PySide6.QtWidgets import QLineEdit

from ncc_gui.dialogs import confirm, info
from ncc_gui.scaffold import DomainPage


class NetworkPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Network",
            "Check status or connect to a wireless network.",
            parent=parent,
        )
        form = self.add_form_block("Connect to WiFi")
        self.ssid = QLineEdit()
        self.ssid.setPlaceholderText("Network name (SSID)")
        self.psk = QLineEdit()
        self.psk.setEchoMode(QLineEdit.EchoMode.Password)
        self.psk.setPlaceholderText("Password")
        form.addRow("Network", self.ssid)
        form.addRow("Password", self.psk)

        self.add_action("Connect", self._connect, primary=True)
        self.add_action("WiFi status", lambda: self.run_ncc("network", "wifi", "status"))
        self.add_action("Scan networks", lambda: self.run_ncc("network", "wifi", "scan"))
        self.add_action("Saved networks", lambda: self.run_ncc("network", "wifi", "list"))
        self.add_action(
            "Disconnect",
            lambda: self.run_ncc("network", "wifi", "disconnect", need_confirm="Disconnect"),
        )

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
        proc = self.run_ncc("network", "wifi", "connect", ssid, "--psk", psk)
        if proc.returncode == 0:
            info(self, "Connected", f"Connected to {ssid}.")
            self.psk.clear()


def create_page(parent=None):
    return NetworkPage(parent)


Page = NetworkPage
