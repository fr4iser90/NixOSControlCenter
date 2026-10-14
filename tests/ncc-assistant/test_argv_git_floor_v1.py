"""Phase 39 §4: the floor reads argv, so a hand-built command cannot step around it.

``commit_all`` screens the pathset it builds itself. This is the same two rules one layer down,
where a caller hands ``add -A`` to git directly or a shell tool substitutes an argument into
``git add {{path}}``. The shell path loses more than that: it has no repository to read HEAD
from, no grant step and no ``git_action`` line, so writing history through it is refused rather
than guessed at — reads survive, which is all the shell tool was ever for here.
"""

from __future__ import annotations

import inspect
import json
import os
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

from ncc_assistant import audit, permissions, runtime as runtime_module, workflow_execute
from ncc_assistant.config import Settings
from test_permission_ladder_v1 import _repo, grant_env


@pytest.fixture(autouse=True)
def fresh_audit():
    """The floor's whole promise is a greppable line, so every case reads the real log."""
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


# --- blanket staging, read out of the argv ------------------------------------------


BLANKET_ARGV = (
    ["add", "-A"],
    ["add", "--all"],
    ["add", "-u"],
    ["add", "--", "."],
    ["add", "--", "./"],
    ["add", "--", "*"],
    ["add", "--", ":(glob)*"],
    ["add", "-A", "--", "notes.md"],
    ["commit", "-a", "-m", "x"],
    ["commit", "--all", "-m", "x"],
    ["commit", "-am", "x"],
    ["-C", "/srv/repo", "add", "-A"],
)


def test_a_pathset_that_names_nothing_is_refused_in_the_argv():
    for argv in BLANKET_ARGV:
        verdict = permissions.check_git_argv(argv)
        assert verdict.allowed is False, argv
        assert verdict.code == "denied_blanket_path", (argv, verdict.code)
        assert verdict.hint, argv


def test_a_secret_named_in_the_argv_is_refused_in_the_argv():
    for argv in (
        ["add", "--", ".env"],
        ["add", "--", "keys/deploy.pem"],
        ["add", "--", "service-credentials.json"],
        ["commit", "-m", "x", "--", ".envrc"],
        ["add", "-f", "--", ".env"],
    ):
        verdict = permissions.check_git_argv(argv)
        assert verdict.allowed is False, argv
        assert verdict.code == "denied_secret_path", (argv, verdict.code)


def test_a_commit_message_names_no_path():
    """The message is free text: without this, the rule would refuse ordinary work."""
    for argv in (
        ["commit", "-m", "docs: note the .env file"],
        ["commit", "--message", "stage everything in credentials.json"],
        ["commit", "--message=mention *.pem handling"],
        ["commit", "-m", "fix: the . path", "--", "notes.md"],
    ):
        assert permissions.check_git_argv(argv).allowed is True, argv


def test_the_work_the_tools_actually_do_stays_allowed():
    for argv in (
        ["add", "--", "notes.md", "src/app.py"],
        ["commit", "-m", "docs: notes"],
        ["commit", "-m", "x", "--", "notes.md"],
        ["reset", "-q", "--", "notes.md"],
        ["status", "--porcelain", "--untracked-files=all"],
        ["push", "-u", "origin", "ncc/workflow-1"],
    ):
        assert permissions.check_git_argv(argv).allowed is True, argv


# --- the shell tool inherits the argv rules, and loses the writes -------------------


def test_a_shell_string_is_screened_like_an_argv():
    for command, code in (
        ("git add -A", "denied_blanket_path"),
        ("git add -- . && git commit -m x", "denied_blanket_path"),
        ("cd /srv/repo && git add -- .env", "denied_secret_path"),
        # the most specific escalation in the chain is the code that gets logged, whichever
        # invocation it sits in
        ("git add -- notes.md || git commit --no-verify -m x", "denied_hook_bypass"),
        ("cd /srv/repo && git push --force-with-lease", "denied_force_push"),
        # no space before the separator: ``shlex.split`` keeps ``--porcelain;`` in one token, so
        # the command after it used to go unexamined entirely.
        ("git status --porcelain;git commit -m x", "denied_shell_git_write"),
        ("git log --oneline -3&&git push origin ncc/x", "denied_shell_git_write"),
    ):
        verdict = permissions.check_shell_command(command)
        assert verdict.allowed is False, command
        assert verdict.code == code, (command, verdict.code)


def test_writing_git_is_out_of_reach_for_a_shell_string():
    for command in (
        "git commit -m 'docs: notes'",
        "cd /srv/repo && git checkout main && git commit -m 'escapes the floor'",
        "git push origin ncc/workflow-1",
        "git tag -a v1.2.0 -m release",
        "git reset --hard HEAD~1",
        "git status --porcelain; git commit -m 'smuggled by substitution'",
    ):
        verdict = permissions.check_shell_command(command)
        assert verdict.allowed is False, command
        assert verdict.code == "denied_shell_git_write", (command, verdict.code)
        assert "workflow" in verdict.hint, command


