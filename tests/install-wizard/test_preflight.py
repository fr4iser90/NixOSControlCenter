#!/usr/bin/env python3
"""Tests for install preflight helpers (no Qt)."""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

# __file__ = <repo>/tests/install-wizard/test_preflight.py
REPO = Path(__file__).resolve().parents[2]
GUI = REPO / "nixos/core/management/install-wizard/ui/gui"
sys.path.insert(0, str(GUI))

import preflight as pf  # noqa: E402


class PreflightTests(unittest.TestCase):
    def test_mode_label(self) -> None:
        self.assertIn("Migrate", pf.mode_label("migrate"))
        self.assertIn("Fresh", pf.mode_label("fresh"))

    def test_find_nixos_source_from_env(self) -> None:
        with mock.patch.dict(os.environ, {"NCC_INSTALL_REPO": "/etc/nixos"}, clear=False):
            with mock.patch.object(pf, "_is_ncc_nixos_tree", return_value=True):
                self.assertEqual(pf.find_nixos_source(), "/etc/nixos")

    def test_find_install_repo_alias(self) -> None:
        with mock.patch.object(pf, "find_nixos_source", return_value="/etc/nixos"):
            self.assertEqual(pf.find_install_repo(), "/etc/nixos")

    def test_gather_aarch64_warns_not_blocked(self) -> None:
        import types

        stub = types.ModuleType("device_discover")
        stub.discover_device_targets = lambda: []
        stub.match_device_targets = lambda _=None: []
        with (
            mock.patch.object(pf.platform, "machine", return_value="aarch64"),
            mock.patch.object(
                pf, "_read_os_release", return_value={"ID": "nixos", "PRETTY_NAME": "NixOS"}
            ),
            mock.patch.object(pf, "_etc_nixos_kind", return_value=(True, "plain")),
            mock.patch.object(pf, "find_nixos_source", return_value="/tmp/nixos"),
            mock.patch.dict("sys.modules", {"device_discover": stub}),
        ):
            got = pf.gather_preflight()
        self.assertEqual(got.recommended_mode, "migrate")
        self.assertTrue(any("aarch64" in w for w in got.warnings))
        self.assertTrue(any("Jetpack" in w or "jetpack" in w for w in got.warnings))


if __name__ == "__main__":
    unittest.main()
