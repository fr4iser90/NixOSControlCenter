"""Local install / migrate preflight probes for the Install domain page."""

from __future__ import annotations

import json
import os
import platform
import socket
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class InstallPreflight:
    hostname: str = "—"
    arch: str = "—"
    is_nixos: bool = False
    os_pretty: str = "—"
    etc_nixos: bool = False
    etc_nixos_kind: str = "missing"  # missing | plain | ncc
    repo: str = ""  # Host NixOS tree used for rsync (usually /etc/nixos on live NCC)
    device_matched: list[str] = field(default_factory=list)
    device_available: list[str] = field(default_factory=list)
    recommended_mode: str = "unknown"  # fresh | migrate | reconfigure | blocked
    warnings: list[str] = field(default_factory=list)
    remote_target: str = ""


_LIVE_NIXOS = Path("/etc/nixos")


def _is_ncc_nixos_tree(path: Path) -> bool:
    """Deployed or checkout nixos tree (flake + core/management)."""
    return (path / "flake.nix").is_file() and (path / "core" / "management").is_dir()


def _configured_local_source() -> str:
    raw = (os.environ.get("NCC_HOST_POLICY") or "").strip()
    if not raw:
        return ""
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return str(data.get("localSourceDir") or "").strip()
    except json.JSONDecodeError:
        pass
    return ""


def find_nixos_source() -> str:
    """Directory to rsync to remote Target (live ``/etc/nixos`` first on NCC hosts)."""
    override = (os.environ.get("NCC_INSTALL_REPO") or "").strip()
    if override:
        cand = Path(override)
        if _is_ncc_nixos_tree(cand):
            return str(cand.resolve())
        nested = cand / "nixos"
        if _is_ncc_nixos_tree(nested):
            return str(nested.resolve())

    configured = _configured_local_source()
    if configured:
        cand = Path(configured)
        if _is_ncc_nixos_tree(cand):
            return str(cand.resolve())
        nested = cand / "nixos"
        if _is_ncc_nixos_tree(nested):
            return str(nested.resolve())

    if _is_ncc_nixos_tree(_LIVE_NIXOS):
        return str(_LIVE_NIXOS.resolve())

    d = Path.cwd().resolve()
    for p in [d, *d.parents]:
        nested = p / "nixos"
        if _is_ncc_nixos_tree(nested):
            return str(nested.resolve())
    return ""


def find_install_repo() -> str:
    """Backward-compatible alias — returns the Host NixOS tree path."""
    return find_nixos_source()


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


def _etc_nixos_kind() -> tuple[bool, str]:
    root = Path("/etc/nixos")
    if not root.is_dir():
        return False, "missing"
    # NCC dual layout / monolith markers
    markers = [
        root / "systemConfig.nix",
        root / "systemConfig",
        root / "flake.nix",
    ]
    nccish = False
    for m in markers:
        if m.exists():
            nccish = True
            break
    if not nccish:
        try:
            flake = (root / "flake.nix").read_text(encoding="utf-8", errors="ignore")
            if "NixOSControlCenter" in flake or "core/management" in flake:
                nccish = True
        except OSError:
            pass
    if not nccish:
        # Heuristic: configuration.nix imports looking like stock generate-config
        conf = root / "configuration.nix"
        if conf.is_file():
            try:
                body = conf.read_text(encoding="utf-8", errors="ignore")
                if "hardware-configuration.nix" in body and "systemConfig" not in body:
                    return True, "plain"
            except OSError:
                pass
        return True, "plain"
    return True, "ncc"


def gather_preflight(*, remote_target: str = "") -> InstallPreflight:
    """Probe this machine (filesystem). Remote target is noted, not probed."""
    pf = InstallPreflight(remote_target=(remote_target or "").strip())
    try:
        pf.hostname = socket.gethostname() or "—"
    except OSError:
        pf.hostname = "—"
    pf.arch = platform.machine() or "—"

    osr = _read_os_release()
    pf.os_pretty = osr.get("PRETTY_NAME") or osr.get("NAME") or "—"
    pf.is_nixos = (
        osr.get("ID") == "nixos"
        or Path("/run/current-system").exists()
        or "nixos" in (osr.get("ID_LIKE") or "").lower()
    )

    pf.etc_nixos, pf.etc_nixos_kind = _etc_nixos_kind()
    pf.repo = find_nixos_source()

    # Host blueprints under deployed core (when present on live /etc/nixos)
    if pf.repo:
        bp = (
            Path(pf.repo)
            / "core"
            / "management"
            / "install-wizard"
            / "scripts"
            / "setup"
            / "modes"
            / "host-blueprints"
        )
        if bp.is_dir():
            os.environ.setdefault("NCC_HOST_BLUEPRINTS", str(bp))

    # Device targets (same SSOT as wizard)
    try:
        from device_discover import discover_device_targets, match_device_targets

        targets = discover_device_targets()
        pf.device_available = [t.label for t in targets]
        pf.device_matched = [t.label for t in match_device_targets(targets)]
    except Exception:
        pf.device_available = []
        pf.device_matched = []

    arch_l = pf.arch.lower()
    if arch_l in ("aarch64", "arm64"):
        pf.warnings.append(
            "Live arch aarch64 → system.platform=aarch64-linux (preflight sync). "
            "NVIDIA Jetpack modules are not wired into NCC yet — Orin GPU stack may need manual jetpack config."
        )

    if not pf.is_nixos and not pf.etc_nixos:
        pf.recommended_mode = "fresh"
        pf.warnings.append("No NixOS install detected — use a NixOS ISO / fresh path.")
    elif pf.etc_nixos_kind == "ncc":
        pf.recommended_mode = "reconfigure"
    elif pf.etc_nixos:
        pf.recommended_mode = "migrate"
        pf.warnings.append(
            "/etc/nixos exists (non-NCC or plain). Back up before migrate."
        )
    else:
        pf.recommended_mode = "fresh"

    if not pf.repo:
        pf.warnings.append(
            "No Host NixOS tree — need /etc/nixos (NCC) or set NCC_INSTALL_REPO."
        )

    if pf.remote_target:
        pf.warnings.append(
            f"Target {pf.remote_target!r} connected — install deploy uses "
            "Host→Target rsync (same as System → Update)."
        )

    return pf


def mode_label(mode: str) -> str:
    return {
        "fresh": "Fresh install",
        "migrate": "Migrate existing NixOS → NCC",
        "reconfigure": "Already NCC — reconfigure / sync",
        "blocked": "Blocked (arch / unsupported)",
        "unknown": "Unknown",
    }.get(mode, mode)
