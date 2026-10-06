#!/usr/bin/env python3
"""Phase 37 workflow execute: per-task start/finish, validate gate, confirm."""

from __future__ import annotations

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


class WorkflowExecuteTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)
        self.repo = home / "proj"
        self.repo.mkdir()
        import subprocess

        subprocess.run(["git", "init"], cwd=self.repo, check=True, capture_output=True)
        subprocess.run(
            ["git", "config", "user.email", "t@example.com"],
            cwd=self.repo,
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test"],
            cwd=self.repo,
            check=True,
            capture_output=True,
        )
        # default branch name for older git
        subprocess.run(
            ["git", "checkout", "-b", "main"],
            cwd=self.repo,
            check=False,
            capture_output=True,
        )
        (self.repo / "README.md").write_text("# hi\n", encoding="utf-8")
        subprocess.run(
            ["git", "add", "README.md"], cwd=self.repo, check=True, capture_output=True
        )
        subprocess.run(
            ["git", "commit", "-m", "init"],
            cwd=self.repo,
            check=True,
            capture_output=True,
        )
        from ncc_assistant.preferences import set_active_workspace_id
        from ncc_assistant.workspaces import upsert_workspace

        upsert_workspace(workspace_id="proj", path=str(self.repo), label="Proj")
        set_active_workspace_id("proj")

    def test_ensure_branch_task_slug(self) -> None:
        from ncc_assistant.workflow_execute import ensure_branch

        r = ensure_branch("proj", prefix="agents-md", task_id="abc123dead")
        self.assertTrue(r["ok"])
        self.assertTrue(str(r["branch"]).startswith("ncc/workflow-agents-md-"))
        self.assertIn("abc123dead", str(r["branch"]))

    def test_task_start_marks_doing_and_progress(self) -> None:
        from ncc_assistant.workspace_workflow import plan_from_audit
        from ncc_assistant.workflow_execute import load_progress, task_start
        from ncc_assistant.workflows import get_task

        plan = plan_from_audit("proj")
        tid = plan["created_tasks"][0]["id"]
        r = task_start("proj", task_id=tid)
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["task_id"], tid)
        self.assertTrue(str(r["branch"]).startswith("ncc/workflow-"))
        task = get_task(tid)
        assert task is not None
        self.assertEqual(task["status"], "doing")
        prog = load_progress("proj")
        self.assertEqual(prog["current_task_id"], tid)
        self.assertEqual(prog["current_branch"], r["branch"])

    def test_task_finish_refuses_on_validate_fail(self) -> None:
        from ncc_assistant.workspace_workflow import plan_from_audit
        from ncc_assistant.workflow_execute import task_finish, task_start

        plan = plan_from_audit("proj")
        tid = plan["created_tasks"][0]["id"]
        self.assertTrue(task_start("proj", task_id=tid)["ok"])
        # Drop a broken validate script so validate fails hard
        gates = self.repo / "tests"
        gates.mkdir(exist_ok=True)
        (gates / "run-gates.sh").write_text("#!/bin/bash\nexit 1\n", encoding="utf-8")
        os.chmod(gates / "run-gates.sh", 0o755)
        r = task_finish("proj", task_id=tid, message="should fail")
        self.assertFalse(r["ok"])
        self.assertEqual(r.get("error"), "validate_failed")

    def test_merge_requires_confirm(self) -> None:
        from ncc_assistant.workflow_execute import merge_pull_request

        r = merge_pull_request("proj", confirm="nope")
        self.assertFalse(r["ok"])
        self.assertEqual(r.get("error"), "confirm_required")

    def test_bump_requires_confirm(self) -> None:
        from ncc_assistant.workflow_execute import bump_version

        r = bump_version("proj", confirm="")
        self.assertFalse(r["ok"])
        self.assertEqual(r.get("error"), "confirm_required")

    def test_bump_package_json(self) -> None:
        from ncc_assistant.workflow_execute import bump_version, ensure_branch

        ensure_branch("proj", prefix="bump", allow_dirty=True)
        (self.repo / "package.json").write_text(
            json.dumps({"name": "x", "version": "1.2.3"}, indent=2) + "\n",
            encoding="utf-8",
        )
        r = bump_version("proj", confirm="CONFIRM", part="patch")
        self.assertTrue(r["ok"])
        self.assertEqual(r["version"], "1.2.4")
        data = json.loads((self.repo / "package.json").read_text(encoding="utf-8"))
        self.assertEqual(data["version"], "1.2.4")

    def test_resume_status(self) -> None:
        from ncc_assistant.workspace_workflow import plan_from_audit
        from ncc_assistant.workflow_execute import resume_status, task_start

        plan_from_audit("proj")
        before = resume_status("proj")
        self.assertTrue(before["ok"])
        self.assertIsNotNone(before.get("next"))
        tid = before["next"]["id"]
        task_start("proj", task_id=tid)
        after = resume_status("proj")
        self.assertEqual(after["current_task"]["id"], tid)
        self.assertIn("task-start", after["hint"])

    def test_templates(self) -> None:
        from ncc_assistant.agent_templates import get_agent_template

        ex = get_agent_template("autonomous-agent-run")
        ship = get_agent_template("autonomous-agent-ship")
        self.assertIsNotNone(ex)
        self.assertIsNotNone(ship)
        assert ex is not None and ship is not None
        self.assertFalse(ex.dry_run)
        self.assertEqual(ex.profile, "config-writer")
        self.assertEqual(ship.profile, "ops")
        confirm = next(p for p in ship.params if p.id == "confirm")
        self.assertIn("CONFIRM", confirm.options)
        max_tasks = next(p for p in ex.params if p.id == "maxTasks")
        self.assertIn("2", max_tasks.options)

    def test_companion_exposes_workflow_templates(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("Workflows", text)
        self.assertIn('("template", t.id)', text)


if __name__ == "__main__":
    unittest.main()
