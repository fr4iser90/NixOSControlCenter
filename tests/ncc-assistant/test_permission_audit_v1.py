"""Phase 39 L9/L10: every ladder-relevant action and refusal lands in audit.jsonl.

An approval is only worth what it can be read back as: who asked, how far that run was
allowed to go, and what the floor refused anyway.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

from ncc_assistant import audit, notifications, paths, permissions, workflow_execute
from test_permission_ladder_v1 import _repo, grant_env

GIT_ENV = {
    "GIT_AUTHOR_NAME": "test",
    "GIT_AUTHOR_EMAIL": "test@example.invalid",
    "GIT_COMMITTER_NAME": "test",
    "GIT_COMMITTER_EMAIL": "test@example.invalid",
}


@pytest.fixture(autouse=True)
def fresh_audit():
    """One test, one log — the suite shares the session's throwaway XDG home."""
    audit.clear_audit()
    yield


def _events(event: str | None = None) -> list[dict]:
    """Audit lines newest-first, as written (so redaction and actor are the real ones)."""
    path = paths.audit_file()
    if not path.is_file():
        return []
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [r for r in rows if event is None or r.get("event") == event]


# --- where state is allowed to land ---------------------------------------------------


def test_the_suite_writes_to_its_own_config_home():
    """Guards everything below: without this, these tests would pollute the operator's audit log."""
    xdg = Path(os.environ["XDG_CONFIG_HOME"]).resolve()
    assert str(xdg).startswith("/tmp") and xdg.name.startswith("ncc-assistant-tests-")
    assert paths.config_home() == xdg / "ncc-assistant"


# --- git_action ----------------------------------------------------------------------


def test_reads_stay_out_of_the_audit(tmp_path):
    root = _repo(tmp_path)
    with grant_env(repo="commit", actor="schedule:daily-audit"):
        out = workflow_execute._git(root, "status", "--porcelain")
    assert out["ok"] is True
    assert _events("git_action") == []


def test_a_commit_is_audited_with_the_actor_that_made_it(tmp_path):
    root = _repo(tmp_path)
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    with grant_env(repo="commit", actor="schedule:daily-audit"):
        workflow_execute._git(root, "add", "-A")
        out = workflow_execute._git(root, "commit", "-m", "docs: notes")
    assert out["ok"] is True, out
    actions = _events("git_action")
    assert [a["tool"] for a in actions] == ["git commit"], "add/reads are not actions"
    assert actions[0]["actor"] == "schedule:daily-audit"
    assert actions[0]["result"] == "ok"


def test_a_human_run_is_audited_as_cli(tmp_path):
    root = _repo(tmp_path)
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    env = {**os.environ, **GIT_ENV}
    subprocess.run(["git", "add", "-A"], cwd=root, check=True, env=env, capture_output=True)
    with grant_env():
        out = workflow_execute._git(root, "commit", "-m", "docs: notes")
    assert out["ok"] is True, out
    assert _events("git_action")[0]["actor"] == "cli"


def test_a_failing_git_action_is_recorded_as_error(tmp_path):
    root = _repo(tmp_path)
    with grant_env(repo="commit"):
        out = workflow_execute._git(root, "commit", "-m", "nothing staged")
    assert out["ok"] is False
    recorded = _events("git_action")
    assert len(recorded) == 1 and recorded[0]["result"] == "error"


# --- floor_denied --------------------------------------------------------------------


