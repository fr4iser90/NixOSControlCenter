"""Built-in Control Center settings tabs (gui-engine only — no module deps)."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.chrome_prefs import activity_mode, load_chrome_prefs, set_activity_mode
from ncc_gui.settings.protocol import SettingsTabSpec
from ncc_gui.settings.safety_tab import safety_settings_tab
from ncc_gui.theme import APP_STYLE


class _GeneralPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)
        tip = QLabel(
            "Appearance and command-log behaviour for every domain page."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        form = QFormLayout()
        self.activity_mode = QComboBox()
        self.activity_mode.addItem("Collapsed — Show log when needed", "collapsed")
        self.activity_mode.addItem("Hidden — only via Log button / on output", "hidden")
        self.activity_mode.addItem("Always open", "open")
        cur = activity_mode()
        idx = max(0, self.activity_mode.findData(cur))
        self.activity_mode.setCurrentIndex(idx)
        self.activity_mode.setToolTip(
            "Collapsed (default): log closed until Show log or command output. "
            "Hidden: panel gone until Log. Open: always visible."
        )
        form.addRow("Command log (Activity)", self.activity_mode)
        lay.addLayout(form)
        note = QLabel(
            "Pages without an Activity log (read-only tools) ignore this setting."
        )
        note.setObjectName("nccPageSubtitle")
        note.setWordWrap(True)
        lay.addWidget(note)
        lay.addStretch(1)

    def collect(self) -> dict:
        mode = self.activity_mode.currentData()
        return {"activity_mode": mode if isinstance(mode, str) else "collapsed"}


def _apply_general(data: dict) -> None:
    mode = data.get("activity_mode")
    if isinstance(mode, str):
        set_activity_mode(mode)


def core_settings_tabs(*, enabled_domains: set[str] | None = None) -> list[SettingsTabSpec]:
    """Shell chrome + host Safety (policy is declarative; see safety_tab)."""
    del enabled_domains
    load_chrome_prefs()
    return [
        SettingsTabSpec(
            id="general",
            title="General",
            order=10,
            subtitle="Chrome & Activity",
            build=lambda parent: _GeneralPage(parent),
            collect=lambda w: w.collect() if isinstance(w, _GeneralPage) else {},
            apply=_apply_general,
        ),
        safety_settings_tab(),
    ]
