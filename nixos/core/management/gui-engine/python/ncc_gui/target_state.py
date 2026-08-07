"""Persisted fleet target + host list (SSH client ~/.creds)."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

# Domains that always run on this machine (ignore NCC_TARGET_HOST).
# Everything else follows the Target bar (sidebar + ncc commands).
LOCAL_ONLY_DOMAINS = frozenset(
    {
        "hosts",  # manage fleet list from this PC
        "ssh",  # SSH client connections from this PC
    }
)

_CONFIG_DIR = Path.home() / ".config" / "ncc"
_ACTIVE_FILE = _CONFIG_DIR / "active-target"
_CREDS = Path.home() / ".creds"


def apply_env(target: str | None) -> None:
    host = (target or "").strip()
    if host and host.lower() != "local":
        os.environ["NCC_TARGET_HOST"] = host
    else:
        os.environ.pop("NCC_TARGET_HOST", None)


def get_active_target() -> str | None:
    env = (os.environ.get("NCC_TARGET_HOST") or "").strip()
    if env:
        return env
    try:
        raw = _ACTIVE_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    if not raw or raw.lower() == "local":
        return None
    return raw


def set_active_target(target: str | None) -> None:
    host = (target or "").strip()
    if not host or host.lower() == "local":
        apply_env(None)
        try:
            if _ACTIVE_FILE.exists():
                _ACTIVE_FILE.unlink()
        except OSError:
            pass
        return
    apply_env(host)
    try:
        _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        _ACTIVE_FILE.write_text(host + "\n", encoding="utf-8")
    except OSError:
        pass


def _hosts_from_creds() -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    try:
        text = _CREDS.read_text(encoding="utf-8")
    except OSError:
        return out
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        host, user = line.split("=", 1)
        host, user = host.strip(), user.strip().split(":")[0].strip()
        if host and user:
            out.append((host, user))
    return out


def _hosts_from_ssh_client() -> list[tuple[str, str]] | None:
    try:
        proc = subprocess.run(
            ["ncc", "ssh", "client", "list"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    out: list[tuple[str, str]] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        host, user = line.split("=", 1)
        host, user = host.strip(), user.strip()
        if host and user:
            out.append((host, user))
    return out


def list_host_pairs() -> list[tuple[str, str]]:
    """Return (hostname, user) from SSH client list or ~/.creds."""
    from_cli = _hosts_from_ssh_client()
    if from_cli is not None:
        return from_cli
    return _hosts_from_creds()


def list_host_targets() -> list[str]:
    """Return user@host strings for the target switcher."""
    return [f"{user}@{host}" for host, user in list_host_pairs()]


_DOMAIN_RE = re.compile(r"^\s{0,4}([a-z][a-z0-9]{0,11})\s+-\s+", re.MULTILINE)


def probe_remote_domains(target: str, *, timeout: float = 20) -> set[str] | None:
    """Parse `ncc help` on remote. None = probe failed."""
    from ncc_gui.remote import run_ncc

    try:
        proc = run_ncc("help", target=target, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    text = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()
    if proc.returncode != 0 and not text:
        return None
    found = set(_DOMAIN_RE.findall(text))
    return found if found else None


# Sync env from disk on import so pages see the last active target.
_boot = get_active_target()
if _boot:
    apply_env(_boot)
