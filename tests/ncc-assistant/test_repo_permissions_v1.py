"""Phase 39 L13: a repository may lower its own ladder, never raise it.

``.ncc/permissions.json`` is the one config file whose whole purpose is to take rights away
from the thing reading it, so every case here is about which of the three answers a broken
file gives and who is allowed to change it. The file is read out of ``HEAD`` — the working
tree is precisely what a bounded run may write — so the middle group is the interesting one:
deleting, widening or corrupting the file on disk must not move the ceiling by one step.
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
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import audit, permissions
from cli import cli
from core.store import paths
from core.workflows import workflow_execute
from test_permission_ladder_v1 import _git, _repo, grant_env

CEILING_PATH = permissions.REPO_CEILING_PATH


def _workspace(tmp_path: Path):
    """A seeded agent-branch checkout standing in for a registered workspace."""
    root = _repo(tmp_path)
    return mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)), root


def _commit_ceiling(root: Path, body: str) -> None:
    """The repo owner's own commit — the only write this file ever gets."""
    (root / ".ncc").mkdir(exist_ok=True)
    (root / CEILING_PATH).write_text(body, encoding="utf-8")
    _git(root, "add", "--", ".ncc")
    _git(root, "commit", "-m", "owner: lower this repo's ladder")


def _head_body(root: Path) -> str:
    return subprocess.run(
        ["git", "show", f"HEAD:{CEILING_PATH}"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def _out(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout


def _staged(root: Path) -> list[str]:
    return [p for p in _out(root, "diff", "--cached", "--name-only").splitlines() if p]


def _events(event: str) -> list[dict]:
    path = paths.audit_file()
    if not path.is_file():
        return []
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [r for r in rows if r.get("event") == event]


# --- the file's grammar ---------------------------------------------------------------


def test_a_committed_lowering_is_read_as_a_step():
    verdict = permissions.parse_repo_ceiling('{"version": 1, "repo": "commit"}')
    assert (verdict.step, verdict.code) == ("commit", "")


def test_a_version_may_be_a_string_or_a_number():
    assert permissions.parse_repo_ceiling('{"version": "1", "repo": "pr"}').step == "pr"


@pytest.mark.parametrize(
    "body,needle",
    [
        ("", "is not JSON"),
        ("[]", "is not a JSON object"),
        ('{"repo": "commit", "system": "config-write"}', "system"),
        ('{"repo": "commit", "reviewers": ["ncc"]}', "reviewers"),
        ('{"version": 2, "repo": "commit"}', "version"),
        ('{"repo": "deploy"}', "deploy"),
        ('{"repo": "REPO_ONLY_CAPS_OF_A_REAL_STEP_"}', "not a step"),
    ],
)
def test_a_file_that_is_not_exactly_a_lowering_is_refused(body: str, needle: str):
    """A narrowing nobody can parse must not read as absent — that is the loud answer."""
    verdict = permissions.parse_repo_ceiling(body)
    assert verdict.step is None
    assert verdict.code == "repo_ceiling_invalid", verdict
    assert needle in verdict.reason, verdict.reason
    assert CEILING_PATH in verdict.reason


def test_a_repository_may_not_speak_for_the_machine():
    """The system axis is the host's: a repo file naming it is refused, not ignored."""
    verdict = permissions.parse_repo_ceiling('{"repo": "observe", "system": "rebuild"}')
    assert verdict.code == "repo_ceiling_invalid"
    assert "system" in verdict.reason and "rebuild" not in verdict.reason


# --- HEAD decides, the working tree does not -----------------------------------------


def test_a_repository_with_nothing_committed_keeps_its_host_grant(tmp_path):
    assert permissions.read_repo_ceiling(tmp_path).step is None


def test_an_unborn_head_has_never_lowered_anything(tmp_path):
    root = tmp_path / "fresh"
    root.mkdir()
    _git(root, "init", "-b", "ncc/workflow-test")
    verdict = permissions.read_repo_ceiling(root)
    assert (verdict.step, verdict.code) == (None, ""), "no commit yet is not a broken file"


def test_deleting_the_file_on_disk_does_not_widen_the_repo(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    (root / CEILING_PATH).unlink()
    verdict = permissions.read_repo_ceiling(root)
    assert verdict.step == "commit", "the worktree is what the bounded run is allowed to write"


def test_rewriting_the_file_on_disk_does_not_widen_the_repo(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    (root / CEILING_PATH).write_text('{"version": 1, "repo": "release"}', encoding="utf-8")
    assert permissions.read_repo_ceiling(root).step == "commit"
    assert _head_body(root) == '{"version": 1, "repo": "commit"}'


def test_corrupting_the_file_on_disk_leaves_the_committed_one_in_force(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "push"}')
    (root / CEILING_PATH).write_text("{ broken", encoding="utf-8")
    assert permissions.read_repo_ceiling(root).step == "push"


def test_a_committed_file_that_cannot_be_parsed_floors_the_axis(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"repo": "deploy"}')
    verdict = permissions.read_repo_ceiling(root)
    assert verdict.code == "repo_ceiling_invalid"
    assert _head_body(root) == '{"repo": "deploy"}', "the fixture really committed it"


# --- it only ever lowers ------------------------------------------------------------


def test_a_ceiling_above_the_run_never_applies(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "release"}')
    with grant_env(repo="commit", actor="schedule:nightly"):
        verdict = permissions.evaluate_repo(
            "push", ceiling=permissions.read_repo_ceiling(root), tool="git push"
        )
    assert verdict.allowed is False and verdict.code == "grant_insufficient"
    assert CEILING_PATH not in verdict.hint, "the grant was the narrower answer here"


def test_a_ceiling_below_the_run_is_the_one_that_answers(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    with grant_env(repo="pr", actor="schedule:nightly"):
        verdict = permissions.evaluate_repo(
            "push", ceiling=permissions.read_repo_ceiling(root), tool="git push"
        )
    assert verdict.allowed is False
    assert CEILING_PATH in verdict.hint, verdict.hint
    assert "grant_insufficient" == verdict.code


def test_work_the_lowered_step_covers_still_runs(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    with grant_env(repo="pr"):
        ceiling = permissions.read_repo_ceiling(root)
        assert permissions.evaluate_repo("commit", ceiling=ceiling).allowed is True
        assert permissions.evaluate_repo("read", ceiling=ceiling).allowed is True


# --- what the audit line says ---------------------------------------------------------


def test_the_audit_line_names_the_repository_as_the_narrower_answer(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    audit.clear_audit()
    with grant_env(repo="pr", actor="schedule:nightly"):
        permissions.evaluate_repo("merge", ceiling=permissions.read_repo_ceiling(root), tool="merge")
    lines = _events("grant_evaluated")
    assert len(lines) == 1, lines
    assert f"ceiling={permissions.REPO_CEILING_PATH}" in json.dumps(lines[0]) or (
        "ceiling=commit" in lines[0]["detail"]
    ), lines[0]


def test_an_ignored_ceiling_is_recorded_as_ignored(tmp_path):
    """Otherwise the owner reads a denial as "my file worked" when the grant was lower."""
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "merge"}')
    audit.clear_audit()
    with grant_env(repo="commit", actor="schedule:nightly"):
        permissions.evaluate_repo("push", ceiling=permissions.read_repo_ceiling(root), tool="push")
    lines = _events("grant_evaluated")
    assert len(lines) == 1, lines
    assert "ceiling_ignored=merge" in lines[0]["detail"], lines[0]["detail"]


def test_an_unparsable_ceiling_is_recorded_by_code(tmp_path):
    root = _repo(tmp_path)
    _commit_ceiling(root, "nonsense")
    audit.clear_audit()
    with grant_env(repo="commit", actor="cli"):
        permissions.evaluate_repo("commit", ceiling=permissions.read_repo_ceiling(root), tool="git commit")
    lines = _events("grant_evaluated")
    assert "ceiling=repo_ceiling_invalid" in lines[0]["detail"], lines[0]["detail"]


# --- the tools refuse, and refuse before touching git ---------------------------------


def test_commit_still_works_at_the_lowered_step(tmp_path):
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    with patcher, grant_env(repo="pr"):
        out = workflow_execute.commit_all("t", message="docs: notes")
    assert out["ok"] is True, out


def test_a_lowered_repository_refuses_push_before_touching_the_remote(tmp_path):
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    with patcher, grant_env(repo="release"):
        out = workflow_execute.push_branch("t")
    assert out["ok"] is False and out["error"] == "grant_insufficient", out
    assert CEILING_PATH in out["hint"]


def test_an_unparsable_ceiling_refuses_the_commit_itself(tmp_path):
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"repo": "deploy"}')
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    with patcher, grant_env(repo="release"):
        out = workflow_execute.commit_all("t", message="docs: notes")
    assert out["ok"] is False and out["error"] == "repo_ceiling_invalid", out
    assert _staged(root) == [], "a refusal may not leave this run's pathset in someone's index"


def test_merge_and_release_ask_the_repository_too(tmp_path):
    """The two token-gated steps read the ceiling before the CONFIRM path, inside a grant."""
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "pr"}')
    with patcher, grant_env(repo="release"):
        merged = workflow_execute.merge_pull_request("t", confirm="CONFIRM", pr="1")
        bumped = workflow_execute.bump_version("t", confirm="CONFIRM", part="patch")
    assert merged["ok"] is False and merged["error"] == "grant_insufficient", merged
    assert bumped["ok"] is False and bumped["error"] == "grant_insufficient", bumped
    assert CEILING_PATH in merged["hint"] and CEILING_PATH in bumped["hint"]


def test_a_human_at_the_cli_keeps_the_confirm_token(tmp_path):
    """Outside a grant the ladder steps aside — the file must not strand the owner's own tool."""
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "observe"}')
    (root / "package.json").write_text(json.dumps({"version": "1.2.3"}), encoding="utf-8")
    with patcher:
        refused = workflow_execute.bump_version("t", confirm="")
        granted = workflow_execute.bump_version("t", confirm="CONFIRM", part="patch")
    assert refused.get("error") == "confirm_required"
    assert granted["ok"] is True and granted["version"] == "1.2.4", granted


# --- nobody may stage the file that bounds them ---------------------------------------


def test_a_run_may_not_commit_its_own_ceiling(tmp_path):
    patcher, root = _workspace(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    (root / CEILING_PATH).write_text('{"version": 1, "repo": "release"}', encoding="utf-8")
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    audit.clear_audit()
    with patcher, grant_env(repo="release", actor="schedule:nightly"):
        out = workflow_execute.commit_all("t", message="widen the ladder")
    assert out["ok"] is False and out["error"] == "denied_repo_ceiling_path", out
    assert CEILING_PATH in out["ceilingPaths"]
    assert _staged(root) == []
    floor = _events("floor_denied")
    assert floor and floor[0]["detail"].startswith("denied_repo_ceiling_path"), floor
    assert floor[0]["actor"] == "schedule:nightly"


def test_the_whole_ceiling_directory_is_off_limits(tmp_path):
    patcher, root = _workspace(tmp_path)
    (root / ".ncc").mkdir()
    (root / ".ncc" / "hooks.json").write_text("{}", encoding="utf-8")
    with patcher, grant_env(repo="release"):
        out = workflow_execute.commit_all("t", message="x", paths=[".ncc"])
    assert out["ok"] is False and out["error"] == "denied_repo_ceiling_path", out


def test_a_human_may_not_stage_it_through_the_tool_either(tmp_path):
    """The floor binds the operator's CLI call too — that is what makes it a floor."""
    patcher, root = _workspace(tmp_path)
    with patcher:
        out = workflow_execute.commit_all("t", message="x", paths=[CEILING_PATH])
    assert out["ok"] is False and out["error"] == "denied_repo_ceiling_path", out


def test_ordinary_work_beside_the_directory_is_unaffected(tmp_path):
    patcher, root = _workspace(tmp_path)
    (root / "docs").mkdir()
    (root / "docs" / ".nccnotes.md").write_text("fine\n", encoding="utf-8")
    with patcher, grant_env(repo="commit"):
        out = workflow_execute.commit_all("t", message="docs: note", paths=["docs/.nccnotes.md"])
    assert out["ok"] is True, out


def test_the_argv_floor_refuses_the_ceiling_path_by_name():
    for argv in (
        ["add", "--", CEILING_PATH],
        ["commit", "-m", "widen", "--", ".ncc"],
        ["rm", "--cached", "--", CEILING_PATH],
    ):
        verdict = permissions.check_git_argv(argv)
        assert verdict.allowed is False and verdict.code == "denied_repo_ceiling_path", (argv, verdict)


# --- permissions show tells the truth about it ----------------------------------------


def test_permissions_show_reports_the_repositorys_own_narrowing(tmp_path, capsys):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"version": 1, "repo": "commit"}')
    from core.store.preferences import set_active_workspace_id
    from core.store.workspaces import upsert_workspace

    upsert_workspace(workspace_id="lowered", path=str(root), label="Lowered")
    set_active_workspace_id("lowered")
    with mock.patch.dict(os.environ, {permissions.ENV_REPO_CEILING: "pr"}):
        rc = cli.main(["permissions", "show", "--json"])
    assert rc == 0, rc
    payload = json.loads(capsys.readouterr().out)
    assert payload["repoFile"]["ceiling"] == "commit"
    assert payload["repoFile"]["workspace"] == "lowered"
    assert any(CEILING_PATH in line for line in payload["floor"])


def test_permissions_show_says_so_when_the_file_cannot_be_trusted(tmp_path, capsys):
    root = _repo(tmp_path)
    _commit_ceiling(root, '{"repo": "deploy"}')
    from core.store.preferences import set_active_workspace_id
    from core.store.workspaces import upsert_workspace

    upsert_workspace(workspace_id="broken", path=str(root), label="Broken")
    set_active_workspace_id("broken")
    rc = cli.main(["permissions", "show"])
    printed = capsys.readouterr()
    assert rc == 0, "the display does not decide; it reports what the ladder will hit"
    assert "repo_ceiling_invalid" in printed.err, printed.err


if __name__ == "__main__":
    pytest.main([__file__, "-q"])
