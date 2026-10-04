#!/usr/bin/env python3
"""Phase 33: companion persist, mcp inject, avatar skins (no display)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.companion_store import (  # noqa: E402
    load_companion_chats,
    record_has_content,
    save_companion_chats,
)
from ncc_assistant.harness.mcp_inject import ncc_mcp_entry  # noqa: E402
from ncc_assistant.harness.qwen import map_qwen_line  # noqa: E402
from ncc_assistant.trace_format import format_thinking_header  # noqa: E402


class CompanionStoreTests(unittest.TestCase):
    def test_roundtrip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "companion-chats.json"
            with patch(
                "ncc_assistant.companion_store.companion_store_file",
                return_value=path,
            ):
                save_companion_chats(
                    [
                        {
                            "id": "abc",
                            "title": "My chat",
                            "title_locked": True,
                            "workspace_id": "repo",
                            "history": [{"role": "user", "content": "hi"}],
                        }
                    ]
                )
                loaded = load_companion_chats()
                self.assertEqual(len(loaded), 1)
                self.assertEqual(loaded[0]["title"], "My chat")
                self.assertTrue(loaded[0]["title_locked"])
                self.assertEqual(loaded[0]["workspace_id"], "repo")

    def test_empty_chats_not_persisted(self) -> None:
        self.assertFalse(
            record_has_content({"id": "x", "title": "Chat 1", "history": []})
        )
        self.assertTrue(
            record_has_content(
                {"id": "y", "history": [{"role": "user", "content": "hi"}]}
            )
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "companion-chats.json"
            with patch(
                "ncc_assistant.companion_store.companion_store_file",
                return_value=path,
            ):
                save_companion_chats(
                    [
                        {"id": "empty", "title": "Chat 2", "history": []},
                        {
                            "id": "full",
                            "title": "hi",
                            "history": [{"role": "user", "content": "hi"}],
                        },
                    ]
                )
                raw = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(len(raw["chats"]), 1)
                self.assertEqual(raw["chats"][0]["id"], "full")
                self.assertEqual(len(load_companion_chats()), 1)


class McpInjectTests(unittest.TestCase):
    def test_ncc_entry_shape(self) -> None:
        entry = ncc_mcp_entry()
        self.assertIn("command", entry)
        self.assertIn("args", entry)


class RunSpawnMapTests(unittest.TestCase):
    def test_task_tool_emits_run_spawn(self) -> None:
        evs = map_qwen_line(
            {
                "type": "stream_event",
                "event": {
                    "type": "content_block_start",
                    "content_block": {
                        "type": "tool_use",
                        "name": "Task",
                        "input": {"prompt": "review PR", "description": "review"},
                    },
                },
            }
        )
        kinds = [e["kind"] for e in evs]
        self.assertIn("tool", kinds)
        self.assertIn("run_spawn", kinds)


class AvatarSkinsAstTests(unittest.TestCase):
    def test_module_exists(self) -> None:
        text = (ROOT / "ncc_assistant" / "avatar_skins.py").read_text(encoding="utf-8")
        self.assertIn("list_skins", text)
        self.assertIn("live2d_export", text)
        self.assertIn(format_thinking_header(), "Thinking")


if __name__ == "__main__":
    unittest.main()
