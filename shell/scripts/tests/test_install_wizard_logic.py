#!/usr/bin/env python3
"""Unit tests for install_wizard.py logic (no Tk display required)."""

from __future__ import annotations

import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

# Mock tkinter before importing the wizard module (headless CI / no DISPLAY).
_tk = types.ModuleType("tkinter")
_tk.Tk = mock.MagicMock
_tk.StringVar = mock.MagicMock
_tk.BooleanVar = mock.MagicMock
_tk.Misc = object
_tk.Entry = mock.MagicMock
_tk.Frame = mock.MagicMock
_tk.Label = mock.MagicMock
_tk.Radiobutton = mock.MagicMock
_tk.Checkbutton = mock.MagicMock
_tk.Button = mock.MagicMock
_tk.Canvas = mock.MagicMock
_tk.Scrollbar = mock.MagicMock
_tk.LEFT = "left"
_tk.RIGHT = "right"
_tk.BOTH = "both"
_tk.X = "x"
_tk.Y = "y"
_tk.END = "end"
_tk.NORMAL = "normal"
_tk.DISABLED = "disabled"
_tk.WORD = "word"
sys.modules["tkinter"] = _tk
sys.modules["tkinter.ttk"] = types.ModuleType("tkinter.ttk")
sys.modules["tkinter.filedialog"] = types.ModuleType("tkinter.filedialog")
sys.modules["tkinter.messagebox"] = types.ModuleType("tkinter.messagebox")

ROOT = Path(__file__).resolve().parents[3]
WIZARD = ROOT / "shell" / "scripts" / "ui" / "gui" / "install_wizard.py"
sys.path.insert(0, str(WIZARD.parent))

import install_wizard as wiz  # noqa: E402


class WizardLogicTests(unittest.TestCase):
    def test_load_options_ssot(self) -> None:
        opts = wiz.load_options()
        self.assertIn("Desktop", opts.system_presets)
        self.assertIn("Server", opts.system_presets)
        self.assertIn("Homelab Server", opts.system_presets)
        self.assertIn("From Scratch", opts.system_presets)
        self.assertIn("Jetson Nano", opts.device_presets)
        self.assertEqual(
            opts.preset_defaults.get("Homelab Server"),
            ["docker", "database", "web-server"],
        )
        self.assertEqual(opts.preset_defaults.get("Desktop"), [])
        self.assertIn("podman", opts.conflicts.get("docker", set()))
        self.assertIn("qemu-vm", opts.dependencies.get("virt-manager", set()))
        self.assertTrue(any(e in ("plasma", "gnome", "xfce", "") for e in opts.desktop_envs))

    def test_resolve_features_conflicts_and_deps(self) -> None:
        conflicts = {"docker": {"podman"}, "podman": {"docker"}}
        deps = {"virt-manager": {"qemu-vm"}}
        resolved = wiz.resolve_features(
            ["docker", "podman", "virt-manager"],
            conflicts,
            deps,
        )
        self.assertIn("docker", resolved)
        self.assertNotIn("podman", resolved)
        self.assertIn("virt-manager", resolved)
        self.assertIn("qemu-vm", resolved)

    def test_write_answers_roundtrip_shell(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "answers"
            wiz.write_answers(
                path,
                {
                    "ADMIN_USER": "alice",
                    "PACKAGE_MODULES": "docker database",
                    "VIRT_PASSWORD": "p@ss 'quote",
                },
            )
            text = path.read_text(encoding="utf-8")
            self.assertIn("ADMIN_USER=", text)
            self.assertIn("PACKAGE_MODULES=", text)
            # sourcable by bash
            import subprocess

            out = subprocess.check_output(
                [
                    "bash",
                    "-c",
                    f'source "{path}"; printf "%s|%s|%s" "$ADMIN_USER" "$PACKAGE_MODULES" "$VIRT_PASSWORD"',
                ],
                text=True,
            )
            self.assertEqual(out, "alice|docker database|p@ss 'quote")

    def test_default_admin_prefers_sudo_user(self) -> None:
        with mock.patch.dict(
            os.environ,
            {"SUDO_USER": "fr4iser", "USER": "root", "LOGNAME": "root"},
            clear=False,
        ):
            self.assertEqual(wiz.default_admin(), "fr4iser")

    def test_default_admin_rejects_root_when_possible(self) -> None:
        with mock.patch.dict(
            os.environ,
            {"SUDO_USER": "root", "USER": "root", "LOGNAME": "root"},
            clear=False,
        ):
            with mock.patch("getpass.getuser", return_value="root"):
                name = wiz.default_admin()
                # Last resort may still be "root" from SUDO_USER, or "user"
                self.assertIn(name, ("root", "user"))
                self.assertTrue(isinstance(name, str) and len(name) > 0)

if __name__ == "__main__":
    # Fail loud
    result = unittest.main(verbosity=2, exit=False)
    sys.exit(0 if result.result.wasSuccessful() else 1)
