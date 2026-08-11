"""Probe local or remote host: OS, arch, NCC presence / configVersion."""

from __future__ import annotations

import json
import os
import platform
import re
import shutil
import socket
import subprocess
from dataclasses import dataclass
from pathlib import Path

# Keep in sync with system-manager config-migration schema.currentVersion
EXPECTED_CONFIG_VERSION = "2.1"

SUPPORTED_ARCH = frozenset({"x86_64", "amd64", "aarch64", "arm64"})

# Single remote script — one SSH round-trip
_REMOTE_PROBE_SH = r"""
set +e
ARCH=$(uname -m 2>/dev/null || echo unknown)
OS_ID=unknown
OS_PRETTY=unknown
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID=${ID:-unknown}
  OS_PRETTY=${PRETTY_NAME:-unknown}
fi
NCC=0
command -v ncc >/dev/null 2>&1 && NCC=1
ETC=missing
if [ -d /etc/nixos ]; then
  ETC=plain
  if [ -e /etc/nixos/systemConfig.nix ] || [ -d /etc/nixos/systemConfig ]; then
    ETC=ncc
  elif [ -f /etc/nixos/flake.nix ] && grep -qE 'NixOSControlCenter|core/management' /etc/nixos/flake.nix 2>/dev/null; then
    ETC=ncc
  fi
fi
VER=
HOST=
# Prefer filesystem (works when ncc status is missing/broken on old targets)
if [ -f /etc/nixos/systemConfig/core/management/system-manager/config.nix ]; then
  VER=$(sed -n 's/.*configVersion[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    /etc/nixos/systemConfig/core/management/system-manager/config.nix 2>/dev/null | head -1)
elif [ -f /etc/nixos/systemConfig.nix ]; then
  VER=$(sed -n 's/.*configVersion[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    /etc/nixos/systemConfig.nix 2>/dev/null | head -1)
fi
if [ -f /etc/nixos/systemConfig/core/base/network/config.nix ]; then
  HOST=$(sed -n 's/.*hostName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    /etc/nixos/systemConfig/core/base/network/config.nix 2>/dev/null | head -1)
fi
if [ -z "$HOST" ]; then
  HOST=$(uname -n 2>/dev/null || true)
fi
if [ "$NCC" = 1 ]; then
  RAW=$(ncc system status --json 2>/dev/null || true)
  if [ -n "$RAW" ]; then
    V2=$(printf '%s\n' "$RAW" | sed -n 's/.*"configVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    H2=$(printf '%s\n' "$RAW" | sed -n 's/.*"hostname"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$V2" ] && VER=$V2
    [ -n "$H2" ] && HOST=$H2
  fi
fi
printf 'arch=%s\n' "$ARCH"
printf 'os_id=%s\n' "$OS_ID"
printf 'os_pretty=%s\n' "$OS_PRETTY"
printf 'ncc=%s\n' "$NCC"
printf 'etc=%s\n' "$ETC"
printf 'ver=%s\n' "$VER"
printf 'hostname=%s\n' "$HOST"
"""


@dataclass(frozen=True)
class TargetProbe:
    """Result of probing one machine (local or via SSH)."""

    target: str | None  # None = this machine; else user@host
    reachable: bool
    is_nixos: bool
    arch: str
    os_id: str
    os_pretty: str
    hostname: str
    ncc_on_path: bool
    etc_nixos_kind: str  # missing | plain | ncc
    config_version: str  # "" if unknown
    error: str = ""
    auth_required: bool = False  # SSH up, but key/password auth failed

    @property
    def platform_linux(self) -> str:
        a = (self.arch or "").lower()
        if a in ("aarch64", "arm64"):
            return "aarch64-linux"
        if a in ("x86_64", "amd64"):
            return "x86_64-linux"
        return ""

    @property
    def arch_supported(self) -> bool:
        return (self.arch or "").lower() in SUPPORTED_ARCH


def parse_version(raw: str) -> tuple[int, ...]:
    s = (raw or "").strip()
    if not s:
        return ()
    parts: list[int] = []
    for bit in re.split(r"[^\d]+", s):
        if bit.isdigit():
            parts.append(int(bit))
    return tuple(parts)


def version_lt(a: str, b: str) -> bool:
    """True if a < b (empty a counts as older)."""
    pa, pb = parse_version(a), parse_version(b)
    if not pb:
        return False
    if not pa:
        return True
    # Pad to same length
    n = max(len(pa), len(pb))
    pa = pa + (0,) * (n - len(pa))
    pb = pb + (0,) * (n - len(pb))
    return pa < pb


