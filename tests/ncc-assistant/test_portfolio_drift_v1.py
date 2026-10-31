"""Witnesses for the portfolio drift audit — the report the agent cannot build itself.

``ncc ai agent run`` has no tool that walks a directory: the `git` MCP server is bound to a single
``{{workspace.path}}``, the `filesystem` server is rooted at ``/tmp/ncc-mcp-fs``, and the
``read-only`` profile sets ``allow_shell=False``. The drift kinds below are therefore the only
place where "folder name vs origin name vs what workspaces.json claims" is decided, and a kind
that no real portfolio happens to trigger stays dead code unless a fixture forces it. On the
operator's own portfolio ``folder_vs_origin_name`` had zero hits — this file manufactures it.

Two claims here are about *not* doing something, so both are measured rather than asserted:
the scan must leave every ``.git/index`` byte-touched-by-nothing (``git status`` refreshes the
index cache by default, and the audit only came to look), and it must say why GitHub was not
checked instead of reporting nothing about GitHub.

Fixture repositories are real git in a tmp dir; they are safe to spawn because
``conftest.py::GIT_REPO_ENV`` strips the hook's repository-location variables for the session
(``test_git_env_isolation_v1.py`` watches that guard).

No network, no Nix, no PySide6.
"""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))

from core.catalogs import portfolio  # noqa: E402
from core.store.workspaces import delete_workspace, upsert_workspace  # noqa: E402

GIT_IDENTITY = {
    "GIT_AUTHOR_NAME": "drift-test",
    "GIT_AUTHOR_EMAIL": "drift@example.invalid",
    "GIT_COMMITTER_NAME": "drift-test",
    "GIT_COMMITTER_EMAIL": "drift@example.invalid",
}


def _git(root: Path, *args: str) -> None:
    result = subprocess.run(
        ["git", *args],
        cwd=str(root),
        capture_output=True,
        text=True,
        env={**os.environ, **GIT_IDENTITY},
        check=False,
    )
    assert result.returncode == 0, f"git {' '.join(args)}: {result.stderr}"


def _repo(
    parent: Path,
    name: str,
    *,
    origin: str | None = None,
    readme: str | None = None,
    dirty: bool = False,
) -> Path:
    """A real committed repository in ``parent/name``, optionally with an ``origin``."""
    root = parent / name
    root.mkdir(parents=True)
    if readme is not None:
        (root / "README.md").write_text(readme, encoding="utf-8")
    else:
        (root / "keep.txt").write_text("x\n", encoding="utf-8")
    _git(root, "init", "-b", "main")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "seed")
    if origin:
        _git(root, "remote", "add", "origin", origin)
    if dirty:
        (root / "untracked.log").write_text("wip\n", encoding="utf-8")
    return root


