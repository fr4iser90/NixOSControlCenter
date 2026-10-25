#!/usr/bin/env python3
"""The gate must not touch the desktop.

The pre-commit hook runs this suite on the operator's own desktop, and the product paths reach
that desktop on purpose: notify-send on every terminal job state, MPRIS ``Player.Pause`` on an
intervene, a KWin Scripting run setting ``currentDesktop`` + ``activeWindow``, ``wtype`` typing
into whichever window holds focus. Capturing the argv of every desktop tool a gate run spawned
proved the suite drove those while reporting green — the operator's video paused and his window
focus jumped mid-commit.

conftest.py answers that by removing the capability — the tools stop resolving — instead of
asking each test to stub. These tests are the tripwire: weaken that boundary and this suite goes
red, which is the only way the next reader learns the boundary has a reason to exist.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "nixos" / "modules" / "specialized" / "ncc-assistant"
sys.path.insert(0, str(PKG))

from plugins.doomscroll import actions as focus_actions  # noqa: E402
from core.policy import notifications

#: Each name is a capability over the session that runs the gate: a bubble, a paused player, a
#: desktop switch, a focused window, synthetic keystrokes. Spelled out here instead of imported
#: from conftest, so narrowing the set there without dropping the product need turns this red.
UNREACHABLE = (
    "notify-send",
    "qdbus",
    "dbus-send",
    "hyprctl",
    "swaymsg",
    "kdotool",
    "wtype",
    "xdotool",
    "ydotool",
)


class DesktopQuietTests(unittest.TestCase):
    def test_a_plain_notify_send_reaches_nothing(self) -> None:
        with patch.object(subprocess, "run") as fake_run:
            sent = notifications.notify_send("NCC Assistant: Job finished", "test goal")
        self.assertFalse(sent)
        fake_run.assert_not_called()

    def test_the_waiting_variant_cannot_block_the_gate(self) -> None:
        with patch.object(subprocess, "run") as fake_run:
            action = notifications.notify_send_actions("Needs a decision", "rebuild?")
        self.assertIsNone(action)
        fake_run.assert_not_called()

    def test_no_desktop_tool_resolves_inside_a_test(self) -> None:
        still_there = [name for name in UNREACHABLE if shutil.which(name) is not None]
        self.assertEqual(
            still_there,
            [],
            f"conftest.py stopped hiding {still_there}: the gate can drive the session that "
            "commits it again — media pause, desktop switch and keystrokes would return.",
        )

    def test_an_intervene_cannot_pause_media_or_move_the_operator(self) -> None:
        """The three intervene side effects on the real session: nothing may be spawned."""
        with patch.object(subprocess, "run") as fake_run:
            paused = focus_actions.pause_browser_media()
            followed = focus_actions.follow_target_desktop()
            left = focus_actions.leave_feed_tab()
        self.assertFalse(paused)
        self.assertFalse(followed)
        self.assertEqual(left.get("error"), "no_key_tool")
        fake_run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
