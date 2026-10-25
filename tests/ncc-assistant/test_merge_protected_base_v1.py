"""Phase 39 §4: ``merge`` lands on an unprotected base, and asks the PR which one that is.

The push floor reads HEAD; a merge target is not HEAD. The PR names the branch the commits end
up on, so the check reads ``baseRefName`` instead of the checkout — a run standing on
``ncc/workflow-1`` can still be about to land on ``main``. A base that cannot be read is refused
too: "probably unprotected" is the same guess as "probably fine", and the floor exists to refuse
guesses. Outside a grant the CONFIRM token is the human decision the ladder keeps for trunk, so
none of these refusals binds the person the step was written for.
"""

from __future__ import annotations

import json
import sys
from contextlib import ExitStack, contextmanager
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import audit
from core.workflows import workflow_execute
from test_permission_ladder_v1 import _repo, grant_env


@pytest.fixture(autouse=True)
def fresh_audit():
    audit.clear_audit()
    yield


def _events(event: str) -> list[dict]:
    path = audit.audit_file()
    if not path.is_file():
        return []
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and json.loads(line).get("event") == event
    ]


@contextmanager
def _gh(tmp_path: Path, base: str | None, *, view_ok: bool = True, branch: str = "ncc/workflow-1"):
    """A workspace plus a ``gh`` that answers with one PR base; yields the gh commands it saw.

    ``base=None`` stands for a PR gh cannot describe — a wrong number, a repo without a PR, a
    network that answered nothing. Only ``gh`` is stubbed, so the repository underneath stays real.
    """
    root = _repo(tmp_path, branch=branch)
    gh_calls: list[list[str]] = []

    def dispatch(cmd, *args, **kwargs):
        if cmd and cmd[0] == "gh":
            gh_calls.append(list(cmd))
            return {
                "ok": view_ok,
                "cmd": list(cmd),
                "returncode": 0 if view_ok else 1,
                "stdout": f"{base}\n" if base is not None else "",
                "stderr": "" if view_ok else "no pull requests found",
            }
        return {"ok": True, "cmd": list(cmd), "returncode": 0, "stdout": "", "stderr": ""}

    with ExitStack() as stack:
        for patcher in (
            mock.patch.object(workflow_execute.shutil, "which", return_value="/usr/bin/gh"),
            mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)),
            mock.patch.object(workflow_execute, "_run", side_effect=dispatch),
        ):
            stack.enter_context(patcher)
        yield root, gh_calls


# --- the refusal ---------------------------------------------------------------------


def test_an_agent_run_may_not_merge_onto_either_trunk_name(tmp_path):
    for trunk in ("main", "master"):
        workspace = tmp_path / trunk
        workspace.mkdir()
        with _gh(workspace, trunk) as _, grant_env(repo="merge", actor="schedule:nightly-ship"):
            out = workflow_execute.merge_pull_request("t", pr="9")
        assert out["ok"] is False, trunk
        assert out["denied"] == "denied_protected_branch", trunk
        assert out["reason"] == f"{trunk} is protected", trunk


def test_the_merge_is_never_spawned_and_the_attempt_is_logged(tmp_path):
    with _gh(tmp_path, "main") as (_, gh_calls):
        with grant_env(repo="merge", actor="schedule:nightly-ship"):
            workflow_execute.merge_pull_request("t", pr="9")

    assert [c[:3] for c in gh_calls] == [["gh", "pr", "view"]], "gh pr merge must not run"
    denied = _events("floor_denied")
    assert len(denied) == 1
    assert denied[0]["tool"] == "gh pr merge"
    assert denied[0]["actor"] == "schedule:nightly-ship"
    assert denied[0]["detail"].startswith("denied_protected_branch: main is protected")
    assert _events("git_action") == [], "a merge that never happened is not an action"


def test_the_target_comes_from_the_pr_not_from_the_checkout(tmp_path):
    """HEAD is the agent branch here, so a floor that read HEAD would call this safe."""
    with _gh(tmp_path, "main", branch="ncc/workflow-1") as (_, gh_calls):
        with grant_env(repo="merge"):
            out = workflow_execute.merge_pull_request("t", pr="12")

    assert out["denied"] == "denied_protected_branch"
    assert gh_calls[0] == ["gh", "pr", "view", "12", "--json", "baseRefName", "--jq", ".baseRefName"]


# --- the step still does its job -----------------------------------------------------


def test_an_unprotected_base_merges_and_names_where_it_landed(tmp_path):
    with _gh(tmp_path, "ncc/integration") as (_, gh_calls):
        with grant_env(repo="merge", actor="cli"):
            out = workflow_execute.merge_pull_request("t", pr="4")

    assert out["ok"] is True, out
    assert out["base"] == "ncc/integration", "the operator can read the target back"
    assert [c[:3] for c in gh_calls] == [["gh", "pr", "view"], ["gh", "pr", "merge"]]
    assert _events("floor_denied") == []


def test_a_grant_below_merge_never_asks_gh(tmp_path):
    with _gh(tmp_path, "main") as (_, gh_calls):
        with grant_env(repo="pr", actor="cli"):
            out = workflow_execute.merge_pull_request("t", pr="9", confirm="CONFIRM")

    assert out["ok"] is False and out["denied"] == "grant_insufficient"
    assert gh_calls == [], "a grant the ladder refuses costs no network call"


# --- fail closed ---------------------------------------------------------------------


def test_a_base_that_cannot_be_read_is_not_merged(tmp_path):
    with _gh(tmp_path, None, view_ok=False) as (_, gh_calls):
        with grant_env(repo="merge", actor="schedule:nightly-ship"):
            out = workflow_execute.merge_pull_request("t")

    assert out["ok"] is False
    assert out["error"] == "merge_base_unknown"
    assert "merge --pr" in out["hint"]
    assert [c[:3] for c in gh_calls] == [["gh", "pr", "view"]]

    denied = _events("floor_denied")
    assert len(denied) == 1 and denied[0]["tool"] == "gh pr merge"
    assert denied[0]["detail"].startswith("merge_base_unknown")


def test_an_empty_answer_is_unknown_even_when_the_command_succeeded(tmp_path):
    """An empty ``baseRefName`` is not an unprotected branch name."""
    with _gh(tmp_path, "", view_ok=True) as (_, gh_calls):
        with grant_env(repo="merge"):
            out = workflow_execute.merge_pull_request("t", pr="9")

    assert out["error"] == "merge_base_unknown"
    assert [c[:3] for c in gh_calls] == [["gh", "pr", "view"]]


# --- the human path keeps its rights -------------------------------------------------


def test_the_human_with_the_token_still_merges_onto_main(tmp_path):
    """The ladder keeps trunk for a person, and the push hint sends them to a PR to get there."""
    with _gh(tmp_path, "main") as (_, gh_calls):
        with grant_env():
            out = workflow_execute.merge_pull_request("t", pr="9", confirm="CONFIRM")

    assert out["ok"] is True, out
    assert [c[:3] for c in gh_calls] == [["gh", "pr", "merge"]], "no base read outside a grant"
    assert _events("floor_denied") == []


def test_a_human_without_the_token_is_still_refused(tmp_path):
    with _gh(tmp_path, "main") as (_, gh_calls):
        with grant_env():
            out = workflow_execute.merge_pull_request("t", pr="9", confirm="")

    assert out["ok"] is False and out["error"] == "confirm_required"
    assert gh_calls == []