class PortfolioDriftTests(unittest.TestCase):
    """Every drift kind the report can name, forced by a fixture that has it."""

    def setUp(self) -> None:
        import shutil
        from contextlib import ExitStack
        from tempfile import mkdtemp

        from core.store.paths import workspaces_file

        self._stack = ExitStack()
        self.tmp = Path(mkdtemp(prefix="ncc-portfolio-"))
        self._stack.callback(shutil.rmtree, self.tmp, True)
        self.addCleanup(self._stack.close)
        self.root = self.tmp / "projects"
        self.root.mkdir()

        # The registry lives in the session's throwaway XDG home, so it is shared by every test in
        # the run. Without this, a count here is the history of whichever tests ran before it.
        registry = workspaces_file()
        snapshot = registry.read_bytes() if registry.is_file() else None

        def _restore() -> None:
            if snapshot is None:
                registry.unlink(missing_ok=True)
            else:
                registry.write_bytes(snapshot)

        self.addCleanup(_restore)

    def _drifts_of(self, report: dict, folder: str) -> list[str]:
        for row in report["projects"]:
            if row["folder"] == folder:
                return row["drifts"]
        self.fail(f"{folder} not in report: {[r['folder'] for r in report['projects']]}")

    def test_clean_registered_repo_reports_no_drift(self) -> None:
        _repo(
            self.root,
            "alpha",
            origin="https://github.com/acme/alpha.git",
            readme="# Alpha — builds the widget\n",
        )
        upsert_workspace("alpha", str(self.root / "alpha"), github="acme/alpha")

        report = portfolio.portfolio_drift_report(self.root)
        self.assertTrue(report["ok"], report)
        self.assertEqual(self._drifts_of(report, "alpha"), [])
        row = next(r for r in report["projects"] if r["folder"] == "alpha")
        self.assertEqual(row["origin_slug"], "acme/alpha")
        self.assertEqual(row["purpose"], "Alpha — builds the widget")
        self.assertEqual(row["purpose_from"], "README.md")

    def test_folder_named_differently_from_its_origin_is_drift(self) -> None:
        """Zero real-world hits made this branch unproven; the fixture is its only proof."""
        _repo(self.root, "beta-tool", origin="git@github.com:acme/other-name.git")

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("folder_vs_origin_name", self._drifts_of(report, "beta-tool"))

    def test_registry_github_that_disagrees_with_origin_is_drift(self) -> None:
        _repo(self.root, "gamma", origin="https://github.com/acme/gamma.git")
        upsert_workspace("gamma", str(self.root / "gamma"), github="acme/gamma-old-name")

        report = portfolio.portfolio_drift_report(self.root)
        drifts = self._drifts_of(report, "gamma")
        self.assertIn("registry_vs_origin", drifts)
        row = next(r for r in report["projects"] if r["folder"] == "gamma")
        self.assertEqual(row["registry_github"], "acme/gamma-old-name")

    def test_repo_with_a_remote_but_no_github_field_is_drift(self) -> None:
        _repo(self.root, "delta", origin="https://github.com/acme/delta.git")
        upsert_workspace("delta", str(self.root / "delta"))

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("registry_github_missing", self._drifts_of(report, "delta"))

    def test_repo_that_was_never_registered_is_drift(self) -> None:
        _repo(self.root, "untracked-project", origin="https://github.com/acme/untracked-project.git")

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("repo_not_registered", self._drifts_of(report, "untracked-project"))

    def test_repo_without_origin_is_drift(self) -> None:
        _repo(self.root, "no-remote")

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("no_origin_remote", self._drifts_of(report, "no-remote"))

    def test_plain_folder_under_the_root_is_reported_not_skipped(self) -> None:
        (self.root / "scratch-notes").mkdir()

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("not_a_repo", self._drifts_of(report, "scratch-notes"))

    def test_dirty_worktree_is_reported_with_its_path_count(self) -> None:
        _repo(self.root, "epsilon", origin="https://github.com/acme/epsilon.git", dirty=True)

        report = portfolio.portfolio_drift_report(self.root)
        self.assertIn("dirty_worktree", self._drifts_of(report, "epsilon"))
        row = next(r for r in report["projects"] if r["folder"] == "epsilon")
        self.assertEqual(row["dirty_paths"], 1)

    def test_registered_path_that_no_longer_exists_is_listed_apart(self) -> None:
        gone = self.root / "removed-checkout"
        gone.mkdir()
        upsert_workspace("removed-checkout", str(gone), github="acme/removed")
        gone.rmdir()

        report = portfolio.portfolio_drift_report(self.root)
        missing = {m["id"] for m in report["registered_but_missing"]}
        self.assertIn("removed-checkout", missing)
        self.assertEqual(report["counts"].get("registered_path_missing"), 1)
        # It is a registry entry, not a folder on disk: it must not also appear as a project row.
        self.assertNotIn("removed-checkout", [r["folder"] for r in report["projects"]])
        delete_workspace("removed-checkout")

    def test_scan_does_not_touch_any_repository_index(self) -> None:
        """The audit only came to look. ``git status`` refreshes the index cache unless told not to."""
        repos = [
            _repo(self.root, f"repo{i}", origin=f"https://github.com/acme/repo{i}.git", dirty=True)
            for i in range(3)
        ]
        before = {(r / ".git" / "index"): (r / ".git" / "index").stat().st_mtime_ns for r in repos}
        tree_before = {
            p.relative_to(self.root): p.stat().st_mtime_ns
            for p in self.root.rglob("*")
            if p.is_file()
        }

        portfolio.portfolio_drift_report(self.root)

        touched = [str(p) for p, ns in before.items() if p.stat().st_mtime_ns != ns]
        self.assertEqual(touched, [], "the scan wrote to a repository index")
        after = {
            p.relative_to(self.root): p.stat().st_mtime_ns
            for p in self.root.rglob("*")
            if p.is_file()
        }
        self.assertEqual(sorted(after), sorted(tree_before))

    def test_github_absence_is_stated_as_a_reason_never_left_silent(self) -> None:
        _repo(self.root, "zeta", origin="https://github.com/acme/zeta.git")

        real_which = portfolio.shutil.which
        portfolio.shutil.which = lambda cmd: None if os.path.basename(str(cmd)) == "gh" else real_which(cmd)
        self.addCleanup(setattr, portfolio.shutil, "which", real_which)

        report = portfolio.portfolio_drift_report(self.root)
        state = report["github"]
        self.assertFalse(state["checked"])
        self.assertIn("gh", state["reason"])

    def test_root_defaults_to_the_folder_holding_the_registered_workspaces(self) -> None:
        _repo(self.root, "theta", origin="https://github.com/acme/theta.git")
        upsert_workspace("theta", str(self.root / "theta"), github="acme/theta")

        report = portfolio.portfolio_drift_report()
        self.assertEqual(Path(report["root"]), self.root.resolve())

    def test_a_root_that_is_not_a_directory_answers_rather_than_raising(self) -> None:
        report = portfolio.portfolio_drift_report(self.tmp / "nowhere")
        self.assertFalse(report["ok"])
        self.assertIn("not a directory", report["error"])


