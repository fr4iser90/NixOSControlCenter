"""Witnesses for workflow run-readiness (assess + remediate, Qt-free).

Module under test: ``core.catalogs.workflow_readiness``.
Existing tests: none for readiness (``test_agent_templates_phase28.py`` covers
instantiate/badges only). Companion UI is covered separately when Qt is on.

Behaviour locked here: blocking rows for missing workspaces/secrets/MCP/host
bins; remediations clear those rows; ``git-<ws>`` install aliases count as git MCP.

User: "ja bbitte" — Start → check requirements → fetch/add missing.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))


class WorkflowReadinessTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory(prefix="ncc-readiness-")
        self.cfg = Path(self._tmpdir.name)
        os.environ["XDG_CONFIG_HOME"] = str(self.cfg)
        os.environ["NCC_DATA_ROOT"] = str(ROOT / "data")
        os.environ["NCC_PROMPTS_ROOT"] = str(ROOT / "data" / "prompts")

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def test_unknown_workflow_blocks(self) -> None:
        from core.catalogs.workflow_readiness import assess_workflow_readiness

        report = assess_workflow_readiness("does-not-exist-xyz")
        self.assertFalse(report.ready)
        self.assertEqual(report.blocking[0].id, "unknown")

    def test_github_review_blocks_without_workspaces_and_secret(self) -> None:
        from core.catalogs.workflow_readiness import assess_workflow_readiness

        report = assess_workflow_readiness("github-code-review")
        self.assertFalse(report.ready)
        ids = {i.id for i in report.blocking}
        self.assertIn("workspaces", ids)
        self.assertTrue(any(i.startswith("secret:") for i in ids))

    def test_scan_and_secret_and_mcp_clear_blocks(self) -> None:
        from core.catalogs.workflow_readiness import (
            assess_workflow_readiness,
            remediate_install_mcp,
            remediate_scan_workspaces,
            remediate_set_secret,
        )

        parent = self.cfg / "Git"
        repo = parent / "demo"
        (repo / ".git").mkdir(parents=True)

        scan = remediate_scan_workspaces(parent)
        self.assertTrue(scan["ok"], scan)
        self.assertIn("demo", scan["imported"])

        secret = remediate_set_secret("github_token", "ghp_test_not_real")
        self.assertTrue(secret["ok"], secret)

        with mock.patch(
            "core.catalogs.marketplace.shutil.which", return_value="/bin/uvx"
        ):
            with mock.patch(
                "core.catalogs.workflow_readiness.shutil.which",
                side_effect=lambda name: "/bin/" + name
                if name in ("git", "uvx", "uv", "gh")
                else None,
            ):
                for mcp_name in ("git", "github"):
                    inst = remediate_install_mcp(mcp_name)
                    self.assertTrue(inst["ok"], inst)
                report = assess_workflow_readiness("github-code-review")

        self.assertTrue(report.ready, [i.to_dict() for i in report.blocking])
        for mcp_id in ("mcp:git", "mcp:github"):
            row = next(i for i in report.items if i.id == mcp_id)
            self.assertEqual(row.severity, "ok", row)

    def test_mcp_git_alias_counts_as_installed(self) -> None:
        from core.catalogs.workflow_readiness import assess_workflow_readiness
        from core.store.paths import mcp_servers_file
        from core.store.workspaces import upsert_workspace

        repo = self.cfg / "repo"
        (repo / ".git").mkdir(parents=True)
        upsert_workspace("ncc", str(repo))

        path = mcp_servers_file()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps({"git-ncc": {"command": "uvx", "args": ["mcp-server-git"]}})
            + "\n",
            encoding="utf-8",
        )

        with mock.patch(
            "core.catalogs.workflow_readiness.shutil.which",
            side_effect=lambda name: "/bin/" + name
            if name in ("git", "uvx", "uv")
            else None,
        ):
            report = assess_workflow_readiness("local-git-status")

        mcp = next(i for i in report.items if i.id == "mcp:git")
        self.assertEqual(mcp.severity, "ok")


if __name__ == "__main__":
    unittest.main()
