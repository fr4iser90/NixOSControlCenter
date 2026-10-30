"""A fixture repository must be its own repository, never the checkout that runs the gate.

``git`` follows ``GIT_DIR``/``GIT_INDEX_FILE``/``GIT_WORK_TREE`` in preference to the directory it
was spawned in, and ``.githooks/pre-commit`` exports all three while it runs this suite. Before
``conftest`` removed them, a fixture that ran ``git init``/``add -A``/``commit`` in a tmp dir wrote
into the repository under development instead: its branch ref ended on the fixture's ``seed``
commit, the index was replaced by the fixture's file list, ``core.bare`` and a test identity
appeared in ``.git/config`` — and a fixture that pushed would have pushed that repository to its
real remote. The suite runs real git on purpose, so the guard is the removed capability plus this
witness that it stayed removed.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

from conftest import GIT_REPO_ENV


def _git(root: Path, *args: str) -> str:
    """Run git the way the fixtures do — inheriting the session env, in the fixture's own dir."""
    result = subprocess.run(
        ["git", *args],
        cwd=root,
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
    assert result.returncode == 0, f"git {' '.join(args)}: {result.stderr}"
    return result.stdout.strip()


def test_the_session_carries_no_pointer_to_another_repository():
    leaked = {name: os.environ[name] for name in GIT_REPO_ENV if os.environ.get(name)}
    assert not leaked, (
        "These variables make every fixture's git call act on a repository other than its own, "
        f"so a gate run would rewrite it: {sorted(leaked)}. conftest removes them for the session."
    )


def test_a_fixture_commit_lands_in_the_fixture(tmp_path):
    root = tmp_path / "repo"
    root.mkdir()
    _git(root, "init", "-b", "main")
    (root / "notes.md").write_text("seed\n", encoding="utf-8")
    _git(root, "add", "-A")
    _git(root, "commit", "-m", "seed")

    assert Path(_git(root, "rev-parse", "--absolute-git-dir")) == (root / ".git").resolve()
    assert Path(_git(root, "rev-parse", "--show-toplevel")) == root.resolve()
    assert _git(root, "status", "--porcelain") == ""
    assert _git(root, "log", "--format=%s") == "seed"


def test_the_checkout_under_development_keeps_its_own_shape(tmp_path):
    """The exact damage this guard exists for, measured on the repository running the suite."""
    assert Path(_git(REPO, "rev-parse", "--absolute-git-dir")) != (tmp_path / ".git").resolve()
    assert _git(REPO, "rev-parse", "--is-bare-repository") == "false"
    assert _git(REPO, "log", "-1", "--format=%s") not in {"seed", "init"}
    identity = subprocess.run(
        ["git", "config", "--local", "--get", "user.email"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    assert identity.stdout.strip() != "test@example.invalid", (
        f"A fixture wrote its identity into {REPO}'s .git/config, so this repository is the one "
        "the fixtures have been committing to."
    )