class PortfolioPlaybookTests(unittest.TestCase):
    """The playbook is the thing the operator starts; a broken reference here fails only at run time."""

    def test_playbook_names_the_tool_and_stays_read_only(self) -> None:
        import json

        path = ROOT / "data" / "playbooks" / "project-drift-audit.json"
        self.assertTrue(path.is_file(), f"{path} missing — the operator has nothing to start")
        data = json.loads(path.read_text(encoding="utf-8"))

        self.assertEqual(data["name"], "project-drift-audit")
        self.assertEqual(data["profile"], "read-only")
        self.assertTrue(data["dry_run"])
        self.assertIn("portfolio_drift_report", data["goal"])
        for kind in ("folder_vs_origin_name", "registered_path_missing", "not_a_repo"):
            self.assertIn(kind, data["goal"], f"goal must name the drift {kind}")

    def test_the_tool_is_registered_and_read_only(self) -> None:
        from core.runtime.registry import ToolRegistry
        from core.runtime.runtime import TOOL_DEFINITIONS

        spec = next((t for t in TOOL_DEFINITIONS if t["name"] == "portfolio_drift_report"), None)
        self.assertIsNotNone(spec, "the report has no schema, so the model cannot call it")
        self.assertIn("root", spec["inputSchema"]["properties"])

        entry = ToolRegistry()._tools.get("portfolio_drift_report")
        self.assertIsNotNone(entry, "the registry never loaded the builtin")
        self.assertEqual(entry.risk, "read", "an inventory that can write is not an inventory")

    def test_a_run_reaches_the_report_through_the_dispatch(self) -> None:
        """A schema without its dispatch branch is a tool the playbook can name and never get.

        The mutation that this catches is one line in ``ToolRuntime.call`` — invisible to every
        check above, because the schema and the registry entry both stay intact without it.
        """
        import json
        import shutil
        import tempfile

        from core.runtime.runtime import ToolRuntime
        from core.store.config import Settings

        root = Path(tempfile.mkdtemp(prefix="ncc-portfolio-dispatch-"))
        self.addCleanup(shutil.rmtree, root, True)
        _repo(root, "dispatch-check", origin="https://github.com/acme/dispatch-check.git")

        result = ToolRuntime(Settings.from_env()).call("portfolio_drift_report", {"root": str(root)})

        self.assertTrue(result.get("ok"), result)
        self.assertIn("dispatch-check", [p["folder"] for p in result["projects"]])
        self.assertNotIn("Unknown tool", json.dumps(result))


if __name__ == "__main__":
    unittest.main()
