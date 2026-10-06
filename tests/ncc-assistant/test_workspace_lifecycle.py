#!/usr/bin/env python3
"""Workspace lifecycle + fleet archive classification."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class WorkspaceLifecycleTests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)
        self.repo = home / "proj"
        self.repo.mkdir()
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

    def test_fresh_repo_is_active(self) -> None:
        from ncc_assistant.workspace_lifecycle import lifecycle_report

        r = lifecycle_report("proj")
        self.assertEqual(r["state"], "active")
        self.assertTrue(r["ok"])

    def test_classify_archive(self) -> None:
        from ncc_assistant.workspace_lifecycle import classify_lifecycle

        state, reasons = classify_lifecycle(
            git={
                "is_git": True,
                "dirty": False,
                "last_commit_days": 200,
                "open_prs": 0,
                "stale_local_branches": 1,
            },
            open_tasks=[],
            archive_days=180,
        )
        self.assertEqual(state, "archive-candidate")
        self.assertTrue(reasons)

    def test_classify_later_with_todos(self) -> None:
        from ncc_assistant.workspace_lifecycle import classify_lifecycle

        state, _ = classify_lifecycle(
            git={
                "is_git": True,
                "dirty": False,
                "last_commit_days": 40,
                "open_prs": 0,
            },
            open_tasks=[{"status": "todo", "title": "x"}],
            active_days=14,
        )
        self.assertEqual(state, "later")

    def test_classify_once(self) -> None:
        from ncc_assistant.workspace_lifecycle import classify_lifecycle

        state, _ = classify_lifecycle(
            git={
                "is_git": True,
                "dirty": False,
                "last_commit_days": 100,
                "open_prs": 0,
            },
            open_tasks=[],
            once_days=90,
            archive_days=180,
        )
        self.assertEqual(state, "once")

    def test_fleet_lists_workspace(self) -> None:
        from ncc_assistant.workspace_lifecycle import fleet_lifecycle

        f = fleet_lifecycle()
        self.assertEqual(f["count"], 1)
        self.assertTrue(any(r["workspace_id"] == "proj" for r in f["workspaces"]))

    def test_new_templates_exist(self) -> None:
        from ncc_assistant.agent_templates import get_agent_template

        for tid in (
            "workspace-lifecycle",
            "workspace-archive-suggest",
            "changelog-creator",
            "contributing-creator",
            "security-md-creator",
            "gitignore-creator",
            "github-actions-creator",
            "codeowners-creator",
        ):
            tmpl = get_agent_template(tid)
            self.assertIsNotNone(tmpl, tid)
            self.assertEqual(tmpl.schedule_kind, "once")

    def test_audit_sees_new_gaps(self) -> None:
        from ncc_assistant.workspace_workflow import audit_workspace

        missing = {g.id for g in audit_workspace("proj").missing}
        self.assertIn("changelog", missing)
        self.assertIn("gitignore", missing)
        self.assertIn("github-actions", missing)

    def test_lifecycle_templates_exist(self) -> None:
        from ncc_assistant.agent_templates import get_agent_template

        self.assertIsNotNone(get_agent_template("workspace-lifecycle"))
        self.assertIsNotNone(get_agent_template("workspace-archive-suggest"))
        self.assertIsNotNone(get_agent_template("workspace-brief"))


if __name__ == "__main__":
    unittest.main()
