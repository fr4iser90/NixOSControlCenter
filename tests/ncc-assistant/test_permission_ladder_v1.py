"""Phase 39 P0: the permission ladder narrows runs, the floor denies by code."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from cli import cli
from core.policy import permissions
from core.workflows import workflow_execute
from core.store.config import Settings

FLOOR_COMMANDS = (
    ["push", "--force"],
    ["push", "--force-with-lease"],
    ["push", "-f", "origin", "ncc/x"],
    ["push", "origin", "+main"],
    ["push", "-o", "force=true", "origin", "ncc/x"],
    ["-c", "commit.gpgsign=false", "commit", "-m", "x"],
    ["commit", "--no-verify", "-m", "x"],
)


def _git(root: Path, *args: str) -> None:
    subprocess.run(
        ["git", *args],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
        env={
            **os.environ,
            "GIT_AUTHOR_NAME": "test",
            "GIT_AUTHOR_EMAIL": "test@example.invalid",
            "GIT_COMMITTER_NAME": "test",
            "GIT_COMMITTER_EMAIL": "test@example.invalid",
        },
    )


#: A workspace mid-task stands on an agent branch: ``commit``/``push`` refuse anywhere else, so
#: a fixture that means "the tool may work" has to start there. Tests about trunk say so with
#: ``branch="main"``.
AGENT_BRANCH = "ncc/workflow-test"


def _repo(tmp_path: Path, *, branch: str = AGENT_BRANCH, with_origin: bool = False) -> Path:
    root = tmp_path / "repo"
    root.mkdir()
    _git(root, "init", "-b", branch)
    _git(root, "config", "user.email", "test@example.invalid")
    _git(root, "config", "user.name", "test")
    (root / "README.md").write_text("seed\n", encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "seed")
    if with_origin:
        origin = tmp_path / "origin.git"
        _git(tmp_path, "init", "--bare", str(origin))
        _git(root, "remote", "add", "origin", str(origin))
    return root


@contextmanager
def grant_env(**steps: str):
    """Set the grant for one call without clearing PATH — these tests run real git."""
    keys = {
        "repo": permissions.ENV_REPO,
        "system": permissions.ENV_SYSTEM,
        "ceiling": permissions.ENV_REPO_CEILING,
        "actor": permissions.ENV_ACTOR,
    }
    saved = {name: os.environ.pop(keys[name], None) for name in keys}
    for name, value in steps.items():
        if value is not None:
            os.environ[keys[name]] = str(value)
    try:
        yield
    finally:
        for name in keys:
            os.environ.pop(keys[name], None)
            if saved[name] is not None:
                os.environ[keys[name]] = saved[name]


# --- parsing and precedence ---------------------------------------------------------


def test_grant_pairs_parse_and_normalise():
    assert permissions.parse_grant_pairs(["repo=pr", "system=none"]) == {"repo": "pr", "system": "none"}
    assert permissions.parse_grant_pairs(["REPO=PR"]) == {"repo": "pr"}
    assert permissions.normalise_step("system", "config_write") == "config-write"
    assert permissions.normalise_step("repo", "nonsense") is None


def test_bad_grant_pair_is_refused_with_the_allowed_steps():
    try:
        permissions.parse_grant_pairs(["repo=deploy"])
    except ValueError as exc:
        assert "deploy" in str(exc) and "observe" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("bad step must raise")


def test_ceiling_narrows_and_naming_the_source_is_loud():
    grant, violations = permissions.resolve_grant(
        requested={"repo": "merge"},
        repo_ceiling="pr",
        system_ceiling_step="config-write",
    )
    assert grant.repo == "pr", "clamp to the ceiling instead of running with more"
    assert len(violations) == 1
    assert "merge exceeds host ceiling pr" in violations[0]
    assert "--grant" in violations[0], "the message must name where the request came from"

    from_env, env_violations = permissions.resolve_grant(
        repo_ceiling="observe",
        env={permissions.ENV_REPO: "push"},
    )
    assert from_env.repo == "observe"
    assert permissions.ENV_REPO in env_violations[0]


def test_asking_within_the_ceiling_is_silent():
    grant, violations = permissions.resolve_grant(
        requested={"repo": "commit", "system": "config-write"},
        repo_ceiling="pr",
        system_ceiling_step="config-write",
    )
    assert (violations, grant.repo, grant.system) == ([], "commit", "config-write")


# --- the ladder gates actions, and stays out of the way without a grant --------------


def test_without_grant_context_nothing_changes():
    with mock.patch.dict(os.environ, {}, clear=True):
        assert permissions.current_grant() is None
        for action in ("read", "commit", "push", "pr", "merge", "release"):
            assert permissions.evaluate_repo(action).allowed is True, action
        for action in ("config_write", "rebuild"):
            assert permissions.evaluate_system(action).allowed is True, action


def test_repo_ladder_gates_by_action():
    with grant_env(repo="propose"):
        assert permissions.evaluate_repo("read").allowed is True
        assert permissions.evaluate_repo("propose").allowed is True
        denied = permissions.evaluate_repo("commit")
        assert denied.allowed is False and denied.code == "grant_insufficient"
        assert "--grant repo=commit" in denied.hint

    with grant_env(repo="pr"):
        assert permissions.evaluate_repo("push").allowed is True
        assert permissions.evaluate_repo("merge").allowed is False
        assert permissions.evaluate_repo("release").allowed is False


def test_system_ladder_gates_by_action():
    with grant_env(system="config-write"):
        assert permissions.evaluate_system("config_write").allowed is True
        assert permissions.evaluate_system("rebuild").code == "grant_insufficient"


def test_unknown_action_is_denied_not_allowed():
    with grant_env(repo="pr"):
        verdict = permissions.evaluate_repo("rm_rf")
        assert verdict.allowed is False and verdict.code == "unknown_action"


# --- floor: below the ladder, no configuration re-enables these ---------------------


def test_force_push_and_hook_bypass_are_denied():
    for argv in FLOOR_COMMANDS:
        verdict = permissions.check_git_argv(argv)
        assert verdict.allowed is False, argv
        assert verdict.code in ("denied_force_push", "denied_hook_bypass"), (argv, verdict.code)


def test_ordinary_git_still_passes_the_floor():
    for argv in (
        ["status", "--porcelain"],
        ["add", "--", "notes.md"],
        ["commit", "-m", "feat: x"],
        ["push", "-u", "origin", "ncc/x"],
        ["-c", "user.name=x", "commit", "-m", "y"],
    ):
        assert permissions.check_git_argv(argv).allowed is True, argv


def test_shell_string_is_checked_too():
    verdict = permissions.check_shell_command("cd /tmp && git push --force-with-lease")
    assert verdict.allowed is False and verdict.code == "denied_force_push"
    assert permissions.check_shell_command("git status --porcelain").allowed is True
    assert permissions.check_shell_command("git add -A; git commit -m x").allowed is False


def test_secret_paths_and_renames():
    hits = permissions.secret_paths(
        [".env", "x509-server.pem", "credentials.json", "id_ed25519", "src/main.py"]
    )
    assert hits == [".env", "x509-server.pem", "credentials.json", "id_ed25519"]
    # git status --porcelain lines and renames must be readable as paths
    assert permissions.secret_paths(["?? x509-server.pem", " M .env"]) == ["x509-server.pem", ".env"]
    assert permissions.secret_paths(["A  notes.md -> .env.local"]) == [".env.local"]
    assert permissions.secret_paths(["src/app.py", "README.md"]) == []


def test_protected_and_agent_branches():
    assert permissions.protected_branch("main") and permissions.protected_branch("master")
    assert not permissions.protected_branch("ncc/x")
    assert permissions.protected_branch("release", extra=("release",))
    assert permissions.is_agent_branch("ncc/task-12") and not permissions.is_agent_branch("main")


# --- transport: the workflow tools themselves ---------------------------------------


def test_git_helper_denies_before_any_subprocess(tmp_path):
    root = _repo(tmp_path)
    with mock.patch.object(workflow_execute, "_run") as run:
        out = workflow_execute._git(root, "push", "--force")
    assert run.called is False, "the floor must deny before spawning git"
    assert out["denied"] == "denied_force_push" and out["returncode"] == 126


def test_commit_all_needs_repo_commit_and_never_stages_secrets(tmp_path):
    root = _repo(tmp_path)
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="propose"):
            out = workflow_execute.commit_all("t", message="docs: notes")
        assert out["ok"] is False and out["denied"] == "grant_insufficient"

        # Enough grant, but a credential-looking file is in the tree: nothing gets staged.
        (root / ".env").write_text("SECRET=1\n", encoding="utf-8")
        with grant_env(repo="commit"):
            out = workflow_execute.commit_all("t", message="docs: notes")
        assert out["ok"] is False and out["error"] == "denied_secret_path"
        assert ".env" in out["secretPaths"]
        assert _git_out(root, "status", "--porcelain").count("\n") == 2, "still unstaged"


def test_push_is_denied_on_a_protected_branch(tmp_path):
    root = _repo(tmp_path, branch="main", with_origin=True)
    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="pr"):
            out = workflow_execute.push_branch("t")
        assert out["ok"] is False and out["error"] == "denied_protected_branch"

        # Without any grant context the human flow keeps working as before.
        with grant_env():
            verdict = permissions.evaluate_repo("push")
        assert verdict.allowed is True


def test_merge_and_bump_need_the_grant_not_a_token_the_model_can_type(tmp_path):
    root = _repo(tmp_path)
    (root / "package.json").write_text(json.dumps({"version": "1.2.3"}), encoding="utf-8")
    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="pr"):
            out = workflow_execute.merge_pull_request("t", pr="7", confirm="CONFIRM")
            assert out["ok"] is False and out["denied"] == "grant_insufficient"
            bump = workflow_execute.bump_version("t", confirm="CONFIRM")
            assert bump["ok"] is False and bump["denied"] == "grant_insufficient"

        # No grant context: the documented CONFIRM token keeps its old meaning.
        with grant_env():
            no_token = workflow_execute.bump_version("t", confirm="")
            assert no_token["ok"] is False and no_token["error"] == "confirm_required"


# --- run wiring --------------------------------------------------------------------


def _settings() -> Settings:
    return Settings.from_env()


def test_no_grant_requested_leaves_the_ladder_out():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(os.environ, {}, clear=True):
        grant, violations = resolve_run_grant(_settings(), ())
    assert grant is None and violations == []


def test_grant_above_the_host_ceiling_is_a_violation_not_a_run():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(os.environ, {permissions.ENV_REPO_CEILING: "push"}, clear=True):
        grant, violations = resolve_run_grant(_settings(), ["repo=merge"])
    assert grant.repo == "push" and violations, violations
    assert "merge exceeds host ceiling push" in violations[0]


def test_schedule_grant_narrows_below_the_host():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(
        os.environ,
        {
            permissions.ENV_REPO_CEILING: "merge",
            permissions.ENV_ACTOR: "schedule",
            "NCC_ASSISTANT_ALLOW_WRITE": "1",
            "NCC_ASSISTANT_ALLOW_REBUILD": "1",
        },
        clear=True,
    ):
        grant, violations = resolve_run_grant(_settings(), ["repo=push", "system=none"])
    assert violations == []
    assert (grant.repo, grant.system, grant.actor) == ("push", "none", "schedule")


# --- two knobs, one ceiling ----------------------------------------------------------
# schedules.nix clamps a unit by agent.allowWrite/agent.allowRebuild while the runtime read
# only the host-wide pair, so the same grant meant two different things. The run now holds
# to the lower of the two, and an unset agent pair declares nothing.


def test_the_agent_pair_is_a_ceiling_too():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(
        os.environ,
        {
            "NCC_ASSISTANT_ALLOW_WRITE": "1",
            "NCC_ASSISTANT_ALLOW_REBUILD": "1",
            "NCC_ASSISTANT_AGENT_ALLOW_WRITE": "0",
        },
        clear=True,
    ):
        grant, violations = resolve_run_grant(_settings(), ["system=config-write"])

    assert grant.system == "none", "the agent option closed what the host option opened"
    assert "system=config-write exceeds host ceiling none" in violations[0]
    assert "agent.allowWrite" in violations[0], "the refusal must name the knob that clamped"


def test_an_undeclared_agent_pair_leaves_the_host_ceiling_alone():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(os.environ, {"NCC_ASSISTANT_ALLOW_WRITE": "1"}, clear=True):
        grant, violations = resolve_run_grant(_settings(), ["system=config-write"])

    assert violations == [], "a bare shell declares no agent ceiling"
    assert grant.system == "config-write"


def test_the_agent_pair_never_opens_what_the_host_closed():
    from core.runtime.agent import resolve_run_grant

    with mock.patch.dict(
        os.environ,
        {
            "NCC_ASSISTANT_ALLOW_WRITE": "1",
            "NCC_ASSISTANT_ALLOW_REBUILD": "0",
            "NCC_ASSISTANT_AGENT_ALLOW_WRITE": "1",
            "NCC_ASSISTANT_AGENT_ALLOW_REBUILD": "1",
        },
        clear=True,
    ):
        grant, violations = resolve_run_grant(_settings(), ["system=rebuild"])

    assert grant.system == "config-write" and violations
    assert "agent.allowWrite" not in violations[0], "here the host was the narrower knob"


def test_an_unset_agent_gate_is_not_a_declared_no():
    with mock.patch.dict(os.environ, {}, clear=True):
        unset = Settings.from_env()
        assert (unset.agent_allow_write, unset.agent_allow_rebuild) == (None, None)

    with mock.patch.dict(os.environ, {"NCC_ASSISTANT_AGENT_ALLOW_WRITE": "0"}, clear=True):
        declared = Settings.from_env()
        assert declared.agent_allow_write is False

    assert permissions.agent_axis_ceiling(None, None) is None
    assert permissions.agent_axis_ceiling(True, None) == "config-write"
    assert permissions.agent_axis_ceiling(True, True) == "rebuild"
    assert permissions.agent_axis_ceiling(False, False) == "none"


# --- CLI surface -------------------------------------------------------------------


def test_permissions_show_reports_ceiling_effective_and_floor(capsys):
    argv = ["permissions", "show", "--grant", "repo=commit", "--json"]
    with mock.patch.dict(
        os.environ,
        {permissions.ENV_REPO_CEILING: "pr", permissions.ENV_ACTOR: "cli"},
        clear=True,
    ):
        rc = cli.main(argv)
    assert rc == 0, rc
    payload = json.loads(capsys.readouterr().out)
    assert payload["ceiling"]["repo"] == "pr"
    assert payload["effective"]["repo"] == "commit"
    assert payload["violations"] == []
    assert "force-push" in " ".join(payload["floor"])
    assert "main" in payload["protectedBranches"]


def test_permissions_show_exits_nonzero_when_asked_over_ceiling(capsys):
    with mock.patch.dict(os.environ, {permissions.ENV_REPO_CEILING: "observe"}, clear=True):
        rc = cli.main(["permissions", "show", "--grant", "repo=push", "--json"])
    assert rc == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["violations"] and payload["effective"]["repo"] == "observe"


def _git_out(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout
