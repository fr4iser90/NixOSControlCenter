"""SSH host display labels (alias / cached hostname).

SSOT for connection identity remains ``~/.creds`` (``host=user``).
Display overlays live in ``~/.config/ncc/ssh-host-labels.json`` keyed by
``user@host`` (same string as Target / NCC_TARGET_HOST).

Schema::

    {
      "fr4iser@192.168.178.41": {
        "alias": "Jetson",
        "hostname": "orin"
      }
    }

``alias`` is operator-edited; ``hostname`` is filled from the last successful
Target probe (optional hint when no alias).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

_CONFIG_DIR = Path.home() / ".config" / "ncc"
_LABELS_FILE = _CONFIG_DIR / "ssh-host-labels.json"


def target_key(user: str, host: str) -> str:
    return f"{user.strip()}@{host.strip()}"


def parse_target(target: str) -> tuple[str, str] | None:
    """Split ``user@host`` → (user, host)."""
    raw = (target or "").strip()
    if "@" not in raw:
        return None
    user, _, host = raw.rpartition("@")
    user, host = user.strip(), host.strip()
    if not user or not host:
        return None
    return user, host


def _load_raw() -> dict[str, Any]:
    try:
        data = json.loads(_LABELS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _save_raw(data: dict[str, Any]) -> None:
    try:
        _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        _LABELS_FILE.write_text(
            json.dumps(data, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    except OSError:
        pass


def _entry(data: dict[str, Any], key: str) -> dict[str, str]:
    raw = data.get(key)
    if not isinstance(raw, dict):
        # Legacy: plain string alias
        if isinstance(raw, str) and raw.strip():
            return {"alias": raw.strip()}
        return {}
    out: dict[str, str] = {}
    alias = str(raw.get("alias") or "").strip()
    hostname = str(raw.get("hostname") or "").strip()
    if alias:
        out["alias"] = alias
    if hostname:
        out["hostname"] = hostname
    return out


def get_alias(user: str, host: str) -> str:
    return _entry(_load_raw(), target_key(user, host)).get("alias", "")


def get_cached_hostname(user: str, host: str) -> str:
    return _entry(_load_raw(), target_key(user, host)).get("hostname", "")


def set_alias(user: str, host: str, alias: str) -> None:
    """Set or clear operator alias for ``user@host``."""
    key = target_key(user, host)
    data = _load_raw()
    entry = _entry(data, key)
    clean = (alias or "").strip()
    if clean:
        entry["alias"] = clean
    else:
        entry.pop("alias", None)
    if entry:
        data[key] = entry
    else:
        data.pop(key, None)
    _save_raw(data)


def set_cached_hostname(user: str, host: str, hostname: str) -> None:
    """Remember live hostname from a successful probe (non-destructive)."""
    clean = (hostname or "").strip()
    if not clean:
        return
    # Skip if it looks like the same as the address already used
    if clean == host.strip() or clean == target_key(user, host):
        return
    key = target_key(user, host)
    data = _load_raw()
    entry = _entry(data, key)
    entry["hostname"] = clean
    data[key] = entry
    _save_raw(data)


def clear_label(user: str, host: str) -> None:
    data = _load_raw()
    data.pop(target_key(user, host), None)
    _save_raw(data)


def migrate_key(old_user: str, old_host: str, new_user: str, new_host: str) -> None:
    """Move label when user/host identity changes."""
    old_k = target_key(old_user, old_host)
    new_k = target_key(new_user, new_host)
    if old_k == new_k:
        return
    data = _load_raw()
    entry = _entry(data, old_k)
    data.pop(old_k, None)
    if entry:
        # Merge with any existing new key (prefer moving alias)
        existing = _entry(data, new_k)
        merged = {**existing, **entry}
        data[new_k] = merged
    _save_raw(data)


def display_label(user: str, host: str, *, target: str | None = None) -> str:
    """Human label for lists / Target combo.

    Preference: alias → cached hostname (if distinct) → ``user@host``.
    """
    key = target or target_key(user, host)
    entry = _entry(_load_raw(), target_key(user, host))
    alias = entry.get("alias", "")
    hostname = entry.get("hostname", "")
    if alias:
        return f"{alias} · {key}"
    if hostname and hostname not in (host, key):
        return f"{hostname} · {key}"
    return key


def display_for_target(target: str) -> str:
    parsed = parse_target(target)
    if parsed is None:
        return target
    user, host = parsed
    return display_label(user, host, target=target)
