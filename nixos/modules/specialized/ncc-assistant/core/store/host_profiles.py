"""Multi-host profiles for per-machine endpoints, models, and flake attrs."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


@dataclass
class HostProfile:
    """A named host/flake profile."""
    name: str
    hostname: str | None = None
    flakeAttr: str | None = None
    endpoint: str | None = None
    model: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}

    @classmethod
    def from_dict(cls, name: str, data: dict[str, Any]) -> "HostProfile":
        return cls(
            name=name,
            hostname=data.get("hostname"),
            flakeAttr=data.get("flakeAttr") or data.get("flake_attr"),
            endpoint=data.get("endpoint"),
            model=data.get("model"),
        )


def _read_live_hostname() -> str | None:
    """Read the current machine hostname from /etc/hostname."""
    path = Path("/etc/hostname")
    try:
        if path.is_file():
            value = path.read_text(encoding="utf-8").strip()
            return value or None
    except OSError:
        pass
    return os.environ.get("HOSTNAME") or os.uname().nodename or None


def _load_profiles_raw() -> dict[str, dict[str, Any]]:
    """Load host profiles dict from env JSON."""
    raw = os.environ.get("NCC_ASSISTANT_HOST_PROFILES_JSON", "").strip()
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for name, cfg in data.items():
        if isinstance(name, str) and isinstance(cfg, dict):
            out[name] = cfg
    return out


def list_host_profiles() -> list[HostProfile]:
    """List all configured host profiles."""
    raw = _load_profiles_raw()
    return [HostProfile.from_dict(name, cfg) for name, cfg in sorted(raw.items())]


def get_host_profile(name: str) -> HostProfile | None:
    """Get a host profile by name."""
    raw = _load_profiles_raw()
    cfg = raw.get(name)
    if cfg is None:
        return None
    return HostProfile.from_dict(name, cfg)


def resolve_active_profile() -> HostProfile | None:
    """
    Resolve the active host profile using /etc/hostname.

    Prefer an explicit override via NCC_ASSISTANT_HOST_PROFILE, then match
    profile.hostname against the live hostname, then fall back to a profile
    whose name equals the hostname.
    """
    override = os.environ.get("NCC_ASSISTANT_HOST_PROFILE", "").strip()
    if override:
        profile = get_host_profile(override)
        if profile is not None:
            return profile

    live = _read_live_hostname()
    profiles = list_host_profiles()
    if not profiles:
        return None

    if live:
        for profile in profiles:
            if profile.hostname and profile.hostname == live:
                return profile
        for profile in profiles:
            if profile.name == live:
                return profile

    return None


def assert_hostname_allowed(hostname: str | None) -> str | None:
    """
    Guard rebuild/write targets against the wrong host.

    Returns an error message if *hostname* is set and does not match the live
    host (or the active profile's hostname). Returns None when allowed.
    """
    if hostname is None or hostname == "" or hostname == "default":
        return None

    live = _read_live_hostname()
    active = resolve_active_profile()

    allowed: set[str] = set()
    if live:
        allowed.add(live)
    if active and active.hostname:
        allowed.add(active.hostname)
    if active and active.name:
        allowed.add(active.name)

    force = os.environ.get("NCC_ASSISTANT_FORCE_HOST", "").lower() in (
        "1", "true", "yes",
    )
    if force:
        return None

    if allowed and hostname not in allowed:
        return (
            f"Hostname '{hostname}' is not allowed for this machine "
            f"(live={live!r}, active_profile={active.name if active else None}). "
            "Set NCC_ASSISTANT_FORCE_HOST=1 to override."
        )
    return None
