#!/usr/bin/env python3
"""Phase 34 ops cockpit: capacity, idle, workflows, templates (no display)."""

from __future__ import annotations

import ast
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class CapacityTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)
        # Reset prefs
        from ncc_assistant.preferences import save_preferences

        save_preferences({"max_concurrency": 2})

    def test_acquire_release(self) -> None:
        from ncc_assistant.capacity import active_count, release, try_acquire

        t1 = try_acquire("a")
        t2 = try_acquire("b")
        self.assertIsNotNone(t1)
        self.assertIsNotNone(t2)
        self.assertEqual(active_count(), 2)
        self.assertIsNone(try_acquire("c"))
        release(t1)
        self.assertEqual(active_count(), 1)
        t3 = try_acquire("c")
        self.assertIsNotNone(t3)
        release(t2)
        release(t3)


class IdleTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)

    def test_idle_eligibility_off_by_default(self) -> None:
        from ncc_assistant.idle import is_idle_eligible, touch_activity
        from ncc_assistant.preferences import set_idle_mode

        set_idle_mode("off")
        touch_activity("test")
        self.assertFalse(is_idle_eligible())

    def test_idle_eligibility_after_minutes(self) -> None:
        import time

        from ncc_assistant.idle import is_idle_eligible, touch_activity
        from ncc_assistant.paths import activity_file
        from ncc_assistant.preferences import set_idle_after_min, set_idle_mode

        set_idle_mode("schedules")
        set_idle_after_min(5)
        # Fake old activity
        activity_file().parent.mkdir(parents=True, exist_ok=True)
        activity_file().write_text(
            json.dumps({"ts": time.time() - 600, "reason": "old"}) + "\n",
            encoding="utf-8",
        )
        with mock.patch("ncc_assistant.idle.get_presence", create=True):
            # presence import is inside is_idle_eligible
            pass
        # Mock presence paused → not eligible
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="available"),
        ):
            self.assertTrue(is_idle_eligible())
        with mock.patch(
            "ncc_assistant.presence.get_presence",
            return_value=mock.Mock(state="paused"),
        ):
            self.assertFalse(is_idle_eligible())


class WorkflowsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)

    def test_digest_shape_and_tasks(self) -> None:
        from ncc_assistant.workflows import (
            add_roadmap_item,
            add_task,
            load_daily,
            save_daily,
        )

        data = load_daily()
        self.assertEqual(data["version"], 1)
        self.assertIn("issues", data)
        self.assertIn("pullRequests", data)
        self.assertIn("tasks", data)
        self.assertIn("roadmap", data)
        t = add_task("Ship phase 34", priority="p0")
        self.assertEqual(t["status"], "todo")
        self.assertEqual(t["priority"], "p0")
        r = add_roadmap_item("Ops cockpit", horizon="now")
        self.assertEqual(r["horizon"], "now")
        again = load_daily()
        self.assertEqual(len(again["tasks"]), 1)
        self.assertEqual(len(again["roadmap"]), 1)
        save_daily(again)
        digest = Path(os.environ["XDG_CONFIG_HOME"]) / "ncc-assistant" / "workflows" / "daily.json"
        self.assertTrue(digest.is_file())


class TemplateAstTests(unittest.TestCase):
    EXPECTED = {
        "roadmap-creator",
        "design-concept-creator",
        "task-breakdown",
        "impressum-creator",
        "precommit-creator",
        "githooks-creator",
        "agents-md-creator",
        "skill-pack-creator",
        "editorconfig-creator",
        "license-chooser",
    }

    def test_creator_rulebook_ids_present(self) -> None:
        agents = ROOT / "ncc_assistant" / "templates" / "agents"
        ids = {p.stem for p in agents.glob("*.json")}
        missing = self.EXPECTED - ids
        self.assertFalse(missing, f"missing templates: {missing}")

    def test_settings_and_workflows_ui(self) -> None:
        gui_pages = (ROOT / "ncc_assistant" / "gui_pages.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("4d · Capacity & idle", gui_pages)
        self.assertIn("4e · Daily workflows", gui_pages)
        self.assertIn("class WorkflowsPage", gui_pages)
        companion = (ROOT / "ncc_assistant" / "companion.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("PANEL_DAILY", companion)
        self.assertIn("_idle_tick", companion)
        capacity = ROOT / "ncc_assistant" / "capacity.py"
        tree = ast.parse(capacity.read_text(encoding="utf-8"))
        names = {
            n.name
            for n in tree.body
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
        }
        self.assertIn("try_acquire", names)
        self.assertIn("release", names)
        self.assertIn("active_count", names)


if __name__ == "__main__":
    unittest.main()
