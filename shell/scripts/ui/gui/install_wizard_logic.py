"""Pure install-wizard logic (options SSOT, answers, feature resolve).

Shared by the PySide6 GUI and unit tests — no Qt/Tk imports.
"""

from __future__ import annotations

import getpass
import os
import re
import shlex
from pathlib import Path
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
        if section == "INSTALL_BASES":
            opts.system_presets.append(line)
        elif section == "DEVICE_TARGETS":
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
        elif section == "INSTALL_BASE_DEFAULT_PACKAGES":
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


def host_blueprints_dir() -> Path:
    setup = os.environ.get("SETUP_DIR", "")
    if setup:
        return Path(setup) / "modes" / "host-blueprints"
    here = Path(__file__).resolve()
    return here.parents[2] / "setup" / "modes" / "host-blueprints"


# Back-compat alias
profiles_dir = host_blueprints_dir


def write_answers(path: Path, data: Dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# NCC GUI answers — generated by NCC install wizard"]
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