def test_reading_git_still_works_through_a_shell_string():
    for command in (
        "git status --porcelain",
        "git status --porcelain && git log --oneline -5",
        "git diff HEAD -- nixos",
        "git rev-parse --abbrev-ref HEAD",
        "git show HEAD:nixos/modules/x.nix",
        "git ls-remote origin",
        "git log --grep='git commit'",
    ):
        assert permissions.check_shell_command(command).allowed is True, command


def test_what_counts_as_an_action_is_refused_in_the_shell_path():
    """One list may not drift: a write worth auditing is a write the shell may not run."""
    assert workflow_execute._GIT_ACTIONS <= permissions._SHELL_FORBIDDEN_GIT_ACTIONS


# --- both entry points refuse before spawning, and say so in the log ----------------


def test_the_git_helper_refuses_a_blanket_add_and_logs_the_attempt(tmp_path):
    root = _repo(tmp_path)
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    with mock.patch.object(workflow_execute, "_run") as run:
        with grant_env(repo="commit", actor="companion"):
            out = workflow_execute._git(root, "add", "-A")
    assert run.called is False, "git must never see a refused argv"
    assert out["ok"] is False and out["returncode"] == 126
    assert out["denied"] == "denied_blanket_path"
    assert "git add -A" in out["stderr"] and "git add --" in out["stderr"]

    denied = _events("floor_denied")
    assert len(denied) == 1
    assert denied[0]["tool"] == "git add"
    assert denied[0]["actor"] == "companion"
    assert denied[0]["detail"].startswith("denied_blanket_path")
    assert _events("git_action") == [], "a refusal is not an action"


def _shell_runtime() -> runtime_module.ToolRuntime:
    return runtime_module.ToolRuntime(Settings.from_env())


SHELL_ENV = {
    "NCC_ASSISTANT_ALLOW_SHELL": "1",
    # Wide open on purpose: the floor, not the allowlist, has to be what stops these.
    "NCC_ASSISTANT_SHELL_ALLOWLIST": "git",
}


def test_the_shell_tool_refuses_a_substituted_write_and_logs_it(tmp_path):
    with mock.patch.dict(os.environ, {**SHELL_ENV, "XDG_CONFIG_HOME": str(tmp_path)}):
        runtime = _shell_runtime()
        with mock.patch.object(runtime_module.subprocess, "run") as runner:
            with grant_env(actor="schedule:argv-gap"):
                denied = runtime._call_shell_tool("stage", {"paths": "-A"}, "git add {{paths}}")
        assert runner.called is False
        assert denied["ok"] is False
        assert denied["denied"] == "denied_blanket_path"

        logged = _events("floor_denied")
        assert len(logged) == 1
        assert logged[0]["tool"] == "shell stage"
        assert logged[0]["actor"] == "schedule:argv-gap"
        assert logged[0]["detail"].startswith("denied_blanket_path")


def test_the_shell_tool_refuses_a_commit_even_though_it_is_allowlisted(tmp_path):
    """The bypass this closes: an allowlisted ``git commit`` on trunk used to reach ``sh``."""
    with mock.patch.dict(os.environ, {**SHELL_ENV, "XDG_CONFIG_HOME": str(tmp_path)}):
        runtime = _shell_runtime()
        assert runtime._shell_allowlisted("git commit -m x") is True
        with mock.patch.object(runtime_module.subprocess, "run") as runner:
            denied = runtime._call_shell_tool("commit", {}, "git commit -m x")
        assert runner.called is False
        assert denied["denied"] == "denied_shell_git_write"
        assert _events("floor_denied")[0]["actor"] == "cli", "no grant means a human is typing"


def test_a_read_only_shell_command_is_answered_by_the_allowlist_as_before(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path), "NCC_ASSISTANT_ALLOW_SHELL": "1"}):
        os.environ.pop("NCC_ASSISTANT_SHELL_ALLOWLIST", None)
        runtime = _shell_runtime()
        with mock.patch.object(runtime_module.subprocess, "run") as runner:
            out = runtime._call_shell_tool("status", {}, "git status")
    assert runner.called is False
    assert "shellAllowlist is empty" in out["error"], "the floor did not answer this one"
    assert _events("floor_denied") == []


# --- purity: the floor reads neither configuration nor a repository ------------------


def test_the_new_rules_read_no_configuration_and_spawn_nothing():
    for fn in (
        permissions._split_git_argv,
        permissions._staging_argv,
        permissions._check_staging,
        permissions.check_git_argv,
        permissions.check_shell_command,
    ):
        source = inspect.getsource(fn)
        for needle in ("os.environ", "getenv", "settings", "cfg."):
            assert needle not in source, f"{fn.__name__} consults {needle}"

    with mock.patch.object(subprocess, "run") as runner:
        for argv in BLANKET_ARGV:
            permissions.check_git_argv(argv)
        permissions.check_shell_command("git commit -m x")
    assert runner.called is False
