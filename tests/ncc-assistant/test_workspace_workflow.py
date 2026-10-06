#!/usr/bin/env python3
"""Phase 37 workspace workflow audit/plan (no display)."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class WorkspaceWorkflowTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)
        self.repo = home / "proj"
        self.repo.mkdir()
        (self.repo / ".git").mkdir()
        (self.repo / "README.md").write_text("# hi\n", encoding="utf-8")
        from ncc_assistant.workspaces import upsert_workspace

        upsert_workspace(
            workspace_id="proj",
            path=str(self.repo),
            label="Proj",
        )
        from ncc_assistant.preferences import set_active_workspace_id

        set_active_workspace_id("proj")

    def test_audit_finds_gaps(self) -> None:
        from ncc_assistant.workspace_workflow import audit_workspace

        report = audit_workspace("proj")
        missing = {g.id for g in report.missing}
        self.assertIn("agents-md", missing)
        self.assertIn("skills", missing)
        self.assertIn("impressum", missing)
        self.assertIn("privacy", missing)
        self.assertNotIn("readme", missing)

    def test_plan_uses_gap_links_idempotent(self) -> None:
        from ncc_assistant.workspace_workflow import gap_link, plan_from_audit
        from ncc_assistant.workflows import list_tasks

        r1 = plan_from_audit("proj")
        self.assertTrue(r1["ok"])
        self.assertGreater(len(r1["created_tasks"]), 0)
        for t in r1["created_tasks"]:
            links = [str(x) for x in (t.get("links") or [])]
            self.assertTrue(any(x.startswith("gap:") for x in links), links)
        n1 = len(list_tasks())
        r2 = plan_from_audit("proj")
        self.assertEqual(len(r2["created_tasks"]), 0)
        self.assertEqual(len(list_tasks()), n1)
        # renaming title must not create duplicate gap task
        from ncc_assistant.workflows import update_task

        t0 = r1["created_tasks"][0]
        gap = next(x[4:] for x in t0["links"] if str(x).startswith("gap:"))
        update_task(t0["id"], title="totally different title")
        r3 = plan_from_audit("proj")
        self.assertIn(gap, r3["skipped_gaps"])
        self.assertEqual(gap_link("agents-md"), "gap:agents-md")

    def test_next_prefers_doing(self) -> None:
        from ncc_assistant.workspace_workflow import next_open_task, plan_from_audit
        from ncc_assistant.workflows import update_task

        plan_from_audit("proj")
        nxt = next_open_task("proj")
        assert nxt is not None
        update_task(str(nxt["id"]), status="doing")
        again = next_open_task("proj")
        assert again is not None
        self.assertEqual(again["id"], nxt["id"])
        self.assertEqual(again["status"], "doing")

    def test_templates_exist(self) -> None:
        from ncc_assistant.agent_templates import get_agent_template

        for tid in (
            "workspace-audit",
            "workspace-lifecycle",
            "workspace-archive-suggest",
            "privacy-policy-creator",
            "impressum-creator",
            "autonomous-agent-run",
            "autonomous-agent-ship",
            "changelog-creator",
            "gitignore-creator",
        ):
            tmpl = get_agent_template(tid)
            self.assertIsNotNone(tmpl, tid)
            self.assertEqual(tmpl.id, tid)
        run = get_agent_template("autonomous-agent-run")
        assert run is not None
        self.assertFalse(run.dry_run)
        self.assertEqual(run.profile, "config-writer")
        self.assertIn("task-start", run.goal_template)
        self.assertIn("task-finish", run.goal_template)

    def test_companion_workflow_templates_surface(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("Workflows (once / cron)", text)
        self.assertIn("workspace-brief", text)
        self.assertIn("PANEL_CRON", text)
        self.assertNotIn("steward", text.lower())
        self.assertNotIn("maybe_fire_brief", text)


if __name__ == "__main__":
    unittest.main()
