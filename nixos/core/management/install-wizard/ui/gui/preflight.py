"""Local install / migrate preflight probes for the Install domain page."""

from __future__ import annotations

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
    repo: str = ""
    device_matched: list[str] = field(default_factory=list)
    device_available: list[str] = field(default_factory=list)
    recommended_mode: str = "unknown"  # fresh | migrate | reconfigure | blocked
    warnings: list[str] = field(default_factory=list)
    remote_target: str = ""


def find_install_repo() -> str:
    for key in ("NCC_INSTALL_REPO",):
        v = (os.environ.get(key) or "").strip()
        if v and (Path(v) / "nixos" / "core").is_dir():
            return v
    d = Path.cwd().resolve()
    for p in [d, *d.parents]:
        if (p / "nixos" / "core" / "management").is_dir():
            return str(p)
    home = Path.home()
    for cand in (
        home / "Documents" / "Git" / "NixOSControlCenter",
        home / "NixOSControlCenter",
    ):
        if (cand / "nixos" / "core" / "management").is_dir():
            return str(cand)
    return ""


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
    pf.repo = find_install_repo()

    # Prefer repo blueprints when GUI page is loaded without SCRIPT_ROOT
    if pf.repo:
        bp = (
            Path(pf.repo)
            / "nixos"
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
        # SCRIPT_ROOT / blueprints may be absent outside install shell
        pf.device_available = []
        pf.device_matched = []

    # Live arch → expected system.platform (prebuild syncs like CPU/GPU).
    # Jetpack for Orin is still a separate flake input — warn, do not hard-block.
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
        pf.warnings.append("Repo not found — set NCC_INSTALL_REPO or open from a checkout.")

    if pf.remote_target:
        pf.warnings.append(
            f"GUI target is {pf.remote_target!r} — preflight probes are local only; "
            "wizard/deploy still follow install tooling for the chosen host."
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
