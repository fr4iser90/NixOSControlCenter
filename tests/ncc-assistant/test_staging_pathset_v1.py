"""Phase 39 L6: staging takes the run's pathset, and the deny list beats every grant.

``git add -A`` staged whatever was dirty, so an untracked ``.env`` reached history on the
strength of an unrelated commit message. Both halves of the replacement are checked here:
a commit stages a named set of paths, and a credential-shaped path is refused whether the
run found it or asked for it.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
MODULE = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"
sys.path.insert(0, str(MODULE))

from core.policy import audit
from core.store import paths
from core.workflows import workflow_execute
from test_permission_ladder_v1 import _git, _repo, grant_env


@pytest.fixture
def workspace(tmp_path):
    """A seeded repo standing in for a registered workspace."""
    root = _repo(tmp_path)
    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        yield root


def _out(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout


def _staged(root: Path) -> list[str]:
    return [p for p in _out(root, "diff", "--cached", "--name-only").splitlines() if p]


def _committed(root: Path) -> list[str]:
    return [p for p in _out(root, "show", "--pretty=format:", "--name-only", "HEAD").splitlines() if p]


def _dirty(root: Path) -> str:
    return _out(root, "status", "--porcelain")


# --- the deny list is unconditional ---------------------------------------------------


def test_a_dirty_env_leaves_nothing_staged(workspace):
    """Plan acceptance: dirty ``.env`` + ``commit`` → nothing staged, ``denied_secret_path``."""
    (workspace / "notes.md").write_text("work\n", encoding="utf-8")
    (workspace / ".env").write_text("TOKEN=1\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="docs: notes")
    assert out["ok"] is False and out["error"] == "denied_secret_path"
    assert out["secretPaths"] == [".env"]
    assert _staged(workspace) == [], "not even the innocent file may be left in the index"
    assert "notes.md" in _dirty(workspace), "the real change stays where the human can see it"


def test_a_suffix_less_env_file_is_refused_too(workspace):
    """The deny list is ``.env*``: ``.envrc`` holds secrets exactly as ``.env.local`` does."""
    (workspace / ".envrc").write_text("export TOKEN=1\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="feat: direnv")
    assert out["error"] == "denied_secret_path" and ".envrc" in out["secretPaths"]
    assert _staged(workspace) == []


def test_a_secret_in_a_brand_new_directory_is_refused(workspace):
    """What ``add -A`` hid: git reports an untracked directory as ``keys/``, never as the key."""
    (workspace / "keys").mkdir()
    (workspace / "keys" / "deploy.key").write_text("PRIVATE\n", encoding="utf-8")
    assert _dirty(workspace).split() == ["??", "keys/"], "a text screen over this sees a folder"
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="feat: deploy")
    assert out["error"] == "denied_secret_path"
    assert out["secretPaths"] == ["keys/deploy.key"]
    assert _staged(workspace) == []


def test_naming_a_secret_does_not_stage_it(workspace):
    (workspace / ".env").write_text("TOKEN=1\n", encoding="utf-8")
    (workspace / "notes.md").write_text("work\n", encoding="utf-8")
    with grant_env(repo="release"):
        out = workflow_execute.commit_all("t", message="x", paths=["notes.md", ".env"])
    assert out["error"] == "denied_secret_path" and ".env" in out["secretPaths"]
    assert _staged(workspace) == [], "the deny list outranks an explicit request and the top step"


def test_a_refused_pathset_is_audited_as_a_floor_denial(workspace):
    audit.clear_audit()
    (workspace / ".env").write_text("TOKEN=1\n", encoding="utf-8")
    with grant_env(repo="pr", actor="schedule:nightly"):
        assert workflow_execute.commit_all("t", message="x")["error"] == "denied_secret_path"
    rows = [
        json.loads(line)
        for line in paths.audit_file().read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    denied = [r for r in rows if r.get("event") == "floor_denied"]
    assert [d["tool"] for d in denied] == ["git commit"]
    assert denied[0]["detail"].startswith("denied_secret_path")
    assert denied[0]["actor"] == "schedule:nightly"


# --- a pathset, not the tree ----------------------------------------------------------


def test_only_the_named_paths_are_committed(workspace):
    (workspace / "notes.md").write_text("work\n", encoding="utf-8")
    (workspace / "other.md").write_text("someone else's\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="docs: notes", paths=["notes.md"])
    assert out["ok"] is True and out["committed"] is True, out
    assert out["stagedPaths"] == ["notes.md"]
    assert _committed(workspace) == ["notes.md"]
    assert "other.md" in _dirty(workspace), "work the run did not touch is not the run's to commit"


def test_the_whole_tree_is_not_a_pathset(workspace):
    (workspace / "notes.md").write_text("work\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="x", paths=["."])
    assert out["error"] == "denied_blanket_path" and out["rejectedPaths"] == ["."]
    assert _staged(workspace) == [], "``.`` is git add -A by another name"


def test_a_path_may_not_leave_the_checkout(workspace):
    (workspace.parent / "elsewhere.txt").write_text("not this repo\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="x", paths=["../elsewhere.txt"])
    assert out["error"] == "denied_path_outside_repo" and out["rejectedPaths"] == ["../elsewhere.txt"]
    assert _staged(workspace) == []


def test_an_empty_pathset_commits_nothing(workspace):
    (workspace / "notes.md").write_text("work\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="x", paths=[])
    assert out["ok"] is True and out["committed"] is False
    assert out["reason"] == "nothing_to_commit"
    assert _staged(workspace) == [], "no list is not the same as every list"


def test_a_path_the_run_did_not_change_is_not_an_error(workspace):
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="x", paths=["README.md"])
    assert out["ok"] is True and out["committed"] is False and out["reason"] == "nothing_to_commit"


# --- the default pathset still covers a real change ----------------------------------


def test_a_deletion_is_committed(workspace):
    (workspace / "stale.md").write_text("old\n", encoding="utf-8")
    _git(workspace, "add", "-A")
    _git(workspace, "commit", "-m", "stale")
    (workspace / "stale.md").unlink()
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="drop the stale note")
    assert out["ok"] is True, out
    assert _committed(workspace) == ["stale.md"]


def test_a_rename_is_not_committed_as_a_copy(workspace):
    (workspace / "old.md").write_text("content\n", encoding="utf-8")
    _git(workspace, "add", "-A")
    _git(workspace, "commit", "-m", "old name")
    (workspace / "old.md").rename(workspace / "new.md")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="rename the note")
    assert out["ok"] is True, out
    moved = [line for line in _out(workspace, "show", "--pretty=format:", "--name-status", "HEAD").splitlines()]
    assert any(l.startswith("R") and "old.md" in l and "new.md" in l for l in moved), (
        f"staging only the destination would leave old.md in the tree: {moved}"
    )


def test_a_new_directory_of_real_work_is_committed(workspace):
    (workspace / "docs" / "guide.md").parent.mkdir()
    (workspace / "docs" / "guide.md").write_text("how to\n", encoding="utf-8")
    with grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="docs: guide")
    assert out["ok"] is True, out
    assert _committed(workspace) == ["docs/guide.md"]


def test_bump_stages_only_the_manifest(workspace):
    (workspace / "package.json").write_text(json.dumps({"version": "1.2.3"}), encoding="utf-8")
    (workspace / "notes.md").write_text("someone else's\n", encoding="utf-8")
    with grant_env(repo="release"):
        out = workflow_execute.bump_version("t", confirm="CONFIRM", part="patch")
    assert out["ok"] is True and out["version"] == "1.2.4", out
    assert _committed(workspace) == ["package.json"], "a bump is not a licence to commit the tree"
    assert "notes.md" in _dirty(workspace)


# --- the blanket stage is gone --------------------------------------------------------


def test_no_blanket_stage_is_left_in_the_workflow():
    src = (MODULE / "core" / "workflows" / "workflow_execute.py").read_text(encoding="utf-8")
    assert '"add", "-A"' not in src and '"add", "-A",' not in src
    assert '"add", "--"' in src, "staging must name its paths to git"
    cli_src = (MODULE / "cli" / "cli.py").read_text(encoding="utf-8")
    assert 'dest="paths"' in cli_src and 'paths=getattr(args, "paths", None)' in cli_src
    assert "git add -A && commit" not in cli_src, "the help must not promise what the code no longer does"
