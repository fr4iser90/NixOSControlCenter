#!/usr/bin/env python3
"""Workspace brief = workflow template; not a plugin. No Daily board."""

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


class WorkspaceBriefArchitectureTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)

    def test_brief_is_not_a_plugin(self) -> None:
        from ncc_assistant.plugins import get_plugin, list_plugins

        ids = [p.id for p in list_plugins()]
        self.assertNotIn("morning-brief", ids)
        self.assertIn("doomscroll", ids)
        self.assertIsNone(get_plugin("morning-brief"))

    def test_workspace_brief_template_exists(self) -> None:
        from ncc_assistant.agent_templates import get_agent_template

        tmpl = get_agent_template("workspace-brief")
        self.assertIsNotNone(tmpl)
        assert tmpl is not None
        self.assertEqual(tmpl.schedule_kind, "poll")
        self.assertTrue(tmpl.dry_run)
        self.assertIn("repositories", [p.id for p in tmpl.params])

    def test_companion_has_no_daily_toolbar(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("Workflows (once / cron)", text)
        self.assertIn("PANEL_CRON", text)
        # primary toolbar must not advertise a Daily board
        primary = text.split("primary = (", 1)[1].split(")", 1)[0]
        self.assertNotIn("PANEL_WORKFLOWS", primary)
        self.assertNotIn("maybe_fire_brief", text)

    def test_gui_tabs_no_workflows_board(self) -> None:
        gui = (ROOT / "ncc_assistant" / "gui.py").read_text(encoding="utf-8")
        self.assertIn('addTab(self.templates_page, "Workflows")', gui)
        self.assertIn('addTab(self.schedules_page, "Cron")', gui)
        self.assertNotIn('addTab(self.workflows_page', gui)

    def test_parse_digest_hhmm_still_works(self) -> None:
        from ncc_assistant.morning_brief import parse_digest_hhmm

        self.assertEqual(parse_digest_hhmm("*-*-* 08:30:00"), (8, 30))

    def test_due_respects_enable(self) -> None:
        from ncc_assistant.morning_brief import due_for_brief
        from ncc_assistant.preferences import (
            set_daily_digest_enable,
            set_daily_digest_on_calendar,
            set_morning_brief_last_fired,
        )

        set_daily_digest_enable(False)
        set_daily_digest_on_calendar("*-*-* 08:30:00")
        set_morning_brief_last_fired("")
        tz = ZoneInfo("Europe/Berlin")
        after = datetime(2026, 10, 5, 9, 0, tzinfo=tz)
        self.assertFalse(due_for_brief(now=after))


if __name__ == "__main__":
    unittest.main()
