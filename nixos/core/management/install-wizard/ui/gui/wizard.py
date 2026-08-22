#!/usr/bin/env python3
"""NCC install wizard — PySide6 UI matching the Control Center design kit.

Stdout: one selection line on success (exit 0). Cancel → exit 1. No display → 2.
Homelab/Docker answers → --answers-file as KEY=shell-quoted values.
"""

from __future__ import annotations

import argparse
import os
import re
import secrets
import sys
from pathlib import Path
from typing import Callable, Dict, List, Optional

def _gui_engine_python() -> Path | None:
    env = (os.environ.get("NCC_GUI_ENGINE_PYTHON") or "").strip()
    if env and Path(env).is_dir():
        return Path(env)
    # ui/gui → module root parents[2], sibling gui-engine
    mod = Path(__file__).resolve().parents[2]
    sibling = mod.parent / "gui-engine" / "python"
    if sibling.is_dir():
        return sibling
    here = Path(__file__).resolve().parent
    for p in [here, *here.parents]:
        cand = p / "nixos" / "core" / "management" / "gui-engine" / "python"
        if cand.is_dir():
            return cand
    return None


_GUI_ENGINE = _gui_engine_python()
if _GUI_ENGINE is not None:
    sys.path.insert(0, str(_GUI_ENGINE))

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QCheckBox,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QRadioButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

from install_wizard_logic import (
    DOMAIN_RE,
    EMAIL_RE,
    InstallOptions,
    default_admin,
    filter_feature_groups_for_system,
    filter_features_for_system,
    host_blueprints_dir,
    load_options,
    resolve_features,
    write_answers,
)

try:
    from ncc_gui.theme import APP_STYLE
except ImportError:  # pragma: no cover
    APP_STYLE = ""

try:
    from ncc_gui.branding import app_icon
except ImportError:  # pragma: no cover

    def app_icon():  # type: ignore[misc]
        from PySide6.QtGui import QIcon

        return QIcon()


def _is_dry_run() -> bool:
    return os.environ.get("NCC_DRY_RUN", "").lower() in ("1", "true", "yes", "on")


