#!/usr/bin/env python3
"""Unit tests for domain_fs_status (desktop settings + module enables from systemConfig)."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GUI_PY = REPO / "nixos/core/management/gui-engine/python"


class DomainFsStatusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ps = str(GUI_PY)
        if ps not in sys.path:
            sys.path.insert(0, ps)

    def test_parse_monolith_desktop_disabled(self) -> None:
        from ncc_gui.domain_fs_status import parse_desktop_fs_stdout

        raw = """found=1
enable=false
environment=
manager=
server=
session=
dark=
"""
        fs = parse_desktop_fs_stdout(raw)
        self.assertTrue(fs.ok)
        self.assertFalse(fs.enable)
        snap = fs.as_snapshot()
        self.assertEqual(snap["enable"], "false")
        self.assertEqual(snap["environment"], "plasma")

    def test_parse_split_desktop_full(self) -> None:
        from ncc_gui.domain_fs_status import parse_desktop_fs_stdout

        raw = """found=1
enable=true
environment=gnome
manager=gdm
server=wayland
session=gnome
dark=false
"""
        fs = parse_desktop_fs_stdout(raw)
        self.assertTrue(fs.ok)
        self.assertTrue(fs.enable)
        snap = fs.as_snapshot()
        self.assertEqual(snap["environment"], "gnome")
        self.assertEqual(snap["manager"], "gdm")
        self.assertEqual(snap["dark"], "false")

    def test_parse_missing_block(self) -> None:
        from ncc_gui.domain_fs_status import parse_desktop_fs_stdout

        fs = parse_desktop_fs_stdout("found=0\nenable=\n")
        self.assertFalse(fs.ok)

    def test_parse_module_enables_stdout(self) -> None:
        from ncc_gui.domain_fs_status import parse_module_enables_stdout

        raw = """enable.desktop=false
enable.stacks=true
enable.chronicle=false
arch=x86_64
"""
        got = parse_module_enables_stdout(raw)
        self.assertEqual(
            got, {"desktop": False, "stacks": True, "chronicle": False}
        )

    def test_parse_network_hardware_users_fs(self) -> None:
        from ncc_gui.domain_fs_status import (
            parse_hardware_fs_stdout,
            parse_network_fs_stdout,
            parse_users_fs_stdout,
        )

        net = parse_network_fs_stdout(
            "found=1\nhostname=jetson-orin\nenable=true\nwifi_enable=false\n"
        )
        self.assertTrue(net.ok)
        self.assertEqual(net.hostname, "jetson-orin")
        self.assertTrue(net.enable)
        self.assertFalse(net.wifi_enable)

        hw = parse_hardware_fs_stdout(
            "found=1\ncpu=none\ngpu=jetson\nramGB=8\n"
        )
        self.assertTrue(hw.ok)
        self.assertEqual(hw.as_configured(), {"cpu": "none", "gpu": "jetson", "ramGB": 8})

        users = parse_users_fs_stdout(
            "found=1\n"
            "user=fr4iser|role=admin|shell=zsh|autoLogin=false\n"
        )
        self.assertTrue(users.ok)
        self.assertEqual(len(users.users), 1)
        self.assertEqual(users.users[0].name, "fr4iser")
        self.assertEqual(users.users[0].role, "admin")
        self.assertFalse(users.users[0].auto_login)

    def test_module_enables_script_monolith(self) -> None:
        from ncc_gui.domain_fs_status import (
            MODULE_ENABLES_SCRIPT,
            parse_module_enables_stdout,
        )

        mono = """
{
  core = {
    base = {
      desktop = {
        enable = false;
      };
      network = {
        enable = true;
      };
    };
  };
  modules = {
    infrastructure = {
      "stack-manager" = {
        enable = true;
      };
      vm = {
        enable = false;
      };
    };
  };
}
"""
        with tempfile.TemporaryDirectory() as tmp:
            nixos = Path(tmp) / "etc" / "nixos"
            nixos.mkdir(parents=True)
            (nixos / "systemConfig.nix").write_text(mono, encoding="utf-8")
            script = MODULE_ENABLES_SCRIPT.replace(
                "NIXOS=/etc/nixos", f"NIXOS={nixos}"
            )
            proc = subprocess.run(
                ["bash", "-s"],
                input=script,
                check=False,
                capture_output=True,
                text=True,
                timeout=8,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            got = parse_module_enables_stdout(proc.stdout or "")
            self.assertEqual(got.get("desktop"), False)
            self.assertEqual(got.get("network"), True)
            self.assertEqual(got.get("stacks"), True)
            self.assertEqual(got.get("vm"), False)


class ChromePrefsHideInactiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ps = str(GUI_PY)
        if ps not in sys.path:
            sys.path.insert(0, ps)

    def test_hide_inactive_default_false(self) -> None:
        from ncc_gui import chrome_prefs as cp

        self.assertFalse(cp._DEFAULT["hide_inactive_features"])


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
