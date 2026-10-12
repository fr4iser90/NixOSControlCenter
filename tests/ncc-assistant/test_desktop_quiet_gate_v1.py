#!/usr/bin/env python3
"""The gate must not touch the desktop.

The pre-commit hook runs this suite on a desktop where notify-send exists, and the run path
notifies on every terminal job state — without the session guard in conftest.py, a green gate
popped a bubble per agent run, and notify_send_actions would have blocked on --wait.
Probed through the real notify_send / notify_send_actions: no subprocess, no bubble.
"""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"
sys.path.insert(0, str(PKG))

from ncc_assistant import notifications  # noqa: E402


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


if __name__ == "__main__":
    unittest.main()
