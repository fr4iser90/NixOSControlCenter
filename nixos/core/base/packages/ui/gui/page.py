"""Packages — Store (apps) + My packages + Sets & recipes (+ system for admins)."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QCheckBox,
    QGroupBox,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QSplitter,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import confirm_rebuild, error, info
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage

try:
    from .intent_store import (
        format_intent_details,
        install_status,
        intents_in_category,
        is_store_intent,
        search_intents,
        stage_argv_for_intent,
        store_intents,
        undo_argv_for_intent,
    )
except ImportError:  # flat load in unit tests / source tree
    from intent_store import (
        format_intent_details,
        install_status,
        intents_in_category,
        is_store_intent,
        search_intents,
        stage_argv_for_intent,
        store_intents,
        undo_argv_for_intent,
    )

TAB_STORE = "Store"
TAB_MINE = "My packages"
# Qt uses & as mnemonic — escape as && so the tab bar shows "Sets & recipes"
TAB_SETS = "Sets && recipes"
TAB_SYSTEM = "System packages"


def _humanize_group(group: str) -> str:
    """Display label from catalog metadata.group (no hardcoded group map)."""
    raw = (group or "").strip() or "other"
    # kebab/snake → words: virtualization → Virtualization, game-engines-ish groups stay as-is
    return raw.replace("-", " ").replace("_", " ").strip().title()


def _packages_bin() -> str:
    return os.environ.get("NCC_PACKAGES_BIN", "ncc-packages")


def _catalog_path() -> Path:
    raw = os.environ.get("NCC_PACKAGES_CATALOG", "")
    if raw:
        return Path(raw)
    return Path("/etc/nixos/core/base/packages/lib/catalog.nix")


def _nixos_root() -> Path:
    return Path(os.environ.get("NIXOS_DIR", "/etc/nixos"))


def _packages_root() -> Path:
    return _nixos_root() / "core" / "base" / "packages"


def _sets_dir() -> Path:
    raw = os.environ.get("NCC_PACKAGES_SETS", "")
    if raw:
        return Path(raw)
    return _packages_root() / "components" / "sets"


def _base_dir() -> Path:
    return _packages_root() / "components" / "base"


_PKG_LINE = re.compile(r"^\s+([a-zA-Z_][a-zA-Z0-9_.-]*)\s*(?:#.*)?$")
_PROGRAMS_ENABLE = re.compile(
    r"^\s*programs\.([a-zA-Z0-9_-]+)\s*=\s*\{|\bprograms\.([a-zA-Z0-9_-]+)\.enable\s*=\s*true\b"
)
_PROGRAMS_ENABLE_BLOCK = re.compile(
    r"programs\.([a-zA-Z0-9_-]+)\s*=\s*\{[^}]*enable\s*=\s*true",
    re.DOTALL,
)
_SERVICES_ENABLE = re.compile(
    r"services\.([a-zA-Z0-9_.-]+)\.enable\s*=\s*true"
)


def _scan_module_nix(path: Path) -> dict[str, list[str]]:
    """Extract package attrs, enabled programs.*, and enabled services.* from a module file."""
    out: dict[str, list[str]] = {"packages": [], "programs": [], "services": []}
    if not path.is_file():
        return out
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return out

    # programs.foo.enable = true  OR  programs.foo = { enable = true; ... }
    for m in re.finditer(
        r"programs\.([a-zA-Z0-9_-]+)\.enable\s*=\s*true", text
    ):
        name = m.group(1)
        if name not in out["programs"]:
            out["programs"].append(name)
    for m in _PROGRAMS_ENABLE_BLOCK.finditer(text):
        name = m.group(1)
        if name not in out["programs"]:
            out["programs"].append(name)

    for m in _SERVICES_ENABLE.finditer(text):
        name = m.group(1)
        if name not in out["services"]:
            out["services"].append(name)

    # environment.systemPackages / home.packages / extraPackages blocks
    in_pkgs = False
    for line in text.splitlines():
        if any(
            k in line
            for k in (
                "environment.systemPackages",
                "home.packages",
                "extraPackages",
                "extraPackages32",
            )
        ):
            in_pkgs = True
            continue
        if in_pkgs:
            if "]" in line and "with pkgs" not in line:
                in_pkgs = False
                continue
            m = _PKG_LINE.match(line)
            if m:
                pkg = m.group(1)
                if pkg not in ("with", "pkgs", "lib", "config", "pkgsi686Linux"):
                    # keep dotted attrs like rocmPackages.rocm-smi
                    if pkg not in out["packages"]:
                        out["packages"].append(pkg)
    return out


def _packages_in_set_file(name: str) -> list[str]:
    """Package attrs + programs.* from a set module (for details pane)."""
    scanned = _scan_module_nix(_sets_dir() / f"{name}.nix")
    labels = list(scanned["packages"])
    for p in scanned["programs"]:
        labels.append(f"programs.{p}")
    for s in scanned["services"]:
        labels.append(f"services.{s}")
    return labels


def load_core_hints() -> dict:
    """Read systemType / gpu / audio from monolith or split (best-effort)."""
    mono = _nixos_root() / "systemConfig.nix"
    if mono.is_file():
        proc = subprocess.run(
            [
                "nix-instantiate",
                "--eval",
                "--strict",
                "--json",
                "-E",
                f"""
                let c = import {mono};
                in {{
                  systemType = c.core.management."system-manager".systemType or "desktop";
                  gpu = c.core.base.hardware.gpu or null;
                  cpu = c.core.base.hardware.cpu or null;
                  audio = c.core.base.audio.audio or c.core.base.desktop.audio or null;
                }}
                """,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0 and (proc.stdout or "").strip():
            try:
                return json.loads(proc.stdout)
            except json.JSONDecodeError:
                pass
    return {"systemType": "desktop", "gpu": None, "cpu": None, "audio": None}


def build_system_inventory(
    explicit: list[str], active_sets: set[str]
) -> list[tuple[str, dict]]:
    """Package inventory from the packages module only: systemPackages + sets + core/profile."""
    hints = load_core_hints()
    rows: list[tuple[str, dict]] = []
    seen: set[str] = set()

    def add(label: str, data: dict) -> None:
        key = label
        if key in seen:
            return
        seen.add(key)
        rows.append((label, data))

    # 1) Explicit systemPackages (user/admin-managed list)
    for name in sorted(explicit):
        add(
            f"{name}  ·  systemPackages",
            {"kind": "explicit", "name": name},
        )

    # 2) Active sets (packages + programs.* + services.*)
    for set_name in sorted(active_sets):
        scanned = _scan_module_nix(_sets_dir() / f"{set_name}.nix")
        for p in sorted(scanned["packages"]):
            add(
                f"{p}  ·  set:{set_name}",
                {"kind": "set", "name": p, "set": set_name},
            )
        for p in sorted(scanned["programs"]):
            add(
                f"programs.{p}  ·  set:{set_name}",
                {"kind": "set", "name": f"programs.{p}", "set": set_name},
            )
        for s in sorted(scanned["services"]):
            add(
                f"services.{s}  ·  set:{set_name}",
                {"kind": "set", "name": f"services.{s}", "set": set_name},
            )
        if not (
            scanned["packages"] or scanned["programs"] or scanned["services"]
        ):
            add(
                f"(empty module)  ·  set:{set_name}",
                {"kind": "set-meta", "name": set_name, "set": set_name},
            )

    # 3) Always-on core + profile extras (desktop XOR server)
    system_type = str(hints.get("systemType") or "desktop")
    core_scan = _scan_module_nix(_base_dir() / "core.nix")
    for p in sorted(core_scan["packages"]):
        add(
            f"{p}  ·  core",
            {"kind": "base", "name": p, "base": "core"},
        )
    profile = "desktop" if system_type == "desktop" else "server"
    if system_type in ("desktop", "server"):
        profile_scan = _scan_module_nix(_base_dir() / f"{profile}.nix")
        for p in sorted(profile_scan["packages"]):
            add(
                f"{p}  ·  profile:{profile}",
                {"kind": "base", "name": p, "base": profile},
            )
        for s in sorted(profile_scan.get("services") or []):
            add(
                f"services.{s}  ·  profile:{profile}",
                {"kind": "base", "name": f"services.{s}", "base": profile},
            )

    kind_rank = {
        "explicit": 0,
        "set": 1,
        "set-meta": 1,
        "base": 2,
    }

    def sort_key(item: tuple[str, dict]) -> tuple:
        _label, data = item
        kind = data.get("kind") or ""
        base = str(data.get("base") or "")
        base_rank = 0 if base == "core" else 1
        return (
            kind_rank.get(str(kind), 9),
            base_rank,
            str(data.get("set") or base),
            str(data.get("name") or _label).lower(),
        )

    rows.sort(key=sort_key)

    out: list[tuple[str, dict]] = []
    last_section = None
    section_title = {
        "explicit": "── systemPackages (explicit) ──",
        "set": "── active sets ──",
        "set-meta": "── active sets ──",
        "base": "── core + profile (not sets) ──",
    }
    for label, data in rows:
        kind = str(data.get("kind") or "")
        section = "set" if kind in ("set", "set-meta") else kind
        if section != last_section:
            title = section_title.get(section, f"── {section} ──")
            out.append((title, {"kind": "header", "name": section}))
            last_section = section
        out.append((label, data))
    return out


def _whoami_role() -> tuple[str, str, bool]:
    """user, role, can_write_system (admin | restricted-admin)."""
    proc = run_ncc("user", "whoami", "--json")
    if proc.returncode == 0 and (proc.stdout or "").strip():
        try:
            data = json.loads(proc.stdout)
            role = str(data.get("role") or "guest")
            return (
                str(data.get("user") or ""),
                role,
                role in ("admin", "restricted-admin"),
            )
        except json.JSONDecodeError:
            pass
    return ("", "guest", False)


def load_catalog() -> dict:
    catalog = _catalog_path()
    if catalog.suffix == ".json" and catalog.is_file():
        return json.loads(catalog.read_text(encoding="utf-8"))
    expr = f"(import {catalog} {{}})"
    # Prefer full JSON builder next to catalog.nix when present
    mk = catalog.parent / "mk-catalog-json.nix"
    if catalog.name == "catalog.nix" and mk.is_file():
        # Cannot import writeText easily; eval intent+catalog via small expr
        intent = catalog.parent / "intent-catalog.nix"
        if intent.is_file():
            expr = f"""
              let
                data = import {catalog} {{
                  metadata = import {catalog.parent}/metadata.nix;
                  setsDir = {catalog.parent.parent}/components/sets;
                  recipesDir = {catalog.parent.parent}/components/recipes;
                  userPresetsDir = {catalog.parent.parent}/components/user-presets;
                }};
                intents = import {intent};
              in data // {{ categories = intents.categories; intents = intents.intents; }}
            """
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


def load_package_lists() -> tuple[list[str], list[str]]:
    proc = subprocess.run(
        [_packages_bin(), "list", "--json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return [], []
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return [], []
    mine = data.get("mine") if isinstance(data, dict) else None
    system = data.get("system") if isinstance(data, dict) else None
    return (
        [str(x) for x in mine] if isinstance(mine, list) else [],
        [str(x) for x in system] if isinstance(system, list) else [],
    )


def run_packages(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [_packages_bin(), *args],
        check=False,
        capture_output=True,
        text=True,
    )


_PKG_NAME = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._+-]*$")


def _parse_pkg_names(raw: str) -> list[str]:
    parts = re.split(r"[\s,;]+", raw.strip())
    out: list[str] = []
    for p in parts:
        if not p:
            continue
        if not _PKG_NAME.match(p):
            continue
        out.append(p)
    return out


def _make_item(text: str, data=None) -> QListWidgetItem:
    item = QListWidgetItem(text)
    item.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable)
    if data is not None:
        item.setData(Qt.ItemDataRole.UserRole, data)
    return item


def _selected(lw: QListWidget) -> list[QListWidgetItem]:
    return list(lw.selectedItems())


class PackagesPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Packages",
            "Store = individual apps → your userPackages. "
            "Sets & recipes = bundles / combos (system or user presets). "
            "Save draft → Apply → Rebuild when offered.",
            parent=parent,
        )
        self._me = ""
        self._role = "guest"
        self._can_system = False
        self._system_type = "desktop"
        self._catalog: dict = {
            "sets": [],
            "presets": [],
            "intents": [],
            "categories": [],
        }
        self._sets_by_name: dict[str, dict] = {}
        self._presets_by_name: dict[str, dict] = {}
        self._active: set[str] = set()
        self._mine: list[str] = []
        self._system_pkgs: list[str] = []
        self._flush_queue: list[PendingChange] = []
        self._flush_summary = ""

        self.tabs = QTabWidget()
        self._build_store_tab()
        self._build_mine_tab()
        self._build_sets_tab()
        self._build_system_pkgs_tab()
        self.add_content_widget(self.tabs, stretch=1)

        self.role_lbl = QLabel("")
        self.role_lbl.setObjectName("nccPageSubtitle")
        self.add_content_widget(self.role_lbl)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)

        self.btn_add = self.add_action("Add selected", self._add_selected)
        self.btn_remove = self.add_action("Remove selected", self._remove_selected)
        self.btn_add_typed = self.add_action("Add by name…", self._add_by_name)
        self.btn_try = self.add_action("Try selected…", self._try_selected)
        self.btn_update_nixpkgs = self.add_action(
            "Update nixpkgs…", self._update_nixpkgs
        )
        self.add_action("Refresh", self.reload)
        self.btn_rebuild = self.add_action("Rebuild…", self._rebuild)

        self.tabs.currentChanged.connect(self._sync_actions_for_tab)
        self.reload()

    def _build_store_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Individual apps only (→ userPackages). "
            "✓ = already in your config (or via an active set). "
            "Bundles: Sets & recipes. "
            "Try selected… = temporary nix-shell. "
            "Package versions follow the nixpkgs pin — use Update nixpkgs… then Rebuild."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)

        search_row = QHBoxLayout()
        self.store_search = QLineEdit()
        self.store_search.setPlaceholderText(
            "Search apps… e.g. obs, vscode, firefox, lutris"
        )
        self.store_search.textChanged.connect(self._on_store_search)
        self.store_search.returnPressed.connect(self._on_store_search)
        search_row.addWidget(self.store_search, stretch=1)
        lay.addLayout(search_row)

        self.store_empty = QLabel("")
        self.store_empty.setObjectName("nccPageSubtitle")
        self.store_empty.setWordWrap(True)
        lay.addWidget(self.store_empty)

        split = QSplitter(Qt.Orientation.Horizontal)

        left = QWidget()
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(0, 0, 0, 0)
        box_cat = QGroupBox("Categories")
        bc = QVBoxLayout(box_cat)
        self.store_categories = QListWidget()
        self.store_categories.currentItemChanged.connect(self._on_store_category)
        self.store_categories.itemClicked.connect(self._on_store_category)
        bc.addWidget(self.store_categories)
        left_l.addWidget(box_cat)
        split.addWidget(left)

        mid = QGroupBox("Apps")
        mid_l = QVBoxLayout(mid)
        self.store_results = QListWidget()
        self.store_results.setSelectionMode(
            QAbstractItemView.SelectionMode.SingleSelection
        )
        self.store_results.currentItemChanged.connect(self._show_store_details)
        self.store_results.itemClicked.connect(self._show_store_details)
        mid_l.addWidget(self.store_results)
        split.addWidget(mid)

        right = QGroupBox("Details")
        right_l = QVBoxLayout(right)
        self.store_details = QTextEdit()
        self.store_details.setReadOnly(True)
        right_l.addWidget(self.store_details)
        split.addWidget(right)
        split.setSizes([200, 320, 300])
        lay.addWidget(split, stretch=1)
        self.tabs.addTab(w, TAB_STORE)

    def _build_mine_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Packages listed for you (users.<you>.userPackages). "
            "Mark items to remove, or Add by name…"
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        split = QSplitter(Qt.Orientation.Horizontal)
        box = QGroupBox("Installed for you")
        bl = QVBoxLayout(box)
        self.mine_list = QListWidget()
        self.mine_list.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        bl.addWidget(self.mine_list)
        split.addWidget(box)
        det = QGroupBox("Hint")
        dl = QVBoxLayout(det)
        self.mine_hint = QTextEdit()
        self.mine_hint.setReadOnly(True)
        self.mine_hint.setPlainText(
            "Add by name… accepts several names (space or comma separated), "
            "e.g. firefox htop.\n\n"
            "Names must be nixpkgs attribute names (e.g. ripgrep, not rg).\n\n"
            "Packages pulled in by a set appear under System packages "
            "(labeled set:…) and under Recipes & sets."
        )
        dl.addWidget(self.mine_hint)
        split.addWidget(det)
        split.setStretchFactor(0, 3)
        split.setStretchFactor(1, 2)
        split.setSizes([480, 280])
        lay.addWidget(split, stretch=1)
        self.tabs.addTab(w, TAB_MINE)

    def _build_sets_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Sets = one thematic bundle (e.g. streaming, gaming). "
            "Recipes = several sets at once (e.g. gaming-desktop). "
            "User presets = several apps into your userPackages only. "
            "Store adds single apps — use this tab for bundles."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        filt = QHBoxLayout()
        self.filter_machine = QCheckBox("Only this machine type")
        self.filter_machine.setChecked(True)
        self.filter_machine.stateChanged.connect(lambda _=0: self._rebuild_available())
        self.show_individual_sets = QCheckBox("Show individual system sets")
        self.show_individual_sets.setChecked(True)
        self.show_individual_sets.stateChanged.connect(self._on_show_sets_toggled)
        filt.addWidget(self.filter_machine)
        filt.addWidget(self.show_individual_sets)
        filt.addStretch(1)
        lay.addLayout(filt)

        split = QSplitter(Qt.Orientation.Horizontal)

        left = QWidget()
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(0, 0, 0, 0)

        box_r = QGroupBox("1 · Recipes  [system combos]")
        br = QVBoxLayout(box_r)
        self.list_recipes = QListWidget()
        self.list_recipes.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        br.addWidget(self.list_recipes)
        left_l.addWidget(box_r, stretch=2)

        box_u = QGroupBox("2 · User presets  [user]")
        bu = QVBoxLayout(box_u)
        self.list_user_presets = QListWidget()
        self.list_user_presets.setSelectionMode(
            QAbstractItemView.SelectionMode.MultiSelection
        )
        bu.addWidget(self.list_user_presets)
        left_l.addWidget(box_u, stretch=2)

        self.box_sets = QGroupBox("3 · Sets  [system bundles]")
        bs = QVBoxLayout(self.box_sets)
        self.list_sets = QListWidget()
        self.list_sets.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        bs.addWidget(self.list_sets)
        left_l.addWidget(self.box_sets, stretch=3)
        self.box_sets.setVisible(True)

        # Keep alias used by older helpers / clear paths
        self.available = self.list_recipes

        split.addWidget(left)

        mid = QGroupBox("Active")
        mid_l = QVBoxLayout(mid)
        self.active_list = QListWidget()
        self.active_list.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        mid_l.addWidget(self.active_list)
        split.addWidget(mid)

        right = QGroupBox("Details")
        right_l = QVBoxLayout(right)
        self.details = QTextEdit()
        self.details.setReadOnly(True)
        right_l.addWidget(self.details)
        split.addWidget(right)
        split.setSizes([340, 260, 300])
        lay.addWidget(split, stretch=1)

        for lw in (self.list_recipes, self.list_user_presets, self.list_sets):
            lw.currentItemChanged.connect(self._show_available_details)
            lw.itemClicked.connect(self._show_available_details)
        self.active_list.currentItemChanged.connect(self._show_active_details)
        self.active_list.itemClicked.connect(self._show_active_details)
        self.tabs.addTab(w, TAB_SETS)

    def _on_show_sets_toggled(self, _state: int = 0) -> None:
        show = bool(self.show_individual_sets.isChecked())
        self.box_sets.setVisible(show)
        if show:
            self._rebuild_available()

    def _build_system_pkgs_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Sorted: systemPackages → sets → core/profile. "
            "core = every machine (operable baseline). "
            "profile:desktop = LibreOffice/AppImage only; "
            "profile:server = server ops tools. "
            "Hardware/audio stay in their domains. "
            "Remove only systemPackages rows or whole sets."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        box = QGroupBox("System packages")
        bl = QVBoxLayout(box)
        self.system_list = QListWidget()
        self.system_list.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection)
        bl.addWidget(self.system_list)
        lay.addWidget(box)
        self._system_tab_index = self.tabs.addTab(w, TAB_SYSTEM)

    def _current_tab(self) -> str:
        return self.tabs.tabText(self.tabs.currentIndex())

    def _sync_actions_for_tab(self, _idx: int = 0) -> None:
        tab = self._current_tab()
        is_store = tab == TAB_STORE
        is_sets = tab == TAB_SETS
        is_mine = tab == TAB_MINE
        is_sys = tab == TAB_SYSTEM
        can_write_sys = self._can_system
        can_write_mine = True

        self.btn_add_typed.setVisible(is_mine or (is_sys and can_write_sys))
        self.btn_try.setVisible(is_store)
        self.btn_update_nixpkgs.setVisible(is_store and can_write_sys)
        if is_store:
            self.btn_add.setEnabled(True)
            self.btn_add.setVisible(True)
            self.btn_remove.setVisible(False)
            self.btn_try.setEnabled(True)
        elif is_sets:
            # User presets: any user; system sets/presets: gated in handlers
            self.btn_add.setEnabled(True)
            self.btn_remove.setEnabled(True)
            self.btn_add.setVisible(True)
            self.btn_remove.setVisible(True)
        elif is_mine:
            self.btn_add.setVisible(False)
            self.btn_remove.setEnabled(can_write_mine)
            self.btn_remove.setVisible(True)
        elif is_sys:
            self.btn_add.setVisible(False)
            self.btn_remove.setEnabled(can_write_sys)
            self.btn_remove.setVisible(can_write_sys)
            self.btn_add_typed.setEnabled(can_write_sys)

        self.tabs.setTabVisible(self._system_tab_index, self._can_system)

    def _rebuild(self) -> None:
        if not confirm_rebuild(self, "Rebuild && switch the running system."):
            return
        self.run_ncc_root(["system", "build", "switch"], label="Rebuild && switch")

    def _update_nixpkgs(self) -> None:
        """Refresh flake inputs (all packages follow the pin) — not per-app apt upgrade."""
        if not self._can_system:
            error(self, "Update nixpkgs", "Administrator rights required.")
            return
        info(
            self,
            "Update nixpkgs",
            "NixOS does not upgrade one Store app in isolation.\n\n"
            "This runs: ncc system update-channels\n"
            "(refresh flake inputs / channel pin, then rebuild).\n\n"
            "Confirm in the next dialog if prompted.",
        )
        self.run_ncc_root(
            ["system", "update-channels"],
            label="Update nixpkgs (channels)",
        )

    def _store_status(self, intent: dict) -> dict:
        return install_status(
            intent,
            mine=self._mine,
            active_sets=self._active,
        )

    def _stage(
        self,
        summary: str,
        argv: list[str],
        *,
        elevated: bool = False,
        undo_argv: list[str] | None = None,
        undo_elevated: bool = False,
    ) -> None:
        assert self.commit is not None
        self.commit.stage(
            PendingChange(
                summary=summary,
                argv=argv,
                elevated=elevated,
                undo_argv=undo_argv,
                undo_elevated=undo_elevated,
            )
        )

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

        if ch.elevated:
            self.run_ncc_root(ch.argv, label=ch.summary, on_done=done)
        else:
            self.run_ncc_async(ch.argv, label=ch.summary, on_done=done)

    def reload(self) -> None:
        self._me, self._role, self._can_system = _whoami_role()
        self.role_lbl.setText(f"Signed in as {self._me} · role {self._role}")
        self._system_type = str(load_core_hints().get("systemType") or "desktop")

        try:
            self._catalog = load_catalog()
        except Exception as exc:  # noqa: BLE001
            error(self, "Catalog", str(exc))
            self._catalog = {"sets": [], "presets": [], "intents": [], "categories": []}
        self._sets_by_name = {
            s["name"]: s for s in (self._catalog.get("sets") or []) if s.get("name")
        }
        self._presets_by_name = {
            p["name"]: p for p in (self._catalog.get("presets") or []) if p.get("name")
        }
        try:
            self._active = set(load_active_modules())
        except Exception:  # noqa: BLE001
            self._active = set()
        self._mine, self._system_pkgs = load_package_lists()

        self._rebuild_store()

        self.mine_list.clear()
        for name in sorted(self._mine):
            self.mine_list.addItem(_make_item(name))

        # Full inventory with section headers
        self.system_list.clear()
        for label, data in build_system_inventory(self._system_pkgs, self._active):
            item = _make_item(label, data)
            if data.get("kind") == "header":
                item.setFlags(Qt.ItemFlag.NoItemFlags)
            self.system_list.addItem(item)

        self._rebuild_available()
        self._rebuild_active()
        self._sync_actions_for_tab()

    def _matches_machine(self, system_types: list | None) -> bool:
        """True if entry should show under current filter."""
        if not getattr(self, "filter_machine", None) or not self.filter_machine.isChecked():
            return True
        types = list(system_types or [])
        if not types:
            return True
        return self._system_type in types

    def _add_list_header(self, lw: QListWidget, title: str) -> None:
        item = _make_item(f"── {title} ──", ("header", {}))
        item.setFlags(Qt.ItemFlag.NoItemFlags)
        lw.addItem(item)

    def _applied_system_recipes(self) -> list[dict]:
        """System recipes whose modules are all currently in packageModules."""
        out: list[dict] = []
        for p in self._catalog.get("presets") or []:
            if (p.get("scope") or "system") != "system":
                continue
            mods = p.get("modules") or []
            if mods and all(m in self._active for m in mods):
                out.append(p)
        return sorted(out, key=lambda x: x.get("name") or "")

    def _sets_covered_by_recipes(self, recipes: list[dict]) -> set[str]:
        covered: set[str] = set()
        for r in recipes:
            for m in r.get("modules") or []:
                covered.add(m)
        return covered

    def _rebuild_active(self) -> None:
        """Active: recipes (collapsed) · leftover system sets · user presets — never mix kinds."""
        if not hasattr(self, "active_list"):
            return
        self.active_list.clear()
        recipes = self._applied_system_recipes()
        covered = self._sets_covered_by_recipes(recipes)

        if recipes:
            self._add_list_header(self.active_list, "System recipes  [system]")
            for preset in recipes:
                name = preset["name"]
                self.active_list.addItem(
                    _make_item(f"{name}  [system]", ("preset", preset))
                )

        loose = sorted(n for n in self._active if n not in covered)
        if loose:
            self._add_list_header(self.active_list, "System sets  [system]")
            for name in loose:
                self.active_list.addItem(
                    _make_item(
                        f"{name}  [system]",
                        ("set", self._sets_by_name.get(name) or {"name": name}),
                    )
                )

        user_applied = [
            p
            for p in (self._catalog.get("presets") or [])
            if (p.get("scope") or "system") == "user" and self._user_preset_applied(p)
        ]
        user_applied = sorted(user_applied, key=lambda p: p.get("name") or "")
        if user_applied:
            self._add_list_header(self.active_list, "User presets  [user]")
            for preset in user_applied:
                name = preset["name"]
                self.active_list.addItem(
                    _make_item(f"{name}  [user]", ("preset", preset))
                )

    def _rebuild_available(self) -> None:
        """Fill three separate lists: recipes | user presets | individual sets."""
        if not hasattr(self, "list_recipes"):
            return
        self.list_recipes.clear()
        self.list_user_presets.clear()
        self.list_sets.clear()

        presets = list(self._catalog.get("presets") or [])
        recipes_src = list(self._catalog.get("recipes") or [])
        users_src = list(self._catalog.get("userPresets") or [])
        if not recipes_src:
            recipes_src = [
                p for p in presets if (p.get("scope") or "system") == "system"
            ]
        if not users_src:
            users_src = [
                p for p in presets if (p.get("scope") or "system") == "user"
            ]

        recipes_on = {p["name"] for p in self._applied_system_recipes()}
        covered = self._sets_covered_by_recipes(self._applied_system_recipes())

        for preset in sorted(recipes_src, key=lambda p: p.get("name") or ""):
            if not self._matches_machine(preset.get("systemTypes")):
                continue
            name = preset.get("name") or ""
            if not name:
                continue
            mark = "  ✓" if name in recipes_on else ""
            self.list_recipes.addItem(
                _make_item(f"{name}{mark}", ("preset", preset))
            )

        for preset in sorted(users_src, key=lambda p: p.get("name") or ""):
            if not self._matches_machine(preset.get("systemTypes")):
                continue
            name = preset.get("name") or ""
            if not name:
                continue
            mark = "  ✓" if self._user_preset_applied(preset) else ""
            self.list_user_presets.addItem(
                _make_item(f"{name}{mark}", ("preset", preset))
            )

        show_sets = bool(
            getattr(self, "show_individual_sets", None)
            and self.show_individual_sets.isChecked()
        )
        self.box_sets.setVisible(show_sets)
        if not show_sets:
            return

        by_group: dict[str, list[dict]] = {}
        for s in self._catalog.get("sets") or []:
            name = s.get("name") or ""
            if not name or s.get("deprecatedAliasOf"):
                continue
            if not self._matches_machine(s.get("systemTypes")):
                continue
            group = (s.get("group") or "other").strip() or "other"
            by_group.setdefault(group, []).append(s)

        for group in sorted(by_group.keys(), key=lambda g: _humanize_group(g).lower()):
            entries = sorted(by_group[group], key=lambda x: x.get("name") or "")
            if not entries:
                continue
            self._add_list_header(
                self.list_sets, f"{_humanize_group(group)}  [system]"
            )
            for s in entries:
                name = s["name"]
                if name in covered:
                    row = f"{name}  ✓ (via recipe)"
                elif name in self._active:
                    row = f"{name}  ✓"
                else:
                    row = name
                self.list_sets.addItem(_make_item(row, ("set", s)))

    def _format_set_details(self, data: dict) -> str:
        name = data.get("name") or ""
        pkgs = _packages_in_set_file(name)
        via = ""
        for r in self._applied_system_recipes():
            if name in (r.get("modules") or []):
                via = f"Included via system recipe: {r.get('name')}"
                break
        lines = [
            name,
            "",
            "Kind: system set (package module)",
            "Scope: SYSTEM — whole machine (admin)",
            data.get("description") or "",
        ]
        if via:
            lines.extend(["", via])
        lines.extend(
            [
                "",
                f"Group: {data.get('group') or '—'}",
                f"Currently active: {'yes' if name in self._active else 'no'}",
            ]
        )
        deps = data.get("dependencies") or []
        if deps:
            lines.append(f"Depends on: {', '.join(deps)}")
        if pkgs:
            lines.extend(["", "Packages in this set (from module):", *[f"  • {p}" for p in pkgs]])
        else:
            lines.extend(
                [
                    "",
                    "(No package list extracted — set may enable programs.* "
                    "or services instead of listing pkgs.)",
                ]
            )
        return "\n".join(lines)

    def _user_preset_applied(self, data: dict) -> bool:
        pkgs = data.get("packages") or []
        if not pkgs:
            return False
        mine = set(self._mine)
        return all(p in mine for p in pkgs)

    def _is_user_preset_name(self, name: str) -> bool:
        p = self._presets_by_name.get(name) or {}
        return (p.get("scope") or "system") == "user"

    def _partition_names(self, names: list[str]) -> tuple[list[str], list[str]]:
        user: list[str] = []
        system: list[str] = []
        for n in names:
            if self._is_user_preset_name(n):
                user.append(n)
            else:
                system.append(n)
        return user, system

    def _format_preset_details(self, data: dict) -> str:
        name = data.get("name") or ""
        scope = data.get("scope") or "system"
        mods = data.get("modules") or []
        pkgs = data.get("packages") or []
        if scope == "user":
            scope_line = "Scope: USER — only your account (userPackages)"
            kind_line = "Kind: user preset"
        else:
            scope_line = "Scope: SYSTEM — whole machine (admin)"
            kind_line = "Kind: system recipe (expands to sets below)"
        lines = [
            name,
            "",
            kind_line,
            scope_line,
            data.get("description") or "",
        ]
        if scope == "user":
            applied = self._user_preset_applied(data)
            lines.extend(
                [
                    "",
                    f"Applied to your userPackages: {'yes' if applied else 'no'}",
                    "",
                    "Packages (→ users.<you>.userPackages):",
                ]
            )
            if pkgs:
                lines.extend(f"  • {p}" for p in pkgs)
            else:
                lines.append("  (none)")
            return "\n".join(lines)
        applied = bool(mods) and all(m in self._active for m in mods)
        lines.extend(
            [
                "",
                f"Recipe active (all sets on): {'yes' if applied else 'no'}",
                "",
                "Expands to system sets:",
            ]
        )
        for m in mods:
            meta = self._sets_by_name.get(m) or {}
            desc = meta.get("description") or ""
            active = " ✓ on" if m in self._active else ""
            if desc:
                lines.append(f"  • {m}{active} — {desc}")
            else:
                lines.append(f"  • {m}{active}")
            set_pkgs = _packages_in_set_file(m)
            for p in set_pkgs:
                lines.append(f"      - {p}")
        return "\n".join(lines)

    def _show_available_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None or not isinstance(cur, QListWidgetItem):
            return
        raw = cur.data(Qt.ItemDataRole.UserRole)
        if not raw:
            return
        kind, data = raw
        if kind == "header":
            return
        if kind == "preset":
            self.details.setPlainText(self._format_preset_details(data))
        else:
            self.details.setPlainText(self._format_set_details(data))

    def _show_active_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None or not isinstance(cur, QListWidgetItem):
            return
        raw = cur.data(Qt.ItemDataRole.UserRole)
        if raw and raw[0] == "preset":
            self.details.setPlainText(self._format_preset_details(raw[1]))
            return
        if raw and raw[0] == "set":
            self.details.setPlainText(self._format_set_details(raw[1]))
            return
        name = cur.text().replace("  ✓", "").strip()
        data = self._sets_by_name.get(name) or {"name": name}
        self.details.setPlainText(self._format_set_details(data))

    def _selected_available_names(self) -> list[str]:
        names: list[str] = []
        lists = []
        if hasattr(self, "list_recipes"):
            lists.extend(
                [self.list_recipes, self.list_user_presets, self.list_sets]
            )
        elif hasattr(self, "available"):
            lists.append(self.available)
        for lw in lists:
            for item in _selected(lw):
                raw = item.data(Qt.ItemDataRole.UserRole)
                if not raw or not isinstance(raw, tuple):
                    continue
                kind, data = raw
                if kind == "header":
                    continue
                name = data.get("name")
                if name and name not in names:
                    names.append(name)
        return names

    def _selected_active_names(self) -> list[str]:
        names: list[str] = []
        for item in _selected(self.active_list):
            raw = item.data(Qt.ItemDataRole.UserRole)
            if raw and isinstance(raw, tuple) and raw[1].get("name"):
                name = raw[1]["name"]
            else:
                name = item.text().replace("  ✓", "").strip()
                for suffix in ("  [user]", "  [system]"):
                    if name.endswith(suffix):
                        name = name[: -len(suffix)]
            if name and name not in names:
                names.append(name)
        return names

    def _stage_module(
        self, op: str, user_names: list[str], system_names: list[str]
    ) -> None:
        """Stage user presets (no root) and system sets/presets (root)."""
        undo = "remove" if op == "add" else "add"
        if user_names:
            self._stage(
                f"module {op} {', '.join(user_names)}",
                ["packages", "module", op, *user_names, "--no-build"],
                elevated=False,
                undo_argv=["packages", "module", undo, *user_names, "--no-build"],
                undo_elevated=False,
            )
        if system_names:
            self._stage(
                f"module {op} {', '.join(system_names)}",
                ["packages", "module", op, *system_names, "--no-build"],
                elevated=True,
                undo_argv=["packages", "module", undo, *system_names, "--no-build"],
                undo_elevated=True,
            )

    def _add_selected(self) -> None:
        if self._current_tab() == TAB_STORE:
            self._add_store_selected()
            return
        if self._current_tab() != TAB_SETS:
            return
        names = self._selected_available_names()
        if not names:
            info(
                self,
                "Add",
                "Mark one or more sets/presets in Available (click to toggle), then Add selected.",
            )
            return
        user_names, system_names = self._partition_names(names)
        if system_names and not self._can_system:
            error(
                self,
                "Packages",
                "Only administrators can change system sets/presets:\n"
                + ", ".join(system_names),
            )
            return
        self._stage_module("add", user_names, system_names)

    def _selected_store_intent(self) -> dict | None:
        if not hasattr(self, "store_results"):
            return None
        item = self.store_results.currentItem()
        if item is None:
            sels = _selected(self.store_results)
            item = sels[0] if sels else None
        if item is None:
            return None
        raw = item.data(Qt.ItemDataRole.UserRole)
        return raw if isinstance(raw, dict) else None

    def _rebuild_store(self) -> None:
        if not hasattr(self, "store_categories"):
            return
        q = ""
        if hasattr(self, "store_search"):
            q = self.store_search.text().strip()
        self.store_categories.blockSignals(True)
        self.store_categories.clear()
        for cat in self._catalog.get("categories") or []:
            if not isinstance(cat, dict) or not cat.get("id"):
                continue
            title = str(cat.get("title") or cat["id"])
            self.store_categories.addItem(
                _make_item(title, ("category", cat))
            )
        self.store_categories.blockSignals(False)

        empty = not self._mine and not self._active
        if empty and not q:
            self.store_empty.setText(
                "Browse a category (Media, Games, …) or search an app name. "
                "For bundles like streaming / gaming-desktop use Sets & recipes."
            )
            self.store_empty.setVisible(True)
        elif not q:
            self.store_empty.setText(
                "Browse a category or type an app name above."
            )
            self.store_empty.setVisible(True)
        else:
            self.store_empty.setVisible(False)

        if q:
            self._fill_store_results(search_intents(self._catalog, q, store_only=True))
        else:
            popular_ids = {
                "firefox",
                "vscode",
                "cursor",
                "steam",
                "obs",
                "vlc",
                "htop",
            }
            popular = [
                it
                for it in store_intents(self._catalog)
                if it.get("id") in popular_ids
            ]
            self._fill_store_results(popular)

    def _fill_store_results(self, intents: list[dict]) -> None:
        self.store_results.clear()
        if not intents:
            self.store_details.setPlainText(
                "No curated match.\n\n"
                "If you know the nixpkgs attribute name, use My packages → Add by name…\n"
                "Or try: ncc packages search <query>"
            )
            return
        for it in intents:
            if not is_store_intent(it):
                continue
            title = str(it.get("title") or it.get("id") or "")
            kind = it.get("kind") or "?"
            st = self._store_status(it)
            mark = ""
            if st["state"] != "missing":
                mark += "  ✓"
            part = it.get("partOfSet")
            if part:
                mark += f"  · set:{part}"
            if kind == "guided":
                row = f"{title}  [tip]{mark}"
            else:
                row = f"{title}  [app]{mark}"
            self.store_results.addItem(_make_item(row, it))
        if self.store_results.count() > 0:
            self.store_results.setCurrentRow(0)

    def _on_store_search(self, _text: str = "") -> None:
        if not hasattr(self, "store_results"):
            return
        q = self.store_search.text().strip()
        if not q:
            self._rebuild_store()
            return
        self.store_empty.setVisible(False)
        self._fill_store_results(search_intents(self._catalog, q, store_only=True))

    def _on_store_category(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None or not isinstance(cur, QListWidgetItem):
            return
        raw = cur.data(Qt.ItemDataRole.UserRole)
        if not raw or not isinstance(raw, tuple) or raw[0] != "category":
            return
        cat = raw[1]
        cid = str(cat.get("id") or "")
        if hasattr(self, "store_search"):
            self.store_search.blockSignals(True)
            self.store_search.clear()
            self.store_search.blockSignals(False)
        self.store_empty.setVisible(False)
        self._fill_store_results(
            intents_in_category(self._catalog, cid, store_only=True)
        )

    def _show_store_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None or not isinstance(cur, QListWidgetItem):
            return
        raw = cur.data(Qt.ItemDataRole.UserRole)
        if isinstance(raw, dict):
            self.store_details.setPlainText(
                format_intent_details(raw, status=self._store_status(raw))
            )

    def _add_store_selected(self) -> None:
        intent = self._selected_store_intent()
        if not intent:
            info(self, "Add", "Select a Store app, then Add selected.")
            return
        if intent.get("kind") == "guided":
            notes = intent.get("notes") or intent.get("description") or ""
            part = intent.get("partOfSet")
            hint = (
                f"\n\nRelated set: {part} under Sets & recipes."
                if part
                else "\n\nSee Sets & recipes for bundles."
            )
            info(
                self,
                str(intent.get("title") or "Tip"),
                f"{notes}{hint}",
            )
            return
        st = self._store_status(intent)
        if st.get("via_user"):
            info(
                self,
                "Already installed",
                f"{intent.get('title') or intent.get('attr')} is already in your "
                f"userPackages.\n\nStatus: {st['label']}\n\n"
                "Remove it from My packages if you want it gone. "
                "To get newer builds: Update nixpkgs… then Rebuild.",
            )
            return
        staged = stage_argv_for_intent(intent)
        if not staged:
            error(self, "Store", "Cannot stage this app automatically.")
            return
        summary, argv, elevated = staged
        if elevated and not self._can_system:
            error(
                self,
                "Packages",
                "Only administrators can install this:\n"
                + str(intent.get("title") or summary),
            )
            return
        undo = undo_argv_for_intent(intent)
        undo_argv = undo[0] if undo else None
        undo_elev = undo[1] if undo else False
        self._stage(
            summary,
            argv,
            elevated=elevated,
            undo_argv=undo_argv,
            undo_elevated=undo_elev,
        )

    def _try_selected(self) -> None:
        if self._current_tab() != TAB_STORE:
            return
        intent = self._selected_store_intent()
        if not intent:
            info(self, "Try", "Select a Store result that supports Try.")
            return
        if not intent.get("tryable") or not intent.get("attr"):
            error(
                self,
                "Try",
                "This item cannot be tried in nix-shell "
                "(needs a module enable and rebuild).\n\n"
                + (intent.get("notes") or ""),
            )
            return
        self._run_try_shell(str(intent.get("attr")))

    def _run_try_shell(self, attr: str) -> None:
        term = (
            shutil.which("konsole")
            or shutil.which("gnome-terminal")
            or shutil.which("xfce4-terminal")
            or shutil.which("xterm")
            or shutil.which("kitty")
            or shutil.which("alacritty")
        )
        nix_shell = shutil.which("nix-shell") or "nix-shell"
        if term:
            try:
                if "gnome-terminal" in term:
                    subprocess.Popen(
                        [term, "--", nix_shell, "-p", attr],
                        start_new_session=True,
                    )
                elif "konsole" in term:
                    subprocess.Popen(
                        [term, "-e", nix_shell, "-p", attr],
                        start_new_session=True,
                    )
                else:
                    subprocess.Popen(
                        [term, "-e", nix_shell, "-p", attr],
                        start_new_session=True,
                    )
                info(
                    self,
                    "Try",
                    f"Opened a temporary shell with {attr}.\n"
                    "Exit the shell when done, then Add selected to install permanently.",
                )
                return
            except OSError as exc:
                error(self, "Try", str(exc))
                return
        # Fallback: non-interactive smoke build
        proc = subprocess.run(
            [nix_shell, "-p", attr, "--run", "true"],
            check=False,
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0:
            info(
                self,
                "Try",
                f"{attr} is available via nix-shell.\n"
                "No graphical terminal found to open an interactive shell.\n"
                f"CLI: ncc packages try {attr}\n"
                "Add selected to install permanently into your userPackages.",
            )
        else:
            err = (proc.stderr or proc.stdout or "nix-shell failed").strip()
            error(self, "Try", err[:800])

    def _remove_selected(self) -> None:
        tab = self._current_tab()
        if tab == TAB_SETS:
            names = self._selected_active_names()
            if not names:
                for n in self._selected_available_names():
                    if self._is_user_preset_name(n):
                        p = self._presets_by_name.get(n) or {}
                        if self._user_preset_applied(p):
                            names.append(n)
                    elif n in self._active:
                        names.append(n)
            if not names:
                info(
                    self,
                    "Remove",
                    "Mark items in Active (or applied presets / active sets on the left).",
                )
                return
            user_names, system_names = self._partition_names(names)
            if system_names and not self._can_system:
                error(
                    self,
                    "Packages",
                    "Only administrators can change system sets/presets:\n"
                    + ", ".join(system_names),
                )
                return
            self._stage_module("remove", user_names, system_names)
            return

        if tab == TAB_MINE:
            names = [i.text() for i in _selected(self.mine_list)]
            if not names:
                info(self, "Remove", "Mark packages to remove.")
                return
            self._stage(
                f"remove {', '.join(names)}",
                ["packages", "remove", *names, "--no-build"],
                elevated=False,
                undo_argv=["packages", "add", *names, "--no-build"],
                undo_elevated=False,
            )
            return

        if tab == TAB_SYSTEM:
            if not self._can_system:
                return
            explicit: list[str] = []
            sets_to_drop: list[str] = []
            blocked: list[str] = []
            for item in _selected(self.system_list):
                raw = item.data(Qt.ItemDataRole.UserRole)
                if not isinstance(raw, dict):
                    continue
                kind = raw.get("kind")
                if kind == "explicit":
                    n = raw.get("name")
                    if n and n not in explicit:
                        explicit.append(n)
                elif kind in ("set", "set-meta"):
                    s = raw.get("set")
                    if s and s not in sets_to_drop:
                        sets_to_drop.append(s)
                else:
                    blocked.append(item.text())
            if blocked and not explicit and not sets_to_drop:
                info(
                    self,
                    "Remove",
                    "Base / hardware / audio rows are not removed here.\n"
                    "Change Desktop/Hardware/Audio or remove a set instead.\n\n"
                    + "\n".join(blocked[:12]),
                )
                return
            if not explicit and not sets_to_drop:
                info(self, "Remove", "Mark packages (or set rows) to remove.")
                return
            if sets_to_drop:
                self._stage(
                    f"module remove {', '.join(sets_to_drop)}",
                    ["packages", "module", "remove", *sets_to_drop, "--no-build"],
                    elevated=True,
                    undo_argv=[
                        "packages",
                        "module",
                        "add",
                        *sets_to_drop,
                        "--no-build",
                    ],
                    undo_elevated=True,
                )
            if explicit:
                self._stage(
                    f"remove --system {', '.join(explicit)}",
                    ["packages", "remove", *explicit, "--system", "--no-build"],
                    elevated=True,
                    undo_argv=[
                        "packages",
                        "add",
                        *explicit,
                        "--system",
                        "--no-build",
                    ],
                    undo_elevated=True,
                )

    def _add_by_name(self) -> None:
        tab = self._current_tab()
        raw, ok = QInputDialog.getText(
            self,
            "Add packages",
            "Package names (space or comma separated):",
        )
        if not ok or not raw.strip():
            return
        names = _parse_pkg_names(raw)
        if not names:
            error(self, "Packages", "No valid package names.")
            return

        if tab == TAB_MINE:
            self._stage(
                f"add {', '.join(names)}",
                ["packages", "add", *names, "--no-build"],
                elevated=False,
                undo_argv=["packages", "remove", *names, "--no-build"],
                undo_elevated=False,
            )
        elif tab == TAB_SYSTEM and self._can_system:
            self._stage(
                f"add --system {', '.join(names)}",
                ["packages", "add", *names, "--system", "--no-build"],
                elevated=True,
                undo_argv=[
                    "packages",
                    "remove",
                    *names,
                    "--system",
                    "--no-build",
                ],
                undo_elevated=True,
            )



def create_page() -> PackagesPage:
    return PackagesPage()


Page = PackagesPage
