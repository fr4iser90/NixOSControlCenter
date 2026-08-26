"""Remote install uses system-manager prebuild checks (layer-correct)."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IW_GUI = ROOT / "nixos" / "core" / "management" / "install-wizard" / "ui" / "gui"
GUI_PY = ROOT / "nixos" / "core" / "management" / "gui-engine" / "python"
SM = ROOT / "nixos" / "core" / "management" / "system-manager"


def _load_remote_deploy():
    spec = importlib.util.spec_from_file_location("remote_deploy_gate", IW_GUI / "remote_deploy.py")
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules["remote_deploy_gate"] = mod
    spec.loader.exec_module(mod)
    return mod


def test_no_install_wizard_gate_script() -> None:
    assert not (IW_GUI / "remote_install_gate.sh").is_file()


def test_host_staging_uses_blueprint_only() -> None:
    rd = _load_remote_deploy()
    env = rd._HOST_STAGING_ENV
    assert env.get("NCC_INSTALL_HOST_BLUEPRINT_ONLY") == "1"
    assert "NCC_INSTALL_SKIP_COLLECT" not in env


def test_system_manager_has_remote_gate_and_preflight_remote() -> None:
    assert (SM / "components/system-checks/scripts/remote-install-gate.nix").is_file()
    assert (SM / "components/system-checks/lib/preflight-remote.nix").is_file()
    text = (SM / "components/system-checks/lib/preflight-remote.nix").read_text(encoding="utf-8")
    assert "NCC_PREFLIGHT_MODE" in text
    assert "prebuild-check-users" in text


def test_push_tree_check_steps_match_ssot() -> None:
    sys.path.insert(0, str(GUI_PY))
    from ncc_gui import push_tree

    names = [cmd for cmd, _ in push_tree._REMOTE_INSTALL_CHECK_STEPS]
    assert names[0] == "prebuild-check-users"
    assert "prebuild-check-gpu" in names
    assert push_tree._REMOTE_INSTALL_CHECK_STEPS[1][1]["NCC_PREFLIGHT_MODE"] == "compare"
