#!/usr/bin/env python3
"""Companion theme pack: dark default + readable QSS hooks."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.companion_themes import (  # noqa: E402
    DEFAULT_THEME,
    THEMES,
    get_theme,
    list_themes,
    normalize_theme_id,
    stylesheet_for,
)


class CompanionThemesTests(unittest.TestCase):
    def test_default_is_dark(self) -> None:
        self.assertEqual(DEFAULT_THEME, "dark")
        self.assertIn("dark", THEMES)
        self.assertIn("light", THEMES)
        self.assertIn("midnight", THEMES)

    def test_normalize_unknown(self) -> None:
        self.assertEqual(normalize_theme_id(None), "dark")
        self.assertEqual(normalize_theme_id("nope"), "dark")
        self.assertEqual(normalize_theme_id("Light"), "light")

    def test_stylesheet_sets_text_and_combo_popup(self) -> None:
        qss = stylesheet_for(get_theme("dark"))
        self.assertIn("QComboBox QAbstractItemView", qss)
        self.assertIn("QListWidget::item", qss)
        self.assertIn("QMenu", qss)
        self.assertIn("QLabel#nccMuted", qss)
        self.assertIn(get_theme("dark").text, qss)
        self.assertIn(get_theme("dark").base, qss)

    def test_list_themes(self) -> None:
        ids = [t[0] for t in list_themes()]
        self.assertEqual(set(ids), set(THEMES))

    def test_companion_wires_theme_menu(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("_apply_theme", text)
        self.assertIn('_set_theme', text)
        self.assertIn('addMenu("Theme")', text)
        self.assertIn("companion_themes", text)
        self.assertIn('setObjectName("nccMuted")', text)
        self.assertNotIn("rgba(244, 246, 248", text)


if __name__ == "__main__":
    unittest.main()
