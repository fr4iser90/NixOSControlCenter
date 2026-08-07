"""Multi-domain shell with global target bar; sidebar shows active host's domains."""

from __future__ import annotations

from collections.abc import Callable

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
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
from ncc_gui.target_bar import TargetBar
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_state import (
    LOCAL_ONLY_DOMAINS,
    get_active_target,
    probe_remote_domains,
    set_active_target,
)
from ncc_gui.theme import APP_STYLE

PageBuilder = Callable[[DomainInfo], QWidget]


class NccShell(QMainWindow):
    """Sidebar = domains on the active Target. Disabled domains are hidden."""

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
        self._local_enabled = {d.id: d.enabled for d in domains}
        self._pages: list[QWidget] = []

        for info in domains:
            item = QListWidgetItem(info.label)
            self._nav.addItem(item)
            # Build real pages even when locally off — Target may enable them remotely.
            page = build_page(info)
            self._pages.append(page)
            self._stack.addWidget(page)

        self._nav.currentRowChanged.connect(self._stack.setCurrentIndex)

        self._target = TargetBar(
            hint="Which machine’s NCC you are using",
            persist=True,
        )
        self._target.targetChanged.connect(self._on_target)

        root = QWidget()
        root.setObjectName("nccShellRoot")
        outer = QVBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        outer.addWidget(self._target)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

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
        body.addWidget(left_wrap)
        body.addWidget(self._stack, stretch=1)
        body_w = QWidget()
        body_w.setLayout(body)
        outer.addWidget(body_w, stretch=1)
        self.setCentralWidget(root)

        active = get_active_target()
        set_active_target(active)
        self._apply_nav_for_target(active)
        self._select_first_visible()

    def select_domain(self, domain_id: str) -> None:
        for i, info in enumerate(self._infos):
            if info.id == domain_id:
                item = self._nav.item(i)
                if item is not None and not item.isHidden():
                    self._nav.setCurrentRow(i)
                return

    def _select_first_visible(self) -> None:
        for i in range(self._nav.count()):
            item = self._nav.item(i)
            if item is not None and not item.isHidden():
                self._nav.setCurrentRow(i)
                return

    def _on_target(self, target: object) -> None:
        t = target if isinstance(target, str) and target.strip() else None
        self._apply_nav_for_target(t)
        target_bus().changed.emit(t)
        cur = self._nav.currentRow()
        item = self._nav.item(cur) if cur >= 0 else None
        if item is None or item.isHidden():
            self._select_first_visible()

    def _apply_nav_for_target(self, target: str | None) -> None:
        remote_ids: set[str] | None = None
        if target:
            remote_ids = probe_remote_domains(target)

        for i, info in enumerate(self._infos):
            local_on = self._local_enabled.get(info.id, False)

            if info.id in LOCAL_ONLY_DOMAINS:
                # Always this machine's catalog
                enabled = local_on
            elif not target:
                enabled = local_on
            elif remote_ids is None:
                # Probe failed: keep local, hide if off
                enabled = local_on
            else:
                # Sidebar follows the remote host's NCC
                enabled = info.id in remote_ids

            info.enabled = enabled
            item = self._nav.item(i)
            if item is None:
                continue
            item.setFlags(Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled)
            # Disabled = hidden (no grey stubs cluttering the nav)
            item.setHidden(not enabled)
            if enabled:
                item.setToolTip("")
            elif target and remote_ids is not None:
                item.setToolTip(f"Not on {target}")
            else:
                item.setToolTip(f"Not enabled locally (“{info.id}”)")
