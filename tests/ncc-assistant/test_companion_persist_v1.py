#!/usr/bin/env python3
"""Phase 33: companion persist, mcp inject, avatar skins (no display)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.companion_store import (  # noqa: E402
    ARGS_MAX,
    RESULT_MAX,
    STORE_VERSION,
    TEXT_MAX,
    TRANSCRIPT_KEEP,
    load_companion_chats,
    record_has_content,
    save_companion_chats,
    slot_to_record,
    transcript_for_store,
)
from ncc_assistant.harness.mcp_inject import ncc_mcp_entry  # noqa: E402
from ncc_assistant.harness.native import seed_history  # noqa: E402
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

    def test_transcript_only_record_has_content(self) -> None:
        # A turn that streamed but never made it into history must still return.
        self.assertTrue(
            record_has_content(
                {"id": "t", "transcript": [{"kind": "user", "text": "hi"}]}
            )
        )
        self.assertFalse(record_has_content({"id": "t", "transcript": []}))

    def test_transcript_for_store_trims_for_disk(self) -> None:
        big_path = "x" * 3000
        kept = transcript_for_store(
            [
                {"kind": "user", "text": "u" * (TEXT_MAX + 1000)},
                {
                    "kind": "tool",
                    "name": "read_file",
                    "args": {"path": big_path},
                    "result": "r" * (RESULT_MAX + 500),
                },
                "not-a-dict",
            ]
        )
        self.assertEqual([i["kind"] for i in kept], ["user", "tool"])
        self.assertEqual(len(kept[0]["text"]), TEXT_MAX)
        self.assertEqual(len(kept[1]["result"]), RESULT_MAX)
        # Oversized args collapse to one truncated blob instead of bloating the store
        self.assertEqual(
            kept[1]["args"], {"truncated": ('{"path": "' + big_path)[:ARGS_MAX]}
        )
        self.assertEqual(len(kept[1]["args"]["truncated"]), ARGS_MAX)
        small = transcript_for_store(
            [{"kind": "tool", "name": "ls", "args": {"d": "."}, "result": ""}]
        )
        self.assertEqual(small[0]["args"], {"d": "."})
        self.assertNotIn("result", small[0])
        many = transcript_for_store(
            [{"kind": "assistant", "text": str(i)} for i in range(TRANSCRIPT_KEEP + 20)]
        )
        self.assertEqual(len(many), TRANSCRIPT_KEEP)
        self.assertEqual(many[-1]["text"], str(TRANSCRIPT_KEEP + 19))

    def test_session_id_and_transcript_roundtrip(self) -> None:
        slot = SimpleNamespace(
            id="s1",
            title="Keep",
            title_locked=False,
            workspace_id=None,
            harness_mode="auto",
            harness="native",
            parent_id=None,
            # Native ChatSession on disk — without this the model loses context.
            session_id="sess-42",
            transcript=[
                {"kind": "user", "text": "hi"},
                {"kind": "tool", "name": "ls", "args": {}, "result": "ok"},
            ],
            last_error="boom",
            user_prompt="hi",
            reply_buf="",
            thinking_buf="",
            history=[],
            tool_traces=[],
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "companion-chats.json"
            with patch(
                "ncc_assistant.companion_store.companion_store_file",
                return_value=path,
            ):
                save_companion_chats([slot_to_record(slot)])
                raw = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(raw["version"], STORE_VERSION)
                loaded = load_companion_chats()
                self.assertEqual(loaded[0]["session_id"], "sess-42")
                self.assertEqual(loaded[0]["last_error"], "boom")
                self.assertEqual(
                    [i["kind"] for i in loaded[0]["transcript"]], ["user", "tool"]
                )
                self.assertEqual(loaded[0]["transcript"][1]["result"], "ok")


class _StubSession:
    def __init__(self, messages: list[dict[str, str]]) -> None:
        self.messages = list(messages)
        self.refreshed = 0

    def refresh_system_prompt(self) -> None:
        self.refreshed += 1


class SeedHistoryTests(unittest.TestCase):
    def test_seeds_only_an_empty_session(self) -> None:
        fresh = _StubSession([{"role": "system", "content": "sys"}])
        seed_history(
            fresh,
            [
                {"role": "user", "content": "one"},
                {"role": "assistant", "content": "two"},
                {"role": "tool", "content": "not a turn"},
                {"role": "user", "content": "   "},
            ],
        )
        self.assertEqual([m["role"] for m in fresh.messages], ["system", "user", "assistant"])
        self.assertEqual(fresh.refreshed, 1)

        filled = _StubSession(
            [{"role": "system", "content": "sys"}, {"role": "user", "content": "mine"}]
        )
        seed_history(filled, [{"role": "user", "content": "one"}])
        self.assertEqual([m["content"] for m in filled.messages], ["sys", "mine"])
        self.assertEqual(filled.refreshed, 0)

    def test_noop_without_history_or_session(self) -> None:
        s = _StubSession([{"role": "system", "content": "sys"}])
        seed_history(s, None)
        seed_history(s, [])
        seed_history(None, [{"role": "user", "content": "x"}])
        self.assertEqual(s.messages, [{"role": "system", "content": "sys"}])
        self.assertEqual(s.refreshed, 0)


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
