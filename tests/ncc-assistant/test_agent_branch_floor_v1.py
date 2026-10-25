"""Phase 39 §4: ``commit``/``push`` happen on ``ncc/…`` only — below the ladder, for anyone.

``ensure_branch`` already refuses to *create* a branch outside ``ncc/workflow-…``, but HEAD can
land on trunk without going through that door: a workspace resumed after a merge, a checkout a
human made, a schedule that never branched. The prefix is therefore a precondition of the two
writing steps themselves, checked before the index is touched, and a refusal carries
``denied_non_agent_branch`` so the audit reads as an attempted escalation.
"""

from __future__ import annotations

import inspect
import json
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import audit, permissions
from core.store import paths
from core.workflows import workflow_execute
from test_permission_ladder_v1 import AGENT_BRANCH, _git, _repo, grant_env

CODE = "denied_non_agent_branch"


@pytest.fixture(autouse=True)
def fresh_audit():
    """One test, one log — the breach assertions below count lines in a shared XDG home."""
    audit.clear_audit()
    yield


def _git_out(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout


def _events(event: str) -> list[dict]:
    path = paths.audit_file()
    if not path.is_file():
        return []
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [r for r in rows if r.get("event") == event]


def _work(root: Path, name: str = "notes.md") -> Path:
    """One untracked file — the pathset ``commit_all`` would stage if the floor let it."""
    path = root / name
    path.write_text("work\n", encoding="utf-8")
    return path


def _at(root: Path, branch: str, *, with_origin: bool = False):
    """Put a workspace onto ``branch`` and watch ``_repo_root`` return it."""
    _git(root, "checkout", "-b", branch)
    return mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root))


# --- the rule itself ---------------------------------------------------------------


def test_the_floor_wants_the_prefix_not_the_creation_pattern():
    """Renaming by hand is allowed; being on someone's trunk is not. ``ncc/`` is the line."""
    assert permissions.check_branch("ncc/workflow-7").allowed is True
    assert permissions.check_branch("ncc/release-notes").allowed is True

    for branch in ("main", "master", "feature/wedding-plans", "develop", "trunk"):
        verdict = permissions.check_branch(branch)
        assert verdict.allowed is False and verdict.code == CODE, branch
        assert branch in verdict.reason
        assert "ncc/" in verdict.hint

    # No branch at all answers the same way: nothing to land on is not permission for trunk.
    for absent in ("HEAD", "", None):
        verdict = permissions.check_branch(absent)
        assert verdict.allowed is False and verdict.code == CODE, absent


def test_the_rule_names_which_step_it_refused():
    assert "commit" in permissions.check_branch("main", action="commit").reason
    assert "push" in permissions.check_branch("main", action="push").reason


# --- commit -------------------------------------------------------------------------


def test_a_commit_on_trunk_is_refused_and_leaves_nothing_behind(tmp_path):
    """The order matters: refusing after ``git add`` would leave this run's pathset staged."""
    root = _repo(tmp_path)
    _git(root, "checkout", "-b", "main")
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release", actor="schedule:nightly"):
            out = workflow_execute.commit_all("t", message="docs: notes")

    assert out["ok"] is False and out["error"] == CODE and out["committed"] is False
    assert out["branch"] == "main"
    assert _git_out(root, "diff", "--cached", "--numstat") == "", "index untouched"
    assert len(_git_out(root, "log", "--oneline").splitlines()) == 1, "no commit was made"
    assert "notes.md" in _git_out(root, "status", "--porcelain"), "the work is still there"


def test_a_commit_refused_on_trunk_is_refused_with_no_grant_at_all(tmp_path):
    """§4 sits below the ladder: a human at the CLI is refused for the same reason, by the
    same code — and the hint tells them to run git themselves."""
    root = _repo(tmp_path)
    _git(root, "checkout", "-b", "main")
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env():
            out = workflow_execute.commit_all("t", message="docs: notes")

    assert out["ok"] is False and out["denied"] == CODE
    assert out["hint"], "the refusal has to say what to do instead"


def test_a_detached_head_is_not_a_place_to_commit(tmp_path):
    root = _repo(tmp_path)
    _git(root, "checkout", "--detach")
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release"):
            out = workflow_execute.commit_all("t", message="docs: notes")

    assert out["ok"] is False and out["denied"] == CODE
    assert "detached" in out["reason"]
    assert _git_out(root, "diff", "--cached", "--numstat") == ""


def test_the_agent_branch_is_the_normal_case_and_still_commits(tmp_path):
    """Control: this floor is a fence around trunk, not a halt to the workflow."""
    root = _repo(tmp_path)
    assert _git_out(root, "rev-parse", "--abbrev-ref", "HEAD").strip() == AGENT_BRANCH
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="commit"):
            out = workflow_execute.commit_all("t", message="docs: notes")

    assert out["ok"] is True and out["committed"] is True, out
    assert len(_git_out(root, "log", "--oneline").splitlines()) == 2


# --- push ---------------------------------------------------------------------------


