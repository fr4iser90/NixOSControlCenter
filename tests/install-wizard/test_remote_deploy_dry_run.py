#!/usr/bin/env python3
"""Dry-run the remote Install deploy chain (stage + SSH probe + rsync -n).

No writes to Target /etc/nixos. Use before GUI round-trips.

Usage:
  bash tests/install-wizard/test-remote-deploy-dry-run.sh
  bash tests/install-wizard/test-remote-deploy-dry-run.sh fr4iser@192.168.178.41

Env:
  NCC_INSTALL_REMOTE_TARGET  SSH target (user@host)
  NCC_INSTALL_BLUEPRINT      blueprint file name under host-blueprints/ (default: fr4iser-jetson-orin)
  NCC_INSTALL_REPO           override Host nixos tree (else /etc/nixos or cwd)
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IW_GUI = ROOT / "nixos" / "core" / "management" / "install-wizard" / "ui" / "gui"
GUI_PY = ROOT / "nixos" / "core" / "management" / "gui-engine" / "python"
BLUEPRINTS = (
    ROOT
    / "nixos"
    / "core"
    / "management"
    / "install-wizard"
    / "scripts"
    / "setup"
    / "modes"
    / "host-blueprints"
)


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _find_nixos_source() -> str:
    override = (os.environ.get("NCC_INSTALL_REPO") or "").strip()
    if override:
        return override
    live = Path("/etc/nixos")
    if (live / "flake.nix").is_file() and (live / "core" / "management").is_dir():
        return str(live)
    nested = ROOT / "nixos"
    if (nested / "flake.nix").is_file():
        return str(nested)
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Remote install deploy dry-run")
    parser.add_argument(
        "target",
        nargs="?",
        default=(os.environ.get("NCC_INSTALL_REMOTE_TARGET") or "").strip(),
        help="SSH target user@host (e.g. fr4iser@192.168.178.41)",
    )
    parser.add_argument(
        "--blueprint",
        default=(os.environ.get("NCC_INSTALL_BLUEPRINT") or "fr4iser-jetson-orin").strip(),
        help="Host blueprint file name in host-blueprints/",
    )
    args = parser.parse_args()

    if str(GUI_PY) not in sys.path:
        sys.path.insert(0, str(GUI_PY))

    preflight = _load("preflight_probe", IW_GUI / "preflight.py")
    remote_deploy = _load("remote_deploy_dry", IW_GUI / "remote_deploy.py")

    nixos_source = preflight.find_nixos_source() or _find_nixos_source()
    if not nixos_source:
        print("FAIL: no Host nixos tree — set NCC_INSTALL_REPO or deploy NCC to /etc/nixos")
        return 1

    bp = BLUEPRINTS / args.blueprint
    if not bp.is_file():
        print(f"FAIL: blueprint not found: {bp}")
        return 1

    selection = f"LOAD_BLUEPRINT:{bp.resolve()}"
    print(f"Host tree: {nixos_source}")
    print(f"Blueprint: {bp.name}")
    print(f"Selection: {selection}")

    sudo_password = (os.environ.get("NCC_TARGET_SUDO_PASSWORD") or "").strip() or None

    if not args.target:
        print("\nSKIP remote (no target) — local stage only")
        staging = remote_deploy.make_staging_dir()
        ok, detail = remote_deploy.stage_install_config(
            selection=selection,
            answers_file="",
            nixos_source=nixos_source,
            staging_etc=staging,
        )
        print(detail[-4000:])
        if not ok:
            print("FAIL: local stage")
            return 1
        print(f"OK: systemConfig staged under {staging}")
        return 0

    ok, detail = remote_deploy.dry_run_remote_deploy(
        target=args.target,
        selection=selection,
        nixos_source=nixos_source,
        sudo_password=sudo_password,
        on_log=lambda s: print(s, end=""),
    )
    if not ok:
        print(f"\nFAIL: {detail}")
        return 1
    print(f"\nOK: dry-run complete (flake attr: {detail})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
