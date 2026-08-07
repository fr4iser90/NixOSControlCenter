"""Packages domain page — clearer end-user layout."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, confirm_rebuild, error, info
from ncc_gui.theme import APP_STYLE


def _packages_bin() -> str:
    return os.environ.get("NCC_PACKAGES_BIN", "ncc-packages")


def _catalog_path() -> Path:
    raw = os.environ.get("NCC_PACKAGES_CATALOG", "")
    if raw:
        return Path(raw)
    return Path("/etc/nixos/core/base/packages/lib/catalog.nix")


def load_catalog() -> dict:
    catalog = _catalog_path()
    # Preferred: build-time JSON (NCC_PACKAGES_CATALOG from mk-catalog-json.nix)
    if catalog.suffix == ".json" and catalog.is_file():
        return json.loads(catalog.read_text(encoding="utf-8"))

    # Dev fallback: evaluate Nix SSOT in-tree (needs sibling metadata/sets/presets)
    expr = f'(import {catalog} {{}})'
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


def maybe_rebuild(parent: QWidget, summary: str) -> None:
    if not confirm_rebuild(parent, summary):
        return
    proc = subprocess.run(
        ["sudo", "nixos-rebuild", "switch"],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        error(parent, "Rebuild failed", proc.stderr or proc.stdout or "unknown error")
    else:
        info(parent, "Rebuild", "System update finished.")


class PackagesPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        self._catalog: dict = {"sets": [], "presets": []}
        self._active: set[str] = set()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)

        title = QLabel("Packages")
        title.setObjectName("nccPageTitle")
        layout.addWidget(title)
        sub = QLabel(
            "Turn software sets and presets on or off. Changes are written to your NixOS config; "
            "rebuild when you are ready."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        layout.addWidget(sub)

        split = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(split, stretch=1)

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

        btns = QHBoxLayout()
        self.btn_refresh = QPushButton("Refresh")
        self.btn_add = QPushButton("Add selected")
        self.btn_remove = QPushButton("Remove selected")
        self.btn_rebuild = QPushButton("Rebuild system…")
        for b in (self.btn_refresh, self.btn_add, self.btn_remove):
            btns.addWidget(b)
        btns.addStretch(1)
        btns.addWidget(self.btn_rebuild)
        layout.addLayout(btns)

        self.btn_refresh.clicked.connect(self.reload)
        self.btn_add.clicked.connect(self.add_selected)
        self.btn_remove.clicked.connect(self.remove_selected)
        self.btn_rebuild.clicked.connect(lambda: maybe_rebuild(self, "Apply package changes."))
        self.available.currentItemChanged.connect(self._show_available_details)
        self.active_list.currentItemChanged.connect(self._show_active_details)
        self.reload()

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
                f"{data['name']}\n\n{data.get('description') or ''}\n\n"
                f"Includes: {mods}"
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
        info(self, "Added", "Saved to config. Rebuild when you want it active.")
        self.reload()
        maybe_rebuild(self, f"Added: {', '.join(names)}")

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
        info(self, "Removed", "Saved to config.")
        self.reload()
        maybe_rebuild(self, f"Removed: {', '.join(names)}")