def test_pushing_a_branch_that_no_host_protects_is_still_refused(tmp_path):
    """``protected_branch`` covers trunk; a colleague's branch is the gap this closes."""
    root = _repo(tmp_path, branch="feature/wedding-plans", with_origin=True)
    assert permissions.protected_branch("feature/wedding-plans") is False

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release", actor="companion"):
            out = workflow_execute.push_branch("t")

    assert out["ok"] is False and out["error"] == CODE and out["branch"] == "feature/wedding-plans"
    assert _git_out(root, "ls-remote", "--heads", "origin").strip() == "", "nothing went public"


def test_push_without_a_grant_refuses_to_publish_someone_elses_branch(tmp_path):
    """The behaviour change a human will notice: ``ncc workflow push`` off an agent branch is
    no longer a plain push, whatever the grant says."""
    root = _repo(tmp_path, branch="scratch/try-this", with_origin=True)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env():
            out = workflow_execute.push_branch("t")

    assert out["ok"] is False and out["denied"] == CODE
    assert _git_out(root, "ls-remote", "--heads", "origin").strip() == ""


def test_trunk_still_answers_with_the_protected_branch_code(tmp_path):
    """The specific rule keeps winning: ``main`` is protected, and that is what the audit
    should say rather than the generic prefix refusal."""
    root = _repo(tmp_path, branch="main", with_origin=True)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release"):
            out = workflow_execute.push_branch("t")

    assert out["ok"] is False and out["error"] == "denied_protected_branch"


def test_pushing_the_agent_branch_still_works(tmp_path):
    """Control: the whole point of the tool is unchanged on ``ncc/…``."""
    root = _repo(tmp_path, with_origin=True)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="push"):
            out = workflow_execute.push_branch("t")

    assert out["ok"] is True, out
    assert AGENT_BRANCH in _git_out(root, "ls-remote", "--heads", "origin")


# --- the version bump is refused before it writes ------------------------------------


def test_a_version_bump_refuses_before_it_touches_package_json(tmp_path):
    """The bump commits what it just wrote. Refusing that commit afterwards would leave a
    version number on disk that nothing recorded, so the floor is checked first."""
    root = _repo(tmp_path)
    _git(root, "checkout", "-b", "main")
    pkg = root / "package.json"
    pkg.write_text(json.dumps({"name": "x", "version": "1.2.3"}), encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "chore: package")
    before = pkg.read_text(encoding="utf-8")

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release", actor="schedule:release-notes"):
            out = workflow_execute.bump_version("t", confirm="CONFIRM")

    assert out["ok"] is False and out["denied"] == CODE
    assert pkg.read_text(encoding="utf-8") == before, "no unrecorded version on disk"
    assert _git_out(root, "status", "--porcelain") == ""


# --- what the log says --------------------------------------------------------------


def test_every_branch_refusal_is_a_floor_denial_in_the_audit(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    _git(root, "checkout", "-b", "main")
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="release", actor="schedule:nightly"):
            assert workflow_execute.commit_all("t", message="x")["denied"] == CODE
            assert workflow_execute.push_branch("t")["error"] == "denied_protected_branch"

    denied = _events("floor_denied")
    assert [d["tool"] for d in denied] == ["git commit", "git push"]
    assert all(d["actor"] == "schedule:nightly" and d["result"] == "denied" for d in denied)
    assert denied[0]["detail"].startswith(CODE)


def test_a_refused_commit_on_an_agent_branch_audits_nothing_extra(tmp_path):
    """Control for the line above: the floor stays quiet when it is satisfied."""
    root = _repo(tmp_path)
    _work(root)

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="commit"):
            assert workflow_execute.commit_all("t", message="docs: notes")["ok"] is True

    assert _events("floor_denied") == []


# --- the floor cannot be configured, and the pack attacks it -------------------------


def test_the_branch_floor_reads_no_configuration():
    source = inspect.getsource(permissions.check_branch)
    for needle in ("os.environ", "getenv", "settings", "cfg."):
        assert needle not in source, f"check_branch consults {needle}"


def test_the_red_team_pack_attacks_the_prefix_on_both_steps():
    from core.policy import red_team

    attempts = [a for a in red_team.FLOOR_ATTEMPTS if a.code == CODE]
    assert attempts, "the floor grew a rule the pack never asks about"
    assert {a.rule for a in attempts} == {"non_agent_branch"}
    assert any("git commit" in a.attempt for a in attempts) and any(
        "git push" in a.attempt for a in attempts
    )

    # Control cases live under ``ordinary_work`` on purpose: a floor that refused every branch
    # would pass the attacks above while making the workflow unusable.
    controls = [a for a in red_team.FLOOR_PERMITTED if "HEAD=" in a.attempt]
    assert len(controls) == 2, controls
    assert all(a.expect_denied is False and a.probe().allowed for a in controls), controls


def test_branch_names_are_never_run_as_shell():
    """The floor is pure, and the branch name reaches it from ``rev-parse`` — no probe here
    may spawn git, or the GUI button would be checking out branches."""
    with mock.patch.object(subprocess, "run") as runner:
        permissions.check_branch("main; rm -rf /")
    assert runner.called is False


if __name__ == "__main__":
    pytest.main([__file__, "-q"])
