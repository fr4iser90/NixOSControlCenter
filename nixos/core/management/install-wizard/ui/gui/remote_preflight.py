"""Remote install preflight — staged systemConfig vs live Target hardware.

Same checks as local ``prebuild-check-{platform,cpu,gpu,memory,users}``,
but compare-only (no auto-write) and over SSH before ``nixos-rebuild``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path


_HW_PROBE_SH = r"""
set -euo pipefail
# --- platform ---
case "$(uname -m 2>/dev/null || echo unknown)" in
  x86_64|amd64) PLATFORM=x86_64-linux ;;
  aarch64|arm64) PLATFORM=aarch64-linux ;;
  *) PLATFORM=unknown ;;
esac
# --- cpu (same policy as prebuild-check-cpu) ---
CPU=none
if command -v lscpu >/dev/null 2>&1; then
  info=$(lscpu 2>/dev/null || true)
  if echo "$info" | grep -qi GenuineIntel; then CPU=intel
  elif echo "$info" | grep -qi AuthenticAMD; then CPU=amd
  fi
fi
# --- gpu (PCI + Jetson tegra) ---
GPU=none
if [ -f /etc/nv_tegra_release ] \
  || grep -qiE 'tegra|jetson|orin' /sys/firmware/devicetree/base/compatible 2>/dev/null \
  || grep -qiE 'tegra|jetson|orin' /sys/firmware/devicetree/base/model 2>/dev/null; then
  GPU=jetson
else
  nvidia=0; amd=0; intel=0; amd_count=0
  if command -v lspci >/dev/null 2>&1; then
    while IFS= read -r line; do
      bus=$(echo "$line" | cut -d' ' -f1)
      ids=$(lspci -n -s "$bus" 2>/dev/null | awk '{print $2,$3}')
      class=$(echo "$ids" | awk '{print $1}' | cut -d: -f1)
      vendor=$(echo "$ids" | awk '{print $2}' | cut -d: -f1)
      case "$class" in
        0300|0302|0380)
          case "$vendor" in
            10de) nvidia=1 ;;
            1002) amd=1; amd_count=$((amd_count + 1)) ;;
            8086) intel=1 ;;
          esac
          ;;
      esac
    done < <(lspci -nn 2>/dev/null | grep -E '\[0300\]|\[0302\]|\[0380\]' || true)
  fi
  if [ "$nvidia" = 1 ] && [ "$intel" = 1 ]; then GPU=nvidia-intel
  elif [ "$amd" = 1 ] && [ "$intel" = 1 ]; then GPU=amd-intel
  elif [ "$amd_count" = 2 ]; then GPU=amd-amd
  elif [ "$nvidia" = 1 ]; then GPU=nvidia
  elif [ "$amd" = 1 ]; then GPU=amd
  elif [ "$intel" = 1 ]; then GPU=intel
  elif command -v systemd-detect-virt >/dev/null 2>&1; then
    vt=$(systemd-detect-virt 2>/dev/null || echo none)
    [ "$vt" != none ] && GPU=vm-gpu
  fi
