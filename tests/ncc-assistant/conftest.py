"""Keep the desktop and the live config out of the test run.

Two side effects a green gate must never have on the machine that runs it:

* **Bubbles.** The run path notifies on every terminal job state and focus.py reminds on
  doomscroll, so on the desktop where the pre-commit hook runs this suite, a green gate popped
  a bubble per agent run — and notify_send_actions would have blocked the gate on --wait.
  Hiding the binary is the guard that also holds for a test that forgets to stub. A test that
  wants the real notify-send argv patches shutil.which itself; its nested patch wins.
* **Written state.** audit.jsonl, budget.json, jobs and approvals all resolve through
  ``paths.config_home()`` on every call, so any test that drives the agent or a git helper
  without its own tmp home would append to the operator's real state. Pointing XDG at a
  throwaway dir removes that capability instead of asking each test to remember it; a test
  that sets XDG_CONFIG_HOME itself still wins for its own body.
"""

from __future__ import annotations

import os
import shutil
import tempfile
from pathlib import Path

import pytest

#: Binaries that must never resolve inside a test process.
NOTIFY_BINARIES = frozenset({"notify-send"})

#: Throwaway XDG config home for this session (set in pytest_configure, removed on exit).
_SESSION_XDG: Path | None = None


def pytest_configure(config):
    """Give the whole session a throwaway XDG config home before any module reads paths."""
    global _SESSION_XDG
    _SESSION_XDG = Path(tempfile.mkdtemp(prefix="ncc-assistant-tests-"))
    os.environ["XDG_CONFIG_HOME"] = str(_SESSION_XDG)


def pytest_unconfigure(config):
    if _SESSION_XDG is not None:
        shutil.rmtree(_SESSION_XDG, ignore_errors=True)


@pytest.fixture(autouse=True)
def no_desktop_notifications(monkeypatch):
    real_which = shutil.which

    def which(cmd, *args, **kwargs):
        if str(cmd) in NOTIFY_BINARIES:
            return None
        return real_which(cmd, *args, **kwargs)

    monkeypatch.setattr(shutil, "which", which)
