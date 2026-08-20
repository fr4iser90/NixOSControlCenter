#!/usr/bin/env python3
"""Unit tests for install_wizard_logic.py (no GUI display required)."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
IW = REPO / "nixos/core/management/install-wizard"
GUI = IW / "ui" / "gui"
sys.path.insert(0, str(GUI))


def _ensure_script_root() -> None:
    if (os.environ.get("SCRIPT_ROOT") or "").strip():
        return
    for cand in (
        Path("/tmp/ncc-install-tree"),
        REPO / "result-script-tree",
    ):
        if (cand / "ui" / "gui" / "export-options.sh").is_file():
            os.environ["SCRIPT_ROOT"] = str(cand)
            return
    expr = f"let pkgs = import <nixpkgs> {{}}; in (import {IW / 'scripts'} {{ inherit pkgs; }}).scriptTree"
    out = subprocess.check_output(
        ["nix-build", "-E", expr, "--no-out-link"],
        cwd=str(REPO),
        text=True,
    ).strip()
    os.environ["SCRIPT_ROOT"] = out


_ensure_script_root()

import wizard_logic as wiz  # noqa: E402


class WizardLogicTests(unittest.TestCase):
    def test_load_options_ssot(self) -> None:
        opts = wiz.load_options()
        self.assertIn("Desktop", opts.system_presets)
        self.assertIn("Server", opts.system_presets)
        self.assertNotIn("Homelab Server", opts.system_presets)
        self.assertIn("From Scratch", opts.system_presets)
        self.assertIn("Homelab Server", opts.install_starters)
        self.assertIn("Jetson Orin Nano", opts.device_presets)
        self.assertIn("Strix Halo", opts.device_presets)
        self.assertEqual(opts.device_blueprint_map.get("Strix Halo"), "fr4iser-strix-halo")
        self.assertEqual(
            opts.device_blueprint_map.get("Jetson Orin Nano"),
            "fr4iser-jetson-orin",
        )
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

    def test_browser_choices_include_firefox_default(self) -> None:
        opts = wiz.load_options()
        names = [n for n, _ in opts.browser_choices]
        self.assertEqual(opts.browser_default, "firefox")
        self.assertEqual(names[0], "firefox")
        self.assertIn("chromium", names)
        self.assertIn("brave", names)
        self.assertIn("librewolf", names)

    def test_feature_system_types_from_metadata(self) -> None:
        opts = wiz.load_options()
        self.assertIn("server", opts.feature_system_types.get("database", set()))
        self.assertNotIn("desktop", opts.feature_system_types.get("database", set()))
        self.assertIn("server", opts.feature_system_types.get("mail-server", set()))
        self.assertIn("desktop", opts.feature_system_types.get("gaming", set()))
        self.assertNotIn("server", opts.feature_system_types.get("gaming", set()))
        self.assertIn("desktop", opts.feature_system_types.get("docker", set()))
        self.assertIn("server", opts.feature_system_types.get("docker", set()))

    def test_filter_features_hides_server_only_on_desktop(self) -> None:
        opts = wiz.load_options()
        feats = ["gaming", "database", "mail-server", "docker", "web-server"]
        desktop = wiz.filter_features_for_system(feats, "desktop", opts.feature_system_types)
        server = wiz.filter_features_for_system(feats, "server", opts.feature_system_types)
        self.assertEqual(desktop, ["gaming", "docker"])
        self.assertEqual(server, ["database", "mail-server", "docker", "web-server"])
        groups = wiz.filter_feature_groups_for_system(
            opts.feature_groups, "desktop", opts.feature_system_types
        )
        flat = [f for _, fs in groups for f in fs]
        self.assertIn("gaming", flat)
        self.assertNotIn("database", flat)
        self.assertNotIn("mail-server", flat)

    def test_write_answers_includes_browsers(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "answers"
            wiz.write_answers(path, {"BROWSERS": "firefox chromium", "PACKAGE_MODULES": ""})
            text = path.read_text(encoding="utf-8")
            self.assertIn("BROWSERS=", text)
            import subprocess

            out = subprocess.check_output(
                ["bash", "-c", f'source "{path}"; printf "%s" "$BROWSERS"'],
                text=True,
            )
            self.assertEqual(out, "firefox chromium")

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
                self.assertIn(name, ("root", "user"))
                self.assertTrue(isinstance(name, str) and len(name) > 0)

    def test_homelab_defaults_present(self) -> None:
        opts = wiz.load_options()
        self.assertEqual(
            opts.preset_defaults["Homelab Server"],
            ["docker", "database", "web-server"],
        )


if __name__ == "__main__":
    result = unittest.main(verbosity=2, exit=False)
    sys.exit(0 if result.result.wasSuccessful() else 1)
