#!/usr/bin/env python3
"""Hard gate: the companion chat is one inline feed that keeps every turn.

Regression: tool traces lived in their own fixed-height band above the reply and
``_send`` repainted only the in-flight buffers, so a second prompt made earlier
turns vanish — and results from parallel calls landed on the wrong card.

  python3 tests/gui/test_companion_feed_smoke.py
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSISTANT_PY = REPO / "nixos/modules/specialized/ncc-assistant/python"


class _FakeSignal:
    def __init__(self) -> None:
        self.slots: list = []

    def connect(self, fn) -> None:
        self.slots.append(fn)


class _FakeWorker:
    """Stands in for ``_CompanionChatWorker`` — no thread, no model call."""

    def __init__(self, slot_id: str, text: str, **kwargs) -> None:
        self.slot_id = slot_id
        self.text = text
        self.kwargs = kwargs
        self.event = _FakeSignal()
        self.failed = _FakeSignal()
        self.finished = _FakeSignal()

    def start(self) -> None:
        return None


class CompanionFeedSmoke(unittest.TestCase):
    def setUp(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not available")
        if str(ASSISTANT_PY) not in sys.path:
            sys.path.insert(0, str(ASSISTANT_PY))
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ["XDG_CONFIG_HOME"] = tempfile.mkdtemp(prefix="ncc-companion-feed-")
        self.app = QApplication.instance() or QApplication([])

        import ncc_assistant.companion as companion

        self.companion = companion
        self._real_worker = companion._CompanionChatWorker
        companion._CompanionChatWorker = _FakeWorker
        self.win = companion.CompanionWindow()
        # Never build a real ChatSession (that would reach for an API key).
        self.win._pick_harness = lambda slot, text: "qwen"

    def tearDown(self) -> None:
        self.companion._CompanionChatWorker = self._real_worker
        self.win.close()
        self.app.processEvents()

    # -- helpers -----------------------------------------------------------
    def _slot(self):
        return self.win._slot()

    def _feed(self) -> list:
        widgets = []
        for i in range(self.win.feed.count()):
            w = self.win.feed.itemAt(i).widget()
            if w is not None:
                widgets.append(w)
        return widgets

    def _run_turn(self, text: str, events: list[dict]) -> None:
        slot = self._slot()
        self.win.input.setText(text)
        self.win._send()
        for ev in events:
            self.win._on_event(slot.id, ev)
        self.win._on_worker_done(slot.id)
        self.app.processEvents()

    # -- the turn itself ---------------------------------------------------
    def test_tool_card_renders_inline_in_turn_order(self) -> None:
        self._run_turn(
            "read the file",
            [
                {"kind": "thinking_delta", "text": "looking at the repo"},
                {"kind": "tool", "name": "read_file", "args": {"path": "README.md"}},
                {"kind": "tool_result", "name": "read_file", "text": "42 lines"},
                {"kind": "assistant_delta", "text": "Done — "},
                {"kind": "assistant", "text": "Done — 42 lines."},
                {"kind": "done"},
            ],
        )
        slot = self._slot()
        self.assertEqual(
            [i["kind"] for i in slot.transcript],
            ["user", "thinking", "tool", "assistant"],
        )
        widgets = self._feed()
        self.assertEqual(
            [type(w).__name__ for w in widgets],
            ["Bubble", "ThinkingBlock", "ToolTraceWidget", "Bubble"],
        )
        card = widgets[2]
        self.assertEqual(card._name, "read_file")
        self.assertEqual(card._result, "42 lines")
        # Inline means inline: the card sits in the feed layout, not a side band.
        self.assertIs(card.parentWidget(), self.win.feed_host)
        self.assertFalse(hasattr(self.win, "tools_scroll"))
        self.assertIn("read the file", widgets[0].plain_text())
        self.assertIn("Done — 42 lines.", widgets[3].plain_text())

    def test_results_pair_by_name_when_calls_overlap(self) -> None:
        self._run_turn(
            "two writes",
            [
                {"kind": "tool", "name": "read_file", "args": {}},
                {"kind": "tool", "name": "write_file", "args": {}},
                {"kind": "tool_result", "name": "write_file", "text": "wrote"},
                {"kind": "tool_result", "name": "read_file", "text": "read"},
                {"kind": "assistant", "text": "ok"},
                {"kind": "done"},
            ],
        )
        tools = [i for i in self._slot().transcript if i["kind"] == "tool"]
        self.assertEqual(
            [(t["name"], t["result"]) for t in tools],
            [("read_file", "read"), ("write_file", "wrote")],
        )
        cards = [w for w in self._feed() if type(w).__name__ == "ToolTraceWidget"]
        self.assertEqual([c._result for c in cards], ["read", "wrote"])

    def test_second_prompt_keeps_earlier_turns(self) -> None:
        self._run_turn(
            "first question",
            [{"kind": "assistant", "text": "first answer"}, {"kind": "done"}],
        )
        self._run_turn(
            "second question",
            [{"kind": "assistant", "text": "second answer"}, {"kind": "done"}],
        )
        slot = self._slot()
        self.assertEqual(
            [i["kind"] for i in slot.transcript],
            ["user", "assistant", "user", "assistant"],
        )
        shown = "\n".join(
            w.plain_text() for w in self._feed() if type(w).__name__ == "Bubble"
        )
        for expected in ("first question", "first answer", "second question", "second answer"):
            self.assertIn(expected, shown)
        # The harness must still see the older turns, not just the last one.
        self.assertEqual(
            [t["content"] for t in slot.history],
            ["first question", "first answer", "second question", "second answer"],
        )

    def test_switching_chats_rebuilds_the_same_feed(self) -> None:
        first = self._slot()
        self._run_turn(
            "keep me",
            [
                {"kind": "tool", "name": "ls", "args": {}, "result": "file"},
                {"kind": "assistant", "text": "listed"},
                {"kind": "done"},
            ],
        )
        self.win._new_chat()
        self.assertEqual(len(self._slot().transcript), 0)
        self.assertEqual([type(w).__name__ for w in self._feed()], ["QLabel"])

        self.win._active_id = first.id
        self.win._apply_slot_ui()
        self.assertEqual(
            [type(w).__name__ for w in self._feed()],
            ["Bubble", "ToolTraceWidget", "Bubble"],
        )
        # Nothing may stay "live" once the turn is finished.
        self.assertIsNone(self.win._reply_live)
        self.assertIsNone(self.win._think_live)

    def test_error_is_a_feed_item_and_repeats_collapse(self) -> None:
        slot = self._slot()
        self._run_turn(
            "boom",
            [
                {"kind": "error", "text": "provider down"},
                {"kind": "error", "text": "provider down"},
                {"kind": "done"},
            ],
        )
        self.assertEqual([i["kind"] for i in slot.transcript], ["user", "error"])
        self.assertEqual(slot.transcript[1]["text"], "provider down")
        self.assertTrue(slot.last_error)
        self.assertFalse(self.win.retry_btn.isHidden())

    # -- pure transcript model (needs the package import, so lives here) ---
    def test_tool_result_pairing_rules(self) -> None:
        find_tool_trace = self.companion.find_tool_trace
        items = [
            {"kind": "tool", "name": "a", "args": {}, "result": "done"},
            {"kind": "tool", "name": "b", "args": {}, "result": ""},
            {"kind": "tool", "name": "c", "args": {}, "result": ""},
        ]
        self.assertIs(find_tool_trace(items, "c"), items[2])
        # No name → oldest open row, never one that already has a result.
        self.assertIs(find_tool_trace(items), items[1])
        self.assertIsNone(find_tool_trace([dict(items[0])], "zz"))
        self.assertIsNone(find_tool_trace(None))
        self.assertIsNone(find_tool_trace([{"kind": "assistant", "text": "hi"}]))

    def test_transcript_append_bounds_and_dedupes_errors(self) -> None:
        append = self.companion.transcript_append
        slot = self.companion.ChatSlot.new("t")
        for i in range(self.companion.TRANSCRIPT_MAX_ITEMS + 25):
            append(slot, {"kind": "assistant", "text": str(i)})
        self.assertEqual(len(slot.transcript), self.companion.TRANSCRIPT_MAX_ITEMS)
        self.assertEqual(slot.transcript[0]["text"], "25")

        kept = append(slot, {"kind": "error", "text": "same"})
        again = append(slot, {"kind": "error", "text": "same"})
        self.assertIs(kept, again)
        self.assertEqual(sum(1 for i in slot.transcript if i["kind"] == "error"), 1)
        other = append(slot, {"kind": "error", "text": "other"})
        self.assertIsNot(kept, other)

    def test_legacy_record_migrates_into_turn_order(self) -> None:
        rec = {
            "id": "old",
            "title": "Old",
            "history": [
                {"role": "user", "content": "one"},
                {"role": "assistant", "content": "two"},
            ],
            "thinking_buf": "hm",
            "tool_traces": [{"name": "ls", "args": {"d": "."}, "result": "a"}],
            "user_prompt": "three",
            "reply_buf": "",
            "last_error": "boom",
        }
        slot = self.companion.ChatSlot.from_record(rec)
        self.assertEqual(
            [i["kind"] for i in slot.transcript],
            ["user", "assistant", "thinking", "tool", "user", "error"],
        )
        self.assertEqual(slot.transcript[3]["name"], "ls")
        self.assertEqual(slot.transcript[4]["text"], "three")

    def test_transcript_from_chat_session_messages(self) -> None:
        msgs = [
            {"role": "system", "content": "instructions"},
            {"role": "user", "content": "hi"},
            {
                "role": "assistant",
                "content": "",
                "tool_calls": [
                    {
                        "id": "c1",
                        "function": {"name": "read_file", "arguments": '{"p": "x"}'},
                    }
                ],
            },
            {"role": "tool", "tool_call_id": "c1", "name": "read_file", "content": "out"},
            {"role": "assistant", "content": "done"},
        ]
        items = self.companion.transcript_from_messages(msgs)
        self.assertEqual(
            [i["kind"] for i in items], ["user", "tool", "assistant"]
        )
        self.assertEqual(items[1]["name"], "read_file")
        self.assertEqual(items[1]["args"], {"p": "x"})
        self.assertEqual(items[1]["result"], "out")

    def test_store_roundtrip_restores_session_and_feed(self) -> None:
        self._run_turn(
            "keep me",
            [
                {"kind": "tool", "name": "ls", "args": {"d": "."}},
                {"kind": "tool_result", "name": "ls", "text": "file"},
                {"kind": "assistant", "text": "listed"},
                {"kind": "done"},
            ],
        )
        slot = self._slot()
        slot.session_id = "sess-42"
        self.win._persist_chats()

        from ncc_assistant.companion_store import load_companion_chats

        restored = self.companion.ChatSlot.from_record(load_companion_chats()[0])
        self.assertEqual(restored.id, slot.id)
        self.assertEqual(restored.session_id, "sess-42")
        self.assertEqual(
            [i["kind"] for i in restored.transcript], ["user", "tool", "assistant"]
        )
        self.assertEqual(restored.transcript[1]["result"], "file")
        self.assertEqual(restored.transcript[0]["text"], "keep me")

    def test_background_chat_still_gets_its_reply_item(self) -> None:
        slot = self._slot()
        other = self.companion.ChatSlot.new("bg")
        self.win._slots.append(other)
        self.win.input.setText("active turn")
        self.win._send()
        self.win._on_event(other.id, {"kind": "assistant", "text": "quiet answer"})
        self.win._on_worker_done(other.id)
        self.assertEqual(
            [i["kind"] for i in other.transcript], ["assistant"]
        )
        self.assertEqual(other.transcript[0]["text"], "quiet answer")
        # The active slot's feed stayed untouched by the background turn.
        self.assertEqual(
            [w.plain_text() for w in self._feed() if type(w).__name__ == "Bubble"],
            ["active turn"],
        )


if __name__ == "__main__":
    unittest.main()
