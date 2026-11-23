"""Single tray-icon owner: Companion XOR ``ncc ai tray``.

Callers: ``companion.window._setup_tray`` / ``_quit_companion``,
``tray.daemon.run_tray``. No other mutex for tray icons exists.
Writes ``tray-owner.json``: ``{pid, role, updatedAt}`` (ISO UTC).

User: "Kein Doppel-Tray: Companion und ncc ai tray gegenseitig erkennen."
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any, Literal

from core.store.paths import tray_owner_file

Role = Literal["companion", "tray"]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def load_tray_owner() -> dict[str, Any] | None:
    path = tray_owner_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    try:
        pid = int(data.get("pid") or 0)
    except (TypeError, ValueError):
        return None
    role = str(data.get("role") or "")
    if role not in ("companion", "tray") or not _pid_alive(pid):
        try:
            path.unlink(missing_ok=True)
        except OSError:
            pass
        return None
    return {"pid": pid, "role": role, "updatedAt": data.get("updatedAt")}


def claim_tray_owner(role: Role) -> dict[str, Any]:
    """Claim tray icon. Returns ``{ok, reason, owner}``."""
    existing = load_tray_owner()
    my_pid = os.getpid()
    if existing is not None:
        if int(existing["pid"]) == my_pid and existing.get("role") == role:
            return {"ok": True, "reason": "already", "owner": existing}
        return {
            "ok": False,
            "reason": "held",
            "owner": existing,
            "hint": (
                f"Tray owned by {existing.get('role')} pid={existing.get('pid')}. "
                "Quit that process to avoid two icons."
            ),
        }
    payload = {"pid": my_pid, "role": role, "updatedAt": _now()}
    path = tray_owner_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload) + "\n", encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return {"ok": True, "reason": "claimed", "owner": payload}


def release_tray_owner(role: Role) -> None:
    existing = load_tray_owner()
    if existing is None:
        return
    if int(existing.get("pid") or 0) != os.getpid():
        return
    if existing.get("role") != role:
        return
    try:
        tray_owner_file().unlink(missing_ok=True)
    except OSError:
        pass
