"""Read domain settings from Target /etc/nixos (local or SSH).

Fallback when ``ncc <domain> status`` is missing or stale on remote hosts.
Same pattern as ``system_fs_status.py`` — filesystem is SSOT for GUI display.
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass

_DESKTOP_FS_SH = r"""
set +e
NIXOS=/etc/nixos
CFG=
if [ -f "$NIXOS/systemConfig/core/base/desktop/config.nix" ]; then
  CFG=$(cat "$NIXOS/systemConfig/core/base/desktop/config.nix" 2>/dev/null)
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  CFG=$(awk '/desktop = \{/{flag=1} flag{print} flag && /\};/{exit}' "$NIXOS/systemConfig.nix" 2>/dev/null)
fi

_pick_str() {
  key="$1"
  printf '%s\n' "$CFG" | sed -n "s/.*${key}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

_pick_bool() {
  key="$1"
  printf '%s\n' "$CFG" | sed -n "s/.*${key}[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p" | head -1
}

enable=$(_pick_bool enable)
environment=$(_pick_str environment)
manager=$(_pick_str manager)
server=$(_pick_str server)
session=$(_pick_str session)
dark=$(_pick_bool dark)
if [ -z "$dark" ]; then
  dark=$(printf '%s\n' "$CFG" | awk '/theme = \{/,/\};/ { if (/dark = /) { gsub(/.*dark = /,""); gsub(/;.*/,""); print; exit } }')
fi
if [ -z "$manager" ]; then
  manager=$(printf '%s\n' "$CFG" | awk '/display = \{/,/\};/ { if (/manager = /) { gsub(/.*manager = /,""); gsub(/;.*/,""); gsub(/"/,""); print; exit } }')
fi
if [ -z "$server" ]; then
  server=$(printf '%s\n' "$CFG" | awk '/display = \{/,/\};/ { if (/server = /) { gsub(/.*server = /,""); gsub(/;.*/,""); gsub(/"/,""); print; exit } }')
fi
if [ -z "$session" ]; then
  session=$(printf '%s\n' "$CFG" | awk '/display = \{/,/\};/ { if (/session = /) { gsub(/.*session = /,""); gsub(/;.*/,""); gsub(/"/,""); print; exit } }')
fi

printf 'found=%s\n' "$([ -n "$CFG" ] && echo 1 || echo 0)"
printf 'enable=%s\n' "$enable"
printf 'environment=%s\n' "$environment"
printf 'manager=%s\n' "$manager"
printf 'server=%s\n' "$server"
printf 'session=%s\n' "$session"
printf 'dark=%s\n' "$dark"
"""


@dataclass(frozen=True)
class FsDesktopStatus:
    enable: bool | None = None
    environment: str = ""
    manager: str = ""
    server: str = ""
    session: str = ""
    dark: bool | None = None
    found: bool = False
    error: str = ""

    @property
    def ok(self) -> bool:
        return self.found and not self.error

    def as_snapshot(self) -> dict[str, str]:
        """Keys aligned with DesktopPage._live."""
        enable = "true" if self.enable is True else "false" if self.enable is False else "false"
        env = self.environment or "plasma"
        mgr = self.manager or "sddm"
        server = self.server or "wayland"
        dark = "true" if self.dark is not False else "false"
        return {
            "enable": enable,
            "environment": env,
            "manager": mgr,
            "server": server,
            "dark": dark,
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


def _bool_or_none(raw: str) -> bool | None:
    s = (raw or "").strip().lower()
    if s == "true":
        return True
    if s == "false":
        return False
    return None


def parse_desktop_fs_stdout(raw: str, *, error: str = "") -> FsDesktopStatus:
    kv = _parse_kv(raw)
    return FsDesktopStatus(
        enable=_bool_or_none(kv.get("enable", "")),
        environment=(kv.get("environment") or "").strip(),
        manager=(kv.get("manager") or "").strip(),
        server=(kv.get("server") or "").strip(),
        session=(kv.get("session") or "").strip(),
        dark=_bool_or_none(kv.get("dark", "")),
        found=kv.get("found") == "1",
        error=error,
    )


def _run_script(script: str, *, argv: list[str], timeout: float) -> tuple[str, str, int]:
    try:
        proc = subprocess.run(
            argv,
            input=script,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return "", str(e), 1
    return proc.stdout or "", (proc.stderr or "").strip(), proc.returncode


def read_desktop_fs_local(*, timeout: float = 8) -> FsDesktopStatus:
    out, err, rc = _run_script(_DESKTOP_FS_SH, argv=["bash", "-s"], timeout=timeout)
    if rc != 0 and not out.strip():
        return FsDesktopStatus(error=(err or f"exit {rc}")[:200])
    return parse_desktop_fs_stdout(out)


def read_desktop_fs_remote(target: str, *, timeout: float = 12) -> FsDesktopStatus:
    host = (target or "").strip()
    if not host:
        return FsDesktopStatus(error="empty target")
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
    out, err, rc = _run_script(_DESKTOP_FS_SH, argv=argv, timeout=timeout)
    if rc != 0 and not out.strip():
        return FsDesktopStatus(error=(err or f"SSH exit {rc}")[:200])
    return parse_desktop_fs_stdout(out)


def read_desktop_fs(target: str | None = None) -> FsDesktopStatus:
    host = (target or "").strip()
    if host:
        return read_desktop_fs_remote(host)
    return read_desktop_fs_local()


DESKTOP_FS_SCRIPT = _DESKTOP_FS_SH

# Catalog domain id → split systemConfig path (relative to systemConfig/).
# FS probe only — mirrors registerGuiDomain short ids, not Nix discovery.
_MODULE_ENABLE_SPLIT: dict[str, str] = {
    "desktop": "core/base/desktop/config.nix",
    "network": "core/base/network/config.nix",
    "hardware": "core/base/hardware/config.nix",
    "packages": "core/base/packages/config.nix",
    "stacks": "modules/infrastructure/stack-manager/config.nix",
    "vm": "modules/infrastructure/vm/config.nix",
    "bootentry": "modules/infrastructure/bootentry-manager/config.nix",
    "ssh": "modules/security/ssh-manager/config.nix",
    "lock": "modules/system/lock-manager/config.nix",
    "chronicle": "modules/specialized/chronicle/config.nix",
    "ai": "modules/specialized/ncc-assistant/config.nix",
}


def _build_module_enables_sh() -> str:
    split_lines = "\n".join(
        f'  _emit_file "{did}" "$SC/{rel}"'
        for did, rel in _MODULE_ENABLE_SPLIT.items()
    )
    # Monolith: search needle → catalog id (hyphenated modules use quoted attrs)
    mono_pairs = (
        ("desktop", "desktop"),
        ("network", "network"),
        ("hardware", "hardware"),
        ("packages", "packages"),
        ('"stack-manager"', "stacks"),
        ("vm", "vm"),
        ('"bootentry-manager"', "bootentry"),
        ('"ssh-manager"', "ssh"),
        ('"lock-manager"', "lock"),
        ("chronicle", "chronicle"),
        ('"ncc-assistant"', "ai"),
    )
    mono_lines = "\n".join(
        # Preserve quote chars in needle for hyphenated Nix attrs
        f"  _emit_mono_block '{key}' \"{did}\""
        for key, did in mono_pairs
    )
    return f"""
set +e
NIXOS=/etc/nixos
SC="$NIXOS/systemConfig"
MONO="$NIXOS/systemConfig.nix"
_SEEN=""

_seen_has() {{
  case " $_SEEN " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}}

_emit() {{
  id="$1"
  en="$2"
  [ -n "$id" ] && [ -n "$en" ] || return 0
  _seen_has "$id" && return 0
  _SEEN="$_SEEN $id "
  printf 'enable.%s=%s\\n' "$id" "$en"
}}

_emit_file() {{
  id="$1"
  file="$2"
  [ -f "$file" ] || return 0
  en=$(sed -n 's/.*enable[[:space:]]*=[[:space:]]*\\(true\\|false\\).*/\\1/p' "$file" 2>/dev/null | head -1)
  _emit "$id" "$en"
}}

_emit_mono_block() {{
  key="$1"
  id="$2"
  [ -f "$MONO" ] || return 0
  _seen_has "$id" && return 0
  blk=$(awk -v k="$key" '
    index($0, k " = {{") {{ flag=1 }}
    flag {{ print }}
    flag && /}};/ {{ exit }}
  ' "$MONO" 2>/dev/null)
  en=$(printf '%s\\n' "$blk" | sed -n 's/.*enable[[:space:]]*=[[:space:]]*\\(true\\|false\\).*/\\1/p' | head -1)
  _emit "$id" "$en"
}}

