"""Remote install gate pipes Host prebuild scripts via SSH."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GUI_PY = ROOT / "nixos" / "core" / "management" / "gui-engine" / "python"
if str(GUI_PY) not in sys.path:
    sys.path.insert(0, str(GUI_PY))

from ncc_gui.push_tree import remote_target_install_gate


def test_remote_gate_runs_prebuild_steps(monkeypatch) -> None:
    calls: list[tuple[str, str]] = []

    def fake_checks(target, **kwargs):  # type: ignore[no-untyped-def]
        calls.append(("checks", target))
        return True, "checks ok"

    def fake_post(host, script, **kwargs):  # type: ignore[no-untyped-def]
        calls.append(("post", script[:40]))
        return True, "post ok"

    monkeypatch.setattr("ncc_gui.push_tree.run_remote_prebuild_checks", fake_checks)
    monkeypatch.setattr("ncc_gui.push_tree._run_remote_sudo_bash", fake_post)
    monkeypatch.setattr("ncc_gui.push_tree._host_ncc_script_body", lambda _: None)

    ok, out = remote_target_install_gate("u@host", "jetson-orin")
    assert ok and "post ok" in out
    assert calls[0] == ("checks", "u@host")
    assert calls[1][0] == "post"
