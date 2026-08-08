"""Network — DomainPage kit (overview + conditional Ethernet / WiFi)."""

from __future__ import annotations

import json

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.scaffold import DomainPage


class NetworkPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Network",
            "See connection status. WiFi controls appear only when a wireless "
            "adapter is present; Ethernet only when a wired device exists.",
            parent=parent,
        )
        self._wifi_present = False
        self._wifi_radio_on = False
        self._eth_present = False

        # --- Overview (always) ---
        ov = self.add_form_block("Overview")
        self.ov_online = QLabel("—")
        self.ov_host = QLabel("—")
        self.ov_summary = QLabel("—")
        self.ov_summary.setWordWrap(True)
        ov.addRow("Online", self.ov_online)
        ov.addRow("Hostname", self.ov_host)
        ov.addRow("Links", self.ov_summary)

        # --- Ethernet (hidden if no device) ---
        self.eth_box = self.add_block("Ethernet")
        eth_l = QFormLayout(self.eth_box)
        self.eth_state = QLabel("—")
        self.eth_device = QLabel("—")
        self.eth_ip = QLabel("—")
        self.eth_gw = QLabel("—")
        eth_l.addRow("State", self.eth_state)
        eth_l.addRow("Device", self.eth_device)
        eth_l.addRow("IPv4", self.eth_ip)
        eth_l.addRow("Gateway", self.eth_gw)
        self.eth_box.setVisible(False)

        # --- WiFi (hidden if no device) ---
        self.wifi_box = self.add_block("WiFi")
        wifi_outer = QVBoxLayout(self.wifi_box)
        wifi_form = QFormLayout()
        self.wifi_radio = QLabel("—")
        self.wifi_state = QLabel("—")
        self.wifi_device = QLabel("—")
        self.wifi_conn = QLabel("—")
        self.wifi_ip = QLabel("—")
        wifi_form.addRow("Radio", self.wifi_radio)
        wifi_form.addRow("State", self.wifi_state)
        wifi_form.addRow("Device", self.wifi_device)
        wifi_form.addRow("Network", self.wifi_conn)
        wifi_form.addRow("IPv4", self.wifi_ip)
        wifi_outer.addLayout(wifi_form)

        self.wifi_off_hint = QLabel("WiFi radio is off. Turn it on to scan and connect.")
        self.wifi_off_hint.setObjectName("nccPageSubtitle")
        self.wifi_off_hint.setWordWrap(True)
        wifi_outer.addWidget(self.wifi_off_hint)

        self.wifi_live = QWidget()
        live_l = QVBoxLayout(self.wifi_live)
        live_l.setContentsMargins(0, 0, 0, 0)
        live_l.addWidget(QLabel("Nearby networks"))
        self.scan_list = QListWidget()
        self.scan_list.setMaximumHeight(160)
        self.scan_list.itemClicked.connect(self._pick_ssid)
        live_l.addWidget(self.scan_list)

        form = QFormLayout()
        self.ssid = QLineEdit()
        self.ssid.setPlaceholderText("Network name (SSID)")
        self.psk = QLineEdit()
        self.psk.setEchoMode(QLineEdit.EchoMode.Password)
        self.psk.setPlaceholderText("Password")
        form.addRow("Network", self.ssid)
        form.addRow("Password", self.psk)
        live_l.addLayout(form)
        wifi_outer.addWidget(self.wifi_live)
        self.wifi_box.setVisible(False)

        self.add_action("Refresh", self.reload, primary=True)
        self._btn_eth_up = self.add_action("Reconnect Ethernet", self._eth_reconnect)
        self._btn_eth_down = self.add_action("Disconnect Ethernet", self._eth_disconnect)
        self._btn_wifi_on = self.add_action("Turn WiFi on", self._wifi_radio_on_act)
        self._btn_scan = self.add_action("Scan WiFi", self._scan)
        self._btn_connect = self.add_action("Connect WiFi", self._connect)
        self._btn_disconnect = self.add_action(
            "Disconnect WiFi",
            lambda: self._run_then_reload("network", "wifi", "disconnect", need_confirm="Disconnect"),
        )
        self._btn_saved = self.add_action(
            "Saved networks",
            lambda: self.run_ncc("network", "wifi", "list"),
        )

        self.reload()

    def reload(self) -> None:
        proc = self.run_ncc("network", "status", "--json", log=False, show_error=False)
        raw = (proc.stdout or "").strip()
        if proc.returncode != 0 or not raw:
            error(self, "Network", (proc.stderr or proc.stdout or "status failed").strip())
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            error(self, "Network", "Invalid status JSON")
            return

        online = bool(data.get("online"))
        self.ov_online.setText("Yes" if online else "No")
        self.ov_host.setText(str(data.get("hostname") or "—"))

        wifi = data.get("wifi") or {}
        eth = data.get("ethernet") or {}
        self._wifi_present = bool(wifi.get("present"))
        self._eth_present = bool(eth.get("present"))
        radio = str(wifi.get("radio") or "")
        self._wifi_radio_on = radio == "enabled"

        parts = []
        if self._eth_present:
            parts.append(f"Ethernet {eth.get('state') or '?'}")
        if self._wifi_present:
            parts.append(f"WiFi {wifi.get('state') or '?'} (radio {radio or '?'})")
        if not parts:
            parts.append("No WiFi or Ethernet device found")
        self.ov_summary.setText(" · ".join(parts))

        self.eth_box.setVisible(self._eth_present)
        if self._eth_present:
            self.eth_state.setText(str(eth.get("state") or "—"))
            self.eth_device.setText(str(eth.get("device") or "—"))
            self.eth_ip.setText(str(eth.get("ipv4") or "—") or "—")
            self.eth_gw.setText(str(eth.get("gateway") or "—") or "—")

        self.wifi_box.setVisible(self._wifi_present)
        if self._wifi_present:
            self.wifi_radio.setText(radio or "—")
            self.wifi_state.setText(str(wifi.get("state") or "—"))
            self.wifi_device.setText(str(wifi.get("device") or "—"))
            self.wifi_conn.setText(str(wifi.get("connection") or "—") or "—")
            self.wifi_ip.setText(str(wifi.get("ipv4") or "—") or "—")
            self.wifi_off_hint.setVisible(not self._wifi_radio_on)
            self.wifi_live.setVisible(self._wifi_radio_on)

        self._sync_actions()

    def _sync_actions(self) -> None:
        self._btn_eth_up.setVisible(self._eth_present)
        self._btn_eth_down.setVisible(self._eth_present)
        self._btn_wifi_on.setVisible(self._wifi_present and not self._wifi_radio_on)
        wifi_live = self._wifi_present and self._wifi_radio_on
        self._btn_scan.setVisible(wifi_live)
        self._btn_connect.setVisible(wifi_live)
        self._btn_disconnect.setVisible(wifi_live)
        self._btn_saved.setVisible(wifi_live)

    def _run_then_reload(self, *args: str, need_confirm: str | None = None) -> None:
        proc = self.run_ncc(*args, need_confirm=need_confirm)
        if need_confirm and (proc.stderr or "").strip() == "cancelled":
            return
        self.reload()

    def _eth_reconnect(self) -> None:
        self._run_then_reload("network", "ethernet", "reconnect")

    def _eth_disconnect(self) -> None:
        if not confirm(self, "Disconnect", "Disconnect Ethernet?"):
            return
        self._run_then_reload("network", "ethernet", "disconnect")

    def _wifi_radio_on_act(self) -> None:
        self._run_then_reload("network", "wifi", "on")

    def _scan(self) -> None:
        self.log_append("• Scanning WiFi…\n")
        proc = self.run_ncc("network", "wifi", "scan", "--json", log=False, show_error=True)
        self.scan_list.clear()
        raw = (proc.stdout or "").strip()
        if proc.returncode != 0 or not raw:
            return
        try:
            networks = json.loads(raw)
        except json.JSONDecodeError:
            error(self, "Scan", "Invalid scan JSON")
            return
        for n in networks if isinstance(networks, list) else []:
            ssid = str(n.get("ssid") or "").strip()
            if not ssid:
                continue
            sig = n.get("signal") or ""
            sec = n.get("security") or ""
            mark = "★ " if n.get("in_use") else ""
            item = QListWidgetItem(f"{mark}{ssid}  ·  {sig}%  ·  {sec}")
            item.setData(Qt.ItemDataRole.UserRole, ssid)
            self.scan_list.addItem(item)
        self.log_append(f"Found {self.scan_list.count()} network(s).\n")

    def _pick_ssid(self, item: QListWidgetItem) -> None:
        ssid = item.data(Qt.ItemDataRole.UserRole)
        if isinstance(ssid, str) and ssid:
            self.ssid.setText(ssid)

    def _connect(self) -> None:
        ssid = self.ssid.text().strip()
        psk = self.psk.text()
        if not ssid:
            info(self, "Connect", "Enter or pick a network name.")
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
            self.reload()


def create_page(parent=None):
    return NetworkPage(parent)


Page = NetworkPage