class InstallWizard(QMainWindow):
    def __init__(self, answers_file: Path, options: InstallOptions) -> None:
        super().__init__()
        self.answers_file = answers_file
        self.opts = options
        self._selection: Optional[str] = None
        self._answers: Dict[str, str] = {}
        self._path: List[str] = []
        self._state: dict = {}

        self.setWindowTitle("NixOS Control Center — Install")
        self.setMinimumSize(720, 560)
        self.resize(800, 640)
        icon = app_icon()
        if not icon.isNull():
            self.setWindowIcon(icon)

        root = QWidget()
        root.setObjectName("nccShellRoot")
        self.setCentralWidget(root)
        lay = QVBoxLayout(root)
        lay.setContentsMargins(20, 16, 20, 16)
        lay.setSpacing(10)

        brand = QLabel("NCC")
        brand.setObjectName("nccPageTitle")
        f = QFont()
        f.setPointSize(11)
        f.setBold(True)
        brand.setFont(f)
        lay.addWidget(brand)

        self.header = QLabel()
        self.header.setObjectName("nccPageTitle")
        lay.addWidget(self.header)

        self.subheader = QLabel()
        self.subheader.setObjectName("nccPageSubtitle")
        self.subheader.setWordWrap(True)
        lay.addWidget(self.subheader)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        self.body_host = QWidget()
        self.body = QVBoxLayout(self.body_host)
        self.body.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.body.setSpacing(8)
        self.scroll.setWidget(self.body_host)
        lay.addWidget(self.scroll, stretch=1)

        nav = QHBoxLayout()
        self.btn_back = QPushButton("Back")
        self.btn_back.clicked.connect(self._back)
        nav.addWidget(self.btn_back)
        nav.addStretch()
        self.btn_cancel = QPushButton("Cancel")
        self.btn_cancel.clicked.connect(self._cancel)
        nav.addWidget(self.btn_cancel)
        self.btn_next = QPushButton("Next")
        self.btn_next.setObjectName("nccPrimaryButton")
        self.btn_next.clicked.connect(self._next)
        nav.addWidget(self.btn_next)
        lay.addLayout(nav)

        self._navigate("welcome")

    def selection(self) -> Optional[str]:
        return self._selection

    # ---- chrome helpers ----

    def _clear_body(self) -> None:
        while self.body.count():
            item = self.body.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
            elif item.layout():
                self._clear_layout(item.layout())

    def _clear_layout(self, layout) -> None:
        while layout.count():
            item = layout.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
            elif item.layout():
                self._clear_layout(item.layout())

    def _add(self, w: QWidget) -> None:
        self.body.addWidget(w)

    def _info(self, title: str, text: str) -> None:
        QMessageBox.information(self, title, text)

    def _error(self, title: str, text: str) -> None:
        QMessageBox.critical(self, title, text)

    def _radio_group(
        self,
        options: List[tuple[str, str, str]],
        *,
        key: str,
        default: str,
    ) -> QButtonGroup:
        """options: (value, title, description)."""
        group = QButtonGroup(self)
        current = self._state.get(key, default)
        self._state[key] = current
        for value, title, desc in options:
            box = QGroupBox()
            box.setFlat(True)
            v = QVBoxLayout(box)
            rb = QRadioButton(title)
            rb.setChecked(value == current)
            group.addButton(rb)
            group.setId(rb, hash(value) & 0x7FFFFFFF)
            rb.toggled.connect(
                lambda on, val=value: self._state.__setitem__(key, val) if on else None
            )
            # Store value on button
            rb.setProperty("nccValue", value)
            v.addWidget(rb)
            if desc:
                d = QLabel(desc)
                d.setObjectName("nccMuted")
                d.setWordWrap(True)
                d.setStyleSheet("padding-left: 22px; color: palette(window-text);")
                v.addWidget(d)
            self._add(box)

        def sync() -> None:
            for b in group.buttons():
                if b.isChecked():
                    self._state[key] = b.property("nccValue")

        group.buttonClicked.connect(lambda _b: sync())
        return group

    def _clear_answers(self) -> None:
        self._answers.clear()

    # ---- navigation ----

    def _screens(self) -> Dict[str, Callable[[], None]]:
        return {
            "welcome": self._screen_welcome,
            "presets": self._screen_presets,
            "starters": self._screen_starters,
            "packages": self._screen_packages,
            "browsers": self._screen_browsers,
            "account": self._screen_account,
            "custom_type": self._screen_custom_type,
            "custom_de": self._screen_custom_de,
            "hl_basics": self._screen_hl_basics,
            "hl_type": self._screen_hl_type,
            "hl_swarm": self._screen_hl_swarm,
            "hl_docker_user": self._screen_hl_docker_user,
            "hl_virt_user": self._screen_hl_virt_user,
            "hl_hosting": self._screen_hl_hosting,
            "hl_desktop": self._screen_hl_desktop,
            "advanced": self._screen_advanced,
            "confirm": self._screen_confirm,
        }

    def _render(self, name: str) -> None:
        self._clear_body()
        self._screens()[name]()
        self.btn_back.setEnabled(name != "welcome")

    def _navigate(self, name: str) -> None:
        self._path.append(name)
        self._render(name)

    def _back(self) -> None:
        if len(self._path) <= 1:
            return
        self._path.pop()
        self._render(self._path[-1])

    def _needs_homelab(self) -> bool:
        return self._state.get("pending_selection") == "Homelab Server"

    def _needs_from_scratch(self) -> bool:
        return self._state.get("pending_selection") == "From Scratch"

    def _packages_include_docker(self) -> bool:
        return "docker" in self._answers.get("PACKAGE_MODULES", "").split()

    def _package_system_type(self) -> str:
        preset = self._state.get("pending_selection") or ""
        if preset == "From Scratch":
            return self._state.get("system_type") or "desktop"
        if preset in ("Server", "Homelab Server"):
            return "server"
        return "desktop"

    def _feature_groups_for_current_type(self):
        return filter_feature_groups_for_system(
            self.opts.feature_groups,
            self._package_system_type(),
            self.opts.feature_system_types,
        )

    def _is_desktop_install(self) -> bool:
        if self._needs_homelab():
            return self._answers.get("ENABLE_DESKTOP") == "true"
        if self._needs_from_scratch():
            return self._state.get("system_type") == "desktop" and bool(
                self._state.get("desktop_env")
            )
        preset = self._state.get("pending_selection") or ""
        if preset in ("Server", "Homelab Server"):
            return False
        return True

    def _needs_browsers_after_packages(self) -> bool:
        if self._needs_homelab():
            return False
        return self._is_desktop_install()

    def _continue_after_packages(self) -> None:
        if self._needs_homelab():
            self._navigate("hl_basics")
        elif self._needs_browsers_after_packages():
            self._navigate("browsers")
        elif self._packages_include_docker():
            self._answers.setdefault("ADMIN_USER", default_admin())
            self._navigate("hl_docker_user")
        else:
            self._navigate("account")

    def _continue_after_browsers(self) -> None:
        if self._needs_homelab():
            self._navigate("confirm")
        elif self._packages_include_docker():
            self._answers.setdefault("ADMIN_USER", default_admin())
            self._navigate("hl_docker_user")
        else:
            self._navigate("account")

    def _next(self) -> None:
        step = self._path[-1]
        if step == "welcome":
            choice = self._state.get("install_type", "presets")
            self._clear_answers()
            self._navigate("advanced" if choice == "advanced" else "presets")
        elif step == "presets":
            preset = self._state.get("preset") or ""
            if not preset:
                self._info("Select a base", "Please choose Desktop, Server, or From Scratch.")
                return
            self._clear_answers()
            self._state["pending_selection"] = preset
            self._state["starter"] = "None"
            if preset == "From Scratch":
                self._navigate("custom_type")
            else:
                self._navigate("starters")
        elif step == "starters":
            starter = self._state.get("starter") or "None"
            base = self._state.get("preset") or "Desktop"
            if starter in ("", "None"):
                self._state["pending_selection"] = base
                self._navigate("packages")
            elif starter == "Homelab Server":
                if base != "Server":
                    self._info(
                        "Homelab needs Server",
                        "Homelab starter is for Server install base.\n"
                        "Go back and pick Server, or choose None / a device target.",
                    )
                    return
                self._state["pending_selection"] = "Homelab Server"
                self._navigate("packages")
            elif starter in self.opts.device_presets:
                bp = self.opts.device_blueprint_map.get(starter, "")
                if not bp:
                    self._info("Missing blueprint", f"No host blueprint mapped for {starter}.")
                    return
                path = host_blueprints_dir() / bp
                if not path.is_file():
                    self._error("Blueprint missing", f"Expected file:\n{path}")
                    return
                self._state["pending_selection"] = f"LOAD_BLUEPRINT:{path}"
                self._navigate("confirm")
            else:
                self._info("Select a starter", "Pick None, Homelab, or a device target.")
                return
        elif step == "custom_type":
            st = self._state.get("system_type", "desktop")
            if st == "desktop":
                self._navigate("custom_de")
            else:
                self._state["desktop_env"] = ""
                self._navigate("packages")
        elif step == "custom_de":
            self._navigate("packages")
        elif step == "packages":
            if not self._capture_packages():
                return
            if self._needs_from_scratch():
                self._state["pending_selection"] = self._build_custom_selection()
            self._continue_after_packages()
        elif step == "browsers":
            if not self._capture_browsers():
                return
            self._continue_after_browsers()
        elif step == "account":
            if not self._capture_account():
                return
            self._navigate("confirm")
        elif step == "hl_basics":
            if not self._capture_hl_basics():
                return
            self._navigate("hl_type")
        elif step == "hl_type":
            if not self._capture_hl_type():
                return
            if self._answers.get("HOMELAB_TYPE") == "swarm":
                self._navigate("hl_swarm")
            else:
                self._navigate("hl_docker_user")
        elif step == "hl_swarm":
            if not self._capture_hl_swarm():
                return
            self._answers["USE_EXTRA_USER"] = "yes"
            self._answers["DOCKER_USER_SETUP"] = "yes"
            self._navigate("hl_virt_user")
        elif step == "hl_docker_user":
            if not self._capture_hl_docker_user():
                return
            if self._answers.get("USE_EXTRA_USER") == "yes":
                self._navigate("hl_virt_user")
            elif self._needs_homelab():
                self._answers["VIRT_USER"] = ""
                self._answers["VIRT_PASSWORD"] = ""
                self._navigate("hl_hosting")
            else:
                if "ADMIN_USER" not in self._answers:
                    self._navigate("account")
                else:
                    self._navigate("confirm")
        elif step == "hl_virt_user":
            if not self._capture_hl_virt_user():
                return
            if self._needs_homelab():
                self._navigate("hl_hosting")
            else:
                if "ADMIN_USER" not in self._answers:
                    self._navigate("account")
                else:
                    self._navigate("confirm")
        elif step == "hl_hosting":
            if not self._capture_hl_hosting():
                return
            self._navigate("hl_desktop")
        elif step == "hl_desktop":
            if not self._capture_hl_desktop():
                return
            if self._answers.get("ENABLE_DESKTOP") == "true":
                self._navigate("browsers")
            else:
                self._answers.pop("BROWSERS", None)
                self._navigate("confirm")
        elif step == "advanced":
            self._clear_answers()
            sel = self._build_advanced_selection()
            if sel is None:
                return
            self._state["pending_selection"] = sel
            self._navigate("confirm")
        elif step == "confirm":
            self._finish()

    def _finish(self) -> None:
        sel = self._state.get("pending_selection")
        if not sel:
            self._error("Error", "Nothing selected.")
            return
        write_answers(self.answers_file, self._answers)
        self._selection = sel
        self.close()

    def _cancel(self) -> None:
        self._selection = None
        self.close()

    def closeEvent(self, event) -> None:  # noqa: N802
        # Treat window X like cancel unless we already finished
        if self._selection is None and not getattr(self, "_finishing", False):
            pass
        event.accept()

    # ---- capture ----

    def _capture_account(self) -> bool:
        admin = (self._state.get("account_user") or "").strip()
        if not admin:
            self._info("Required", "Main username cannot be empty.")
            return False
        if admin == "root":
            self._error(
                "Invalid user",
                "Don't use 'root' as the main login user.\n"
                "Pick a normal username (e.g. your own).",
            )
            return False
        self._answers["ADMIN_USER"] = admin
        return True

    def _capture_packages(self) -> bool:
        checks: Dict[str, QCheckBox] = self._state.get("feature_checks") or {}
        selected = [n for n, cb in checks.items() if cb.isChecked()]
        st = self._package_system_type()
        selected = filter_features_for_system(
            selected, st, self.opts.feature_system_types
        )
        selected = resolve_features(
            selected, self.opts.conflicts, self.opts.dependencies
        )
        selected = filter_features_for_system(
            selected, st, self.opts.feature_system_types
        )
        self._answers["PACKAGE_MODULES"] = " ".join(selected)
        return True

    def _capture_browsers(self) -> bool:
        checks: Dict[str, QCheckBox] = self._state.get("browser_checks") or {}
        selected = [n for n, cb in checks.items() if cb.isChecked()]
        if not selected:
            self._info(
                "Select a browser",
                "Pick at least one browser for the desktop install.",
            )
            return False
        self._answers["BROWSERS"] = " ".join(selected)
        return True

    def _build_custom_selection(self) -> str:
        system_type = self._state.get("system_type") or "desktop"
        features: List[str] = []
        de = self._state.get("desktop_env") or ""
        if de:
            features.append(de)
        features.extend(self._answers.get("PACKAGE_MODULES", "").split())
        features = resolve_features(
            features, self.opts.conflicts, self.opts.dependencies
        )
        des = [f for f in features if f in ("plasma", "gnome", "xfce")]
        others = [f for f in features if f not in ("plasma", "gnome", "xfce")]
        if de and de not in des:
            des = [de]
        elif len(des) > 1:
            des = [de] if de in des else des[:1]
        return " ".join([system_type] + des + others)

    def _capture_hl_basics(self) -> bool:
        admin = (self._state.get("hl_admin") or "").strip()
        if not admin:
            self._info("Required", "Admin username cannot be empty.")
            return False
        if admin == "root":
            self._error(
                "Invalid user",
                "Don't use 'root' as the admin login user.\n"
                "Pick a normal username (e.g. your own).",
            )
            return False
        self._answers["ADMIN_USER"] = admin
        return True

    def _capture_hl_type(self) -> bool:
        t = self._state.get("hl_type") or "single"
        self._answers["HOMELAB_TYPE"] = t
        self._answers.setdefault("STACK_PROFILES", "homelab-core")
        if t == "single":
            self._answers["SWARM_ROLE"] = "none"
        return True

    def _capture_hl_swarm(self) -> bool:
        role = self._state.get("hl_swarm") or "manager"
        self._answers["SWARM_ROLE"] = role
        self._answers["HOMELAB_TYPE"] = "swarm"
        return True

    def _capture_hl_docker_user(self) -> bool:
        use = self._state.get("hl_extra_user") or "yes"
        self._answers["USE_EXTRA_USER"] = use
        self._answers["DOCKER_USER_SETUP"] = use
        return True

    def _capture_hl_virt_user(self) -> bool:
        virt = (self._state.get("hl_virt_user") or "docker").strip() or "docker"
        admin = self._answers.get("ADMIN_USER", default_admin())
        if virt == admin:
            self._error("Conflict", "Admin user and virtualization user cannot be the same.")
            return False
        pw = self._state.get("hl_virt_pw") or ""
        pw2 = self._state.get("hl_virt_pw2") or ""
        suggested = self._state.get("hl_virt_pw_suggested") or ""
        if not pw and not pw2:
            pw = suggested
        elif len(pw) < 8:
            self._error("Too short", "Password must be at least 8 characters.")
            return False
        elif pw != pw2:
            self._error("Mismatch", "Passwords do not match.")
            return False
        self._answers["VIRT_USER"] = virt
        self._answers["VIRT_PASSWORD"] = pw
        self._answers["USE_EXTRA_USER"] = "yes"
        self._answers["DOCKER_USER_SETUP"] = "yes"
        return True

    def _capture_hl_hosting(self) -> bool:
        email = (self._state.get("hl_email") or "").strip()
        domain = (self._state.get("hl_domain") or "").strip()
        if not EMAIL_RE.match(email):
            self._error("Invalid email", "Please enter a valid email address.")
            return False
        if not DOMAIN_RE.match(domain):
            self._error("Invalid domain", "Please enter a valid domain (e.g. example.com).")
            return False
        self._answers["EMAIL"] = email
        self._answers["DOMAIN"] = domain
        return True

    def _capture_hl_desktop(self) -> bool:
        self._answers["ENABLE_DESKTOP"] = self._state.get("hl_desktop") or "true"
        return True

    # ---- screens ----

    def _install_type_value(self, label: str) -> str:
        low = label.lower()
        if "install base" in low or "preset" in low:
            return "presets"
        if "custom" in low:
            return "custom"
        return "advanced"

    def _screen_welcome(self) -> None:
        self.header.setText("Install NixOS Control Center")
        self.subheader.setText(
            "Pick an install base (then tweak packages), or Advanced to load a host blueprint."
        )
        self.btn_next.setText("Next")
        types = self.opts.install_types or ["Install bases", "Advanced Options"]
        default = self._state.get("install_type") or self._install_type_value(types[0])
        opts = []
        for label in types:
            value = self._install_type_value(label)
            title = re.sub(r"^[^\w]+", "", label).strip() or label
            desc = self.opts.desc(title, self.opts.desc(value, ""))
            opts.append((value, title, desc))
        self._radio_group(opts, key="install_type", default=default)

    def _screen_presets(self) -> None:
        self.header.setText("Choose an install base")
        self.subheader.setText(
            "Desktop or Server first. Optional Homelab starter next; "
            "hardware device targets only if this machine matches."
        )
        self.btn_next.setText("Next")
        presets = list(self.opts.system_presets) or ["Desktop", "Server", "From Scratch"]
        default = self._state.get("preset") or (presets[0] if presets else "Desktop")
        opts = []
        for name in presets:
            defaults = self.opts.preset_defaults.get(name, [])
            extra = (
                f"Defaults: {', '.join(defaults)}"
                if defaults
                else "Defaults: (none — add extras after starter)"
            )
            desc = self.opts.desc(name)
            hint = f"{desc}\n{extra}" if desc else extra
            opts.append((name, name, hint))
        self._radio_group(opts, key="preset", default=default)

    def _screen_starters(self) -> None:
        base = self._state.get("preset") or "Desktop"
        self.header.setText("Optional starter")
        self.subheader.setText(
            f"Base: {base}. Homelab is a software starter (Server). "
            "Hardware blueprints appear only when this machine matches "
            "(discovered device targets). All blueprints stay under Advanced."
        )
        self.btn_next.setText("Next")
        from device_detect import detect_matched_device_targets

        matched = set(detect_matched_device_targets(self.opts.device_presets))
        starters: list[str] = []
        for s in self.opts.install_starters or ["None"]:
            if s == "Homelab Server" and base != "Server":
                continue
            starters.append(s)
        for d in self.opts.device_presets:
            if d in matched and d not in starters:
                starters.append(d)
        if "None" not in starters:
            starters.insert(0, "None")
        default = self._state.get("starter") or "None"
        if default not in starters:
            default = "None"
        opts = []
        for name in starters:
            if name == "None":
                desc = self.opts.desc("none", "Plain install base — choose packages next.")
            else:
                defaults = self.opts.preset_defaults.get(name, [])
                extra = (
                    f"Defaults: {', '.join(defaults)}"
                    if defaults
                    else (
                        f"Loads host blueprint: {self.opts.device_blueprint_map.get(name, '?')}"
                        if name in self.opts.device_presets
                        else "Defaults: (none)"
                    )
                )
                d = self.opts.desc(name)
                desc = f"{d}\n{extra}" if d else extra
            opts.append((name, name, desc))
        if matched:
            hint = QLabel("Detected hardware: " + ", ".join(sorted(matched)))
            hint.setObjectName("nccPageSubtitle")
            self._add(hint)
        else:
            hint = QLabel(
                "No matching device hardware detected — use Advanced → blueprints to load manually."
            )
            hint.setObjectName("nccPageSubtitle")
            self._add(hint)
        self._radio_group(opts, key="starter", default=default)

    def _screen_packages(self) -> None:
        preset = self._state.get("pending_selection", "")
        st = self._package_system_type()
        self.header.setText("Packages / features")
        defaults = filter_features_for_system(
            self.opts.preset_defaults.get(preset, []),
            st,
            self.opts.feature_system_types,
        )
        if preset == "From Scratch":
            self.subheader.setText(
                f"Select package modules for this {st} install "
                f"(server-only / desktop-only sets are hidden)."
            )
            defaults = []
        else:
            self.subheader.setText(
                f"Install base “{preset}” ({st}): defaults pre-checked. "
                f"Incompatible modules for this type are hidden."
            )
        self.btn_next.setText("Next")

        prev = self._state.get("_packages_for_preset")
        prev_st = self._state.get("_packages_for_system_type")
        saved: Dict[str, bool] = {}
        if prev == preset and prev_st == st:
            old = self._state.get("feature_checks") or {}
            for name, cb in old.items():
                try:
                    saved[name] = bool(cb.isChecked())
                except RuntimeError:
                    pass
        self._state["_packages_for_preset"] = preset
        self._state["_packages_for_system_type"] = st

        checks: Dict[str, QCheckBox] = {}
        self._state["feature_checks"] = checks
        default_set = set(defaults)
        groups = self._feature_groups_for_current_type()
        if not groups:
            self._add(QLabel("No package modules available for this system type."))
            return
        for group_name, features in groups:
            box = QGroupBox(group_name)
            v = QVBoxLayout(box)
            for feat in features:
                d = self.opts.desc(feat, "")
                label = f"{feat} — {d}" if d else feat
                cb = QCheckBox(label)
                if feat in saved:
                    cb.setChecked(saved[feat])
                else:
                    cb.setChecked(feat in default_set)
                checks[feat] = cb
                v.addWidget(cb)
            self._add(box)

    def _screen_browsers(self) -> None:
        self.header.setText("Web browsers")
        self.subheader.setText(
            "Desktop installs need at least one browser. Firefox is pre-selected."
        )
        self.btn_next.setText("Next")
        saved: Dict[str, bool] = {}
        for name, cb in (self._state.get("browser_checks") or {}).items():
            try:
                saved[name] = bool(cb.isChecked())
            except RuntimeError:
                pass
        checks: Dict[str, QCheckBox] = {}
        self._state["browser_checks"] = checks
        default = self.opts.browser_default or "firefox"
        for name, label in self.opts.browser_choices:
            cb = QCheckBox(label)
            if name in saved:
                cb.setChecked(saved[name])
            else:
                cb.setChecked(name == default)
            checks[name] = cb
            self._add(cb)

    def _screen_account(self) -> None:
        self.header.setText("Main user account")
        self.subheader.setText("Primary login user for this machine (not root).")
        self.btn_next.setText("Next")
        form = QFormLayout()
        edit = QLineEdit(self._state.get("account_user") or default_admin())
        edit.textChanged.connect(lambda t: self._state.__setitem__("account_user", t))
        self._state["account_user"] = edit.text()
        form.addRow("Username", edit)
        wrap = QWidget()
        wrap.setLayout(form)
        self._add(wrap)

    def _screen_custom_type(self) -> None:
        self.header.setText("System type")
        self.subheader.setText("Desktop includes a graphical environment; Server is CLI-first.")
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("desktop", "Desktop", self.opts.desc("desktop")),
                ("server", "Server", self.opts.desc("server")),
            ],
            key="system_type",
            default=self._state.get("system_type") or "desktop",
        )

    def _screen_custom_de(self) -> None:
        self.header.setText("Desktop environment")
        self.subheader.setText("Pick the UI you want (or None for CLI-only).")
        self.btn_next.setText("Next")
        envs = self.opts.desktop_envs or ["plasma", "gnome", "xfce", ""]
        default = self._state.get("desktop_env")
        if default is None:
            default = "plasma" if "plasma" in envs else envs[0]
        opts = []
        for env_id in envs:
            label = self.opts.desktop_env_label(env_id)
            desc_key = "plasma (kde)" if env_id == "plasma" else (env_id or "none")
            opts.append((env_id, label, self.opts.desc(desc_key)))
        self._radio_group(opts, key="desktop_env", default=default)

    def _screen_hl_basics(self) -> None:
        self.header.setText("Homelab — admin user")
        self.subheader.setText("Primary admin account for this machine (not root).")
        self.btn_next.setText("Next")
        form = QFormLayout()
        edit = QLineEdit(self._state.get("hl_admin") or default_admin())
        edit.textChanged.connect(lambda t: self._state.__setitem__("hl_admin", t))
        self._state["hl_admin"] = edit.text()
        form.addRow("Admin username", edit)
        wrap = QWidget()
        wrap.setLayout(form)
        self._add(wrap)

    def _screen_hl_type(self) -> None:
        self.header.setText("Homelab — topology")
        self.subheader.setText("Single server is the default. Multi-server uses Docker Swarm.")
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("single", "Single server", ""),
                ("swarm", "Multi-server (Docker Swarm)", ""),
            ],
            key="hl_type",
            default=self._state.get("hl_type") or "single",
        )

    def _screen_hl_swarm(self) -> None:
        self.header.setText("Homelab — Swarm role")
        self.subheader.setText("Manager coordinates the swarm; Worker joins an existing one.")
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("manager", "Manager", ""),
                ("worker", "Worker", ""),
            ],
            key="hl_swarm",
            default=self._state.get("hl_swarm") or "manager",
        )

    def _screen_hl_docker_user(self) -> None:
        self.header.setText("Docker user setup")
        self.subheader.setText(
            "A separate virtualization user is safer for Docker. Recommended for Homelab."
        )
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("yes", "Yes — separate Docker/virt user", ""),
                ("no", "No — use the admin user only", ""),
            ],
            key="hl_extra_user",
            default=self._state.get("hl_extra_user") or "yes",
        )

    def _screen_hl_virt_user(self) -> None:
        self.header.setText("Virtualization user")
        self.subheader.setText(
            "Username + password for the Docker/virt account. Leave password empty for a random one."
        )
        self.btn_next.setText("Next")
        suggested = self._state.get("hl_virt_pw_suggested") or f"P@ssw0rd-{secrets.token_hex(4)}"
        self._state["hl_virt_pw_suggested"] = suggested
        form = QFormLayout()
        u = QLineEdit(self._state.get("hl_virt_user") or "docker")
        u.textChanged.connect(lambda t: self._state.__setitem__("hl_virt_user", t))
        self._state["hl_virt_user"] = u.text()
        form.addRow("Username", u)
        hint = QLabel(f"Suggested password: {suggested}")
        hint.setObjectName("nccMuted")
        form.addRow("", hint)
        p1 = QLineEdit(self._state.get("hl_virt_pw") or "")
        p1.setEchoMode(QLineEdit.EchoMode.Password)
        p1.textChanged.connect(lambda t: self._state.__setitem__("hl_virt_pw", t))
        form.addRow("Password (empty = use suggested)", p1)
        p2 = QLineEdit(self._state.get("hl_virt_pw2") or "")
        p2.setEchoMode(QLineEdit.EchoMode.Password)
        p2.textChanged.connect(lambda t: self._state.__setitem__("hl_virt_pw2", t))
        form.addRow("Confirm password", p2)
        wrap = QWidget()
        wrap.setLayout(form)
        self._add(wrap)

    def _screen_hl_hosting(self) -> None:
        self.header.setText("Homelab — hosting")
        self.subheader.setText("Used for certificates / reverse-proxy defaults.")
        self.btn_next.setText("Next")
        form = QFormLayout()
        email = QLineEdit(
            self._state.get("hl_email") or os.environ.get("HOST_EMAIL", "")
        )
        email.textChanged.connect(lambda t: self._state.__setitem__("hl_email", t))
        self._state["hl_email"] = email.text()
        form.addRow("Email", email)
        domain = QLineEdit(
            self._state.get("hl_domain") or os.environ.get("HOST_DOMAIN", "")
        )
        domain.textChanged.connect(lambda t: self._state.__setitem__("hl_domain", t))
        self._state["hl_domain"] = domain.text()
        form.addRow("Domain (e.g. example.com)", domain)
        wrap = QWidget()
        wrap.setLayout(form)
        self._add(wrap)

    def _screen_hl_desktop(self) -> None:
        self.header.setText("Homelab — desktop")
        self.subheader.setText(
            'Enable a desktop environment on this server? ("no" can be buggy until reboot after build.)'
        )
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("true", "Yes — enable desktop (Plasma)", ""),
                ("false", "No — CLI only", ""),
            ],
            key="hl_desktop",
            default=self._state.get("hl_desktop") or "true",
        )

    def _screen_advanced(self) -> None:
        self.header.setText("Advanced options")
        self.subheader.setText("Load a host blueprint or import an existing systemConfig.")
        self.btn_next.setText("Next")
        self._radio_group(
            [
                ("profiles", "Browse available host blueprints", ""),
                ("file", "Load host blueprint from file…", ""),
                ("import", "Import existing system config", ""),
            ],
            key="advanced_action",
            default=self._state.get("advanced_action") or "profiles",
        )
        plist = host_blueprints_dir()
        names = sorted(p.name for p in plist.iterdir() if p.is_file()) if plist.is_dir() else []
        if names:
            self._add(QLabel("Host blueprints:"))
            lb = QListWidget()
            lb.setMaximumHeight(180)
            for n in names:
                lb.addItem(QListWidgetItem(n))
            pick = self._state.get("profile_pick") or ""
            if pick:
                matches = lb.findItems(pick, Qt.MatchFlag.MatchExactly)
                if matches:
                    lb.setCurrentItem(matches[0])
            lb.currentTextChanged.connect(
                lambda t: self._state.__setitem__("profile_pick", t)
            )
            self._add(lb)
        else:
            self._add(QLabel(f"No host blueprints in {plist}"))

    def _needs_stack_phase2_hint(self) -> bool:
        sel = self._state.get("pending_selection") or ""
        if sel == "Homelab Server":
            return True
        if self._answers.get("STACK_PROFILES") or self._answers.get("HOMELAB_TYPE"):
            return True
        mods = (self._answers.get("PACKAGE_MODULES") or "").split()
        return "docker" in mods and bool(self._answers.get("DOMAIN"))

    def _screen_confirm(self) -> None:
        dry = _is_dry_run()
        self.header.setText("Confirm" + (" (DRY-RUN)" if dry else ""))
        phase2 = (
            "\n\nAfter rebuild: Phase 2 — workloads\n"
            "  sudo -u <virt-user> ncc stacks fetch\n"
            "  sudo -u <virt-user> ncc stacks init\n"
            "  (or ncc stacks --gui → Catalog → Install)\n"
            "  Single stack: ncc stacks install group/service"
        )
        if dry:
            sub = "DRY-RUN: validate path only — nothing will be written or deployed."
        elif self._needs_stack_phase2_hint():
            sub = (
                "Review selection and answers, then start install."
                + phase2
            )
        else:
            sub = "Review selection and answers, then start install."
        self.subheader.setText(sub)
        self.btn_next.setText("Dry-run" if dry else "Install")
        sel = self._state.get("pending_selection", "")
        self._add(QLabel("Selection"))
        sel_l = QLabel(str(sel))
        sel_l.setWordWrap(True)
        sel_l.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        mono = QFont("monospace")
        mono.setStyleHint(QFont.StyleHint.Monospace)
        sel_l.setFont(mono)
        self._add(sel_l)
        if self._answers:
            self._add(QLabel("Answers"))
            safe = {
                k: ("••••••••" if "PASSWORD" in k else v)
                for k, v in self._answers.items()
                if v != ""
            }
            summary = "\n".join(f"{k}={v}" for k, v in safe.items()) or "(none)"
            ans = QLabel(summary)
            ans.setWordWrap(True)
            ans.setFont(mono)
            ans.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            self._add(ans)

    def _build_advanced_selection(self) -> Optional[str]:
        action = self._state.get("advanced_action") or "profiles"
        if action == "profiles":
            name = self._state.get("profile_pick") or ""
            if not name:
                self._info("Pick a blueprint", "Select a host blueprint from the list.")
                return None
            path = host_blueprints_dir() / name
            if not path.is_file():
                self._error("Missing", f"Host blueprint not found:\n{path}")
                return None
            return f"LOAD_BLUEPRINT:{path}"
        if action == "file":
            path, _ = QFileDialog.getOpenFileName(
                self,
                "Select host blueprint",
                "",
                "Nix / blueprint (*.nix *);;All (*)",
            )
            if not path:
                return None
            return f"LOAD_BLUEPRINT:{path}"
        cfg = os.environ.get("SYSTEM_CONFIG_FILE", "/etc/nixos/system-config.nix")
        monolith = os.environ.get("MONOLITH_FILE", "/etc/nixos/systemConfig.nix")
        for candidate in (monolith, cfg):
            if candidate and Path(candidate).is_file():
                return f"IMPORT_CONFIG:{candidate}"
        self._error(
            "No config",
            f"No existing config found at:\n{monolith}\nor\n{cfg}",
        )
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description="NCC install GUI wizard")
    parser.add_argument(
        "--answers-file",
        default=os.environ.get("NCC_GUI_ANSWERS_FILE", ""),
        help="Write Homelab/Docker answers here for the bash backend",
    )
    args = parser.parse_args()

    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        print("No graphical display (DISPLAY/WAYLAND_DISPLAY unset).", file=sys.stderr)
        return 2

    answers = Path(
        args.answers_file
        or os.environ.get("NCC_GUI_ANSWERS_FILE")
        or f"{os.environ.get('TMPDIR', '/tmp')}/ncc-gui-answers-{os.getpid()}"
    )

    try:
        options = load_options()
    except Exception as exc:
        print(f"Failed to load options from shell: {exc}", file=sys.stderr)
        return 2

    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("NCC Install")
    if APP_STYLE:
        app.setStyleSheet(APP_STYLE)
    icon = app_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)

    try:
        win = InstallWizard(answers, options)
    except Exception as exc:
        print(f"Failed to start GUI: {exc}", file=sys.stderr)
        return 2

    win.show()
    app.exec()
    selection = win.selection()
    if not selection:
        print("Install cancelled.", file=sys.stderr)
        return 1
    print(f"NCC_GUI_ANSWERS_FILE={answers}", file=sys.stderr)
    print(selection)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
