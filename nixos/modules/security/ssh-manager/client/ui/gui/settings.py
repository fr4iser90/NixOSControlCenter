"""SSH module contribution to Control Center settings (discovery).

Owns fleet Target chrome + SSH-specific prefs. Appears only while the ``ssh``
GUI domain is enabled — never registered from gui-engine.
"""

from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.chrome_prefs import (
    load_chrome_prefs,
    save_chrome_prefs,
    set_show_target,
)
from ncc_gui.settings.protocol import SettingsTabSpec
from ncc_gui.theme import APP_STYLE


class _SshSettingsPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)

        tip = QLabel(
            "Fleet Target uses this module’s host list (~/.creds via ncc ssh client). "
            "Hosts and keys are managed on the SSH page."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)

        self.show_target = QCheckBox("Show Target selector in the header")
        self.show_target.setChecked(bool(load_chrome_prefs().get("show_target", True)))
        self.show_target.setToolTip(
            "When off, the header stays on this machine (no Connect/Disconnect)."
        )
        lay.addWidget(self.show_target)
        off_note = QLabel("Turning Target off disconnects any remote session.")
        off_note.setObjectName("nccPageSubtitle")
        off_note.setWordWrap(True)
        lay.addWidget(off_note)

        prefs = load_chrome_prefs()
        skips = prefs.get("skip_ssh_key_offer") or []
        n = len(skips) if isinstance(skips, list) else 0
        self._count = QLabel(f'Remembered “don’t offer save key” hosts: {n}')
        self._count.setObjectName("nccPageSubtitle")
        lay.addWidget(self._count)

        self._clear = QPushButton("Clear remembered skip-key offers")
        self._clear.setEnabled(n > 0)
        self._clear.setToolTip(
            "After password Connect, NCC can offer to save a key. "
            "Hosts you dismissed are listed here."
        )
        self._clear.clicked.connect(self._on_clear)
        lay.addWidget(self._clear)
        lay.addStretch(1)
        self._cleared = False

    def _on_clear(self) -> None:
        self._cleared = True
        self._count.setText('Remembered “don’t offer save key” hosts: 0')
        self._clear.setEnabled(False)

    def collect(self) -> dict:
        return {
            "show_target": bool(self.show_target.isChecked()),
            "clear_skip_ssh_key_offer": self._cleared,
        }


def _apply(data: dict) -> None:
    if "show_target" in data:
        set_show_target(bool(data["show_target"]))
    if data.get("clear_skip_ssh_key_offer"):
        prefs = load_chrome_prefs()
        prefs["skip_ssh_key_offer"] = []
        save_chrome_prefs(prefs)


def get_settings_tab() -> SettingsTabSpec:
    return SettingsTabSpec(
        id="ssh",
        title="SSH",
        order=20,
        requires_domains=("ssh",),
        subtitle="Fleet Target & key offers",
        build=lambda parent: _SshSettingsPage(parent),
        collect=lambda w: w.collect() if isinstance(w, _SshSettingsPage) else {},
        apply=_apply,
    )
