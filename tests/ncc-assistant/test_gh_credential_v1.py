"""The credential a ``gh`` verb carries, and the boundary that keeps it out of everything else.

A schedule has no terminal, so ``gh auth login`` cannot produce the login an unattended
``ncc ai workflow pr`` needs — while the PAT that template already requires sat in
``secrets.json`` and reached only the GitHub MCP server. These tests spawn a fake ``gh`` that
reports its own environment, so what gets asserted is the credential a real child process was
handed, not a line of source text. The mirror case matters just as much: the credential is built
per invocation, so a token published for ``gh`` cannot be inherited by an allowlisted shell
command, the external harness, or a git hook.
"""

from __future__ import annotations

import os
import sys
from contextlib import ExitStack, contextmanager
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.store.secrets import set_secret
from core.workflows import workflow_execute, workflows
from core.workflows.gh_env import gh_env
from test_permission_ladder_v1 import grant_env

TOKEN = "ghp_credential_boundary_not_real"


def _fake_gh(bin_dir: Path, *, echo_token: bool = True) -> None:
    """A ``gh`` that answers with the credential it was launched with.

    Prints ``{"token": ...}`` so ``_gh_json`` parses it, and so the value proven here is the one
    the child actually held rather than the one the parent meant to pass.
    """
    bin_dir.mkdir(parents=True, exist_ok=True)
    body = 'printf \'{"token":"%s"}\\n\' "$GH_TOKEN"\n' if echo_token else 'printf \'{"token":""}\\n\'\n'
    script = bin_dir / "gh"
    script.write_text(f"#!/bin/sh\n{body}", encoding="utf-8")
    script.chmod(0o755)


@contextmanager
def _cleared_token_env(tmp_path: Path, *, gh: bool = True):
    """A config home holding the secret, with no ambient credential pretending to be the grant."""
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        for name in ("GH_TOKEN", "GITHUB_TOKEN"):
            os.environ.pop(name, None)
        bin_dir = tmp_path / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        if gh:
            _fake_gh(bin_dir)
        os.environ["PATH"] = f"{bin_dir}{os.pathsep}{os.environ['PATH']}"
        yield


# --- the credential reaches the verb that needs it ---------------------------------------


def test_the_stored_secret_reaches_a_real_gh_invocation(tmp_path):
    with _cleared_token_env(tmp_path):
        set_secret("github_token", TOKEN)
        out = workflows._gh_json(["pr", "view", "--json", "url"], cwd=str(tmp_path))

    assert out == {"token": TOKEN}, "gh was launched without the credential it cannot ask for"


def test_the_gh_that_carries_a_token_never_names_itself_the_owner(tmp_path):
    """The run's own environment stays empty: a child later on must not inherit the credential."""
    with _cleared_token_env(tmp_path):
        set_secret("github_token", TOKEN)
        workflows._gh_json(["pr", "view", "--json", "url"], cwd=str(tmp_path))
        assert "GH_TOKEN" not in os.environ, "the token was published process-wide"


def test_no_credential_anywhere_leaves_the_gh_state_alone(tmp_path):
    """Without a stored secret, gh keeps using the login of the account the run carries."""
    with _cleared_token_env(tmp_path):
        out = workflows._gh_json(["pr", "view", "--json", "url"], cwd=str(tmp_path))

    assert out == {"token": ""}, "an empty credential slot must stay empty, not be invented"


# --- precedence: what the unit said out loud outranks what the store holds ----------------


def test_an_ambient_gh_token_is_left_exactly_as_it_is(tmp_path):
    with _cleared_token_env(tmp_path):
        set_secret("github_token", TOKEN)
        os.environ["GH_TOKEN"] = "ghp_ambient_wins"
        env = gh_env()

    assert env["GH_TOKEN"] == "ghp_ambient_wins"


def test_an_ambient_github_token_counts_as_an_answer_too(tmp_path):
    with _cleared_token_env(tmp_path):
        set_secret("github_token", TOKEN)
        os.environ["GITHUB_TOKEN"] = "gho_ambient"
        env = gh_env()

    assert env.get("GH_TOKEN") is None, "an existing GitHub credential must not be overridden"


# --- the boundary: git and its hooks are not GitHub-capable -------------------------------


def test_a_git_child_is_never_handed_the_github_credential(tmp_path):
    """``_run`` is shared by git and gh; the credential has to stay on the gh side of that call."""
    # A plain directory, not a git fixture: the ``git`` below is the fake on PATH, and a real
    # ``git init`` here would inherit the pre-commit hook's GIT_DIR/GIT_INDEX_FILE and reach the
    # checkout running the gate.
    root = tmp_path / "repo"
    root.mkdir()
    with _cleared_token_env(tmp_path, gh=False):
        set_secret("github_token", TOKEN)
        probe = tmp_path / "child-token"
        fake_git = tmp_path / "bin" / "git"
        fake_git.write_text(
            f'#!/bin/sh\nprintf "%s" "${{GH_TOKEN-}}" > "{probe}"\n',
            encoding="utf-8",
        )
        fake_git.chmod(0o755)

        res = workflow_execute._run(["git", "rev-parse", "HEAD"], cwd=root)

    assert res["ok"] is True, res
    assert probe.read_text(encoding="utf-8") == "", "a git hook can now push as the agent's account"


def test_the_merge_verb_is_spawned_with_the_credential_and_git_is_not(tmp_path):
    """Same helper, two callers: ``gh pr merge`` gets the token, the surrounding git does not."""
    root = tmp_path / "repo"
    root.mkdir()
    seen: list[tuple[str, str | None]] = []

    def dispatch(cmd, *args, **kwargs):
        seen.append((str(cmd[0]), (kwargs.get("env") or {}).get("GH_TOKEN")))
        return {"ok": True, "cmd": list(cmd), "returncode": 0, "stdout": "ncc/integration", "stderr": ""}

    with _cleared_token_env(tmp_path, gh=False):
        set_secret("github_token", TOKEN)
        with ExitStack() as stack:
            for patcher in (
                mock.patch.object(workflow_execute.shutil, "which", return_value="/usr/bin/gh"),
                mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)),
                mock.patch.object(workflow_execute, "_run", side_effect=dispatch),
            ):
                stack.enter_context(patcher)
            with grant_env(repo="merge", actor="cli"):
                out = workflow_execute.merge_pull_request("t", pr="4")

    assert out["ok"] is True, out
    assert [name for name, _ in seen if name == "gh"], "gh was never spawned, so nothing was proven"
    assert all(tok == TOKEN for name, tok in seen if name == "gh"), "gh ran without the credential"
    assert all(tok is None for name, tok in seen if name == "git"), "git inherited the GitHub credential"
