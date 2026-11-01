#!/usr/bin/env python3
"""GitHub Agent v1 — orchestrator + snapshot (no Qt, no network).

Behaviour under test: ``run_github_agent`` extracts gaps/tasks, DE elevates
privacy/impressum to p0, archive-candidate skips plan_from_audit, snapshot
written under temp XDG. Module: ``core.workflows.github_agent``.

Existing tests: none for GitHub Agent (related: test_workspace_workflow.py,
test_workspace_lifecycle.py, test_portfolio_drift_v1.py).

User: ``tests/ncc-assistant/test_github_agent_v1.py`` — temp XDG, fake git
repos, run_github_agent extracts gaps/tasks, DE elevates privacy, archive
skipped for plan, snapshot written. No Qt. No network.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))


def _init_git_repo(path: Path, *, readme: str = "# hi\n") -> None:
    path.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init"], cwd=path, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "t@example.com"],
        cwd=path,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=path,
        check=True,
        capture_output=True,
    )
    (path / "README.md").write_text(readme, encoding="utf-8")
    subprocess.run(["git", "add", "README.md"], cwd=path, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=path,
        check=True,
        capture_output=True,
    )


class GithubAgentV1Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        home = Path(self._td.name)
        self._patch = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(home)})
        self._patch.start()
        self.addCleanup(self._patch.stop)

        self.active = home / "active-proj"
        self.archive = home / "old-proj"
        _init_git_repo(self.active)
        _init_git_repo(self.archive, readme="# old\n")

        from core.store.preferences import set_active_workspace_id
        from core.store.workspaces import upsert_workspace

        upsert_workspace(workspace_id="active", path=str(self.active), label="Active")
        upsert_workspace(workspace_id="old", path=str(self.archive), label="Old")
        set_active_workspace_id("active")

        from core.store.operator_facts import set_operator_country

        set_operator_country("DE")

    def _fleet_with_archive(self) -> dict:
        return {
            "ok": True,
            "count": 2,
            "workspaces": [
                {
                    "ok": True,
                    "workspace_id": "active",
                    "label": "Active",
                    "state": "active",
                    "path": str(self.active),
                },
                {
                    "ok": True,
                    "workspace_id": "old",
                    "label": "Old",
                    "state": "archive-candidate",
                    "path": str(self.archive),
                },
            ],
            "active": [{"id": "active", "label": "Active"}],
            "archive_candidates": [{"id": "old", "label": "Old"}],
            "later": [],
            "once": [],
            "by_state": {"active": ["active"], "archive-candidate": ["old"]},
        }

    def test_run_extracts_gaps_tasks_and_snapshot(self) -> None:
        from core.store.github_agent_snapshot import load_github_agent_snapshot
        from core.store.paths import github_agent_snapshot_file
        from core.workflows.github_agent import run_github_agent
        from core.workflows.workflows import list_tasks

        self.assertTrue(str(github_agent_snapshot_file()).startswith(self._td.name))

        with mock.patch(
            "core.workflows.github_agent.fleet_lifecycle",
            return_value=self._fleet_with_archive(),
        ), mock.patch(
            "core.workflows.github_agent.portfolio_drift_report",
            return_value={
                "ok": True,
                "root": str(Path(self._td.name)),
                "projects": [],
                "registered_but_missing": [],
                "counts": {},
                "github": {"checked": False, "reason": "test"},
                "summary": "test",
            },
        ):
            result = run_github_agent(extract_tasks=True, include_archived=False)

        self.assertTrue(result["ok"], result.get("errors"))
        self.assertTrue(result.get("job_id"))
        snap = result["snapshot"]
        self.assertEqual(snap["version"], 1)
        self.assertEqual(snap["operatorFacts"]["country"], "DE")
        by_id = {p["workspaceId"]: p for p in snap["projects"]}
        self.assertIn("active", by_id)
        self.assertIn("old", by_id)

        active = by_id["active"]
        missing = [g for g in active["gaps"] if not g["present"]]
        self.assertGreater(len(missing), 0)
        privacy = next(g for g in active["gaps"] if g["id"] == "privacy")
        impressum = next(g for g in active["gaps"] if g["id"] == "impressum")
        self.assertFalse(privacy["present"])
        self.assertEqual(privacy["priority"], "p0")
        self.assertEqual(impressum["priority"], "p0")
        self.assertTrue(active.get("planned"))
        self.assertIsNotNone(active.get("nextTask"))

        old = by_id["old"]
        self.assertEqual(old["state"], "archive-candidate")
        self.assertTrue(old.get("archiveSkippedPlan"))
        self.assertFalse(old.get("planned"))

        tasks = list_tasks()
        active_gap_tasks = [
            t
            for t in tasks
            if t.get("workspaceId") == "active"
            and any(str(x).startswith("gap:") for x in (t.get("links") or []))
        ]
        self.assertGreater(len(active_gap_tasks), 0)
        old_gap_tasks = [
            t
            for t in tasks
            if t.get("workspaceId") == "old"
            and any(str(x).startswith("gap:") for x in (t.get("links") or []))
        ]
        self.assertEqual(len(old_gap_tasks), 0)

        loaded = load_github_agent_snapshot()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded["jobId"], result["job_id"])
        self.assertTrue(github_agent_snapshot_file().is_file())

    def test_us_does_not_elevate_legal_gaps(self) -> None:
        from core.store.operator_facts import set_operator_country
        from core.workflows.github_agent import run_github_agent

        set_operator_country("US")
        with mock.patch(
            "core.workflows.github_agent.fleet_lifecycle",
            return_value=self._fleet_with_archive(),
        ), mock.patch(
            "core.workflows.github_agent.portfolio_drift_report",
            return_value={
                "ok": True,
                "root": str(Path(self._td.name)),
                "projects": [],
                "registered_but_missing": [],
                "counts": {},
                "github": {"checked": False, "reason": "test"},
                "summary": "test",
            },
        ):
            result = run_github_agent(extract_tasks=False, include_archived=False)

        by_id = {p["workspaceId"]: p for p in result["snapshot"]["projects"]}
        privacy = next(g for g in by_id["active"]["gaps"] if g["id"] == "privacy")
        self.assertEqual(privacy["priority"], "p1")

    def test_format_github_agent_chat_brief(self) -> None:
        # Behaviour: compact chat brief from snapshot for Companion Start.
        # Module: core.workflows.github_agent.format_github_agent_chat_brief.
        # Existing: this file (test_github_agent_v1). User: "korregiere das !??!!?
        # es muss dann chat session öffnen und er muss arbeiten!?!?"
        from core.workflows.github_agent import format_github_agent_chat_brief

        brief = format_github_agent_chat_brief(
            {
                "jobId": "j1",
                "operatorFacts": {"country": "DE", "locale": "de_DE"},
                "projects": [
                    {
                        "workspaceId": "demo",
                        "state": "active",
                        "gaps": [
                            {"id": "privacy", "present": False, "priority": "p0"}
                        ],
                        "nextTask": {"title": "Add privacy"},
                        "driftFlags": [],
                    }
                ],
                "drift": {"counts": {"ok": 1}},
            }
        )
        self.assertIn("job j1", brief)
        self.assertIn("demo", brief)
        self.assertIn("privacy:p0", brief)
        self.assertIn("country=DE", brief)
        self.assertEqual(format_github_agent_chat_brief(None), "GitHub Agent: no snapshot.")

    def test_catalog_and_companion_surface(self) -> None:
        # Behaviour: catalog + Start opens chat (PANEL_NONE) + LLM worker.
        # Module: companion/window.py + data/agents/github-agent.json.
        # Existing: this file. User: "korregiere das !??!!? es muss dann chat
        # session öffnen und er muss arbeiten!?!?"
        from core.catalogs.agent_templates import get_agent_template

        tmpl = get_agent_template("github-agent")
        self.assertIsNotNone(tmpl)
        assert tmpl is not None
        self.assertEqual(tmpl.title, "GitHub Agent")
        self.assertEqual(tmpl.category, "GitHub")
        self.assertEqual(tmpl.profile, "read-only")
        self.assertIn("github", tmpl.mcp)
        self.assertIn("github_token", tmpl.requires_secrets)
        self.assertIn("idle-ok", tmpl.tags)

        text = (ROOT / "companion" / "window.py").read_text(encoding="utf-8")
        self.assertIn("PANEL_GITHUB", text)
        self.assertIn("GitHub Agent — board + Start", text)
        self.assertNotIn("Portfolio Agent", text)
        # Start must leave the board and drive a chat slot (analyze + LLM).
        self.assertIn("def _github_agent_analyze(self)", text)
        analyze = text.split("def _github_agent_analyze(self)", 1)[1].split(
            "def _github_agent_rights_dialog", 1
        )[0]
        self.assertIn("self._toggle_panel(PANEL_NONE)", analyze)
        self.assertIn("slot.busy = True", analyze)
        self.assertIn("_CompanionGithubAgentWorker", analyze)
        self.assertIn("worker.event.connect(self._on_event)", analyze)
        worker = text.split("class _CompanionGithubAgentWorker", 1)[1].split(
            "class _CompanionTemplateWorker", 1
        )[0]
        self.assertIn("format_github_agent_chat_brief", worker)
        self.assertIn("run_agent", worker)
        self.assertIn("github_agent_analyze", worker)
        self.assertIn('"text": brief', worker)

        plan = (ROOT / "doc" / "plans" / "40-github-agent.md").read_text(encoding="utf-8")
        self.assertIn("GitHub Agent", plan)
        self.assertRegex(plan, r"(?i)\*\*Status:\s*done\.\*\*")
        self.assertIn("opens chat session", plan)
        self.assertNotIn("Portfolio Agent", plan.split("not")[0])  # title never Portfolio


if __name__ == "__main__":
    unittest.main()
