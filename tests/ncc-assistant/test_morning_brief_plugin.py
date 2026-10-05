#!/usr/bin/env python3
"""Morning Brief feature plugin tests (no display)."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest import mock
from zoneinfo import ZoneInfo

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class MorningBriefTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)

    def test_plugin_registered(self) -> None:
        from ncc_assistant.plugins import get_plugin, list_plugins

        ids = [p.id for p in list_plugins()]
        self.assertIn("morning-brief", ids)
        self.assertIn("doomscroll", ids)
        p = get_plugin("morning-brief")
        self.assertIsNotNone(p)
        assert p is not None
        self.assertEqual(p.title, "Morning Brief")

    def test_parse_digest_hhmm(self) -> None:
        from ncc_assistant.plugins.morning_brief.logic import parse_digest_hhmm

        self.assertEqual(parse_digest_hhmm("*-*-* 08:30:00"), (8, 30))
        self.assertEqual(parse_digest_hhmm("daily"), (0, 0))
        self.assertIsNone(parse_digest_hhmm("hourly"))

    def test_due_once_per_day(self) -> None:
        from ncc_assistant.plugins.morning_brief.logic import due_for_brief
        from ncc_assistant.preferences import (
            set_daily_digest_on_calendar,
            set_morning_brief_last_fired,
        )

        set_daily_digest_on_calendar("*-*-* 08:30:00")
        set_morning_brief_last_fired("")
        tz = ZoneInfo("Europe/Berlin")
        before = datetime(2026, 10, 5, 8, 0, tzinfo=tz)
        after = datetime(2026, 10, 5, 9, 0, tzinfo=tz)
        self.assertFalse(due_for_brief(now=before))
        self.assertTrue(due_for_brief(now=after))
        set_morning_brief_last_fired("2026-10-05")
        self.assertFalse(due_for_brief(now=after))

    def test_settings_moved_to_plugin(self) -> None:
        gui = (ROOT / "ncc_assistant" / "gui_pages.py").read_text(encoding="utf-8")
        settings = (
            ROOT
            / "ncc_assistant"
            / "plugins"
            / "morning_brief"
            / "settings_ui.py"
        ).read_text(encoding="utf-8")
        self.assertIn("Morning Brief", settings)
        self.assertIn("MORNING_BRIEF_SOURCES", settings)
        self.assertIn("Plugins</b> tab", gui)
        self.assertNotIn("Build daily Issues/PRs/tasks snapshot", gui)


if __name__ == "__main__":
    unittest.main()
