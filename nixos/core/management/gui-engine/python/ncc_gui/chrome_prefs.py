"""Persisted root-shell chrome preferences (~/.config/ncc/gui-chrome.json)."""

from __future__ import annotations

import json
from pathlib import Path

_CONFIG = Path.home() / ".config" / "ncc" / "gui-chrome.json"

_DEFAULT: dict = {
    "show_target": True,
    # Hosts (user@host) for which we never offer “save SSH key” after password Connect.
    "skip_ssh_key_offer": [],
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
    skips = data.get("skip_ssh_key_offer")
    if isinstance(skips, list):
        out["skip_ssh_key_offer"] = [str(x).strip() for x in skips if str(x).strip()]
    return out


def save_chrome_prefs(prefs: dict) -> None:
    body = dict(_DEFAULT)
    body["show_target"] = bool(prefs.get("show_target", True))
    skips = prefs.get("skip_ssh_key_offer") or []
    if isinstance(skips, list):
        body["skip_ssh_key_offer"] = [str(x).strip() for x in skips if str(x).strip()]
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


def should_offer_ssh_key_save(host: str) -> bool:
    host = (host or "").strip()
    if not host:
        return False
    skips = load_chrome_prefs().get("skip_ssh_key_offer") or []
    return host not in skips


def remember_skip_ssh_key_offer(host: str) -> None:
    host = (host or "").strip()
    if not host:
        return
    prefs = load_chrome_prefs()
    skips = list(prefs.get("skip_ssh_key_offer") or [])
    if host not in skips:
        skips.append(host)
    prefs["skip_ssh_key_offer"] = skips
    save_chrome_prefs(prefs)
