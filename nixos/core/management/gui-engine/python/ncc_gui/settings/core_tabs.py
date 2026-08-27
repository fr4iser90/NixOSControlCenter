"""Built-in Control Center settings tabs (gui-engine only — no module deps)."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFormLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.chrome_prefs import (
    activity_mode,
    hide_inactive_features,
    load_chrome_prefs,
    set_activity_mode,
    set_hide_inactive_features,
)
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

        self.hide_inactive = QCheckBox("Hide inactive features")
        self.hide_inactive.setChecked(hide_inactive_features())
        self.hide_inactive.setToolTip(
            "When checked, Features with module enable=false are hidden from the "
            "sidebar. Core domains (Desktop, Network, …) always stay visible so "
            "you can turn them on. Default: off (config manager)."
        )
        form.addRow("Sidebar", self.hide_inactive)
        lay.addLayout(form)
        note = QLabel(
            "Core stays visible even when disabled (values come from the "
            "current target’s systemConfig). Inactive features show “· Off” "
            "unless you hide them here."
        )
        note.setObjectName("nccPageSubtitle")
        note.setWordWrap(True)
        lay.addWidget(note)
        lay.addStretch(1)

    def collect(self) -> dict:
        mode = self.activity_mode.currentData()
        return {
            "activity_mode": mode if isinstance(mode, str) else "collapsed",
            "hide_inactive_features": self.hide_inactive.isChecked(),
        }


def _apply_general(data: dict) -> None:
    mode = data.get("activity_mode")
    if isinstance(mode, str):
        set_activity_mode(mode)
    if "hide_inactive_features" in data:
        set_hide_inactive_features(bool(data["hide_inactive_features"]))


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
