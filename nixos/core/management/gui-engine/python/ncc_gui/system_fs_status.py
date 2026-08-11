"""Read System status from Target /etc/nixos (local or SSH).

Real values from config + flake — does not require ``ncc system status``.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from dataclasses import dataclass
from typing import Any

_STATUS_SH = r"""
set +e
NIXOS=/etc/nixos
HOST=
RUNNING_HOST=$(uname -n 2>/dev/null || true)
VER=
CHANNEL=
STYPE=
CHECKS=
LAYOUT=none
PIN=
RUNNING=

if [ -f "$NIXOS/systemConfig.nix" ] && [ -d "$NIXOS/systemConfig" ]; then
  LAYOUT=both
elif [ -d "$NIXOS/systemConfig" ] && find "$NIXOS/systemConfig" -name config.nix -type f 2>/dev/null | head -1 | grep -q .; then
  LAYOUT=split
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  LAYOUT=monolith
elif [ -f "$NIXOS/system-config.nix" ]; then
  LAYOUT=legacy
fi

SM=
if [ -f "$NIXOS/systemConfig/core/management/system-manager/config.nix" ]; then
  SM=$(cat "$NIXOS/systemConfig/core/management/system-manager/config.nix" 2>/dev/null)
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  SM=$(cat "$NIXOS/systemConfig.nix" 2>/dev/null)
elif [ -f "$NIXOS/system-config.nix" ]; then
  SM=$(cat "$NIXOS/system-config.nix" 2>/dev/null)
fi

