"""Keep the desktop and the live config out of the test run.

Two side effects a green gate must never have on the machine that runs it:

* **The operator's session.** The run path notifies on every terminal job state and the
  doomscroll intervene pauses MPRIS players, switches KWin's ``currentDesktop``, focuses the
  browser and types ``about:blank`` into it. The pre-commit hook runs this suite on that same
  desktop, so a green gate paused the operator's video, jumped them to Firefox and stole the
  window they were typing in — proven by capturing the argv of every desktop tool the run
  spawned (``Player.Pause``, ``kwin.Scripting.loadScript`` from the focus tests). Every one of
  those paths is guarded by ``shutil.which`` on its tool, so hiding the tool removes the
  capability for the whole suite instead of trusting each test to stub. A test that wants real
  argv patches ``shutil.which`` itself; its nested patch wins.
* **Written state.** audit.jsonl, budget.json, jobs and approvals all resolve through
  ``paths.config_home()`` on every call, so any test that drives the agent or a git helper
  without its own tmp home would append to the operator's real state. Pointing XDG at a
  throwaway dir removes that capability instead of asking each test to remember it; a test
  that sets XDG_CONFIG_HOME itself still wins for its own body. The fallback is still one
  call away — ``patch.dict(..., clear=True)`` deletes the throwaway too — so a tripwire
  fails any test whose writes land in the real ``~/.config/ncc-assistant``.
"""

from __future__ import annotations

import os
import shutil
import tempfile
from pathlib import Path

import pytest

#: Binaries that must never resolve inside a test process. Each one is a capability over the
#: session that runs the gate: a bubble, a paused player, a desktop switch, a focused window,
#: synthetic keystrokes. Names are matched on the basename so an absolute path is hidden too.
DESKTOP_BINARIES = frozenset(
    {
        "notify-send",
        "qdbus",
        "dbus-send",
        "hyprctl",
        "swaymsg",
        "kdotool",
        "wtype",
        "xdotool",
        "ydotool",
    }
)

#: Throwaway XDG config home for this session (set in pytest_configure, removed on exit).
_SESSION_XDG: Path | None = None

#: The operator's own audit log, resolved here while ``HOME`` is still intact.
_OPERATOR_AUDIT: Path | None = None


def _fingerprint(path: Path | None) -> tuple[int, int] | None:
    if path is None:
        return None
    try:
        stat = path.stat()
    except OSError:
        return None
    return stat.st_size, stat.st_mtime_ns


def pytest_configure(config):
    """Give the whole session a throwaway XDG config home before any module reads paths."""
    global _SESSION_XDG, _OPERATOR_AUDIT
    _SESSION_XDG = Path(tempfile.mkdtemp(prefix="ncc-assistant-tests-"))
    _OPERATOR_AUDIT = Path(os.path.expanduser("~")) / ".config" / "ncc-assistant" / "audit.jsonl"
    os.environ["XDG_CONFIG_HOME"] = str(_SESSION_XDG)


def pytest_unconfigure(config):
    if _SESSION_XDG is not None:
        shutil.rmtree(_SESSION_XDG, ignore_errors=True)


@pytest.fixture(autouse=True)
def no_desktop_side_effects(monkeypatch):
    real_which = shutil.which

    def which(cmd, *args, **kwargs):
        if os.path.basename(str(cmd)) in DESKTOP_BINARIES:
            return None
        return real_which(cmd, *args, **kwargs)

    monkeypatch.setattr(shutil, "which", which)


@pytest.fixture(autouse=True)
def operator_state_stays_writable_only_by_itself():
    """Fail the test that appended to the operator's live audit log instead of the session's.

    ``mock.patch.dict(os.environ, {...}, clear=True)`` to prove "no ambient grant" also deletes
    the session's ``XDG_CONFIG_HOME``, after which ``paths.config_home()`` resolves to
    ``~/.config``. Settle the grant with ``grant_env()`` or keep ``XDG_CONFIG_HOME`` inside the
    patched env; either way the run keeps its answer and the operator's history keeps its shape.
    """
    before = _fingerprint(_OPERATOR_AUDIT)
    yield
    after = _fingerprint(_OPERATOR_AUDIT)
    if after is not None and after != before:
        pytest.fail(
            f"This test wrote into the operator's live {_OPERATOR_AUDIT}, so the environment it "
            "patched left no XDG_CONFIG_HOME and paths resolved to ~/.config. Narrow the grant "
            "instead of clearing the env (see grant_env in test_permission_ladder_v1.py), or "
            "carry XDG_CONFIG_HOME through the patch.",
            pytrace=False,
        )

