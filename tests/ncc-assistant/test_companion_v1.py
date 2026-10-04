#!/usr/bin/env python3
"""Companion v1.1: module + CLI wiring (no display required for AST checks)."""

from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class CompanionWiringTests(unittest.TestCase):
    def test_companion_module_exports_run(self) -> None:
        path = ROOT / "ncc_assistant" / "companion.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        names = {
            n.name
            for n in tree.body
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
        }
        self.assertIn("run_companion", names)
        self.assertIn("CompanionWindow", names)
        self.assertIn("AvatarCanvas", names)
        self.assertIn("ChatSlot", names)
        text = path.read_text(encoding="utf-8")
        self.assertIn("get_harness", text)
        self.assertIn("thinking_delta", text)

    def test_cli_has_companion_command(self) -> None:
        path = ROOT / "ncc_assistant" / "cli.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn('"companion"', text)
        self.assertIn('if command == "companion":', text)
        self.assertIn("run_companion", text)

    def test_avatar_states_defined(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        for name in (
            "STATE_IDLE",
            "STATE_THINKING",
            "STATE_SPEAKING",
            "STATE_PAUSED",
            "STATE_ERROR",
        ):
            self.assertIn(name, text)

    def test_v11_ux_hooks(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("startSystemMove", text)
        self.assertIn("WA_TranslucentBackground", text)
        self.assertIn("PANEL_HISTORY", text)
        self.assertIn("PANEL_SKILLS", text)
        self.assertIn("PANEL_CRON", text)
        self.assertIn("PANEL_JOBS", text)
        self.assertIn("_new_chat", text)
        self.assertIn("_switch_chat", text)
        self.assertIn("WindowType.Window", text)
        self.assertNotIn("WindowType.Tool", text)
        self.assertNotIn("setFallbackSessionManagementEnabled", text)


if __name__ == "__main__":
    unittest.main()
