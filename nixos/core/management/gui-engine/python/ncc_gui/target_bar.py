"""Global / local target switcher — This machine + SSH hosts (~/.creds)."""

from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import QComboBox, QHBoxLayout, QLabel, QWidget

from ncc_gui.target_state import get_active_target, list_host_targets, set_active_target
from ncc_gui.theme import APP_STYLE


class TargetBar(QWidget):
    """Emits targetChanged(str|None) where None means this machine."""

    targetChanged = Signal(object)

    def __init__(
        self,
        parent: QWidget | None = None,
        *,
        hint: str = "",
        persist: bool = True,
    ) -> None:
        super().__init__(parent)
        self._persist = persist
        self.setStyleSheet(APP_STYLE)
        row = QHBoxLayout(self)
        row.setContentsMargins(12, 8, 12, 8)
        row.addWidget(QLabel("Target"))
        self.combo = QComboBox()
        self.combo.setMinimumWidth(280)
        row.addWidget(self.combo, stretch=1)
        if hint:
            tip = QLabel(hint)
            tip.setObjectName("nccPageSubtitle")
            row.addWidget(tip)
        self.reload_hosts()
        self.combo.currentIndexChanged.connect(self._on_index)

    def reload_hosts(self) -> None:
        self.combo.blockSignals(True)
        current = get_active_target()
        self.combo.clear()
        self.combo.addItem("This machine", None)
        for target in list_host_targets():
            self.combo.addItem(target, target)
        idx = 0
        if current:
            for i in range(self.combo.count()):
                if self.combo.itemData(i) == current:
                    idx = i
                    break
            else:
                self.combo.addItem(current, current)
                idx = self.combo.count() - 1
        self.combo.setCurrentIndex(idx)
        self.combo.blockSignals(False)

    def current_target(self) -> str | None:
        data = self.combo.currentData()
        if data is None:
            return None
        host = str(data).strip()
        return host or None

    def set_target(self, target: str | None, *, emit: bool = True) -> None:
        want = (target or "").strip() or None
        self.combo.blockSignals(True)
        for i in range(self.combo.count()):
            if self.combo.itemData(i) == want:
                self.combo.setCurrentIndex(i)
                break
        else:
            if want:
                self.combo.addItem(want, want)
                self.combo.setCurrentIndex(self.combo.count() - 1)
            else:
                self.combo.setCurrentIndex(0)
        self.combo.blockSignals(False)
        if emit:
            self._emit()

    def _on_index(self, _i: int) -> None:
        self._emit()

    def _emit(self) -> None:
        t = self.current_target()
        if self._persist:
            set_active_target(t)
        self.targetChanged.emit(t)
