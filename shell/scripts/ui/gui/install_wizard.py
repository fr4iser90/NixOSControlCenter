#!/usr/bin/env python3
"""NCC install wizard — full GUI over the install selection + Homelab prompts.

Prints one selection line to stdout on success (exit 0). Cancel → exit 1.
Homelab (and related) answers are written to --answers-file as KEY=shell-quoted values.
"""

from __future__ import annotations

import argparse
import getpass
import os
import re
import secrets
import shlex
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Dict, List, Optional, Tuple

EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
DOMAIN_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$")


class InstallOptions:
    """Loaded from shell/scripts/ui/prompts via export-options.sh (SSOT)."""

    def __init__(self) -> None:
        self.system_presets: List[str] = []
        self.device_presets: List[str] = []
        self.feature_groups: List[Tuple[str, List[str]]] = []  # (name, features) sans Desktop Env
        self.desktop_envs: List[str] = []  # internal ids incl. "none"
        self.install_types: List[str] = []
        self.advanced_options: List[str] = []
        self.conflicts: Dict[str, set] = {}
        self.dependencies: Dict[str, set] = {}
        self.descriptions: Dict[str, str] = {}
        self.preset_defaults: Dict[str, List[str]] = {}
        # (nixpkgs attr, UI label) — SSOT: setup-options.sh DESKTOP_BROWSERS
        self.browser_choices: List[Tuple[str, str]] = []
        self.browser_default: str = "firefox"
        # feature → allowed systemTypes (from metadata.nix); empty set = unrestricted
        self.feature_system_types: Dict[str, set] = {}

    def desc(self, name: str, fallback: str = "") -> str:
        key = name.strip().lower()
        if key in self.descriptions:
            return self.descriptions[key]
        # strip emoji / punctuation prefixes from INSTALL_TYPE labels
        bare = re.sub(r"^[^\w]+", "", key).strip()
        return self.descriptions.get(bare, fallback or name)

    def desktop_env_label(self, env_id: str) -> str:
        if env_id in ("", "none"):
            return "None (CLI only)"
        # descriptions use keys like "plasma (kde)"
        for key, text in self.descriptions.items():
            if key.startswith(env_id):
                # Prefer short label from description first sentence / known map
                if env_id == "plasma":
                    return "Plasma (KDE)"
                return env_id.upper() if env_id in ("gnome", "xfce") else env_id
        if env_id == "plasma":
            return "Plasma (KDE)"
        if env_id == "gnome":
            return "GNOME"
        if env_id == "xfce":
            return "XFCE"
        return env_id


def _export_options_script() -> Path:
    return Path(__file__).resolve().parent / "export-options.sh"


def load_options() -> InstallOptions:
    """Source setup-options.sh + descriptions via export-options.sh."""
    script = _export_options_script()
    if not script.is_file():
        raise FileNotFoundError(f"Missing options exporter: {script}")

    import subprocess

    proc = subprocess.run(
        ["bash", str(script)],
        check=True,
        capture_output=True,
        text=True,
    )
    opts = InstallOptions()
    section: Optional[str] = None
    for raw in proc.stdout.splitlines():
        line = raw.rstrip("\n")
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if not line or section is None:
            continue
        if section == "SYSTEM_PRESETS":
            opts.system_presets.append(line)
        elif section == "DEVICE_PRESETS":
            opts.device_presets.append(line)
        elif section == "FEATURE_GROUPS":
            name, _, feats = line.partition(":")
            if name == "Desktop Environment":
                continue  # handled via DESKTOP_ENVS screen
            opts.feature_groups.append((name, [f for f in feats.split("|") if f]))
        elif section == "DESKTOP_ENVS":
            opts.desktop_envs.append("" if line == "none" else line)
        elif section == "INSTALL_TYPE_OPTIONS":
            opts.install_types.append(line)
        elif section == "ADVANCED_OPTIONS":
            opts.advanced_options.append(line)
        elif section == "FEATURE_CONFLICTS":
            k, _, v = line.partition("=")
            opts.conflicts[k] = {x for x in v.split("|") if x}
        elif section == "FEATURE_DEPENDENCIES":
            k, _, v = line.partition("=")
            opts.dependencies[k] = {x for x in v.split("|") if x}
        elif section == "PRESET_DEFAULT_PACKAGES":
            k, _, v = line.partition("=")
            opts.preset_defaults[k] = [x for x in v.split() if x]
        elif section == "DESKTOP_BROWSERS":
            pkg, _, label = line.partition("|")
            pkg = pkg.strip()
            if pkg:
                opts.browser_choices.append((pkg, label.strip() or pkg))
        elif section == "DESKTOP_BROWSER_DEFAULT":
            if line.strip():
                opts.browser_default = line.strip()
        elif section == "FEATURE_SYSTEM_TYPES":
            k, _, v = line.partition("=")
            opts.feature_system_types[k.strip()] = {x for x in v.split("|") if x}
        elif section == "DESCRIPTIONS":
            k, _, v = line.partition("=")
            opts.descriptions[k.lower()] = v
    if not opts.browser_choices:
        # Fallback if export is incomplete
        opts.browser_choices = [
            ("firefox", "Firefox — default, free"),
            ("chromium", "Chromium — open-source Chrome"),
            ("brave", "Brave — privacy Chromium (unfree)"),
            ("librewolf", "LibreWolf — privacy Firefox fork"),
        ]
    return opts


