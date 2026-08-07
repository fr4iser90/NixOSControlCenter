"""Target host bar — local vs remote `ncc` (e.g. Gaming GUI → server homelab)."""

from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QComboBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QWidget,
)

from ncc_gui.remote import target_from_env
from ncc_gui.theme import APP_STYLE


class TargetBar(QWidget):
    """Emits targetChanged(str|None) where None means local."""

    targetChanged = Signal(object)

    def __init__(self, parent: QWidget | None = None, *, hint: str = "") -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.addWidget(QLabel("Target"))
        self.mode = QComboBox()
        self.mode.addItem("This machine", "local")
        self.mode.addItem("Remote SSH…", "remote")
        row.addWidget(self.mode)
        self.host = QLineEdit()
        self.host.setPlaceholderText("user@hostname (NCC on remote)")
        self.host.setEnabled(False)
        env = target_from_env()
        if env:
            self.mode.setCurrentIndex(1)
            self.host.setEnabled(True)
            self.host.setText(env)
        row.addWidget(self.host, stretch=1)
        if hint:
            tip = QLabel(hint)
            tip.setObjectName("nccPageSubtitle")
            row.addWidget(tip)

        self.mode.currentIndexChanged.connect(self._emit)
        self.host.editingFinished.connect(self._emit)

    def current_target(self) -> str | None:
        if self.mode.currentData() != "remote":
            return None
        host = self.host.text().strip()
        return host or None

    def _emit(self) -> None:
        remote = self.mode.currentData() == "remote"
        self.host.setEnabled(remote)
        self.targetChanged.emit(self.current_target())
