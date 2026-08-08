"""Multi-domain shell with global target bar; sidebar Core / Features sections."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
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

from ncc_gui.branding import app_icon
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

_ROLE_SECTION = Qt.ItemDataRole.UserRole
_ROLE_STACK = Qt.ItemDataRole.UserRole + 1


@dataclass
class _NavRow:
    """Nav list row: section header or domain."""

    kind: str  # "section" | "domain"
    info: DomainInfo | None = None
    stack_index: int | None = None


class NccShell(QMainWindow):
    """Sidebar = domains on the active Target, grouped Core / Features."""

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
        self._nav_rows: list[_NavRow] = []

        # Build pages in catalog order (already core-then-features)
        for info in domains:
            page = build_page(info)
            self._pages.append(page)
            self._stack.addWidget(page)

        self._rebuild_nav()
        self._nav.currentRowChanged.connect(self._on_nav_row)

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
        brand_row = QHBoxLayout()
        brand_row.setContentsMargins(12, 14, 12, 0)
        brand_row.setSpacing(10)
        icon_lbl = QLabel()
        icon = app_icon()
        if not icon.isNull():
            self.setWindowIcon(icon)
            icon_lbl.setPixmap(icon.pixmap(36, 36))
        brand_row.addWidget(icon_lbl)
        brand_col = QVBoxLayout()
        brand_col.setSpacing(0)
        brand = QLabel("NCC")
        brand.setObjectName("nccPageTitle")
        brand_col.addWidget(brand)
        hint = QLabel("Control Center")
        hint.setObjectName("nccPageSubtitle")
        brand_col.addWidget(hint)
        brand_row.addLayout(brand_col, stretch=1)
        left.addLayout(brand_row)
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

    def _rebuild_nav(self) -> None:
        self._nav.blockSignals(True)
        self._nav.clear()
        self._nav_rows = []

        for group_id, title in (("core", "Core"), ("features", "Features")):
            group_domains = [
                (i, info)
                for i, info in enumerate(self._infos)
                if info.group == group_id
            ]
            if not group_domains:
                continue

            hdr = QListWidgetItem(title)
            hdr.setFlags(Qt.ItemFlag.NoItemFlags)
            font = QFont()
            font.setBold(True)
            font.setPointSize(max(font.pointSize() - 1, 9))
            hdr.setFont(font)
            hdr.setData(_ROLE_SECTION, True)
            self._nav.addItem(hdr)
            self._nav_rows.append(_NavRow(kind="section"))

            for stack_i, info in group_domains:
                item = QListWidgetItem(f"  {info.label}")
                item.setFlags(
                    Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled
                )
                item.setData(_ROLE_SECTION, False)
                item.setData(_ROLE_STACK, stack_i)
                self._nav.addItem(item)
                self._nav_rows.append(
                    _NavRow(kind="domain", info=info, stack_index=stack_i)
                )

        self._nav.blockSignals(False)

    def _on_nav_row(self, row: int) -> None:
        if row < 0 or row >= len(self._nav_rows):
            return
        nav = self._nav_rows[row]
        if nav.kind != "domain" or nav.stack_index is None:
            return
        self._stack.setCurrentIndex(nav.stack_index)

    def select_domain(self, domain_id: str) -> None:
        for i, row in enumerate(self._nav_rows):
            if row.kind == "domain" and row.info and row.info.id == domain_id:
                item = self._nav.item(i)
                if item is not None and not item.isHidden():
                    self._nav.setCurrentRow(i)
                return

    def current_domain_id(self) -> str | None:
        row = self._nav.currentRow()
        if row < 0 or row >= len(self._nav_rows):
            return None
        nav = self._nav_rows[row]
        if nav.kind == "domain" and nav.info is not None:
            return nav.info.id
        return None

    def _select_first_visible(self) -> None:
        for i, row in enumerate(self._nav_rows):
            if row.kind != "domain":
                continue
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
        if item is None or item.isHidden() or (
            cur < len(self._nav_rows) and self._nav_rows[cur].kind == "section"
        ):
            self._select_first_visible()

    def _apply_nav_for_target(self, target: str | None) -> None:
        remote_ids: set[str] | None = None
        if target:
            remote_ids = probe_remote_domains(target)

        # Update DomainInfo.enabled
        for info in self._infos:
            local_on = self._local_enabled.get(info.id, False)
            if info.id in LOCAL_ONLY_DOMAINS:
                enabled = local_on
            elif not target:
                enabled = local_on
            elif remote_ids is None:
                enabled = local_on
            else:
                enabled = info.id in remote_ids
            info.enabled = enabled

        # Hide domain rows; hide section if no visible children
        visible_in_group: dict[str, int] = {"core": 0, "features": 0}
        for i, row in enumerate(self._nav_rows):
            item = self._nav.item(i)
            if item is None:
                continue
            if row.kind == "section":
                continue
            assert row.info is not None
            enabled = row.info.enabled
            item.setHidden(not enabled)
            if enabled:
                visible_in_group[row.info.group] = (
                    visible_in_group.get(row.info.group, 0) + 1
                )
                item.setToolTip("")
            elif target and remote_ids is not None:
                item.setToolTip(f"Not on {target}")
            else:
                item.setToolTip(f"Not enabled locally (“{row.info.id}”)")

        # Section headers
        for i, row in enumerate(self._nav_rows):
            if row.kind != "section":
                continue
            item = self._nav.item(i)
            if item is None:
                continue
            title = item.text().strip().lower()
            group = "core" if title == "core" else "features"
            item.setHidden(visible_in_group.get(group, 0) == 0)
