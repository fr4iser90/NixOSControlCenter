"""Control Center settings dialog — sidebar + pages (discovery-driven)."""

from __future__ import annotations

from PySide6.QtCore import QSize, Qt
from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.settings.discover import discover_settings_tabs
from ncc_gui.settings.protocol import SettingsTabSpec
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE
from ncc_gui.window_geom import persist_window, restore_window

_GEOM_KEY = "geometry/settingsDialog"


class SettingsDialog(QDialog):
    """Multi-section settings. Tabs come from core + module ``settings.py``."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Control Center settings")
        self.setModal(True)
        self.setStyleSheet(APP_STYLE)
        # Wide enough for sidebar + wrapped Safety labels (was 560 → clipped)
        restore_window(
            self,
            _GEOM_KEY,
            default=QSize(720, 520),
            minimum=QSize(640, 440),
        )

        self._specs: list[SettingsTabSpec] = discover_settings_tabs()
        self._pages: list[QWidget] = []

        root = QVBoxLayout(self)
        root.setContentsMargins(16, 16, 16, 16)
        root.setSpacing(12)

        header = QLabel("Settings")
        header.setObjectName("nccPageTitle")
        root.addWidget(header)
        sub = QLabel(
            "Only sections for enabled modules appear here "
            "(discovery — nothing unused)."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        body = QHBoxLayout()
        body.setSpacing(12)

        self.nav = QListWidget()
        self.nav.setObjectName("nccSettingsNav")
        self.nav.setFixedWidth(160)
        self.nav.setSpacing(2)
        body.addWidget(self.nav)

        self.stack = QStackedWidget()
        body.addWidget(self.stack, stretch=1)
        root.addLayout(body, stretch=1)

        if not self._specs:
            empty = QLabel("No settings available.")
            empty.setObjectName("nccPageSubtitle")
            self.stack.addWidget(empty)
        else:
            for spec in self._specs:
                page = spec.build(self)
                self._pages.append(page)
                self.stack.addWidget(page)
                item = QListWidgetItem(spec.title)
                item.setData(Qt.ItemDataRole.UserRole, spec.id)
                if spec.subtitle:
                    item.setToolTip(spec.subtitle)
                self.nav.addItem(item)
            self.nav.setCurrentRow(0)
            self.nav.currentRowChanged.connect(self.stack.setCurrentIndex)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._on_ok)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

    def done(self, result: int) -> None:
        persist_window(self, _GEOM_KEY)
        super().done(result)

    def _on_ok(self) -> None:
        for spec, page in zip(self._specs, self._pages):
            try:
                data = spec.collect(page)
            except Exception:
                data = {}
            if isinstance(data, dict) and data:
                try:
                    spec.apply(data)
                except Exception:
                    pass
        target_bus().chromePrefsChanged.emit()
        self.accept()


def open_settings_dialog(parent: QWidget | None = None) -> bool:
    """Show settings; return True if the user accepted."""
    dlg = SettingsDialog(parent)
    return dlg.exec() == QDialog.DialogCode.Accepted
