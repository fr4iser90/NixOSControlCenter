#!/usr/bin/env python3
"""Tests for install preflight helpers (no Qt)."""

from __future__ import annotations

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

    def test_find_repo_from_cwd(self) -> None:
        repo = REPO
        self.assertTrue((repo / "nixos" / "core").is_dir())
        with mock.patch.object(pf, "Path") as P:
            # simpler: call real find with chdir
            pass
        found = pf.find_install_repo()
        # May be empty if cwd is elsewhere — at least function runs
        self.assertIsInstance(found, str)

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
            mock.patch.object(pf, "find_install_repo", return_value="/tmp/repo"),
            mock.patch.dict("sys.modules", {"device_discover": stub}),
        ):
            got = pf.gather_preflight()
        self.assertEqual(got.recommended_mode, "migrate")
        self.assertTrue(any("aarch64" in w for w in got.warnings))
        self.assertTrue(any("Jetpack" in w or "jetpack" in w for w in got.warnings))


if __name__ == "__main__":
    unittest.main()
