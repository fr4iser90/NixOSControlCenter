#!/usr/bin/env python3
"""Schedule frequency enums → OnCalendar + template Run-once wiring."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.schedule_freq import (  # noqa: E402
    SCHEDULE_MODES,
    cron_fields_to_on_calendar,
    describe_schedule_human,
    normalize_on_calendar,
    parse_stored_frequency,
    system_local_tz_label,
)


class ScheduleFreqTests(unittest.TestCase):
    def test_modes_are_enums(self) -> None:
        ids = [m[0] for m in SCHEDULE_MODES]
        self.assertEqual(
            ids, ["simple", "daily-at", "weekly-at", "cron", "advanced"]
        )

    def test_daily_at(self) -> None:
        self.assertEqual(
            normalize_on_calendar("daily-at", hour=3, minute=15),
            "*-*-* 03:15:00",
        )

    def test_monday_830(self) -> None:
        cal = normalize_on_calendar("weekly-at", hour=8, minute=30, weekday="Mon")
        self.assertEqual(cal, "Mon *-*-* 08:30:00")
        self.assertEqual(describe_schedule_human(cal), "Every Monday at 08:30")
        self.assertTrue(system_local_tz_label())

    def test_cron_daily(self) -> None:
        self.assertEqual(
            cron_fields_to_on_calendar("15", "3", "*", "*", "*"),
            "*-*-* 03:15:00",
        )

    def test_cron_monday_830(self) -> None:
        cal = cron_fields_to_on_calendar("30", "8", "*", "*", "1")
        self.assertEqual(cal, "Mon *-*-* 08:30:00")
        self.assertIn("Monday", describe_schedule_human(cal))

    def test_cron_weekdays(self) -> None:
        self.assertEqual(
            cron_fields_to_on_calendar("0", "9", "*", "*", "1-5"),
            "Mon..Fri *-*-* 09:00:00",
        )

    def test_cron_hourly(self) -> None:
        self.assertEqual(cron_fields_to_on_calendar("0", "*", "*", "*", "*"), "hourly")

    def test_parse_roundtrip_daily(self) -> None:
        p = parse_stored_frequency("*-*-* 03:15:00")
        self.assertEqual(p["mode"], "daily-at")
        self.assertEqual(p["hour"], 3)
        self.assertEqual(p["minute"], 15)

    def test_parse_simple(self) -> None:
        p = parse_stored_frequency("daily")
        self.assertEqual(p["mode"], "simple")
        self.assertEqual(p["preset"], "daily")


class TemplatesUiAstTests(unittest.TestCase):
    def test_run_once_and_modes(self) -> None:
        text = (ROOT / "ncc_assistant" / "templates_ui.py").read_text(encoding="utf-8")
        self.assertIn("run_once_mode", text)
        self.assertIn('"Run once"', text)
        self.assertIn("run_once = Signal", text)
        self.assertIn("SCHEDULE_MODES", text)
        self.assertIn("cron_row", text)
        self.assertIn("_run_once_configure", text)

    def test_schedules_use_picker(self) -> None:
        text = (ROOT / "ncc_assistant" / "gui_pages.py").read_text(encoding="utf-8")
        self.assertIn("FrequencyPicker", text)
        self.assertIn("cal_picker", text)
        self.assertNotIn("self.cal_edit", text)


if __name__ == "__main__":
    unittest.main()
