#!/usr/bin/env python3
"""Swappable harness: resolve + qwen stream mapping (no network)."""

from __future__ import annotations

import ast
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.harness.qwen import map_qwen_line  # noqa: E402
from ncc_assistant.harness.resolve import (  # noqa: E402
    CODING_TAGS,
    looks_like_coding_goal,
    resolve_harness_name,
)


class HarnessResolveTests(unittest.TestCase):
    def test_force_wins(self) -> None:
        self.assertEqual(
            resolve_harness_name(force="dsh", template_harness="qwen", tags=["git"]),
            "dsh",
        )

    def test_template_harness(self) -> None:
        self.assertEqual(
            resolve_harness_name(template_harness="qwen", tags=[]),
            "qwen",
        )

    def test_coding_tags_use_coding_harness(self) -> None:
        with patch.dict(
            os.environ,
            {"NCC_ASSISTANT_CODING_HARNESS": "dsh", "NCC_ASSISTANT_HARNESS": "native"},
            clear=False,
        ):
            self.assertEqual(resolve_harness_name(tags=["git"]), "dsh")

    def test_looks_like_coding_goal(self) -> None:
        self.assertTrue(looks_like_coding_goal("Please review this pull request"))
        self.assertFalse(looks_like_coding_goal("What is disk usage?"))

    def test_coding_tags_nonempty(self) -> None:
        self.assertIn("git", CODING_TAGS)


class QwenMapTests(unittest.TestCase):
    def test_thinking_delta(self) -> None:
        evs = map_qwen_line(
            {
                "type": "stream_event",
                "event": {
                    "type": "content_block_delta",
                    "delta": {"type": "thinking_delta", "thinking": "hmm"},
                },
            }
        )
        self.assertEqual(evs[0]["kind"], "thinking_delta")
        self.assertIn("hmm", evs[0]["text"])

    def test_assistant_text(self) -> None:
        evs = map_qwen_line(
            {
                "type": "assistant",
                "message": {"content": [{"type": "text", "text": "hi"}]},
            }
        )
        kinds = [e["kind"] for e in evs]
        self.assertIn("assistant_delta", kinds)


class HarnessModuleAstTests(unittest.TestCase):
    def test_package_exports(self) -> None:
        path = ROOT / "ncc_assistant" / "harness" / "__init__.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        text = path.read_text(encoding="utf-8")
        self.assertIn("get_harness", text)
        self.assertIn("resolve_harness_name", text)
        self.assertIn("looks_like_coding_goal", text)
        self.assertTrue(any(isinstance(n, ast.ImportFrom) for n in tree.body))
        # Regression: cli/companion import from package root, not resolve.py
        from ncc_assistant.harness import looks_like_coding_goal as exported  # noqa: PLC0415

        self.assertTrue(callable(exported))


if __name__ == "__main__":
    unittest.main()
