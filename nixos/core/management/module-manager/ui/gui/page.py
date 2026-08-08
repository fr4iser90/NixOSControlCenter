"""Module Manager — DomainPage kit (enable / disable NCC modules)."""

from __future__ import annotations

import json
from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QAbstractItemView,
    QCheckBox,
    QComboBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus


PROTECTED = frozenset(
    {"module-manager", "cli-registry", "nixos-control-center", "system-manager"}
)


def _human_area(category: str) -> str:
    """core.base.user → base · user  |  modules.infrastructure.vm → infrastructure · vm"""
    parts = category.split(".")
    if len(parts) >= 2 and parts[0] in ("core", "modules"):
        rest = parts[1:]
        if len(rest) >= 2:
            return f"{rest[0]} · {' · '.join(rest[1:])}"
        return " · ".join(rest) if rest else category
    return category


def _status_label(status: str) -> str:
    return {"enabled": "On", "disabled": "Off"}.get(status, status.title() or "—")


@dataclass(frozen=True)
class ModuleRow:
    name: str
    status: str
    category: str
    version: str
    description: str
    path: str = ""
    scope: str = ""

    @property
    def is_core(self) -> bool:
        return self.scope == "core" or self.category.startswith("core.")

    @property
    def sort_key(self) -> tuple:
        # Same idea as sidebar: Core → Features, then A–Z by name
        return (0 if self.is_core else 1, self.name.lower())


class ModulesPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Modules",
            "Turn NCC modules on or off. The list follows the Target bar; "
            "changes are saved to your system config. Rebuild when you want them active.",
            parent=parent,
        )
        self._rows: list[ModuleRow] = []
        self._selected: ModuleRow | None = None

        filters = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search…")
        self.search.textChanged.connect(self._apply_filter)
        filters.addWidget(self.search, stretch=1)
        self.filter_status = QComboBox()
        self.filter_status.addItem("All statuses", "all")
        self.filter_status.addItem("On", "enabled")
        self.filter_status.addItem("Off", "disabled")
        self.filter_status.currentIndexChanged.connect(self._apply_filter)
        filters.addWidget(self.filter_status)
        self.filter_scope = QComboBox()
        self.filter_scope.addItem("All scopes", "all")
        self.filter_scope.addItem("Core", "core")
        self.filter_scope.addItem("Features", "features")
        self.filter_scope.currentIndexChanged.connect(self._apply_filter)
        filters.addWidget(self.filter_scope)
        filters_w = QWidget()
        filters_w.setLayout(filters)
        self.add_content_widget(filters_w)

        split = QSplitter(Qt.Orientation.Horizontal)
        left = QWidget()
        ll = QVBoxLayout(left)
        ll.setContentsMargins(0, 0, 0, 0)
        ll.addWidget(QLabel("Modules"))
        self.list = QListWidget()
        self.list.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.list.currentItemChanged.connect(self._on_select)
        ll.addWidget(self.list, stretch=1)
        self.count_label = QLabel()
        self.count_label.setObjectName("nccPageSubtitle")
        ll.addWidget(self.count_label)
        split.addWidget(left)

        right = QWidget()
        rl = QVBoxLayout(right)
        rl.setContentsMargins(0, 0, 0, 0)
        rl.addWidget(QLabel("Details"))
        self.detail = QTextEdit()
        self.detail.setReadOnly(True)
        self.detail.setObjectName("nccActivityLog")
        self.detail.setPlaceholderText("Select a module…")
        rl.addWidget(self.detail, stretch=1)
        split.addWidget(right)
        split.setStretchFactor(0, 2)
        split.setStretchFactor(1, 2)
        self.add_content_widget(split, stretch=1)

        self.add_actions_hint("Some core modules are protected and cannot be turned off.")
        self.do_rebuild = QCheckBox("Rebuild & switch after change")
        self.do_rebuild.setChecked(False)
        self.add_actions_widget(self.do_rebuild)
        self.add_action("Enable", self._enable, primary=True)
        self.add_action("Disable", self._disable)
        self.add_action("Refresh", self.reload)

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        proc = self.run_ncc(
            "modules",
            "list",
            "--json",
            follow_target=True,
            log=False,
            show_error=False,
        )
        self._rows = []
        raw = (proc.stdout or "").strip()
        if proc.returncode != 0 or not raw:
            err = strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
            self.detail.setPlainText(err or "Could not list modules.")
            self.list.clear()
            self.count_label.setText("0 modules")
            if proc.returncode != 0:
                error(self, "Module Manager", err or "list failed")
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            error(self, "Module Manager", "Invalid JSON from ncc modules list --json")
            return
        for item in data if isinstance(data, list) else []:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or item.get("id") or "").strip()
            if not name:
                continue
            self._rows.append(
                ModuleRow(
                    name=name,
                    status=str(item.get("status") or "unknown"),
                    category=str(item.get("category") or ""),
                    version=str(item.get("version") or "1.0"),
                    description=str(item.get("description") or ""),
                    path=str(item.get("path") or ""),
                    scope=str(item.get("scope") or ""),
                )
            )
        self._rows.sort(key=lambda r: r.sort_key)
        self._apply_filter()

    def _add_section(self, title: str) -> None:
        hdr = QListWidgetItem(title)
        hdr.setFlags(Qt.ItemFlag.NoItemFlags)
        font = QFont()
        font.setBold(True)
        hdr.setFont(font)
        hdr.setData(Qt.ItemDataRole.UserRole, None)
        self.list.addItem(hdr)

    def _apply_filter(self) -> None:
        q = self.search.text().strip().lower()
        st = self.filter_status.currentData()
        scope = self.filter_scope.currentData()
        current = self._selected.name if self._selected else None
        self.list.clear()
        pick = None
        shown = 0

        filtered = []
        for row in self._rows:
            if st != "all" and row.status != st:
                continue
            if scope == "core" and not row.is_core:
                continue
            if scope == "features" and row.is_core:
                continue
            blob = f"{row.name} {row.category} {row.description}".lower()
            if q and q not in blob:
                continue
            filtered.append(row)

        # Sidebar-style: Core block then Features block (already sorted A–Z within)
        core_rows = [r for r in filtered if r.is_core]
        feat_rows = [r for r in filtered if not r.is_core]

        def _add_rows(rows: list[ModuleRow]) -> None:
            nonlocal pick, shown
            for row in rows:
                label = f"  {row.name}  ·  {_status_label(row.status)}"
                item = QListWidgetItem(label)
                item.setData(Qt.ItemDataRole.UserRole, row)
                self.list.addItem(item)
                shown += 1
                if current and row.name == current:
                    pick = item

        if core_rows and scope != "features":
            self._add_section("Core")
            _add_rows(core_rows)
        if feat_rows and scope != "core":
            self._add_section("Features")
            _add_rows(feat_rows)

        self.count_label.setText(f"{shown} shown · {len(self._rows)} total")
        if pick:
            self.list.setCurrentItem(pick)
        elif self.list.count():
            # skip section headers
            for i in range(self.list.count()):
                it = self.list.item(i)
                if it and it.data(Qt.ItemDataRole.UserRole) is not None:
                    self.list.setCurrentRow(i)
                    break
        else:
            self._selected = None
            self.detail.setPlainText("No modules match the filter.")

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            self._selected = None
            return
        row = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(row, ModuleRow):
            self._selected = None
            return
        self._selected = row
        prot = "Yes — cannot disable" if row.name in PROTECTED else "No"
        scope = "Core" if row.is_core else "Features"
        self.detail.setPlainText(
            f"Name: {row.name}\n"
            f"Status: {_status_label(row.status)}\n"
            f"Scope: {scope}\n"
            f"Area: {_human_area(row.category)}\n"
            f"Version: {row.version}\n"
            f"Protected: {prot}\n\n"
            f"{row.description}"
        )

    def _selected_rows(self) -> list[ModuleRow]:
        rows: list[ModuleRow] = []
        for item in self.list.selectedItems():
            row = item.data(Qt.ItemDataRole.UserRole)
            if isinstance(row, ModuleRow):
                rows.append(row)
        if not rows and self._selected:
            rows = [self._selected]
        return rows

    def _enable(self) -> None:
        rows = self._selected_rows()
        if not rows:
            info(self, "Enable", "Select one or more modules.")
            return
        names = [r.name for r in rows]
        if not confirm(self, "Enable", f"Turn on these modules?\n\n{', '.join(names)}"):
            return
        self._apply_many("enable", names)

    def _disable(self) -> None:
        rows = self._selected_rows()
        if not rows:
            info(self, "Disable", "Select one or more modules.")
            return
        blocked = [r.name for r in rows if r.name in PROTECTED]
        names = [r.name for r in rows if r.name not in PROTECTED]
        if blocked and not names:
            error(
                self,
                "Disable",
                f"These modules are protected and stay on:\n{', '.join(blocked)}",
            )
            return
        msg = f"Turn off these modules?\n\n{', '.join(names)}"
        if blocked:
            msg += f"\n\nSkipped (protected): {', '.join(blocked)}"
        if not confirm(self, "Disable", msg):
            return
        self._apply_many("disable", names)

    def _apply_many(self, action: str, names: list[str]) -> None:
        rebuild = self.do_rebuild.isChecked()
        pending = list(names)

        def _next(code: int = 0) -> None:
            if code != 0:
                return
            if not pending:
                info(self, action.title(), "Done.")
                self.reload()
                return
            name = pending.pop(0)
            args = ["modules", action, name]
            if rebuild and not pending:
                args.append("--rebuild")
            self.run_ncc_root(args, label=f"{action} {name}", on_done=_next)

        _next(0)


def create_page() -> ModulesPage:
    return ModulesPage()


Page = ModulesPage
