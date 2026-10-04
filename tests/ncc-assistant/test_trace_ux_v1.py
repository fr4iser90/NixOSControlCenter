#!/usr/bin/env python3
"""Phase 31 trace UX: headers, exports, companion wiring (no display)."""

from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.trace_format import (  # noqa: E402
    format_thinking_header,
    format_tool_header,
)


class TraceHeaderTests(unittest.TestCase):
    def test_tool_header_compact(self) -> None:
        self.assertEqual(
            format_tool_header("read_file", ms=42, status="✓"),
            "read_file · 42ms · ✓",
        )

    def test_thinking_header_states(self) -> None:
        self.assertEqual(format_thinking_header(streaming=True), "Thinking…")
        self.assertEqual(format_thinking_header(seconds=2.1), "Thinking · 2.1s")
        self.assertEqual(format_thinking_header(), "Thinking")


class TraceAstTests(unittest.TestCase):
    def test_gui_pages_exports_thinking_block(self) -> None:
        path = ROOT / "ncc_assistant" / "gui_pages.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn("class ThinkingBlock", text)
        self.assertIn("format_tool_header", text)
        self.assertIn("compact", text)

    def test_companion_uses_thinking_and_tools(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("ThinkingBlock", text)
        self.assertIn("ToolTraceWidget", text)
        self.assertIn("harness_combo", text)
        self.assertIn("activity_lbl", text)
        self.assertIn("run_spawn", text)
        self.assertIn("_go_parent", text)
        self.assertIn("parent_id", text)
        self.assertNotIn("── thinking ──", text)
        self.assertNotIn("[tool]", text)

    def test_gui_uses_thinking_block(self) -> None:
        text = (ROOT / "ncc_assistant" / "gui.py").read_text(encoding="utf-8")
        self.assertIn("ThinkingBlock", text)
        self.assertIn("harness_combo", text)
        self.assertIn("_finish_think_block", text)

    def test_cli_verbose_flag(self) -> None:
        text = (ROOT / "ncc_assistant" / "cli.py").read_text(encoding="utf-8")
        self.assertIn('"--verbose"', text)
        self.assertIn("Thinking…", text)

    def test_preferences_trace_keys(self) -> None:
        path = ROOT / "ncc_assistant" / "preferences.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        names = {
            n.name
            for n in tree.body
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
        }
        self.assertIn("get_trace_density", names)
        self.assertIn("get_default_harness_mode", names)
        self.assertIn("get_expand_thinking_while_streaming", names)


if __name__ == "__main__":
    unittest.main()
