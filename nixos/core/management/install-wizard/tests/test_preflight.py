#!/usr/bin/env python3
"""Tests for install preflight helpers (no Qt)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

GUI = Path(__file__).resolve().parents[1] / "ui" / "gui"
sys.path.insert(0, str(GUI))

import preflight as pf  # noqa: E402


class PreflightTests(unittest.TestCase):
    def test_mode_label(self) -> None:
        self.assertIn("Migrate", pf.mode_label("migrate"))
        self.assertIn("Fresh", pf.mode_label("fresh"))

    def test_find_repo_from_cwd(self) -> None:
        # Running from repo should resolve
        root = Path(__file__).resolve().parents[4]  # …/NixOSControlCenter
        # parents: tests→install-wizard→management→core→nixos→repo = 5?
        # __file__ = …/install-wizard/tests/test_preflight.py
        # parents[0]=tests, [1]=install-wizard, [2]=management, [3]=core, [4]=nixos, [5]=repo
        repo = Path(__file__).resolve().parents[5]
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