def resolve_features(
    selected: List[str],
    conflicts: Dict[str, set],
    dependencies: Dict[str, set],
) -> List[str]:
    kept: List[str] = []
    for feat in selected:
        conf = conflicts.get(feat, set())
        if any(c in kept for c in conf):
            continue
        if any(feat in conflicts.get(k, set()) for k in kept):
            continue
        kept.append(feat)
    resolved = list(kept)
    for feat in list(resolved):
        for dep in dependencies.get(feat, set()):
            if dep not in resolved:
                resolved.append(dep)
    return resolved


def feature_allowed_for_system(feat: str, system_type: str, type_map: Dict[str, set]) -> bool:
    """True if metadata allows feat for system_type (missing entry = allow)."""
    allowed = type_map.get(feat)
    if not allowed:
        return True
    return system_type in allowed


def filter_features_for_system(
    features: List[str],
    system_type: str,
    type_map: Dict[str, set],
) -> List[str]:
    return [f for f in features if feature_allowed_for_system(f, system_type, type_map)]


def filter_feature_groups_for_system(
    groups: List[Tuple[str, List[str]]],
    system_type: str,
    type_map: Dict[str, set],
) -> List[Tuple[str, List[str]]]:
    out: List[Tuple[str, List[str]]] = []
    for name, feats in groups:
        allowed = filter_features_for_system(feats, system_type, type_map)
        if allowed:
            out.append((name, allowed))
    return out


def profiles_dir() -> Path:
    setup = os.environ.get("SETUP_DIR", "")
    if setup:
        return Path(setup) / "modes" / "profiles"
    here = Path(__file__).resolve()
    return here.parents[2] / "setup" / "modes" / "profiles"