fi
# --- memory buckets (same as prebuild-check-memory) ---
kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
raw=$(( (kb + 524288) / 1048576 ))
if [ "$raw" -ge 120 ]; then MEM=128
elif [ "$raw" -ge 60 ]; then MEM=64
elif [ "$raw" -ge 28 ]; then MEM=32
elif [ "$raw" -ge 14 ]; then MEM=16
elif [ "$raw" -ge 6 ]; then MEM=8
elif [ "$raw" -ge 3 ]; then MEM=4
else MEM=$raw
fi
# --- users (uid 1000–65533, skip nixbld) ---
USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ {print $1}' | tr '\n' ' ')
printf 'platform=%s\n' "$PLATFORM"
printf 'cpu=%s\n' "$CPU"
printf 'gpu=%s\n' "$GPU"
printf 'memory_gb=%s\n' "$MEM"
printf 'users=%s\n' "$USERS"
"""


@dataclass
class StagedHardware:
    platform: str = ""
    cpu: str = ""
    gpu: str = ""
    memory_gb: str = ""
    users: list[str] = field(default_factory=list)


@dataclass
class LiveHardware:
    platform: str = ""
    cpu: str = ""
    gpu: str = ""
    memory_gb: str = ""
    users: list[str] = field(default_factory=list)


@dataclass
class PreflightResult:
    ok: bool
    lines: list[str] = field(default_factory=list)

    @property
    def report(self) -> str:
        return "\n".join(self.lines)


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in (text or "").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def _first_str(text: str, patterns: list[str]) -> str:
    for pat in patterns:
        m = re.search(pat, text, re.MULTILINE)
        if m:
            return m.group(1).strip()
    return ""


def _user_names_from_monolith(text: str) -> list[str]:
    """Extract user attr names under core.base.user = { … }."""
    m = re.search(r"\buser\s*=\s*\{", text)
    if not m:
        return []
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    body = text[start : i - 1]
    names = re.findall(r'(?m)^\s*"?([A-Za-z_][A-Za-z0-9_-]*)"?\s*=\s*\{', body)
    skip = {"role", "defaultShell", "autoLogin"}
    return [n for n in names if n not in skip]


def read_staged_hardware(staging_etc: Path) -> StagedHardware:
    """Read platform/cpu/gpu/ram/users from staged install output."""
    staging_etc = Path(staging_etc)
    hw = StagedHardware()
    monolith = staging_etc / "systemConfig.nix"
    if monolith.is_file():
        text = monolith.read_text(encoding="utf-8", errors="ignore")
        hw.cpu = _first_str(text, [r'\bcpu\s*=\s*"([^"]+)"'])
        hw.gpu = _first_str(text, [r'\bgpu\s*=\s*"([^"]+)"'])
        hw.memory_gb = _first_str(text, [r'\bsizeGB\s*=\s*([0-9]+)'])
        hw.platform = _first_str(
            text,
            [
                r'\bplatform\s*=\s*"([^"]+)"',
                r'system\.platform\s*=\s*"([^"]+)"',
            ],
        )
        hw.users = _user_names_from_monolith(text)
        return hw

    hw_path = staging_etc / "systemConfig" / "core" / "base" / "hardware" / "config.nix"
    if hw_path.is_file():
        text = hw_path.read_text(encoding="utf-8", errors="ignore")
        hw.cpu = _first_str(text, [r'\bcpu\s*=\s*"([^"]+)"'])
        hw.gpu = _first_str(text, [r'\bgpu\s*=\s*"([^"]+)"'])
        hw.memory_gb = _first_str(text, [r'\bsizeGB\s*=\s*([0-9]+)'])

    sm = (
        staging_etc
        / "systemConfig"
        / "core"
        / "management"
        / "system-manager"
        / "config.nix"
    )
    if sm.is_file():
        text = sm.read_text(encoding="utf-8", errors="ignore")
        hw.platform = _first_str(
            text,
            [
                r'system\.platform\s*=\s*"([^"]+)"',
                r'\bplatform\s*=\s*"([^"]+)"',
            ],
        )

    user_cfg = staging_etc / "systemConfig" / "core" / "base" / "user" / "config.nix"
    if user_cfg.is_file():
        text = user_cfg.read_text(encoding="utf-8", errors="ignore")
        hw.users = re.findall(r'(?m)^\s*"?([A-Za-z_][A-Za-z0-9_-]*)"?\s*=\s*\{', text)
    return hw


def compare_systemconfig_to_live(
    staged: StagedHardware,
    live: LiveHardware,
) -> PreflightResult:
    """Hard-fail on platform/cpu/gpu/memory mismatch or empty staged users."""
    lines: list[str] = []
    ok = True

    def check(name: str, configured: str, detected: str, *, required: bool = True) -> None:
        nonlocal ok
        cfg = (configured or "").strip()
        det = (detected or "").strip()
        if not cfg and required:
            lines.append(f"FAIL {name}: systemConfig unset (detected={det or '?'})")
            ok = False
            return
        if not cfg:
            lines.append(f"WARN {name}: systemConfig unset (detected={det or '?'})")
            return
        if not det or det == "unknown":
            lines.append(f"FAIL {name}: could not detect live value (configured={cfg})")
            ok = False
            return
        if cfg != det:
            lines.append(f"FAIL {name}: systemConfig={cfg} live={det}")
            ok = False
        else:
            lines.append(f"OK   {name}: {cfg}")

    check("platform", staged.platform, live.platform)
    check("cpu", staged.cpu, live.cpu)
    check("gpu", staged.gpu, live.gpu)
    check("memory", staged.memory_gb, live.memory_gb)

    staged_users = [u for u in staged.users if u]
    live_users = [u for u in live.users if u]
    if not staged_users:
        lines.append("FAIL users: systemConfig has no users (would break login)")
        ok = False
    else:
        lines.append(f"OK   users(config): {' '.join(staged_users)}")
        missing_on_host = [u for u in staged_users if u not in live_users]
        extra_on_host = [u for u in live_users if u not in staged_users]
        if missing_on_host:
            lines.append(
                f"INFO users: will be created on Target: {' '.join(missing_on_host)}"
            )
        if extra_on_host:
            lines.append(
                f"WARN users: on Target but not in systemConfig: {' '.join(extra_on_host)}"
            )

    return PreflightResult(ok=ok, lines=lines)


def probe_live_hardware(
    target: str,
    *,
    sudo_password: str | None = None,
    timeout: float = 60,
) -> tuple[bool, LiveHardware | str]:
    """SSH probe Target hardware (no sudo required for these reads)."""
    from ncc_gui.push_tree import _run_ssh

    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    # Probe needs no root — run as login user
    rc, out = _run_ssh(host, ["bash", "-s"], input_text=_HW_PROBE_SH, timeout=timeout)
    if rc != 0:
        return False, out or f"hardware probe exit {rc}"
    kv = _parse_kv(out)
    live = LiveHardware(
        platform=kv.get("platform", ""),
        cpu=kv.get("cpu", ""),
        gpu=kv.get("gpu", ""),
        memory_gb=kv.get("memory_gb", ""),
        users=[u for u in (kv.get("users") or "").split() if u],
    )
    if not live.platform or live.platform == "unknown":
        return False, f"Could not detect platform on {host}:\n{out}"
    return True, live


def run_remote_systemconfig_preflight(
    *,
    target: str,
    staging_etc: Path,
    sudo_password: str | None = None,
) -> PreflightResult:
    """Compare staged systemConfig to live Target; return gate result."""
    staged = read_staged_hardware(Path(staging_etc))
    if not staged.platform and not staged.cpu and not staged.gpu:
        return PreflightResult(
            ok=False,
            lines=["FAIL: staged systemConfig has no hardware/platform fields"],
        )
    ok_probe, live_or_err = probe_live_hardware(target, sudo_password=sudo_password)
    if not ok_probe:
        return PreflightResult(ok=False, lines=[f"FAIL probe: {live_or_err}"])
    assert isinstance(live_or_err, LiveHardware)
    result = compare_systemconfig_to_live(staged, live_or_err)
    header = [
        "=== remote preflight: systemConfig vs live Target ===",
        f"Target: {target}",
        f"Live: platform={live_or_err.platform} cpu={live_or_err.cpu} "
        f"gpu={live_or_err.gpu} ram={live_or_err.memory_gb}G "
        f"users=[{' '.join(live_or_err.users)}]",
        f"Config: platform={staged.platform} cpu={staged.cpu} "
        f"gpu={staged.gpu} ram={staged.memory_gb}G "
        f"users=[{' '.join(staged.users)}]",
    ]
    result.lines = header + result.lines
    return result
