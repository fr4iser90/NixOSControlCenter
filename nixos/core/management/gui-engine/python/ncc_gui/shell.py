"""Multi-domain shell with enabled/disabled nav and end-user chrome."""

from __future__ import annotations

from collections.abc import Callable

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.catalog import DomainInfo
from ncc_gui.theme import APP_STYLE

PageBuilder = Callable[[DomainInfo], QWidget]


class DisabledPage(QWidget):
    def __init__(self, info: DomainInfo, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)

        banner = QFrame()
        banner.setObjectName("nccDisabledBanner")
        bl = QVBoxLayout(banner)
        title = QLabel(info.label)
        title.setObjectName("nccPageTitle")
        bl.addWidget(title)
        desc = QLabel(info.description)
        desc.setObjectName("nccMuted")
        desc.setWordWrap(True)
        bl.addWidget(desc)
        msg = QLabel(
            "This area is not enabled on this system.\n\n"
            "Enable the matching module in your NixOS Control Center config "
            f"(domain “{info.id}”), then rebuild.\n\n"
            "Tip: open Modules to browse what can be turned on."
        )
        msg.setObjectName("nccMuted")
        msg.setWordWrap(True)
        bl.addWidget(msg)
        layout.addWidget(banner)
        layout.addStretch(1)


class NccShell(QMainWindow):
    """Sidebar navigation; disabled domains stay visible but greyed out."""

    def __init__(
        self,
        domains: list[DomainInfo],
        build_page: PageBuilder,
        title: str = "NixOS Control Center",
    ) -> None:
        super().__init__()
        self.setWindowTitle(title)
        self.resize(1120, 740)
        self.setStyleSheet(APP_STYLE)

        self._stack = QStackedWidget()
        self._nav = QListWidget()
        self._nav.setObjectName("nccNav")
        self._nav.setFixedWidth(200)
        self._infos = list(domains)

        for info in domains:
            item = QListWidgetItem(info.label)
            if not info.enabled:
                item.setFlags(item.flags() & ~Qt.ItemFlag.ItemIsEnabled)
                item.setToolTip(f"Not enabled — enable module “{info.id}” and rebuild")
                item.setFlags(
                    item.flags() | Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled
                )
                font = QFont()
                font.setItalic(True)
                item.setFont(font)
                item.setForeground(self.palette().mid())
            self._nav.addItem(item)
            if info.enabled:
                self._stack.addWidget(build_page(info))
            else:
                self._stack.addWidget(DisabledPage(info))

        self._nav.currentRowChanged.connect(self._stack.setCurrentIndex)
        if domains:
            for i, info in enumerate(self._infos):
                if info.enabled:
                    self._nav.setCurrentRow(i)
                    break
            else:
                self._nav.setCurrentRow(0)

        root = QWidget()
        root.setObjectName("nccShellRoot")
        layout = QHBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        left = QVBoxLayout()
        brand = QLabel("NCC")
        brand.setObjectName("nccPageTitle")
        brand.setContentsMargins(16, 16, 16, 4)
        left.addWidget(brand)
        hint = QLabel("Control Center")
        hint.setObjectName("nccPageSubtitle")
        hint.setContentsMargins(16, 0, 16, 8)
        left.addWidget(hint)
        left.addWidget(self._nav, stretch=1)
        left_wrap = QWidget()
        left_wrap.setLayout(left)
        left_wrap.setFixedWidth(200)
        layout.addWidget(left_wrap)
        layout.addWidget(self._stack, stretch=1)
        self.setCentralWidget(root)

    def select_domain(self, domain_id: str) -> None:
        for i, info in enumerate(self._infos):
            if info.id == domain_id:
                self._nav.setCurrentRow(i)
                return