def write_answers(path: Path, data: Dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# NCC GUI answers — generated by install_wizard.py"]
    for key, value in data.items():
        if value is None:
            continue
        lines.append(f"{key}={shlex.quote(str(value))}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def default_admin() -> str:
    """Prefer the real user under sudo — never silently pick root."""
    for key in ("SUDO_USER", "PKEXEC_UID", "LOGNAME"):
        val = os.environ.get(key, "").strip()
        if key == "PKEXEC_UID" and val.isdigit():
            try:
                import pwd

                return pwd.getpwuid(int(val)).pw_name
            except Exception:
                continue
        if val and val != "root":
            return val
    try:
        user = getpass.getuser()
        if user and user != "root":
            return user
    except Exception:
        pass
    # Last resort: still avoid root as a "friendly" default
    return os.environ.get("SUDO_USER") or "user"


# Theme tokens
BG = "#14161a"
FG = "#e8eaed"
MUTED = "#9aa0a6"
ACCENT = "#4a9eff"
FIELD = "#1e2229"
ROW = "#1a1d23"
SELECT_BG = "#2a4a6a"
SELECT_FG = "#ffffff"


class InstallWizard(tk.Tk):
    def __init__(self, answers_file: Path, options: InstallOptions) -> None:
        super().__init__()
        self.answers_file = answers_file
        self.opts = options
        self.title("NixOS Control Center — Install")
        self.minsize(640, 520)
        self.geometry("740x600")
        self.configure(bg=BG)

        self._selection: Optional[str] = None
        self._answers: Dict[str, str] = {}
        self._path: List[str] = []
        self._vars: dict = {}

        self._style()
        self._build_chrome()
        self._navigate("welcome")

        self.bind("<Escape>", lambda _e: self._cancel())
        self.protocol("WM_DELETE_WINDOW", self._cancel)

    def _style(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        # Global selection colors (fixes white-on-white)
        self.option_add("*selectBackground", SELECT_BG)
        self.option_add("*selectForeground", SELECT_FG)
        self.option_add("*Entry.selectBackground", SELECT_BG)
        self.option_add("*Entry.selectForeground", SELECT_FG)
        self.option_add("*Text.selectBackground", SELECT_BG)
        self.option_add("*Text.selectForeground", SELECT_FG)

        style.configure(".", background=BG, foreground=FG, fieldbackground=FIELD)
        style.configure("TFrame", background=BG)
        style.configure("TLabel", background=BG, foreground=FG, font=("Sans", 11))
        style.configure("Title.TLabel", background=BG, foreground=FG, font=("Sans", 18, "bold"))
        style.configure("Sub.TLabel", background=BG, foreground=MUTED, font=("Sans", 10))
        style.configure("Hint.TLabel", background=BG, foreground=MUTED, font=("Sans", 9))
        style.configure("TButton", font=("Sans", 10), padding=8)
        style.configure("Accent.TButton", font=("Sans", 10, "bold"), padding=8)
        style.map("Accent.TButton", background=[("active", ACCENT)])
        style.configure(
            "TRadiobutton",
            background=BG,
            foreground=FG,
            font=("Sans", 11, "bold"),
            focuscolor=BG,
            indicatorcolor=FIELD,
        )
        style.map(
            "TRadiobutton",
            background=[("active", BG), ("selected", BG)],
            foreground=[("active", FG), ("selected", FG)],
            indicatorcolor=[("selected", ACCENT), ("!selected", FIELD)],
        )
        style.configure(
            "TCheckbutton",
            background=BG,
            foreground=FG,
            font=("Sans", 11),
            focuscolor=BG,
        )
        style.map(
            "TCheckbutton",
            background=[("active", BG), ("selected", BG)],
            foreground=[("active", FG), ("selected", FG)],
        )
        style.configure("TLabelframe", background=BG, foreground=FG)
        style.configure("TLabelframe.Label", background=BG, foreground=FG, font=("Sans", 10, "bold"))
        style.configure("TEntry", fieldbackground=FIELD, foreground=FG, insertcolor=FG)
        style.map("TEntry", fieldbackground=[("focus", FIELD)], foreground=[("focus", FG)])

    def _clear_answers(self) -> None:
        """Drop leftover Homelab/Docker answers when switching install path."""
        self._answers.clear()

    def _entry(self, parent: tk.Misc, textvariable: tk.StringVar, show: str = "") -> tk.Entry:
        """tk.Entry with readable selection (ttk Entry ignores select colors on many themes)."""
        kwargs = {
            "textvariable": textvariable,
            "bg": FIELD,
            "fg": FG,
            "insertbackground": FG,
            "selectbackground": SELECT_BG,
            "selectforeground": SELECT_FG,
            "relief": "flat",
            "highlightthickness": 1,
            "highlightbackground": "#333843",
            "highlightcolor": ACCENT,
            "font": ("Sans", 11),
        }
        if show:
            kwargs["show"] = show
        ent = tk.Entry(parent, **kwargs)
        return ent

    def _option_row(
        self,
        parent: tk.Misc,
        text: str,
        value: str,
        variable: tk.StringVar,
        desc: str = "",
    ) -> None:
        """Simple radio row — no card chrome, readable when selected."""
        row = tk.Frame(parent, bg=BG)
        row.pack(fill="x", pady=(2, 8), anchor="w")
        rb = tk.Radiobutton(
            row,
            text=text,
            value=value,
            variable=variable,
            bg=BG,
            fg=FG,
            activebackground=BG,
            activeforeground=FG,
            selectcolor=FIELD,
            highlightthickness=0,
            font=("Sans", 11, "bold"),
            anchor="w",
            padx=0,
        )
        rb.pack(anchor="w")
        if desc:
            tk.Label(row, text=desc, bg=BG, fg=MUTED, font=("Sans", 9), wraplength=640, justify="left").pack(
                anchor="w", padx=22
            )

    def _build_chrome(self) -> None:
        self.header = ttk.Label(self, text="", style="Title.TLabel")
        self.header.pack(anchor="w", padx=24, pady=(20, 4))
        self.subheader = ttk.Label(self, text="", style="Sub.TLabel", wraplength=680)
        self.subheader.pack(anchor="w", padx=24, pady=(0, 12))

        self.body = ttk.Frame(self)
        self.body.pack(fill="both", expand=True, padx=24, pady=8)

        nav = ttk.Frame(self)
        nav.pack(fill="x", padx=24, pady=(8, 20))
        self.btn_back = ttk.Button(nav, text="Back", command=self._back)
        self.btn_back.pack(side="left")
        self.btn_cancel = ttk.Button(nav, text="Cancel", command=self._cancel)
        self.btn_cancel.pack(side="right", padx=(8, 0))
        self.btn_next = ttk.Button(nav, text="Next", style="Accent.TButton", command=self._next)
        self.btn_next.pack(side="right")

    def _screens(self) -> dict:
        return {
            "welcome": self._screen_welcome,
            "presets": self._screen_presets,
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

    def _clear_body(self) -> None:
        for child in self.body.winfo_children():
            child.destroy()

    def _render(self, name: str) -> None:
        self._clear_body()
        self._screens()[name]()
        self.btn_back.configure(state=("disabled" if name == "welcome" else "normal"))

    def _navigate(self, name: str) -> None:
        self._path.append(name)
        self._render(name)

    def _back(self) -> None:
        if len(self._path) <= 1:
            return
        self._path.pop()
        self._render(self._path[-1])

    def _needs_homelab(self) -> bool:
        return self._vars.get("pending_selection") == "Homelab Server"

    def _needs_from_scratch(self) -> bool:
        return self._vars.get("pending_selection") == "From Scratch"

    def _packages_include_docker(self) -> bool:
        mods = self._answers.get("PACKAGE_MODULES", "").split()
        return "docker" in mods

    def _package_system_type(self) -> str:
        """systemType used to filter package modules (matches packages assertion)."""
        preset = self._vars.get("pending_selection") or ""
        if preset == "From Scratch":
            return self._vars.get("system_type", tk.StringVar(value="desktop")).get() or "desktop"
        if preset in ("Server", "Homelab Server"):
            return "server"
        return "desktop"

    def _feature_groups_for_current_type(self) -> List[Tuple[str, List[str]]]:
        return filter_feature_groups_for_system(
            self.opts.feature_groups,
            self._package_system_type(),
            self.opts.feature_system_types,
        )

    def _is_desktop_install(self) -> bool:
        """True when this path should require at least one browser."""
        if self._needs_homelab():
            return self._answers.get("ENABLE_DESKTOP") == "true"
        if self._needs_from_scratch():
            st = self._vars.get("system_type", tk.StringVar(value="desktop")).get()
            de = self._vars.get("desktop_env", tk.StringVar(value="")).get()
            return st == "desktop" and bool(de)
        preset = self._vars.get("pending_selection") or ""
        if preset in ("Server",):
            return False
        if preset == "Homelab Server":
            return False
        return True

    def _needs_browsers_after_packages(self) -> bool:
        """Browser screen right after packages (not Homelab — that waits for hl_desktop)."""
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
            choice = self._vars.get("install_type", tk.StringVar(value="presets")).get()
            self._clear_answers()
            if choice == "advanced":
                self._navigate("advanced")
            else:
                self._navigate("presets")
        elif step == "presets":
            preset = self._vars.get("preset", tk.StringVar()).get()
            if not preset:
                messagebox.showinfo("Select a preset", "Please choose a preset to continue.")
                return
            self._clear_answers()
            self._vars["pending_selection"] = preset
            if preset == "From Scratch":
                self._navigate("custom_type")
            else:
                self._navigate("packages")
        elif step == "custom_type":
            st = self._vars.get("system_type", tk.StringVar(value="desktop")).get()
            if st == "desktop":
                self._navigate("custom_de")
            else:
                self._vars["desktop_env"] = tk.StringVar(value="")
                self._navigate("packages")
        elif step == "custom_de":
            self._navigate("packages")
        elif step == "packages":
            if not self._capture_packages():
                return
            if self._needs_from_scratch():
                self._vars["pending_selection"] = self._build_from_scratch_selection()
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
            self._vars["pending_selection"] = sel
            self._navigate("confirm")
        elif step == "confirm":
            self._finish()

    def _finish(self) -> None:
        sel = self._vars.get("pending_selection")
        if not sel:
            messagebox.showerror("Error", "Nothing selected.")
            return
        # Always write answers file (may be empty extras) so backend can skip prompts
        write_answers(self.answers_file, self._answers)
        self._selection = sel
        self.destroy()

    def _cancel(self) -> None:
        self._selection = None
        self.destroy()

    # ---- capture helpers ----

    def _capture_account(self) -> bool:
        admin = self._vars.get("account_user", tk.StringVar()).get().strip()
        if not admin:
            messagebox.showinfo("Required", "Main username cannot be empty.")
            return False
        if admin == "root":
            messagebox.showerror(
                "Invalid user",
                "Don't use 'root' as the main login user.\n"
                "Pick a normal username (e.g. your own).",
            )
            return False
        self._answers["ADMIN_USER"] = admin
        return True

    def _capture_packages(self) -> bool:
        selected: List[str] = []
        for name, var in self._vars.get("feature_vars", {}).items():
            if var.get():
                selected.append(name)
        st = self._package_system_type()
        selected = filter_features_for_system(
            selected, st, self.opts.feature_system_types
        )
        selected = resolve_features(selected, self.opts.conflicts, self.opts.dependencies)
        # Drop deps that aren't allowed for this system type
        selected = filter_features_for_system(
            selected, st, self.opts.feature_system_types
        )
        self._answers["PACKAGE_MODULES"] = " ".join(selected)
        return True

    def _capture_browsers(self) -> bool:
        checks = self._vars.get("browser_vars", {})
        selected = [name for name, var in checks.items() if var.get()]
        if not selected:
            messagebox.showinfo(
                "Select a browser",
                "Pick at least one browser for the desktop install.",
            )
            return False
        self._answers["BROWSERS"] = " ".join(selected)
        return True

    def _build_from_scratch_selection(self) -> str:
        # alias kept for clarity; same as former custom selection
        return self._build_custom_selection()

    def _build_custom_selection(self) -> str:
        system_type = self._vars.get("system_type", tk.StringVar(value="desktop")).get()
        features: List[str] = []
        de = self._vars.get("desktop_env", tk.StringVar(value="")).get()
        if de:
            features.append(de)
        features.extend(self._answers.get("PACKAGE_MODULES", "").split())
        features = resolve_features(features, self.opts.conflicts, self.opts.dependencies)
        des = [f for f in features if f in ("plasma", "gnome", "xfce")]
        others = [f for f in features if f not in ("plasma", "gnome", "xfce")]
        if de and de not in des:
            des = [de]
        elif len(des) > 1:
            des = [de] if de in des else des[:1]
        return " ".join([system_type] + des + others)

    def _capture_hl_basics(self) -> bool:
        admin = self._vars.get("hl_admin", tk.StringVar()).get().strip()
        if not admin:
            messagebox.showinfo("Required", "Admin username cannot be empty.")
            return False
        if admin == "root":
            messagebox.showerror(
                "Invalid user",
                "Don't use 'root' as the admin login user.\n"
                "Pick a normal username (e.g. your own).",
            )
            return False
        self._answers["ADMIN_USER"] = admin
        return True

    def _capture_hl_type(self) -> bool:
        t = self._vars.get("hl_type", tk.StringVar(value="single")).get()
        self._answers["HOMELAB_TYPE"] = t
        if t == "single":
            self._answers["SWARM_ROLE"] = "none"
        return True

    def _capture_hl_swarm(self) -> bool:
        role = self._vars.get("hl_swarm", tk.StringVar(value="manager")).get()
        self._answers["SWARM_ROLE"] = role
        self._answers["HOMELAB_TYPE"] = "swarm"
        return True

    def _capture_hl_docker_user(self) -> bool:
        use = self._vars.get("hl_extra_user", tk.StringVar(value="yes")).get()
        self._answers["USE_EXTRA_USER"] = use
        self._answers["DOCKER_USER_SETUP"] = use  # yes/no — bash maps as needed
        return True

    def _capture_hl_virt_user(self) -> bool:
        virt = self._vars.get("hl_virt_user", tk.StringVar(value="docker")).get().strip() or "docker"
        admin = self._answers.get("ADMIN_USER", default_admin())
        if virt == admin:
            messagebox.showerror("Conflict", "Admin user and virtualization user cannot be the same.")
            return False
        pw = self._vars.get("hl_virt_pw", tk.StringVar()).get()
        pw2 = self._vars.get("hl_virt_pw2", tk.StringVar()).get()
        suggested = self._vars.get("hl_virt_pw_suggested", "")
        if not pw and not pw2:
            pw = suggested
        elif len(pw) < 8:
            messagebox.showerror("Too short", "Password must be at least 8 characters.")
            return False
        elif pw != pw2:
            messagebox.showerror("Mismatch", "Passwords do not match.")
            return False
        self._answers["VIRT_USER"] = virt
        self._answers["VIRT_PASSWORD"] = pw
        self._answers["USE_EXTRA_USER"] = "yes"
        self._answers["DOCKER_USER_SETUP"] = "yes"
        return True

    def _capture_hl_hosting(self) -> bool:
        email = self._vars.get("hl_email", tk.StringVar()).get().strip()
        domain = self._vars.get("hl_domain", tk.StringVar()).get().strip()
        if not EMAIL_RE.match(email):
            messagebox.showerror("Invalid email", "Please enter a valid email address.")
            return False
        if not DOMAIN_RE.match(domain):
            messagebox.showerror("Invalid domain", "Please enter a valid domain (e.g. example.com).")
            return False
        self._answers["EMAIL"] = email
        self._answers["DOMAIN"] = domain
        return True

    def _capture_hl_desktop(self) -> bool:
        en = self._vars.get("hl_desktop", tk.StringVar(value="true")).get()
        self._answers["ENABLE_DESKTOP"] = en
        return True

    # ---- screens ----

    def _install_type_value(self, label: str) -> str:
        low = label.lower()
        if "preset" in low:
            return "presets"
        if "custom" in low:
            return "custom"
        return "advanced"

    def _screen_welcome(self) -> None:
        self.header.configure(text="Install NixOS Control Center")
        self.subheader.configure(
            text="Pick a preset (then tweak packages), or Advanced to load a profile."
        )
        self.btn_next.configure(text="Next")
        types = self.opts.install_types or ["Presets", "Advanced Options"]
        default = self._install_type_value(types[0])
        var = self._vars.setdefault("install_type", tk.StringVar(value=default))
        for label in types:
            value = self._install_type_value(label)
            title = re.sub(r"^[^\w]+", "", label).strip() or label
            desc = self.opts.desc(title, self.opts.desc(value, ""))
            self._option_row(self.body, title, value, var, desc)

    def _screen_presets(self) -> None:
        self.header.configure(text="Choose a preset")
        self.subheader.configure(
            text="Next step: add or remove package modules. Homelab starts with docker/database/web-server."
        )
        self.btn_next.configure(text="Next")
        presets = self.opts.system_presets + self.opts.device_presets
        default = presets[0] if presets else "Desktop"
        var = self._vars.setdefault("preset", tk.StringVar(value=default))
        for name in presets:
            defaults = self.opts.preset_defaults.get(name, [])
            extra = f"Defaults: {', '.join(defaults)}" if defaults else "Defaults: (none — add extras next)"
            desc = self.opts.desc(name)
            hint = f"{desc}\n{extra}" if desc else extra
            self._option_row(self.body, name, name, var, hint)

    def _screen_packages(self) -> None:
        preset = self._vars.get("pending_selection", "")
        st = self._package_system_type()
        self.header.configure(text="Packages / features")
        defaults = self.opts.preset_defaults.get(preset, [])
        defaults = filter_features_for_system(
            defaults, st, self.opts.feature_system_types
        )
        if preset == "From Scratch":
            self.subheader.configure(
                text=f"Select package modules for this {st} install "
                f"(server-only / desktop-only sets are hidden)."
            )
            defaults = []
        else:
            self.subheader.configure(
                text=f"Preset “{preset}” ({st}): defaults pre-checked. "
                f"Incompatible modules for this type are hidden."
            )
        self.btn_next.configure(text="Next")

        # Reset feature vars when entering from a different preset or system type
        prev = self._vars.get("_packages_for_preset")
        prev_st = self._vars.get("_packages_for_system_type")
        if prev != preset or prev_st != st:
            self._vars["feature_vars"] = {}
            self._vars["_packages_for_preset"] = preset
            self._vars["_packages_for_system_type"] = st

        checks = self._vars.setdefault("feature_vars", {})
        canvas = tk.Canvas(self.body, bg=BG, highlightthickness=0)
        scroll = ttk.Scrollbar(self.body, orient="vertical", command=canvas.yview)
        inner = ttk.Frame(canvas)
        inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=inner, anchor="nw")
        canvas.configure(yscrollcommand=scroll.set)
        canvas.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        default_set = set(defaults)
        groups = self._feature_groups_for_current_type()
        if not groups:
            ttk.Label(
                inner,
                text="No package modules available for this system type.",
            ).pack(anchor="w", padx=4, pady=8)
            return
        for group_name, features in groups:
            box = ttk.LabelFrame(inner, text=group_name, padding=8)
            box.pack(fill="x", pady=6, padx=4)
            for feat in features:
                if feat not in checks:
                    checks[feat] = tk.BooleanVar(value=(feat in default_set))
                d = self.opts.desc(feat, "")
                label = f"{feat} — {d}" if d else feat
                ttk.Checkbutton(box, text=label, variable=checks[feat]).pack(anchor="w")

    def _screen_browsers(self) -> None:
        self.header.configure(text="Web browsers")
        self.subheader.configure(
            text="Desktop installs need at least one browser. Firefox is pre-selected."
        )
        self.btn_next.configure(text="Next")
        checks = self._vars.setdefault("browser_vars", {})
        default = self.opts.browser_default or "firefox"
        for name, label in self.opts.browser_choices:
            if name not in checks:
                checks[name] = tk.BooleanVar(value=(name == default))
            ttk.Checkbutton(self.body, text=label, variable=checks[name]).pack(
                anchor="w", pady=4
            )

    def _screen_account(self) -> None:
        self.header.configure(text="Main user")
        self.subheader.configure(text="Normal login account (not root). Detected from SUDO_USER when possible.")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("account_user", tk.StringVar(value=default_admin()))
        ttk.Label(self.body, text="Username").pack(anchor="w")
        self._entry(self.body, var).pack(anchor="w", fill="x", pady=6)

    def _screen_custom_type(self) -> None:
        self.header.configure(text="From Scratch — system type")
        self.subheader.configure(text="Desktop includes a graphical environment; Server is CLI-first.")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("system_type", tk.StringVar(value="desktop"))
        self._option_row(self.body, "Desktop", "desktop", var, self.opts.desc("desktop"))
        self._option_row(self.body, "Server", "server", var, self.opts.desc("server"))

    def _screen_custom_de(self) -> None:
        self.header.configure(text="Desktop environment")
        self.subheader.configure(text="Pick the UI you want (or None for CLI-only).")
        self.btn_next.configure(text="Next")
        envs = self.opts.desktop_envs or ["plasma", "gnome", "xfce", ""]
        default = "plasma" if "plasma" in envs else envs[0]
        var = self._vars.setdefault("desktop_env", tk.StringVar(value=default))
        for env_id in envs:
            label = self.opts.desktop_env_label(env_id)
            desc_key = "plasma (kde)" if env_id == "plasma" else (env_id or "none")
            self._option_row(self.body, label, env_id, var, self.opts.desc(desc_key))

    def _screen_hl_basics(self) -> None:
        self.header.configure(text="Homelab — admin user")
        self.subheader.configure(text="Primary admin account for this machine (not root).")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("hl_admin", tk.StringVar(value=default_admin()))
        ttk.Label(self.body, text="Admin username").pack(anchor="w")
        self._entry(self.body, var).pack(anchor="w", fill="x", pady=6)

    def _screen_hl_type(self) -> None:
        self.header.configure(text="Homelab — topology")
        self.subheader.configure(text="Single server is the default. Multi-server uses Docker Swarm.")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("hl_type", tk.StringVar(value="single"))
        ttk.Radiobutton(self.body, text="Single server", value="single", variable=var).pack(anchor="w", pady=4)
        ttk.Radiobutton(
            self.body, text="Multi-server (Docker Swarm)", value="swarm", variable=var
        ).pack(anchor="w", pady=4)

    def _screen_hl_swarm(self) -> None:
        self.header.configure(text="Homelab — Swarm role")
        self.subheader.configure(text="Manager coordinates the swarm; Worker joins an existing one.")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("hl_swarm", tk.StringVar(value="manager"))
        ttk.Radiobutton(self.body, text="Manager", value="manager", variable=var).pack(anchor="w", pady=4)
        ttk.Radiobutton(self.body, text="Worker", value="worker", variable=var).pack(anchor="w", pady=4)

    def _screen_hl_docker_user(self) -> None:
        self.header.configure(text="Docker user setup")
        self.subheader.configure(
            text="A separate virtualization user is safer for Docker. Recommended for Homelab."
        )
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("hl_extra_user", tk.StringVar(value="yes"))
        ttk.Radiobutton(
            self.body, text="Yes — separate Docker/virt user", value="yes", variable=var
        ).pack(anchor="w", pady=4)
        ttk.Radiobutton(
            self.body, text="No — use the admin user only", value="no", variable=var
        ).pack(anchor="w", pady=4)

    def _screen_hl_virt_user(self) -> None:
        self.header.configure(text="Virtualization user")
        self.subheader.configure(
            text="Username + password for the Docker/virt account. Leave password empty for a random one."
        )
        self.btn_next.configure(text="Next")
        suggested = f"P@ssw0rd-{secrets.token_hex(4)}"
        self._vars["hl_virt_pw_suggested"] = suggested
        u = self._vars.setdefault("hl_virt_user", tk.StringVar(value="docker"))
        p1 = self._vars.setdefault("hl_virt_pw", tk.StringVar())
        p2 = self._vars.setdefault("hl_virt_pw2", tk.StringVar())
        ttk.Label(self.body, text="Username").pack(anchor="w")
        self._entry(self.body, u).pack(anchor="w", fill="x", pady=(0, 8))
        ttk.Label(self.body, text=f"Suggested password: {suggested}", style="Sub.TLabel").pack(anchor="w")
        ttk.Label(self.body, text="Password (empty = use suggested)").pack(anchor="w", pady=(8, 0))
        self._entry(self.body, p1, show="•").pack(anchor="w", fill="x", pady=(0, 8))
        ttk.Label(self.body, text="Confirm password").pack(anchor="w")
        self._entry(self.body, p2, show="•").pack(anchor="w", fill="x", pady=(0, 8))

    def _screen_hl_hosting(self) -> None:
        self.header.configure(text="Homelab — hosting")
        self.subheader.configure(text="Used for certificates / reverse-proxy defaults.")
        self.btn_next.configure(text="Next")
        email = self._vars.setdefault("hl_email", tk.StringVar(value=os.environ.get("HOST_EMAIL", "")))
        domain = self._vars.setdefault("hl_domain", tk.StringVar(value=os.environ.get("HOST_DOMAIN", "")))
        ttk.Label(self.body, text="Email").pack(anchor="w")
        self._entry(self.body, email).pack(anchor="w", fill="x", pady=(0, 8))
        ttk.Label(self.body, text="Domain (e.g. example.com)").pack(anchor="w")
        self._entry(self.body, domain).pack(anchor="w", fill="x", pady=(0, 8))

    def _screen_hl_desktop(self) -> None:
        self.header.configure(text="Homelab — desktop")
        self.subheader.configure(
            text='Enable a desktop environment on this server? ("no" can be buggy until reboot after build.)'
        )
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("hl_desktop", tk.StringVar(value="true"))
        ttk.Radiobutton(self.body, text="Yes — enable desktop (Plasma)", value="true", variable=var).pack(
            anchor="w", pady=4
        )
        ttk.Radiobutton(self.body, text="No — CLI only", value="false", variable=var).pack(anchor="w", pady=4)

    def _screen_advanced(self) -> None:
        self.header.configure(text="Advanced options")
        self.subheader.configure(text="Load a known profile or import an existing systemConfig.")
        self.btn_next.configure(text="Next")
        var = self._vars.setdefault("advanced_action", tk.StringVar(value="profiles"))
        ttk.Radiobutton(
            self.body, text="Browse available profiles", value="profiles", variable=var
        ).pack(anchor="w", pady=4)
        ttk.Radiobutton(
            self.body, text="Load profile from file…", value="file", variable=var
        ).pack(anchor="w", pady=4)
        ttk.Radiobutton(
            self.body, text="Import existing system config", value="import", variable=var
        ).pack(anchor="w", pady=4)

        self._vars.setdefault("profile_pick", tk.StringVar(value=""))
        plist = profiles_dir()
        names = sorted(p.name for p in plist.iterdir() if p.is_file()) if plist.is_dir() else []
        if names:
            ttk.Label(self.body, text="Profiles:", style="Sub.TLabel").pack(anchor="w", pady=(12, 4))
            lb = tk.Listbox(
                self.body,
                height=min(8, len(names)),
                bg="#242830",
                fg="#e8eaed",
                selectbackground="#4a9eff",
                relief="flat",
                font=("Sans", 11),
            )
            for n in names:
                lb.insert("end", n)
            lb.pack(fill="x")
            lb.bind(
                "<<ListboxSelect>>",
                lambda _e: self._vars["profile_pick"].set(lb.get(lb.curselection()[0]))
                if lb.curselection()
                else None,
            )
        else:
            ttk.Label(self.body, text=f"No profiles in {plist}", style="Sub.TLabel").pack(anchor="w")

    def _screen_confirm(self) -> None:
        dry = os.environ.get("NCC_DRY_RUN", "").lower() in ("1", "true", "yes", "on")
        self.header.configure(text="Confirm" + (" (DRY-RUN)" if dry else ""))
        self.subheader.configure(
            text=(
                "DRY-RUN: validate path only — nothing will be written or deployed."
                if dry
                else "Review selection and answers, then start install."
            )
        )
        self.btn_next.configure(text="Dry-run" if dry else "Install")
        sel = self._vars.get("pending_selection", "")
        ttk.Label(self.body, text="Selection", style="Sub.TLabel").pack(anchor="w")
        ttk.Label(self.body, text=sel, wraplength=640, font=("Mono", 11)).pack(anchor="w", pady=(0, 12))
        if self._answers:
            ttk.Label(self.body, text="Answers", style="Sub.TLabel").pack(anchor="w")
            safe = {
                k: ("••••••••" if "PASSWORD" in k else v)
                for k, v in self._answers.items()
                if v != ""
            }
            summary = "\n".join(f"{k}={v}" for k, v in safe.items()) or "(none)"
            ttk.Label(self.body, text=summary, wraplength=640, font=("Mono", 10)).pack(anchor="w")

    def _build_advanced_selection(self) -> Optional[str]:
        action = self._vars.get("advanced_action", tk.StringVar(value="profiles")).get()
        if action == "profiles":
            name = self._vars.get("profile_pick", tk.StringVar()).get()
            if not name:
                messagebox.showinfo("Pick a profile", "Select a profile from the list.")
                return None
            path = profiles_dir() / name
            if not path.is_file():
                messagebox.showerror("Missing", f"Profile not found:\n{path}")
                return None
            return f"LOAD_PROFILE:{path}"
        if action == "file":
            path = filedialog.askopenfilename(
                title="Select profile file",
                filetypes=[("Nix / profile", "*.nix *"), ("All", "*")],
            )
            if not path:
                return None
            return f"LOAD_PROFILE:{path}"
        cfg = os.environ.get("SYSTEM_CONFIG_FILE", "/etc/nixos/system-config.nix")
        monolith = os.environ.get("MONOLITH_FILE", "/etc/nixos/systemConfig.nix")
        for candidate in (monolith, cfg):
            if candidate and Path(candidate).is_file():
                return f"IMPORT_CONFIG:{candidate}"
        messagebox.showerror(
            "No config",
            f"No existing config found at:\n{monolith}\nor\n{cfg}",
        )
        return None

    def run(self) -> Optional[str]:
        self.mainloop()
        return self._selection


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

    try:
        app = InstallWizard(answers, options)
    except tk.TclError as exc:
        print(f"Failed to start GUI: {exc}", file=sys.stderr)
        return 2

    selection = app.run()
    if not selection:
        print("Install cancelled.", file=sys.stderr)
        return 1
    # Ensure parent knows the path even if it set NCC_GUI_ANSWERS_FILE already
    print(f"NCC_GUI_ANSWERS_FILE={answers}", file=sys.stderr)
    print(selection)
    return 0


if __name__ == "__main__":
    sys.exit(main())