if [ -n "$SM" ]; then
  VER=$(printf '%s\n' "$SM" | sed -n 's/.*configVersion[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  CHANNEL=$(printf '%s\n' "$SM" | sed -n 's/.*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  STYPE=$(printf '%s\n' "$SM" | sed -n 's/.*systemType[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if printf '%s\n' "$SM" | grep -qE 'enableChecks[[:space:]]*=[[:space:]]*false'; then
    CHECKS=false
  elif printf '%s\n' "$SM" | grep -qE 'enableChecks[[:space:]]*=[[:space:]]*true'; then
    CHECKS=true
  fi
fi

if [ -f "$NIXOS/systemConfig/core/base/network/config.nix" ]; then
  HOST=$(sed -n 's/.*hostName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$NIXOS/systemConfig/core/base/network/config.nix" 2>/dev/null | head -1)
fi
if [ -z "$HOST" ] && [ -f "$NIXOS/systemConfig.nix" ]; then
  HOST=$(sed -n 's/.*hostName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$NIXOS/systemConfig.nix" 2>/dev/null | head -1)
fi
if [ -z "$HOST" ] && [ -f "$NIXOS/system-config.nix" ]; then
  HOST=$(sed -n 's/.*hostName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$NIXOS/system-config.nix" 2>/dev/null | head -1)
fi
if [ -z "$HOST" ]; then
  HOST=$RUNNING_HOST
fi

if [ -f "$NIXOS/flake.nix" ]; then
  PIN=$(grep -E 'nixpkgs-stable\.url|nixos-[0-9]+\.[0-9]+' "$NIXOS/flake.nix" 2>/dev/null \
    | grep -oE 'nixos-[0-9]+\.[0-9]+' | head -1 | sed 's/nixos-//')
fi

RUNNING=$(cat /run/current-system/nixos-version 2>/dev/null || true)

printf 'hostname=%s\n' "$HOST"
printf 'runningHostname=%s\n' "$RUNNING_HOST"
printf 'configVersion=%s\n' "$VER"
printf 'channel=%s\n' "$CHANNEL"
printf 'systemType=%s\n' "$STYPE"
printf 'enableChecks=%s\n' "$CHECKS"
printf 'layout=%s\n' "$LAYOUT"
printf 'nixosPin=%s\n' "$PIN"
printf 'running=%s\n' "$RUNNING"
"""


@dataclass(frozen=True)
class FsSystemStatus:
    hostname: str = ""
    running_hostname: str = ""
    config_version: str = ""
    channel: str = ""
    system_type: str = ""
    enable_checks: bool | None = None
    layout: str = ""
    nixos_pin: str = ""
    running: str = ""
    error: str = ""

    def as_meta(self) -> dict[str, Any]:
        checks: Any
        if self.enable_checks is True:
            checks = True
        elif self.enable_checks is False:
            checks = False
        else:
            checks = None
        return {
            "hostname": self.hostname,
            "configuredHostname": self.hostname,
            "runningHostname": self.running_hostname,
            "configVersion": self.config_version,
            "channel": self.channel,
            "systemType": self.system_type,
            "enableChecks": checks,
            "layout": self.layout,
            "nixosPin": self.nixos_pin,
            "running": self.running,
        }


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in (text or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def _from_kv(kv: dict[str, str], *, error: str = "") -> FsSystemStatus:
    checks_raw = (kv.get("enableChecks") or "").strip().lower()
    if checks_raw == "true":
        checks: bool | None = True
    elif checks_raw == "false":
        checks = False
    else:
        checks = None
    return FsSystemStatus(
        hostname=(kv.get("hostname") or "").strip(),
        running_hostname=(kv.get("runningHostname") or "").strip(),
        config_version=(kv.get("configVersion") or "").strip(),
        channel=(kv.get("channel") or "").strip(),
        system_type=(kv.get("systemType") or "").strip(),
        enable_checks=checks,
        layout=(kv.get("layout") or "").strip(),
        nixos_pin=(kv.get("nixosPin") or "").strip(),
        running=(kv.get("running") or "").strip(),
        error=error,
    )


def parse_fs_status_stdout(raw: str, *, error: str = "") -> FsSystemStatus:
    return _from_kv(_parse_kv(raw), error=error)


def read_fs_status_local() -> FsSystemStatus:
    try:
        proc = subprocess.run(
            ["bash", "-s"],
            input=_STATUS_SH,
            check=False,
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return FsSystemStatus(error=str(e))
    if proc.returncode != 0 and not (proc.stdout or "").strip():
        return FsSystemStatus(error=(proc.stderr or f"exit {proc.returncode}")[:200])
    return _from_kv(_parse_kv(proc.stdout or ""))


def read_fs_status_remote(target: str, *, timeout: float = 12) -> FsSystemStatus:
    host = (target or "").strip()
    if not host:
        return FsSystemStatus(error="empty target")
    argv = [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "StrictHostKeyChecking=accept-new",
        host,
        "--",
        "bash",
        "-s",
    ]
    try:
        proc = subprocess.run(
            argv,
            input=_STATUS_SH,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return FsSystemStatus(error=str(e))
    if proc.returncode != 0 and not (proc.stdout or "").strip():
        err = (proc.stderr or "").strip() or f"SSH exit {proc.returncode}"
        return FsSystemStatus(error=err[:200])
    return _from_kv(_parse_kv(proc.stdout or ""))


def read_fs_status(target: str | None = None) -> FsSystemStatus:
    host = (target or "").strip()
    if host:
        return read_fs_status_remote(host)
    return read_fs_status_local()


def fetch_latest_stable_pin(*, timeout: float = 8) -> str:
    import urllib.request

    url = "https://api.github.com/repos/NixOS/nixpkgs/git/matching-refs/heads/nixos-"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ncc-gui"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
    except Exception:
        return ""
    pins: list[str] = []
    for item in data if isinstance(data, list) else []:
        ref = str(item.get("ref") or "")
        m = re.search(r"refs/heads/nixos-(\d+\.\d+)$", ref)
        if m:
            pins.append(m.group(1))
    if not pins:
        return ""

    def _key(p: str) -> tuple[int, ...]:
        return tuple(int(x) for x in p.split("."))

    return sorted(pins, key=_key)[-1]


def release_from_fs(fs: FsSystemStatus, *, latest: str = "") -> dict[str, str]:
    pin = (fs.nixos_pin or "").strip()
    latest = (latest or "").strip()
    channel = (fs.channel or "").strip() or "—"
    running = (fs.running or "").strip() or "—"
    if not pin:
        status = "error: no nixos pin in flake"
    elif not latest:
        status = "pin from flake"
    elif pin == latest:
        status = "current"
    else:

        def _key(p: str) -> tuple[int, ...]:
            parts = []
            for b in p.split("."):
                if b.isdigit():
                    parts.append(int(b))
            return tuple(parts)

        try:
            status = "update-available" if _key(latest) > _key(pin) else "current"
        except Exception:
            status = "pin from flake"
    return {
        "channel": channel,
        "current": pin or "—",
        "latest": latest or "—",
        "running": running,
        "status": status,
    }


def build_fs_status_argv(target: str | None = None) -> list[str]:
    host = (
        target if target is not None else os.environ.get("NCC_TARGET_HOST") or ""
    ).strip()
    if not host:
        return ["bash", "-s"]
    return [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "StrictHostKeyChecking=accept-new",
        host,
        "--",
        "bash",
        "-s",
    ]


STATUS_SCRIPT = _STATUS_SH
