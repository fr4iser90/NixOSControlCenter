"""Module Manager — DomainPage kit (enable/disable drafts → CommitBar)."""

from __future__ import annotations

import json
from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QAbstractItemView,
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
from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import error, info
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus

PROTECTED = frozenset(
    {"module-manager", "cli-registry", "nixos-control-center", "system-manager"}
)

_OP = "module-toggle"


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
        return (0 if self.is_core else 1, self.name.lower())


class ModulesPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Modules",
            "Turn NCC modules on or off (list follows the Target bar). "
            "Enable/Disable stages a draft — Apply writes config; "
            "rebuild is offered after Apply.",
            parent=parent,
        )
        self._rows: list[ModuleRow] = []
        self._selected: ModuleRow | None = None
        self._flush_queue: list[PendingChange] = []
        self._flush_summary = ""

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

        self.add_actions_hint(
            "Some core modules are protected and cannot be turned off. "
            "Enable/Disable only stages — use Apply to write."
        )
        self.add_action("Enable", self._enable)
        self.add_action("Disable", self._disable)
        self.add_action("Refresh", self.reload)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._apply_filter)

        target_bus().changed.connect(self._on_target_changed)
        self.reload()

    def _on_target_changed(self, _t) -> None:
        assert self.commit is not None
        if self.commit.pending:
            self.commit.clear()
            self.log_append("• cleared module drafts (target changed)\n")
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

    def _pending_by_name(self) -> dict[str, PendingChange]:
        assert self.commit is not None
        out: dict[str, PendingChange] = {}
        for ch in self.commit.pending:
            if ch.meta.get("op") != _OP:
                continue
            name = str(ch.meta.get("name") or "")
            if name:
                out[name] = ch
        return out

    def _live_status(self, name: str) -> str:
        for row in self._rows:
            if row.name == name:
                return row.status
        return "unknown"

    def _effective_status(self, name: str) -> str:
        ch = self._pending_by_name().get(name)
        if ch is not None:
            action = str(ch.meta.get("action") or "")
            if action == "enable":
                return "enabled"
            if action == "disable":
                return "disabled"
        return self._live_status(name)

    def _pending_label(self, name: str) -> str:
        ch = self._pending_by_name().get(name)
        if ch is None:
            return ""
        action = str(ch.meta.get("action") or "")
        if action == "enable":
            return " · pending enable"
        if action == "disable":
            return " · pending disable"
        return " · pending"

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
            eff = self._effective_status(row.name)
            if st != "all" and eff != st:
                continue
            if scope == "core" and not row.is_core:
                continue
            if scope == "features" and row.is_core:
                continue
            blob = f"{row.name} {row.category} {row.description}".lower()
            if q and q not in blob:
                continue
            filtered.append(row)

        core_rows = [r for r in filtered if r.is_core]
        feat_rows = [r for r in filtered if not r.is_core]

        def _add_rows(rows: list[ModuleRow]) -> None:
            nonlocal pick, shown
            for row in rows:
                eff = self._effective_status(row.name)
                label = (
                    f"  {row.name}  ·  {_status_label(eff)}"
                    f"{self._pending_label(row.name)}"
                )
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

        n_pending = len(self._pending_by_name())
        extra = f" · {n_pending} pending" if n_pending else ""
        self.count_label.setText(f"{shown} shown · {len(self._rows)} total{extra}")
        if pick:
            self.list.setCurrentItem(pick)
        elif self.list.count():
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
        eff = self._effective_status(row.name)
        pending = self._pending_label(row.name).strip(" ·") or "none"
        self.detail.setPlainText(
            f"Name: {row.name}\n"
            f"Status: {_status_label(eff)} (live: {_status_label(row.status)})\n"
            f"Draft: {pending}\n"
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

    @staticmethod
    def _same_module(a: PendingChange, b: PendingChange) -> bool:
        return (
            a.meta.get("op") == b.meta.get("op") == _OP
            and a.meta.get("name") == b.meta.get("name")
        )

    def _stage_toggle(self, action: str, names: list[str]) -> None:
        assert self.commit is not None
        for name in names:
            live = self._live_status(name)
            want = "enabled" if action == "enable" else "disabled"
            if live == want:
                # Already live — drop any opposite draft
                self.commit.discard_where(
                    lambda c, n=name: c.meta.get("op") == _OP
                    and c.meta.get("name") == n,
                    log=f"• {name} already {want} — cleared draft\n",
                )
                continue
            self.commit.stage_replace(
                PendingChange(
                    summary=f"modules {action} {name}",
                    argv=["modules", action, name],
                    elevated=True,
                    meta={"op": _OP, "action": action, "name": name},
                ),
                same=self._same_module,
            )

    def _enable(self) -> None:
        rows = self._selected_rows()
        if not rows:
            info(self, "Enable", "Select one or more modules.")
            return
        self._stage_toggle("enable", [r.name for r in rows])

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
        if blocked:
            self.log_append(
                f"• skipped protected: {', '.join(blocked)}\n"
            )
        self._stage_toggle("disable", names)

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        self._flush_queue = list(changes)
        self._flush_summary = "; ".join(c.summary for c in changes)
        self._run_next_flush()

    def _run_next_flush(self) -> None:
        assert self.commit is not None
        if not self._flush_queue:
            self.commit.notify_apply_finished(True, self._flush_summary)
            self.reload()
            return
        ch = self._flush_queue.pop(0)

        def done(code: int) -> None:
            if code != 0:
                self._flush_queue.clear()
                return
            self._run_next_flush()

        self.run_ncc_root(ch.argv, label=ch.summary, on_done=done)


def create_page() -> ModulesPage:
    return ModulesPage()


Page = ModulesPage
