#!/usr/bin/env python3
"""Phase 28: secrets, workspaces, MCP placeholders, agent templates."""

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant import agent_templates as at  # noqa: E402
from ncc_assistant import marketplace as mp  # noqa: E402
from ncc_assistant import schedule_freq as sf  # noqa: E402
from ncc_assistant import secrets as secrets_mod  # noqa: E402
from ncc_assistant import workspaces as ws_mod  # noqa: E402


class Phase28Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.cfg = Path(self._tmp.name)
        self.env_patch = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.cfg)})
        self.env_patch.start()

    def tearDown(self) -> None:
        self.env_patch.stop()
        self._tmp.cleanup()

    def test_secret_roundtrip_chmod(self) -> None:
        meta = secrets_mod.set_secret("github_token", "s3cret-value", label="GitHub PAT")
        self.assertEqual(meta.name, "github_token")
        self.assertTrue(secrets_mod.has_secret("github_token"))
        self.assertEqual(secrets_mod.get_secret_value("github_token"), "s3cret-value")
        public = [s.to_public_dict() for s in secrets_mod.list_secrets()]
        self.assertEqual(public[0]["name"], "github_token")
        self.assertNotIn("s3cret", json.dumps(public))
        mode = (self.cfg / "ncc-assistant" / "secrets.json").stat().st_mode & 0o777
        self.assertEqual(mode, 0o600)

    def test_workspace_upsert(self) -> None:
        path = self.cfg / "repo"
        path.mkdir()
        (path / ".git").mkdir()
        ws = ws_mod.upsert_workspace("ncc", str(path), label="NCC", github="me/NCC")
        self.assertEqual(ws.id, "ncc")
        self.assertEqual(ws_mod.get_workspace("ncc").path, str(path.resolve()))

    def test_import_from_parent_scans_children(self) -> None:
        parent = self.cfg / "Git"
        parent.mkdir()
        a = parent / "NixOSControlCenter"
        b = parent / "other"
        a.mkdir()
        b.mkdir()
        (a / ".git").mkdir()
        (b / ".git").mkdir()
        (parent / "not-a-repo").mkdir()
        imported = ws_mod.import_from_parent(parent, detect_github=False)
        ids = {w.id for w in imported}
        self.assertIn("NixOSControlCenter", ids)
        self.assertIn("other", ids)
        self.assertEqual(len(imported), 2)

    def test_mcp_placeholder_expansion(self) -> None:
        path = self.cfg / "repo"
        path.mkdir()
        ws_mod.upsert_workspace("ncc", str(path))
        secrets_mod.set_secret("github_token", "tok")
        # Expand only — install writes mcp-servers.json
        ctx = mp.build_placeholder_context(workspace_id="ncc")
        self.assertEqual(ctx["workspace.path"], str(path.resolve()))
        expanded = mp.expand_placeholders("--repository {{workspace.path}}", ctx)
        self.assertIn(str(path.resolve()), expanded)

        result = mp.install_template("git", workspace_id="ncc")
        self.assertTrue(result["ok"], result)
        self.assertIn(str(path.resolve()), result["entry"]["args"])

        gh = mp.install_template("github")
        self.assertTrue(gh["ok"], gh)
        self.assertIn("GITHUB_PERSONAL_ACCESS_TOKEN", gh["entry"]["env_keys"])

    def test_agent_templates_load_and_badges(self) -> None:
        templates = at.list_agent_templates()
        ids = {t.id for t in templates}
        self.assertIn("agents-md-maintainer", ids)
        self.assertIn("github-code-review", ids)
        self.assertIn("skills-maintainer", ids)
        gh = at.get_agent_template("github-code-review")
        assert gh is not None
        badges = at.template_badges(gh)
        labels = " ".join(b["label"] for b in badges)
        self.assertIn("Secret missing", labels)

    def test_instantiate_requires_workspace(self) -> None:
        result = at.instantiate(
            "agents-md-maintainer",
            {"checkFrequency": "weekly", "timezone": "Europe/Berlin", "repositories": ["missing"]},
        )
        self.assertFalse(result["ok"])

        path = self.cfg / "repo"
        path.mkdir()
        ws_mod.upsert_workspace("ncc", str(path))
        result = at.instantiate(
            "agents-md-maintainer",
            {
                "checkFrequency": "weekly",
                "timezone": "Europe/Berlin",
                "repositories": ["ncc"],
            },
            instance_id="test-agents",
            enable_schedule=True,
        )
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["playbook"], "tmpl-test-agents")
        self.assertEqual(result["schedule"], "tmpl-test-agents")
        goal = result["goal"]
        self.assertIn(str(path.resolve()), goal)
        self.assertIn("AGENTS.md", goal)
        # Secret values must never appear in goals
        secrets_mod.set_secret("github_token", "NEVER_LEAK_TOKEN")
        gh_path = self.cfg / "repo2"
        gh_path.mkdir()
        ws_mod.upsert_workspace("r2", str(gh_path), github="me/r2")
        gh_res = at.instantiate(
            "github-code-review",
            {
                "checkFrequency": "hourly",
                "timezone": "UTC",
                "repositories": ["r2"],
                "triggerLabel": "needs-review",
                "requestedReviewer": "alice",
                "reviewTone": "brief",
                "maintainers": ["bob", "carol"],
                "githubTokenSecret": "github_token",
            },
            instance_id="gh-rev",
        )
        self.assertTrue(gh_res["ok"], gh_res)
        self.assertNotIn("NEVER_LEAK_TOKEN", gh_res["goal"])

    def test_skill_load(self) -> None:
        text = at.load_skill_text("skills/agents-md-maintainer.md")
        self.assertIn("AGENTS.md", text)

    def test_instance_stores_provider_model(self) -> None:
        path = self.cfg / "repo"
        path.mkdir()
        (path / ".git").mkdir()
        ws_mod.upsert_workspace("ncc", str(path))
        result = at.instantiate(
            "local-git-status",
            {
                "checkFrequency": "daily",
                "timezone": "UTC",
                "repositories": ["ncc"],
            },
            instance_id="llm-bind",
            provider_id="my-provider",
            model="coder",
        )
        self.assertTrue(result["ok"], result)
        inst = at.get_instance("llm-bind")
        assert inst is not None
        self.assertEqual(inst.provider_id, "my-provider")
        self.assertEqual(inst.model, "coder")
        # Edit
        result2 = at.instantiate(
            "local-git-status",
            {
                "checkFrequency": "hourly",
                "timezone": "UTC",
                "repositories": ["ncc"],
            },
            instance_id="llm-bind",
            provider_id="other",
            model="chat",
            update_existing=True,
        )
        self.assertTrue(result2["ok"], result2)
        inst2 = at.get_instance("llm-bind")
        assert inst2 is not None
        self.assertEqual(inst2.provider_id, "other")
        self.assertEqual(inst2.model, "chat")
        self.assertEqual(inst2.params.get("checkFrequency"), "hourly")

    def test_normalize_on_calendar(self) -> None:
        self.assertEqual(sf.normalize_on_calendar("hourly"), "hourly")
        self.assertEqual(sf.normalize_on_calendar("every-15m"), "*:0/15")
        self.assertEqual(
            sf.normalize_on_calendar("daily-at", hour=3, minute=15),
            "*-*-* 03:15:00",
        )
        self.assertEqual(
            sf.normalize_on_calendar("weekly-at", hour=4, minute=0, weekday="Sun"),
            "Sun *-*-* 04:00:00",
        )
        self.assertEqual(
            sf.normalize_on_calendar("15 3 * * *"),
            "*-*-* 03:15:00",
        )
        self.assertEqual(sf.normalize_on_calendar("*-*-* 02:45:00"), "*-*-* 02:45:00")


if __name__ == "__main__":
    unittest.main()
