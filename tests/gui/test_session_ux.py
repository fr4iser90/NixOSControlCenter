#!/usr/bin/env python3
"""Unit tests for session scope UX helpers (no Qt / PySide6)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

GUI_PY = Path(__file__).resolve().parents[2] / "nixos/core/management/gui-engine/python"
sys.path.insert(0, str(GUI_PY))

from ncc_gui.session_ux import (  # noqa: E402
    chip_text,
    needs_local_write_confirm,
    operating_on_line,
    session_mode,
)


def _s(**kwargs) -> SimpleNamespace:
    base = dict(
        state="idle",
        candidate=None,
        connected=None,
        probe=None,
        message="",
    )
    base.update(kwargs)
    return SimpleNamespace(**base)


class SessionUxTests(unittest.TestCase):
    def test_idle_is_local(self) -> None:
        s = _s()
        self.assertEqual(session_mode(s), "local")
        self.assertFalse(needs_local_write_confirm(s))
        self.assertTrue(chip_text(s).startswith("LOCAL ·"))
        self.assertIn("Operating on: LOCAL", operating_on_line(s))

    def test_candidate_is_pending(self) -> None:
        s = _s(state="candidate", candidate="u@host")
        self.assertEqual(session_mode(s), "pending")
        self.assertTrue(needs_local_write_confirm(s))
        self.assertIn("pending: u@host", chip_text(s))
        self.assertIn("press Connect", operating_on_line(s))

    def test_unreachable_is_failed_still_local(self) -> None:
        s = _s(
            state="blocked",
            candidate="u@192.168.1.1",
            connected=None,
            message="Still on LOCAL …",
        )
        self.assertEqual(session_mode(s), "failed")
        self.assertTrue(needs_local_write_confirm(s))
        self.assertIn("failed: u@192.168.1.1", chip_text(s))
        self.assertIn("not connected", operating_on_line(s))

    def test_ready_is_remote(self) -> None:
        s = _s(state="ready", candidate="u@h", connected="u@h")
        self.assertEqual(session_mode(s), "remote")
        self.assertFalse(needs_local_write_confirm(s))
        self.assertEqual(chip_text(s), "REMOTE · u@h")
        self.assertIn("REMOTE (u@h)", operating_on_line(s))

    def test_connecting(self) -> None:
        s = _s(state="connecting", candidate="u@h")
        self.assertEqual(session_mode(s), "connecting")
        self.assertTrue(needs_local_write_confirm(s))


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
