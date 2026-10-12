"""Keep the desktop out of the test run.

The run path notifies on every terminal job state and focus.py reminds on doomscroll, so on
the developer desktop that runs this suite from the pre-commit hook, a green gate popped a
bubble per agent run — and notify_send_actions would have blocked the gate on --wait. Hiding
the binary is the guard that also holds for a test that forgets to stub. A test that wants the
real notify-send argv patches shutil.which itself; its nested patch wins over this fixture.
"""

from __future__ import annotations

import shutil

import pytest

#: Binaries that must never resolve inside a test process.
NOTIFY_BINARIES = frozenset({"notify-send"})


@pytest.fixture(autouse=True)
def no_desktop_notifications(monkeypatch):
    real_which = shutil.which

    def which(cmd, *args, **kwargs):
        if str(cmd) in NOTIFY_BINARIES:
            return None
        return real_which(cmd, *args, **kwargs)

    monkeypatch.setattr(shutil, "which", which)
