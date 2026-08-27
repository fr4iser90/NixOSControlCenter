"""Persisted root-shell chrome preferences (~/.config/ncc/gui-chrome.json)."""

from __future__ import annotations

import json
from pathlib import Path

_CONFIG = Path.home() / ".config" / "ncc" / "gui-chrome.json"

# activity_mode:
#   collapsed — Activity title visible; log hidden until Show log / first command output
#   hidden    — Activity off until user opens Log (or first command output this session)
#   open      — always show the command log (legacy default look)
_ACTIVITY_MODES = frozenset({"collapsed", "hidden", "open"})

_DEFAULT: dict = {
    "show_target": True,
    "activity_mode": "collapsed",
    # When True: hide Features sidebar entries whose module enable is false.
    # Core domains always stay visible (config manager). Default off.
    "hide_inactive_features": False,
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
    if "hide_inactive_features" in data:
        out["hide_inactive_features"] = bool(data["hide_inactive_features"])
    mode = data.get("activity_mode")
    if isinstance(mode, str) and mode.strip() in _ACTIVITY_MODES:
        out["activity_mode"] = mode.strip()
    skips = data.get("skip_ssh_key_offer")
    if isinstance(skips, list):
        out["skip_ssh_key_offer"] = [str(x).strip() for x in skips if str(x).strip()]
    return out


def save_chrome_prefs(prefs: dict) -> None:
    body = dict(_DEFAULT)
    body["show_target"] = bool(prefs.get("show_target", True))
    body["hide_inactive_features"] = bool(
        prefs.get("hide_inactive_features", _DEFAULT["hide_inactive_features"])
    )
    mode = prefs.get("activity_mode", _DEFAULT["activity_mode"])
    if isinstance(mode, str) and mode.strip() in _ACTIVITY_MODES:
        body["activity_mode"] = mode.strip()
    skips = prefs.get("skip_ssh_key_offer") or []
    if isinstance(skips, list):
        body["skip_ssh_key_offer"] = [str(x).strip() for x in skips if str(x).strip()]
    try:
        _CONFIG.parent.mkdir(parents=True, exist_ok=True)
        _CONFIG.write_text(json.dumps(body, indent=2) + "\n", encoding="utf-8")
    except OSError:
        pass


def show_target_enabled() -> bool:
    """Target bar: user pref AND SSH domain enabled in catalog (no fleet chrome without SSH)."""
    if not bool(load_chrome_prefs().get("show_target", True)):
        return False
    try:
        from ncc_gui.catalog import load_domains

        return any(d.id == "ssh" and d.enabled for d in load_domains())
    except Exception:
        return False


def set_show_target(enabled: bool) -> None:
    prefs = load_chrome_prefs()
    prefs["show_target"] = bool(enabled)
    save_chrome_prefs(prefs)


def hide_inactive_features() -> bool:
    return bool(load_chrome_prefs().get("hide_inactive_features", False))


def set_hide_inactive_features(enabled: bool) -> None:
    prefs = load_chrome_prefs()
    prefs["hide_inactive_features"] = bool(enabled)
    save_chrome_prefs(prefs)


def activity_mode() -> str:
    mode = load_chrome_prefs().get("activity_mode", "collapsed")
    if isinstance(mode, str) and mode in _ACTIVITY_MODES:
        return mode
    return "collapsed"


def set_activity_mode(mode: str) -> None:
    want = (mode or "").strip()
    if want not in _ACTIVITY_MODES:
        want = "collapsed"
    prefs = load_chrome_prefs()
    prefs["activity_mode"] = want
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
