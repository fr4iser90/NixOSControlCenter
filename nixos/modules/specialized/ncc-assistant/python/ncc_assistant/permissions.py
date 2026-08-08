"""NCC role → capability checks for domain AI tools (mirrors user/api.nix)."""

from __future__ import annotations

import json
import subprocess
from functools import lru_cache
from typing import Any

# Keep in sync with nixos/core/base/user/api.nix roleCapabilities
ROLE_CAPABILITIES: dict[str, list[str]] = {
    "admin": [
        "system.update",
        "system.build",
        "system.check.*",
        "module.*",
        "user.*",
        "package.*",
        "network.*",
        "hardware.*",
        "boot.*",
        "desktop.*",
        "audio.*",
        "localization.*",
    ],
    "guest": [
        "system.check.self",
        "user.read.self",
        "package.user.self",
        "desktop.read",
    ],
    "restricted-admin": [
        "system.update",
        "system.build",
        "system.check.*",
        "module.*",
        "user.*",
        "network.read",
        "package.user.*",
        "package.system",
        "desktop.*",
    ],
    "virtualization": [
        "system.check.self",
        "user.read.self",
        "package.user.self",
        "package.docker",
        "package.podman",
        "desktop.read",
    ],
}


def has_permission(caps: list[str], required: str) -> bool:
    for cap in caps:
        if cap == required:
            return True
        if cap.endswith(".*") and required.startswith(cap[:-1]):
            return True
    return False


def role_has_permission(role: str, permission: str | None) -> bool:
    """True if role may use a tool requiring ``permission`` (None = always)."""
    if not permission:
        return True
    caps = ROLE_CAPABILITIES.get(role or "guest") or ROLE_CAPABILITIES["guest"]
    return has_permission(caps, permission)


@lru_cache(maxsize=4)
def invoker_whoami() -> dict[str, Any]:
    """``ncc user whoami --json`` for the process user."""
    try:
        proc = subprocess.run(
            ["ncc", "user", "whoami", "--json"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"user": "", "role": "guest", "canManage": False}
    if proc.returncode != 0:
        return {"user": "", "role": "guest", "canManage": False}
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return {"user": "", "role": "guest", "canManage": False}
    if not isinstance(data, dict):
        return {"user": "", "role": "guest", "canManage": False}
    role = str(data.get("role") or "guest")
    return {
        "user": str(data.get("user") or ""),
        "role": role,
        "canManage": bool(data.get("canManage"))
        or role in ("admin", "restricted-admin"),
    }


def invoker_role() -> str:
    return str(invoker_whoami().get("role") or "guest")


def clear_whoami_cache() -> None:
    invoker_whoami.cache_clear()