if [ -d "$SC" ]; then
{split_lines}
fi
if [ -f "$MONO" ]; then
{mono_lines}
fi
"""


_MODULE_ENABLES_SH = _build_module_enables_sh()


def parse_module_enables_stdout(raw: str) -> dict[str, bool]:
    out: dict[str, bool] = {}
    for line in (raw or "").splitlines():
        line = line.strip()
        if not line.startswith("enable.") or "=" not in line:
            continue
        left, _, right = line.partition("=")
        did = left[len("enable.") :].strip()
        val = _bool_or_none(right)
        if did and val is not None:
            out[did] = val
    return out


def read_module_enables_local(*, timeout: float = 8) -> dict[str, bool]:
    out, _err, _rc = _run_script(_MODULE_ENABLES_SH, argv=["bash", "-s"], timeout=timeout)
    return parse_module_enables_stdout(out)


def read_module_enables_remote(target: str, *, timeout: float = 12) -> dict[str, bool]:
    host = (target or "").strip()
    if not host:
        return {}
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
    out, _err, _rc = _run_script(_MODULE_ENABLES_SH, argv=argv, timeout=timeout)
    return parse_module_enables_stdout(out)


def read_module_enables(target: str | None = None) -> dict[str, bool]:
    host = (target or "").strip()
    if host:
        return read_module_enables_remote(host)
    return read_module_enables_local()


MODULE_ENABLES_SCRIPT = _MODULE_ENABLES_SH


def _target_argv(target: str | None) -> list[str]:
    host = (target or "").strip()
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


_NETWORK_FS_SH = r"""
set +e
NIXOS=/etc/nixos
CFG=
if [ -f "$NIXOS/systemConfig/core/base/network/config.nix" ]; then
  CFG=$(cat "$NIXOS/systemConfig/core/base/network/config.nix" 2>/dev/null)
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  CFG=$(awk '
    /network = \{/ && !done {
      flag=1; depth=0
    }
    flag {
      print
      for (i=1;i<=length($0);i++) {
        c=substr($0,i,1)
        if (c=="{") depth++
        if (c=="}") depth--
      }
      if (flag && depth<=0) { done=1; flag=0 }
    }
  ' "$NIXOS/systemConfig.nix" 2>/dev/null)
fi

host=$(printf '%s\n' "$CFG" | sed -n 's/.*hostName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
enable=$(printf '%s\n' "$CFG" | sed -n 's/.*enable[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p' | head -1)
wifi_en=$(printf '%s\n' "$CFG" | awk '/wifi = \{/,/\};/ { if (/enable = /) { gsub(/.*enable = /,""); gsub(/;.*/,""); print; exit } }')

printf 'found=%s\n' "$([ -n "$CFG" ] && echo 1 || echo 0)"
printf 'hostname=%s\n' "$host"
printf 'enable=%s\n' "$enable"
printf 'wifi_enable=%s\n' "$wifi_en"
"""


_HARDWARE_FS_SH = r"""
set +e
NIXOS=/etc/nixos
CFG=
if [ -f "$NIXOS/systemConfig/core/base/hardware/config.nix" ]; then
  CFG=$(cat "$NIXOS/systemConfig/core/base/hardware/config.nix" 2>/dev/null)
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  CFG=$(awk '
    /hardware = \{/ && !done {
      flag=1; depth=0
    }
    flag {
      print
      for (i=1;i<=length($0);i++) {
        c=substr($0,i,1)
        if (c=="{") depth++
        if (c=="}") depth--
      }
      if (flag && depth<=0) { done=1; flag=0 }
    }
  ' "$NIXOS/systemConfig.nix" 2>/dev/null)
fi

cpu=$(printf '%s\n' "$CFG" | sed -n 's/.*cpu[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
gpu=$(printf '%s\n' "$CFG" | sed -n 's/.*gpu[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
ram=$(printf '%s\n' "$CFG" | sed -n 's/.*sizeGB[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)

printf 'found=%s\n' "$([ -n "$CFG" ] && echo 1 || echo 0)"
printf 'cpu=%s\n' "$cpu"
printf 'gpu=%s\n' "$gpu"
printf 'ramGB=%s\n' "$ram"
"""


_USERS_FS_SH = r"""
set +e
NIXOS=/etc/nixos
CFG=
if [ -f "$NIXOS/systemConfig/core/base/user/config.nix" ]; then
  CFG=$(cat "$NIXOS/systemConfig/core/base/user/config.nix" 2>/dev/null)
elif [ -f "$NIXOS/systemConfig.nix" ]; then
  CFG=$(awk '
    /user = \{/ && !done {
      flag=1; depth=0
    }
    flag {
      print
      for (i=1;i<=length($0);i++) {
        c=substr($0,i,1)
        if (c=="{") depth++
        if (c=="}") depth--
      }
      if (flag && depth<=0) { done=1; flag=0 }
    }
  ' "$NIXOS/systemConfig.nix" 2>/dev/null)
fi

printf 'found=%s\n' "$([ -n "$CFG" ] && echo 1 || echo 0)"
# Emit one user per line: user=<name>|role=<r>|shell=<s>|autoLogin=<t|f>
printf '%s\n' "$CFG" | awk '
  /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*=[[:space:]]*\{/ {
    name=$1; gsub(/=.*/,"",name); gsub(/[[:space:]]/,"",name)
    if (name=="user" || name=="") next
    cur=name; role=""; shell=""; auto="false"
  }
  cur != "" && /role[[:space:]]*=/ {
    line=$0; sub(/.*role[[:space:]]*=[[:space:]]*"/,"",line); sub(/".*/,"",line); role=line
  }
  cur != "" && /defaultShell[[:space:]]*=/ {
    line=$0; sub(/.*defaultShell[[:space:]]*=[[:space:]]*"/,"",line); sub(/".*/,"",line); shell=line
  }
  cur != "" && /autoLogin[[:space:]]*=/ {
    if ($0 ~ /true/) auto="true"; else auto="false"
  }
  cur != "" && /\};/ {
    if (cur != "") {
      printf "user=%s|role=%s|shell=%s|autoLogin=%s\n", cur, role, shell, auto
      cur=""
    }
  }
'
"""


@dataclass(frozen=True)
class FsNetworkStatus:
    hostname: str = ""
    enable: bool | None = None
    wifi_enable: bool | None = None
    found: bool = False
    error: str = ""

    @property
    def ok(self) -> bool:
        return self.found and not self.error


@dataclass(frozen=True)
class FsHardwareStatus:
    cpu: str = ""
    gpu: str = ""
    ram_gb: int | None = None
    found: bool = False
    error: str = ""

    @property
    def ok(self) -> bool:
        return self.found and not self.error

    def as_configured(self) -> dict:
        out: dict = {}
        if self.cpu:
            out["cpu"] = self.cpu
        if self.gpu:
            out["gpu"] = self.gpu
        if self.ram_gb is not None:
            out["ramGB"] = self.ram_gb
        return out


@dataclass(frozen=True)
class FsUserRow:
    name: str
    role: str = "guest"
    shell: str = "bash"
    auto_login: bool = False


@dataclass(frozen=True)
class FsUsersStatus:
    users: tuple[FsUserRow, ...] = ()
    found: bool = False
    error: str = ""

    @property
    def ok(self) -> bool:
        return self.found and not self.error


def parse_network_fs_stdout(raw: str, *, error: str = "") -> FsNetworkStatus:
    kv = _parse_kv(raw)
    return FsNetworkStatus(
        hostname=(kv.get("hostname") or "").strip(),
        enable=_bool_or_none(kv.get("enable", "")),
        wifi_enable=_bool_or_none(kv.get("wifi_enable", "")),
        found=kv.get("found") == "1",
        error=error,
    )


def parse_hardware_fs_stdout(raw: str, *, error: str = "") -> FsHardwareStatus:
    kv = _parse_kv(raw)
    ram_raw = (kv.get("ramGB") or "").strip()
    ram: int | None
    try:
        ram = int(ram_raw) if ram_raw else None
    except ValueError:
        ram = None
    return FsHardwareStatus(
        cpu=(kv.get("cpu") or "").strip(),
        gpu=(kv.get("gpu") or "").strip(),
        ram_gb=ram,
        found=kv.get("found") == "1",
        error=error,
    )


def parse_users_fs_stdout(raw: str, *, error: str = "") -> FsUsersStatus:
    kv = _parse_kv(raw)
    found = kv.get("found") == "1"
    rows: list[FsUserRow] = []
    for line in (raw or "").splitlines():
        line = line.strip()
        if not line.startswith("user=") or "|" not in line:
            continue
        parts = dict(
            p.split("=", 1) for p in line.split("|") if "=" in p
        )
        name = (parts.get("user") or "").strip()
        if not name:
            continue
        rows.append(
            FsUserRow(
                name=name,
                role=(parts.get("role") or "guest").strip() or "guest",
                shell=(parts.get("shell") or "bash").strip() or "bash",
                auto_login=(parts.get("autoLogin") or "").strip().lower() == "true",
            )
        )
    return FsUsersStatus(users=tuple(rows), found=found, error=error)


def read_network_fs(target: str | None = None, *, timeout: float = 8) -> FsNetworkStatus:
    out, err, rc = _run_script(
        _NETWORK_FS_SH, argv=_target_argv(target), timeout=timeout
    )
    if rc != 0 and not out.strip():
        return FsNetworkStatus(error=(err or f"exit {rc}")[:200])
    return parse_network_fs_stdout(out)


def read_hardware_fs(target: str | None = None, *, timeout: float = 8) -> FsHardwareStatus:
    out, err, rc = _run_script(
        _HARDWARE_FS_SH, argv=_target_argv(target), timeout=timeout
    )
    if rc != 0 and not out.strip():
        return FsHardwareStatus(error=(err or f"exit {rc}")[:200])
    return parse_hardware_fs_stdout(out)


def read_users_fs(target: str | None = None, *, timeout: float = 8) -> FsUsersStatus:
    out, err, rc = _run_script(
        _USERS_FS_SH, argv=_target_argv(target), timeout=timeout
    )
    if rc != 0 and not out.strip():
        return FsUsersStatus(error=(err or f"exit {rc}")[:200])
    return parse_users_fs_stdout(out)
