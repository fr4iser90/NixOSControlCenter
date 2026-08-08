"""Packages — DomainPage kit (sets / presets)."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QGroupBox,
    QListWidget,
    QListWidgetItem,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
)

from ncc_gui.dialogs import confirm, confirm_rebuild, error, info
from ncc_gui.scaffold import DomainPage


def _packages_bin() -> str:
    return os.environ.get("NCC_PACKAGES_BIN", "ncc-packages")


def _catalog_path() -> Path:
    raw = os.environ.get("NCC_PACKAGES_CATALOG", "")
    if raw:
        return Path(raw)
    return Path("/etc/nixos/core/base/packages/lib/catalog.nix")


def load_catalog() -> dict:
    catalog = _catalog_path()
    if catalog.suffix == ".json" and catalog.is_file():
        return json.loads(catalog.read_text(encoding="utf-8"))

    expr = f"(import {catalog} {{}})"
    proc = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", "-E", expr],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "catalog eval failed")
    return json.loads(proc.stdout)


def load_active_modules() -> list[str]:
    proc = subprocess.run(
        [_packages_bin(), "module", "list"],
        check=False,
        capture_output=True,
        text=True,
    )
    active: list[str] = []
    for line in (proc.stdout or "").splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            name = stripped[2:].split()[0]
            if name:
                active.append(name)
    return active


def run_packages(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [_packages_bin(), *args],
        check=False,
        capture_output=True,
        text=True,
    )


class PackagesPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Packages",
            "Turn software sets and presets on or off. Changes are written to your NixOS config; "
            "rebuild when you are ready.",
            parent=parent,
        )
        self._catalog: dict = {"sets": [], "presets": []}
        self._active: set[str] = set()

        split = QSplitter(Qt.Orientation.Horizontal)
        left = QGroupBox("Available")
        left_l = QVBoxLayout(left)
        self.available = QListWidget()
        self.available.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        left_l.addWidget(self.available)
        split.addWidget(left)

        mid = QGroupBox("Active on this system")
        mid_l = QVBoxLayout(mid)
        self.active_list = QListWidget()
        self.active_list.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        mid_l.addWidget(self.active_list)
        split.addWidget(mid)

        right = QGroupBox("Details")
        right_l = QVBoxLayout(right)
        self.details = QTextEdit()
        self.details.setReadOnly(True)
        right_l.addWidget(self.details)
        split.addWidget(right)
        split.setSizes([320, 280, 360])
        self.add_content_widget(split, stretch=1)

        self.add_action("Add selected", self.add_selected, primary=True)
        self.add_action("Remove selected", self.remove_selected)
        self.add_action("Refresh", self.reload)
        self.add_action("Rebuild system…", self._rebuild)

        self.available.currentItemChanged.connect(self._show_available_details)
        self.active_list.currentItemChanged.connect(self._show_active_details)
        self.reload()

    def _rebuild(self) -> None:
        if not confirm_rebuild(self, "Apply package changes."):
            return
        self.run_ncc_root(["system", "build", "switch"], label="Rebuild")

    def reload(self) -> None:
        try:
            self._catalog = load_catalog()
        except Exception as exc:  # noqa: BLE001
            error(self, "Catalog", str(exc))
            self._catalog = {"sets": [], "presets": []}
        try:
            self._active = set(load_active_modules())
        except Exception:  # noqa: BLE001
            self._active = set()

        self.available.clear()
        for preset in self._catalog.get("presets") or []:
            item = QListWidgetItem(f"Preset · {preset['name']}")
            item.setData(Qt.ItemDataRole.UserRole, ("preset", preset))
            self.available.addItem(item)
        for s in self._catalog.get("sets") or []:
            mark = " · on" if s["name"] in self._active else ""
            item = QListWidgetItem(f"Set · {s['name']}{mark}")
            item.setData(Qt.ItemDataRole.UserRole, ("set", s))
            self.available.addItem(item)

        self.active_list.clear()
        for name in sorted(self._active):
            self.active_list.addItem(QListWidgetItem(name))

    def _show_available_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None:
            return
        kind, data = cur.data(Qt.ItemDataRole.UserRole)
        if kind == "preset":
            mods = ", ".join(data.get("modules") or [])
            self.details.setPlainText(
                f"{data['name']}\n\n{data.get('description') or ''}\n\nIncludes: {mods}"
            )
        else:
            self.details.setPlainText(
                f"{data['name']}\n\n{data.get('description') or ''}\n\n"
                f"Group: {data.get('group') or '—'}\n"
                f"Currently active: {'yes' if data['name'] in self._active else 'no'}"
            )

    def _show_active_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None:
            return
        name = cur.text()
        for s in self._catalog.get("sets") or []:
            if s["name"] == name:
                item = QListWidgetItem()
                item.setData(Qt.ItemDataRole.UserRole, ("set", s))
                self._show_available_details(item)
                return
        self.details.setPlainText(name)

    def _selected_names_from_available(self) -> list[str]:
        return [
            item.data(Qt.ItemDataRole.UserRole)[1]["name"]
            for item in self.available.selectedItems()
        ]

    def add_selected(self) -> None:
        names = self._selected_names_from_available()
        if not names:
            info(self, "Add", "Select one or more items on the left.")
            return
        if not confirm(self, "Add", f"Add to your system config?\n\n{', '.join(names)}"):
            return
        proc = run_packages("module", "add", *names, "--no-build")
        if proc.returncode != 0:
            error(self, "Add failed", proc.stderr or proc.stdout or "error")
            return
        self.log_append(f"• Added {', '.join(names)}\n")
        info(self, "Added", "Saved to config. Rebuild when you want it active.")
        self.reload()
        if confirm_rebuild(self, f"Added: {', '.join(names)}"):
            self.run_ncc_root(["system", "build", "switch"], label="Rebuild")

    def remove_selected(self) -> None:
        names = [i.text() for i in self.active_list.selectedItems()]
        if not names:
            names = self._selected_names_from_available()
        if not names:
            info(self, "Remove", "Select items to remove.")
            return
        if not confirm(self, "Remove", f"Remove from config?\n\n{', '.join(names)}"):
            return
        proc = run_packages("module", "remove", *names, "--no-build")
        if proc.returncode != 0:
            error(self, "Remove failed", proc.stderr or proc.stdout or "error")
            return
        self.log_append(f"• Removed {', '.join(names)}\n")
        info(self, "Removed", "Saved to config.")
        self.reload()
        if confirm_rebuild(self, f"Removed: {', '.join(names)}"):
            self.run_ncc_root(["system", "build", "switch"], label="Rebuild")


def create_page() -> PackagesPage:
    return PackagesPage()


Page = PackagesPage
