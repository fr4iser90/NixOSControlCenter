#!/usr/bin/env python3
"""Swappable harness: resolve + qwen stream mapping (no network)."""

from __future__ import annotations

import ast
import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.harness import qwen as qwen_mod  # noqa: E402
from ncc_assistant.harness.qwen import (  # noqa: E402
    TOOL_ECHO_MARKERS,
    QwenHarness,
    map_qwen_line,
    tool_echo_in_text,
    tool_echo_notice,
)
from ncc_assistant.harness.resolve import (  # noqa: E402
    CODING_TAGS,
    looks_like_coding_goal,
    resolve_harness_name,
)
from ncc_assistant.harness.types import HarnessInfo  # noqa: E402


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


# Shape captured from a real scheduled run: the model wrote its call into the
# reply text, so the harness got no structured tool_use and Companion painted
# markup instead of a tool card. Built from the production markers so the guard
# and the fixture can never drift apart.
TOOL_FN = "<" + "function=run_shell_command>"
TOOL_PARAM = (
    "<"
    + 'parameter name="command"'
    + ">date '+%A'"
    + "<"
    + "/parameter"
    + ">"
)
ECHO_TEXT = (
    TOOL_ECHO_MARKERS[0] + "\n" + TOOL_FN + "\n" + TOOL_PARAM + "\n" + TOOL_ECHO_MARKERS[1] + "\n"
) * 2


class _FakeProc:
    def __init__(self, lines: list[str]) -> None:
        self.stdout = iter(lines)
        self.stderr = io.StringIO("")

    def wait(self, timeout: float | None = None) -> int:
        del timeout
        return 0

    def terminate(self) -> None:
        return None

    def kill(self) -> None:
        return None


def _drive_qwen(objs: list[dict]) -> list[dict]:
    """Feed canned stream-json objects through ``QwenHarness.send`` (no binary)."""
    lines = [json.dumps(obj) + "\n" for obj in objs]
    info = HarnessInfo(name="qwen", label="Qwen Code", available=True, detail="test")
    with (
        patch.object(QwenHarness, "probe", lambda self: info),
        patch(
            "ncc_assistant.harness.mcp_inject.ensure_qwen_ncc_mcp",
            lambda: {"status": "unchanged", "detail": ""},
        ),
        patch.object(qwen_mod.subprocess, "Popen", lambda *a, **kw: _FakeProc(lines)),
    ):
        return list(QwenHarness().send("goal"))


class QwenToolEchoGuardTests(unittest.TestCase):
    def test_helper_flags_only_tool_syntax(self) -> None:
        self.assertTrue(tool_echo_in_text(ECHO_TEXT))
        self.assertFalse(tool_echo_in_text("AGENTS.md needs the schedule section."))

    def test_notice_names_count_and_intent(self) -> None:
        notice = tool_echo_notice(ECHO_TEXT)
        self.assertIn("2 tool calls echoed as text", notice)
        self.assertIn("nothing was executed", notice)
        self.assertIn("run_shell_command", notice)

    def test_echoed_calls_never_reach_the_reply(self) -> None:
        events = _drive_qwen(
            [
                {
                    "type": "assistant",
                    "message": {"content": [{"type": "text", "text": ECHO_TEXT}]},
                },
                {"type": "result", "result": ECHO_TEXT},
            ]
        )
        kinds = [e["kind"] for e in events]
        self.assertNotIn("assistant_delta", kinds)
        self.assertNotIn("assistant", kinds)
        self.assertEqual(kinds.count("protocol_error"), 1)
        guard = events[kinds.index("protocol_error")]
        self.assertTrue(guard["drop_live_reply"])
        self.assertIn("nothing was executed", guard["text"])
        self.assertEqual(kinds[-1], "done")

    def test_plain_reply_is_delivered_exactly_once(self) -> None:
        events = _drive_qwen(
            [
                {"type": "system", "subtype": "init"},
                {
                    "type": "assistant",
                    "message": {"content": [{"type": "text", "text": "All done."}]},
                },
                {"type": "result", "result": "All done."},
            ]
        )
        finals = [e for e in events if e["kind"] == "assistant"]
        self.assertEqual([f["text"] for f in finals], ["All done."])
        self.assertNotIn("protocol_error", [e["kind"] for e in events])

    def test_structured_tool_round_is_untouched(self) -> None:
        events = _drive_qwen(
            [
                {
                    "type": "assistant",
                    "message": {
                        "content": [
                            {"type": "tool_use", "name": "read_file", "input": {"p": "x"}}
                        ]
                    },
                },
                {
                    "type": "user",
                    "message": {
                        "content": [
                            {"type": "tool_result", "tool_use_id": "t1", "content": "42 lines"}
                        ]
                    },
                },
                {
                    "type": "assistant",
                    "message": {"content": [{"type": "text", "text": "42 lines."}]},
                },
                {"type": "result", "result": "42 lines."},
            ]
        )
        kinds = [e["kind"] for e in events]
        self.assertEqual(kinds.count("tool"), 1)
        self.assertEqual(kinds.count("tool_result"), 1)
        self.assertEqual(kinds.count("assistant"), 1)
        self.assertNotIn("protocol_error", kinds)


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
