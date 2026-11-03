"""GitHub Agent autonomy v1 — campaign arm/tick/resume + policy.

Behaviour under test: ``arm_campaign`` / ``tick_campaign`` / ``pause_campaign``
/ ``resume_campaign`` persist ``campaign.json`` and apply docs stubs only when
policy allows; denylist and dirty worktrees skip. Module:
``core.workflows.github_agent_act`` (+ policy/stubs/campaign store).

Existing tests: ``test_github_agent_v1.py`` (analyze/snapshot only) — none for
multi-day campaign resume.

User: "kk den kompletten plan machen und dann implemen tieren , das der agent
dann auch autonmm mehre tage läuft , falls disconnected ausgeht er wieder
angeht vllt sogar da weitermacht etc"
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2] / "nixos/modules/specialized/ncc-assistant"


class GithubAgentAutonomyV1Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory(prefix="ncc-assistant-tests-")
        self._prev_xdg = os.environ.get("XDG_CONFIG_HOME")
        self.addCleanup(self._restore_xdg)
        self.addCleanup(self._td.cleanup)
        os.environ["XDG_CONFIG_HOME"] = self._td.name
        self._repo = Path(self._td.name) / "repos" / "demo"
        self._repo.mkdir(parents=True)
        subprocess.run(["git", "init"], cwd=self._repo, check=True, capture_output=True)
        subprocess.run(
            ["git", "config", "user.email", "t@example.com"],
            cwd=self._repo,
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "t"],
            cwd=self._repo,
            check=True,
            capture_output=True,
        )
        (self._repo / "README.md").write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=self._repo, check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "init"],
            cwd=self._repo,
            check=True,
            capture_output=True,
        )

        from core.store.workspaces import upsert_workspace

        upsert_workspace("demo", str(self._repo), label="demo")

    def _restore_xdg(self) -> None:
        if self._prev_xdg is None:
            os.environ.pop("XDG_CONFIG_HOME", None)
        else:
            os.environ["XDG_CONFIG_HOME"] = self._prev_xdg

    def _snap(self) -> dict:
        return {
            "jobId": "j-test",
            "projects": [
                {
                    "workspaceId": "demo",
                    "path": str(self._repo),
                    "state": "active",
                    "gaps": [
                        {"id": "agents-md", "present": False, "priority": "p0"},
                        {"id": "impressum", "present": False, "priority": "p0"},
                        {"id": "privacy", "present": False, "priority": "p0"},
                    ],
                    "nextTask": None,
                    "driftFlags": [],
                }
            ],
        }

    def test_policy_blocks_without_allow_write(self) -> None:
        from core.store.preferences import set_github_agent_allow_write
        from core.workflows.github_agent_policy import evaluate_write

        set_github_agent_allow_write(False)
        v = evaluate_write(
            workspace_id="demo",
            gap_id="agents-md",
            root=self._repo,
            state="active",
            unattended=True,
        )
        self.assertFalse(v["ok"])
        self.assertEqual(v["reason"], "allowWrite_false")

    def test_denylist_and_dirty_skip(self) -> None:
        from core.store.preferences import (
            set_github_agent_allow_write,
            set_github_agent_confirm,
            set_github_agent_denylist,
            set_github_agent_dirty_policy,
        )
        from core.workflows.github_agent_policy import evaluate_write

        set_github_agent_allow_write(True)
        set_github_agent_confirm("writes")
        set_github_agent_denylist(["demo"])
        v = evaluate_write(
            workspace_id="demo",
            gap_id="agents-md",
            root=self._repo,
            state="active",
        )
        self.assertEqual(v["reason"], "denylist")
        set_github_agent_denylist([])
        (self._repo / "dirty.txt").write_text("x", encoding="utf-8")
        set_github_agent_dirty_policy("skip")
        v2 = evaluate_write(
            workspace_id="demo",
            gap_id="agents-md",
            root=self._repo,
            state="active",
        )
        self.assertEqual(v2["reason"], "dirty_skip")

    def test_arm_tick_resume_across_reload(self) -> None:
        from core.store.github_agent_campaign import load_github_agent_campaign
        from core.store.preferences import (
            set_github_agent_allow_write,
            set_github_agent_confirm,
            set_github_agent_max_per_tick,
        )
        from core.workflows.github_agent_act import (
            arm_campaign,
            pause_campaign,
            resume_campaign,
            tick_campaign,
        )

        set_github_agent_allow_write(True)
        set_github_agent_confirm("writes")
        set_github_agent_max_per_tick(1)

        armed = arm_campaign(snapshot=self._snap())
        self.assertTrue(armed["ok"])
        self.assertGreaterEqual(armed["queued"], 3)
        self.assertEqual(armed["campaign"]["status"], "running")

        t1 = tick_campaign(max_items=1, unattended=True)
        self.assertTrue(t1["ok"])
        self.assertEqual(len(t1["applied"]), 1)
        self.assertTrue((self._repo / "AGENTS.md").is_file())

        # Stub write dirties the tree; commit so the next tick can apply (dirty=skip).
        subprocess.run(["git", "add", "-A"], cwd=self._repo, check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "agents stub"],
            cwd=self._repo,
            check=True,
            capture_output=True,
        )

        pause_campaign()
        camp = load_github_agent_campaign()
        self.assertEqual(camp["status"], "paused")
        left = len(camp["queue"])
        self.assertGreater(left, 0)

        resume_campaign()
        t2 = tick_campaign(max_items=1, unattended=True)
        self.assertTrue(t2["ok"])
        self.assertEqual(len(t2["applied"]), 1)
        camp2 = load_github_agent_campaign()
        self.assertEqual(len(camp2["queue"]), left - 1)

    def test_plan_and_surface_strings(self) -> None:
        plan = (ROOT / "doc" / "plans" / "41-github-agent-autonomy.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("campaign.json", plan)
        self.assertIn("act-safe", plan)
        text = (ROOT / "companion" / "window.py").read_text(encoding="utf-8")
        self.assertIn("_github_agent_act", text)
        self.assertIn("Act wave", text)


if __name__ == "__main__":
    unittest.main()