def test_the_floor_denies_and_says_so_in_the_log(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    with mock.patch.object(workflow_execute, "_run") as run:
        with grant_env(repo="release", actor="companion"):
            out = workflow_execute._git(root, "push", "--force")
    assert run.called is False
    assert out["denied"] == "denied_force_push"
    denied = _events("floor_denied")
    assert len(denied) == 1
    assert denied[0]["tool"] == "git push"
    assert denied[0]["actor"] == "companion"
    assert denied[0]["result"] == "denied"
    assert "denied_force_push" in denied[0]["detail"]


def test_secrets_and_protected_branches_are_audited_floor_denials(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    (root / ".env").write_text("TOKEN=1\n", encoding="utf-8")
    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="pr", actor="schedule:nightly"):
            assert workflow_execute.commit_all("t", message="x")["error"] == "denied_secret_path"
            assert workflow_execute.push_branch("t")["error"] == "denied_protected_branch"

    denied = {d["tool"]: d for d in _events("floor_denied")}
    assert set(denied) == {"git commit", "git push"}
    assert denied["git commit"]["detail"].startswith("denied_secret_path")
    assert "denied_protected_branch" in denied["git push"]["detail"]
    assert all(d["actor"] == "schedule:nightly" for d in denied.values())


# --- publish actions -----------------------------------------------------------------


def test_pr_create_and_merge_are_audited_too(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    ok = {"ok": True, "cmd": ["gh"], "returncode": 0, "stdout": "https://github.com/o/r/pull/9", "stderr": ""}
    with mock.patch.object(workflow_execute.shutil, "which", return_value="/usr/bin/gh"):
        with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
            with mock.patch.object(workflow_execute, "_run", return_value=dict(ok)) as run:
                with mock.patch.object(workflow_execute, "push_branch", return_value={"ok": True}):
                    with grant_env(repo="merge", actor="cli"):
                        assert workflow_execute.merge_pull_request("t", pr="9")["ok"] is True
                        assert workflow_execute.open_pull_request("t", title="x")["ok"] is True
    gh_calls = [c.args[0] for c in run.call_args_list if c.args[0][0] == "gh"]
    assert [c[:3] for c in gh_calls] == [["gh", "pr", "merge"], ["gh", "pr", "create"]]
    tools = {a["tool"] for a in _events("git_action")}
    assert tools == {"gh pr merge", "gh pr create"}


# --- who asked (L10) -----------------------------------------------------------------


def test_pending_decision_records_actor_and_grant(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    service = notifications.DecisionService()
    with grant_env(repo="pr", system="none", actor="schedule:daily-audit"):
        decision = service.create("write_confirm", "Write config", "changes nixos/…")
    assert decision.actor == "schedule:daily-audit"
    assert decision.grant == {"repo": "pr", "system": "none"}
    assert decision.grant_label() == "repo=pr system=none"

    on_disk = json.loads(Path(service._decision_path(decision.id)).read_text(encoding="utf-8"))
    assert on_disk["actor"] == "schedule:daily-audit"
    assert on_disk["grant"] == {"repo": "pr", "system": "none"}


def test_a_human_run_records_no_grant(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    service = notifications.DecisionService()
    with grant_env():
        decision = service.create("tool_approval", "Run tool", "")
    assert decision.grant is None
    assert decision.grant_label() == "no grant (human)"
    assert decision.actor == "cli"


def test_approve_list_shows_the_actor_and_the_ladder():
    src = (
        REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python" / "ncc_assistant" / "cli.py"
    ).read_text(encoding="utf-8")
    assert "asked by {d.actor}" in src and "d.grant_label()" in src


# --- schedule actor id (L10 transport) -----------------------------------------------


def test_schedule_actor_is_named_per_unit():
    nix = (REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "schedules.nix").read_text(
        encoding="utf-8"
    )
    assert 'NCC_ASSISTANT_ACTOR = "schedule:${name}"' in nix


def test_both_schedule_actor_spellings_count(monkeypatch):
    for actor, expected in (("schedule", True), ("schedule:daily-audit", True), ("cli", False), ("", False)):
        monkeypatch.setenv(permissions.ENV_ACTOR, actor)
        assert notifications.is_schedule_actor() is expected, actor
    monkeypatch.delenv(permissions.ENV_ACTOR, raising=False)
    assert notifications.actor_identity() == "cli"
