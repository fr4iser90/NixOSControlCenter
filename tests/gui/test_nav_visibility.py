#!/usr/bin/env python3
"""Sidebar visibility rules (GUI-DESIGN §9 / nav_visibility.py)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GUI_PY = REPO / "nixos/core/management/gui-engine/python"


class NavVisibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ps = str(GUI_PY)
        if ps not in sys.path:
            sys.path.insert(0, ps)

    def test_core_manager_always_visible_when_off(self) -> None:
        from ncc_gui.nav_visibility import domain_nav_visible

        self.assertTrue(
            domain_nav_visible(
                always_visible=True,
                group="core",
                catalog_on=False,
                active=False,
                hide_inactive_features=False,
                allow=None,
                domain_id="desktop",
                local_only=frozenset(),
            )
        )

    def test_conditional_core_hidden_when_catalog_off(self) -> None:
        """Hyprland-style: alwaysVisible=false → only when catalog enabled."""
        from ncc_gui.nav_visibility import domain_nav_visible

        self.assertFalse(
            domain_nav_visible(
                always_visible=False,
                group="core",
                catalog_on=False,
                active=False,
                hide_inactive_features=False,
                allow=None,
                domain_id="hyprland",
                local_only=frozenset(),
            )
        )
        self.assertTrue(
            domain_nav_visible(
                always_visible=False,
                group="core",
                catalog_on=True,
                active=True,
                hide_inactive_features=False,
                allow=None,
                domain_id="hyprland",
                local_only=frozenset(),
            )
        )

    def test_features_visible_by_default_when_off(self) -> None:
        from ncc_gui.nav_visibility import domain_nav_visible

        self.assertTrue(
            domain_nav_visible(
                always_visible=False,
                group="features",
                catalog_on=False,
                active=False,
                hide_inactive_features=False,
                allow=None,
                domain_id="vm",
                local_only=frozenset(),
            )
        )

    def test_hide_inactive_features(self) -> None:
        from ncc_gui.nav_visibility import domain_nav_visible

        self.assertFalse(
            domain_nav_visible(
                always_visible=False,
                group="features",
                catalog_on=False,
                active=False,
                hide_inactive_features=True,
                allow=None,
                domain_id="vm",
                local_only=frozenset(),
            )
        )
        self.assertTrue(
            domain_nav_visible(
                always_visible=False,
                group="features",
                catalog_on=True,
                active=True,
                hide_inactive_features=True,
                allow=None,
                domain_id="vm",
                local_only=frozenset(),
            )
        )

    def test_remote_allow_gate(self) -> None:
        from ncc_gui.nav_visibility import domain_nav_visible

        allow = frozenset({"install", "system"})
        self.assertTrue(
            domain_nav_visible(
                always_visible=True,
                group="core",
                catalog_on=True,
                active=True,
                hide_inactive_features=False,
                allow=allow,
                domain_id="install",
                local_only=frozenset({"ssh"}),
            )
        )
        self.assertFalse(
            domain_nav_visible(
                always_visible=True,
                group="core",
                catalog_on=True,
                active=True,
                hide_inactive_features=False,
                allow=allow,
                domain_id="desktop",
                local_only=frozenset({"ssh"}),
            )
        )
        self.assertTrue(
            domain_nav_visible(
                always_visible=False,
                group="features",
                catalog_on=True,
                active=True,
                hide_inactive_features=False,
                allow=allow,
                domain_id="ssh",
                local_only=frozenset({"ssh"}),
            )
        )


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
