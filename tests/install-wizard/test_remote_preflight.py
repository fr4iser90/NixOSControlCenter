"""Remote systemConfig vs live hardware preflight (unit tests, no SSH)."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOD = (
    ROOT
    / "nixos"
    / "core"
    / "management"
    / "install-wizard"
    / "ui"
    / "gui"
    / "remote_preflight.py"
)


def _load():
    spec = importlib.util.spec_from_file_location("remote_preflight", MOD)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules["remote_preflight"] = mod
    spec.loader.exec_module(mod)
    return mod


rp = _load()


def test_compare_ok_jetson() -> None:
    staged = rp.StagedHardware(
        platform="aarch64-linux",
        cpu="none",
        gpu="jetson",
        memory_gb="8",
        users=["fr4iser"],
    )
    live = rp.LiveHardware(
        platform="aarch64-linux",
        cpu="none",
        gpu="jetson",
        memory_gb="8",
        users=["fr4iser"],
    )
    r = rp.compare_systemconfig_to_live(staged, live)
    assert r.ok
    assert any(l.startswith("OK   gpu:") for l in r.lines)


def test_compare_fail_wrong_gpu() -> None:
    staged = rp.StagedHardware(
        platform="aarch64-linux",
        cpu="none",
        gpu="jetson",
        memory_gb="8",
        users=["fr4iser"],
    )
    live = rp.LiveHardware(
        platform="x86_64-linux",
        cpu="amd",
        gpu="amd",
        memory_gb="32",
        users=["fr4iser"],
    )
    r = rp.compare_systemconfig_to_live(staged, live)
    assert not r.ok
    assert any("FAIL platform:" in l for l in r.lines)
    assert any("FAIL gpu:" in l for l in r.lines)
    assert any("FAIL cpu:" in l for l in r.lines)
    assert any("FAIL memory:" in l for l in r.lines)


def test_compare_fail_empty_users() -> None:
    staged = rp.StagedHardware(
        platform="aarch64-linux",
        cpu="none",
        gpu="jetson",
        memory_gb="8",
        users=[],
    )
    live = rp.LiveHardware(
        platform="aarch64-linux",
        cpu="none",
        gpu="jetson",
        memory_gb="8",
        users=["fr4iser"],
    )
    r = rp.compare_systemconfig_to_live(staged, live)
    assert not r.ok
    assert any("FAIL users:" in l for l in r.lines)


def test_read_staged_monolith() -> None:
    text = """{
  core = {
    base = {
      hardware = {
        cpu = "none";
        gpu = "jetson";
        ram = {
          sizeGB = 8;
        };
      };
      user = {
        fr4iser = {
          role = "admin";
          defaultShell = "zsh";
          autoLogin = false;
        };
      };
    };
    management = {
      "system-manager" = {
        system = {
          platform = "aarch64-linux";
        };
      };
    };
  };
}
"""
    with tempfile.TemporaryDirectory() as td:
        p = Path(td)
        (p / "systemConfig.nix").write_text(text, encoding="utf-8")
        hw = rp.read_staged_hardware(p)
    assert hw.cpu == "none"
    assert hw.gpu == "jetson"
    assert hw.memory_gb == "8"
    assert hw.platform == "aarch64-linux"
    assert "fr4iser" in hw.users