def classify_gate(
    probe: TargetProbe,
    *,
    expected_version: str = EXPECTED_CONFIG_VERSION,
) -> str:
    """Return session gate: blocked | needs_install | needs_update | ready."""
    if not probe.reachable:
        return "blocked"
    if probe.error and not probe.is_nixos and not probe.ncc_on_path:
        return "blocked"
    if not probe.arch_supported:
        return "blocked"
    if not probe.is_nixos:
        return "blocked"
    if not probe.ncc_on_path:
        return "needs_install"
    # NCC on PATH but plain/missing tree still needs install/adopt
    if probe.etc_nixos_kind in ("missing", "plain"):
        return "needs_install"
    if version_lt(probe.config_version, expected_version):
        return "needs_update"
    # Has NCC markers but status failed → treat as update
    if probe.etc_nixos_kind == "ncc" and not (probe.config_version or "").strip():
        return "needs_update"
    return "ready"


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in (text or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def _read_os_release() -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        text = Path("/etc/os-release").read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return out
    for line in text.splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"')
    return out


def _local_etc_kind() -> str:
    root = Path("/etc/nixos")
    if not root.is_dir():
        return "missing"
    if (root / "systemConfig.nix").exists() or (root / "systemConfig").is_dir():
        return "ncc"
    flake = root / "flake.nix"
    if flake.is_file():
        try:
            raw = flake.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            raw = ""
        if "NixOSControlCenter" in raw or "core/management" in raw:
            return "ncc"
    return "plain"


def _read_config_version_files() -> str:
    """Fast path: parse configVersion from /etc/nixos without invoking ncc."""
    candidates = [
        Path("/etc/nixos/systemConfig/core/management/system-manager/config.nix"),
        Path("/etc/nixos/systemConfig.nix"),
        Path("/etc/nixos/system-config.nix"),
    ]
    for path in candidates:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        m = re.search(
            r'configVersion\s*=\s*"([^"]+)"',
            text,
        )
        if m:
            return m.group(1)
    return ""


def _read_configured_hostname_files() -> str:
    """Fast path: hostName from network config (split or monolith text)."""
    split = Path("/etc/nixos/systemConfig/core/base/network/config.nix")
    try:
        text = split.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        text = ""
    if text:
        m = re.search(r'hostName\s*=\s*"([^"]+)"', text)
        if m:
            return m.group(1)
    mono = Path("/etc/nixos/systemConfig.nix")
    try:
        text = mono.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""
    m = re.search(r'hostName\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else ""


def probe_local(*, timeout: float = 2.5, invoke_ncc: bool = False) -> TargetProbe:
    """Local probe. Default is filesystem-only (instant); optional short ncc call."""
    osr = _read_os_release()
    is_nixos = osr.get("ID") == "nixos" or Path("/run/current-system").exists()
    arch = platform.machine() or "unknown"
    hostname = _read_configured_hostname_files() or socket.gethostname()
    ncc = bool(shutil.which("ncc"))
    ver = _read_config_version_files()
    etc_kind = _local_etc_kind()
    if invoke_ncc and ncc:
        try:
            proc = subprocess.run(
                ["ncc", "system", "status", "--json"],
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            raw = (proc.stdout or "").strip()
            if proc.returncode == 0 and raw:
                data = json.loads(raw)
                ver = str(data.get("configVersion") or ver or "")
                host = str(data.get("hostname") or "").strip()
                if host:
                    hostname = host
        except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
            pass
    return TargetProbe(
        target=None,
        reachable=True,
        is_nixos=is_nixos,
        arch=arch,
        os_id=osr.get("ID") or ("nixos" if is_nixos else "unknown"),
        os_pretty=osr.get("PRETTY_NAME") or ("NixOS" if is_nixos else platform.system()),
        hostname=hostname,
        ncc_on_path=ncc,
        etc_nixos_kind=etc_kind,
        config_version=ver,
    )


def _ssh_error_is_auth(err: str) -> bool:
    """True when SSH reached the host but rejected credentials (not a network failure)."""
    low = (err or "").lower()
    needles = (
        "permission denied",
        "authentication failed",
        "too many authentication failures",
        "publickey,password",
        "no supported authentication",
    )
    return any(n in low for n in needles)


def _askpass_pair(password: str) -> tuple[Path, Path]:
    """Return (askpass.sh, secret.txt). Caller must delete both."""
    import tempfile

    fd, name = tempfile.mkstemp(prefix="ncc-askpass-", suffix=".sh", text=True)
    script = Path(name)
    secret = script.with_suffix(".secret")
    secret.write_text(password, encoding="utf-8")
    secret.chmod(0o600)
    # Single-quoted path for sh
    quoted = "'" + str(secret).replace("'", "'\\''") + "'"
    os.write(fd, f"#!/bin/sh\ncat {quoted}\n".encode())
    os.close(fd)
    script.chmod(0o700)
    return script, secret


def _cleanup_askpass(script: Path | None, secret: Path | None) -> None:
    for p in (script, secret):
        if p is None:
            continue
        try:
            p.unlink(missing_ok=True)
        except OSError:
            pass


def _ssh_probe_argv(host: str, *, with_password: bool) -> list[str]:
    argv = [
        "ssh",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ]
    if with_password:
        argv.extend(
            [
                "-o",
                "BatchMode=no",
                "-o",
                "NumberOfPasswordPrompts=1",
                "-o",
                "PreferredAuthentications=password,keyboard-interactive,publickey",
            ]
        )
    else:
        argv.extend(["-o", "BatchMode=yes"])
    argv.extend([host, "--", "bash", "-s"])
    return argv


def _failed_probe(host: str, err: str) -> TargetProbe:
    auth = _ssh_error_is_auth(err)
    return TargetProbe(
        target=host,
        reachable=False,
        is_nixos=False,
        arch="",
        os_id="",
        os_pretty="",
        hostname="",
        ncc_on_path=False,
        etc_nixos_kind="missing",
        config_version="",
        error=(err or "")[:200],
        auth_required=auth,
    )


def probe_remote(
    target: str,
    *,
    timeout: float = 12,
    password: str | None = None,
) -> TargetProbe:
    host = (target or "").strip()
    if not host:
        return TargetProbe(
            target=None,
            reachable=False,
            is_nixos=False,
            arch="",
            os_id="",
            os_pretty="",
            hostname="",
            ncc_on_path=False,
            etc_nixos_kind="missing",
            config_version="",
            error="empty target",
        )

    askpass: Path | None = None
    secret: Path | None = None
    env = os.environ.copy()
    use_pw = bool(password)
    if use_pw:
        askpass, secret = _askpass_pair(password or "")
        env["SSH_ASKPASS"] = str(askpass)
        env["SSH_ASKPASS_REQUIRE"] = "force"
        if not env.get("DISPLAY"):
            env["DISPLAY"] = ":0"

    try:
        argv = _ssh_probe_argv(host, with_password=use_pw)
        if use_pw and shutil.which("setsid"):
            argv = ["setsid", *argv]
        proc = subprocess.run(
            argv,
            input=_REMOTE_PROBE_SH,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return _failed_probe(host, "SSH timed out")
    except OSError as e:
        return _failed_probe(host, str(e))
    finally:
        _cleanup_askpass(askpass, secret)

    if proc.returncode != 0 and not (proc.stdout or "").strip():
        err = (proc.stderr or "").strip() or f"SSH exit {proc.returncode}"
        return _failed_probe(host, err)

    kv = _parse_kv(proc.stdout or "")
    os_id = kv.get("os_id") or "unknown"
    is_nixos = os_id == "nixos"
    return TargetProbe(
        target=host,
        reachable=True,
        is_nixos=is_nixos,
        arch=kv.get("arch") or "unknown",
        os_id=os_id,
        os_pretty=kv.get("os_pretty") or os_id,
        hostname=kv.get("hostname") or host.split("@")[-1],
        ncc_on_path=kv.get("ncc") == "1",
        etc_nixos_kind=kv.get("etc") or "missing",
        config_version=kv.get("ver") or "",
        error="" if proc.returncode == 0 else f"probe rc={proc.returncode}",
        auth_required=False,
    )


def copy_ssh_key(target: str, password: str, *, timeout: float = 60) -> tuple[bool, str]:
    """Run ssh-copy-id with SSH_ASKPASS. Returns (ok, error_or_empty)."""
    host = (target or "").strip()
    if not host or not password:
        return False, "host and password required"
    pub = Path.home() / ".ssh" / "id_ed25519.pub"
    if not pub.is_file():
        pub = Path.home() / ".ssh" / "id_rsa.pub"
    if not pub.is_file():
        return False, "No public key in ~/.ssh (id_ed25519.pub / id_rsa.pub)"

    askpass: Path | None = None
    secret: Path | None = None
    env = os.environ.copy()
    askpass, secret = _askpass_pair(password)
    env["SSH_ASKPASS"] = str(askpass)
    env["SSH_ASKPASS_REQUIRE"] = "force"
    if not env.get("DISPLAY"):
        env["DISPLAY"] = ":0"
    try:
        argv = [
            "ssh-copy-id",
            "-i",
            str(pub),
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "NumberOfPasswordPrompts=1",
            host,
        ]
        if shutil.which("setsid"):
            argv = ["setsid", *argv]
        proc = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)
    finally:
        _cleanup_askpass(askpass, secret)

    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "ssh-copy-id failed").strip()
        return False, err[:300]
    return True, ""


def probe_target(
    target: str | None,
    *,
    timeout: float = 12,
    invoke_ncc: bool = False,
    password: str | None = None,
) -> TargetProbe:
    if not target:
        return probe_local(timeout=min(timeout, 2.5), invoke_ncc=invoke_ncc)
    return probe_remote(target, timeout=timeout, password=password)
