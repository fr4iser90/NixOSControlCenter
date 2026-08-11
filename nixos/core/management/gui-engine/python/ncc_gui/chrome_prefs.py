"""Persisted root-shell chrome preferences (~/.config/ncc/gui-chrome.json)."""

from __future__ import annotations

import json
from pathlib import Path

_CONFIG = Path.home() / ".config" / "ncc" / "gui-chrome.json"

# Default: fleet Target selector visible in the header.
_DEFAULT = {
    "show_target": True,
}


def load_chrome_prefs() -> dict:
    try:
        data = json.loads(_CONFIG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return dict(_DEFAULT)
    if not isinstance(data, dict):
        return dict(_DEFAULT)
    out = dict(_DEFAULT)
    if "show_target" in data:
        out["show_target"] = bool(data["show_target"])
    return out


def save_chrome_prefs(prefs: dict) -> None:
    body = dict(_DEFAULT)
    body.update({k: prefs[k] for k in _DEFAULT if k in prefs})
    try:
        _CONFIG.parent.mkdir(parents=True, exist_ok=True)
        _CONFIG.write_text(json.dumps(body, indent=2) + "\n", encoding="utf-8")
    except OSError:
        pass


def show_target_enabled() -> bool:
    return bool(load_chrome_prefs().get("show_target", True))


def set_show_target(enabled: bool) -> None:
    prefs = load_chrome_prefs()
    prefs["show_target"] = bool(enabled)
    save_chrome_prefs(prefs)
