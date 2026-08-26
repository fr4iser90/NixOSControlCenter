"""Install remote deploy helpers (no Qt)."""

from __future__ import annotations

import importlib.util
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IW_GUI = ROOT / "nixos" / "core" / "management" / "install-wizard" / "ui" / "gui"


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


_remote = _load_module("remote_deploy_test", IW_GUI / "remote_deploy.py")


def test_flake_hostname_from_staging() -> None:
    staging = Path("/tmp/ncc-test-staging-hostname")
    cfg = (
        staging
        / "systemConfig"
        / "core"
        / "management"
        / "system-manager"
        / "config.nix"
    )
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text('  hostName = "jetson-orin";\n', encoding="utf-8")
    try:
        assert _remote.flake_hostname(staging) == "jetson-orin"
    finally:
        shutil.rmtree(staging, ignore_errors=True)
