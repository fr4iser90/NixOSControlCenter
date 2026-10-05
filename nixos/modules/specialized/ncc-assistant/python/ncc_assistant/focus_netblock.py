"""Real domain sinkhole for doomscroll (hosts-style / nft) — not soft overlay."""

from __future__ import annotations

import shutil
import subprocess
from typing import Any

from .preferences import get_doomscroll_block_domains, get_doomscroll_lockout_min


def _normalize_domain(raw: str) -> str:
    d = (raw or "").strip().lower()
    for prefix in ("https://", "http://"):
        if d.startswith(prefix):
            d = d[len(prefix) :]
    d = d.split("/")[0].split("?")[0].strip(".")
    return d


def block_domains_list() -> list[str]:
    """Domains from selected site-tag enums (Shorts → youtube.com, …)."""
    return [d for d in (_normalize_domain(x) for x in get_doomscroll_block_domains()) if d]


def apply_net_block(*, minutes: int | None = None) -> dict[str, Any]:
    """
    Sinkhole domains derived from site tags via ncc-focus-netblock (nft + pkexec).
    Requires prior privilege grant (opt-in). Polkit YES rule keeps apply passwordless.
    """
    from .preferences import get_doomscroll_netblock_granted

    if not get_doomscroll_netblock_granted():
        return {
            "ok": False,
            "error": "privilege_not_granted",
            "hint": (
                "Grant admin once in Plugins → Doomscroll → "
                "‘Grant net-block privilege’ (or Companion Plugins panel)."
            ),
        }
    domains = block_domains_list()
    if not domains:
        return {
            "ok": False,
            "error": "no_domains",
            "hint": "Select at least one site tag (e.g. YouTube Shorts).",
        }
    mins = minutes if minutes is not None else get_doomscroll_lockout_min()
    mins = max(1, min(int(mins or 10), 240))
    exe = shutil.which("ncc-focus-netblock")
    if not exe:
        return {
            "ok": False,
            "error": "helper_missing",
            "hint": (
                "ncc-focus-netblock not on PATH — enable ncc-assistant and system-update. "
                "For always-on hosts block set focus.hostsBlock.enable + domains in systemConfig."
            ),
        }
    cmd = [exe, "apply", "--minutes", str(mins)]
    for d in domains:
        cmd.extend(["--domain", d])
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc), "domains": domains, "minutes": mins}
    out = (proc.stdout or "").strip()
    err = (proc.stderr or "").strip()
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": out,
        "stderr": err,
        "domains": domains,
        "minutes": mins,
        "method": "nft",
    }


def grant_netblock_privilege() -> dict[str, Any]:
    """
    Opt-in smoke-test (auth-check). Call from Plugins UI / Companion at setup.
    """
    from .preferences import set_doomscroll_netblock_granted

    exe = shutil.which("ncc-focus-netblock")
    if not exe:
        return {
            "ok": False,
            "error": "helper_missing",
            "hint": "ncc-focus-netblock not on PATH",
        }
    try:
        proc = subprocess.run(
            [exe, "auth-check"],
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        set_doomscroll_netblock_granted(False)
        return {"ok": False, "error": str(exc)}
    ok = proc.returncode == 0 and "auth-ok" in ((proc.stdout or "") + (proc.stderr or ""))
    # Also accept empty success if root already
    if proc.returncode == 0:
        ok = True
    set_doomscroll_netblock_granted(ok)
    return {
        "ok": ok,
        "returncode": proc.returncode,
        "stdout": (proc.stdout or "").strip(),
        "stderr": (proc.stderr or "").strip(),
    }


def clear_net_block() -> dict[str, Any]:
    exe = shutil.which("ncc-focus-netblock")
    if not exe:
        return {"ok": False, "error": "helper_missing"}
    try:
        proc = subprocess.run(
            [exe, "clear"],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc)}
    return {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "stdout": (proc.stdout or "").strip(),
        "stderr": (proc.stderr or "").strip(),
        "method": "nft",
    }


def net_block_status() -> dict[str, Any]:
    exe = shutil.which("ncc-focus-netblock")
    if not exe:
        return {"active": False, "error": "helper_missing"}
    try:
        proc = subprocess.run(
            [exe, "status"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"active": False, "error": str(exc)}
    text = (proc.stdout or "").strip()
    return {
        "active": text != "inactive" and "ncc_focus_block" in text,
        "raw": text[:2000],
    }
