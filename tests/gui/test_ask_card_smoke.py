#!/usr/bin/env python3
"""Hard gate: `ask_user` renders as one question card and its chips free the worker.

The tool blocks inside the running worker, so a surface that shows the question but
never wires the answer back holds the run until the timeout — and a card that stays
clickable after a reload answers a worker that no longer exists.

  python3 tests/gui/test_ask_card_smoke.py
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSISTANT_PY = REPO / "nixos/modules/specialized/ncc-assistant/python"

QUESTION = {
    "kind": "ask",
    "ask_id": "call_1",
    "question": "Which window should I compact?",
    "header": "Scope",
    "options": [
        {"label": "This chat", "description": "Only the active transcript"},
        {"label": "All chats", "description": "Every stored chat"},
    ],
    "multi": False,
}


def _ask_event(**over) -> dict:
    event = dict(QUESTION)
    event.update(over)
    return event


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


class _StubSession:
    """Only what a surface needs while a question is parked."""

    def __init__(self, pending: list[str] | None = None) -> None:
        self.pending = list(pending or [])
        self.answers: list[tuple[str, str | None]] = []

    def pending_ask_ids(self) -> list[str]:
        return list(self.pending)

    def answer_ask(self, ask_id: str, text: str | None) -> bool:
        self.answers.append((ask_id, text))
        return True


class _QtCase(unittest.TestCase):
    def setUpQt(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication, QPushButton
        except ImportError:
            self.skipTest("PySide6 not available")
        if str(ASSISTANT_PY) not in sys.path:
            sys.path.insert(0, str(ASSISTANT_PY))
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ["XDG_CONFIG_HOME"] = tempfile.mkdtemp(prefix="ncc-ask-card-")
        self.QPushButton = QPushButton
        self.app = QApplication.instance() or QApplication([])


class AskWidgetTests(_QtCase):
    """The card on its own: chips are the fast path, typing is always allowed."""

    def setUp(self) -> None:
        self.setUpQt()
        from ncc_assistant.gui_pages import AskWidget

        self.AskWidget = AskWidget

    def _by_text(self, card, text: str):
        return next(b for b in card.findChildren(self.QPushButton) if b.text() == text)

    def test_one_chip_answers_and_closes_the_card(self) -> None:
        answers: list = []
        card = self.AskWidget(dict(QUESTION), on_answer=answers.append)
        self.assertEqual(card.ask_id, "call_1")
        card._buttons[0].click()
        self.assertEqual(answers, ["This chat"])
        self.assertFalse(card._buttons[0].isEnabled())
        self.assertFalse(card._buttons[1].isEnabled())
        self.assertFalse(card._input.isEnabled())
        self.assertEqual(card._status.text(), "Answered · This chat")
        # A second click must not answer twice — the worker is already gone.
        card._buttons[1].click()
        self.assertEqual(answers, ["This chat"])

    def test_typed_answer_is_the_answer(self) -> None:
        answers: list = []
        card = self.AskWidget(dict(QUESTION), on_answer=answers.append)
        card._input.setText("only the last 20 messages")
        card._input.returnPressed.emit()
        self.assertEqual(answers, ["only the last 20 messages"])

    def test_skip_answers_with_nothing(self) -> None:
        answers: list = []
        card = self.AskWidget(dict(QUESTION), on_answer=answers.append)
        self._by_text(card, "Skip").click()
        self.assertEqual(answers, [None])
        self.assertEqual(card._status.text(), "No answer")

    def test_multi_select_collects_every_choice_on_send(self) -> None:
        answers: list = []
        card = self.AskWidget(dict(QUESTION, multi=True), on_answer=answers.append)
        card._buttons[0].click()
        self.assertEqual(answers, [], "multi must not answer on the first chip")
        card._buttons[1].click()
        self._by_text(card, "Send").click()
        self.assertEqual(answers, ["This chat, All chats"])

    def test_a_card_without_a_worker_only_shows_the_stored_answer(self) -> None:
        card = self.AskWidget(dict(QUESTION))
        card.set_answered("This chat")
        self.assertEqual(card._status.text(), "Answered · This chat")
        self.assertFalse(card._buttons[0].isEnabled())
        # Run end may settle it again — the answer that was given stays shown.
        card.set_answered(None)
        self.assertEqual(card._status.text(), "Answered · This chat")


class CompanionAskCardTests(_QtCase):
    def setUp(self) -> None:
        self.setUpQt()
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

    def _feed(self) -> list:
        return [
            self.win.feed.itemAt(i).widget() for i in range(self.win.feed.count())
        ]

    def _cards(self) -> list:
        return [w for w in self._feed() if type(w).__name__ == "AskWidget"]

    def _ask_in_feed(self, event: dict | None = None):
        slot = self._slot()
        self.win.input.setText("compact the context")
        self.win._send()
        slot.session = _StubSession(["call_1"])
        self.win._on_event(slot.id, _ask_event() if event is None else event)
        self.app.processEvents()
        return slot

    def _slot(self):
        return self.win._slot()

    def test_the_question_lands_in_the_feed_as_a_card(self) -> None:
        slot = self._ask_in_feed()
        cards = self._cards()
        self.assertEqual(len(cards), 1)
        self.assertIs(cards[0].parentWidget(), self.win.feed_host)
        self.assertEqual(slot.transcript[-1]["kind"], "ask")
        self.assertEqual(slot.transcript[-1]["ask_id"], "call_1")
        self.assertIsNone(slot.transcript[-1]["answer"])
        self.assertEqual(self.win.activity_lbl.text(), "Waiting for your answer")

    def test_clicking_a_chip_releases_that_slots_worker(self) -> None:
        slot = self._ask_in_feed()
        session = slot.session
        self._cards()[0]._buttons[1].click()
        self.assertEqual(session.answers, [("call_1", "All chats")])
        self.assertEqual(slot.transcript[-1]["answer"], "All chats")
        self.assertEqual(self._cards()[0]._status.text(), "Answered · All chats")

    def test_an_unanswered_card_closes_when_the_run_ends(self) -> None:
        slot = self._ask_in_feed()
        self.win._on_worker_done(slot.id)
        self.assertEqual(self.win._feed_ask_rows, {})
        card = self._cards()[0]
        self.assertFalse(card._buttons[0].isEnabled())
        self.assertEqual(card._status.text(), "No answer")
        # Nothing may answer into a finished run.
        self._cards()[0]._buttons[0].click()
        self.assertEqual(slot.session.answers, [])

    def test_a_reloaded_card_shows_the_answer_but_cannot_answer(self) -> None:
        slot = self._ask_in_feed()
        self._cards()[0]._buttons[0].click()
        slot.session.answers.clear()
        slot.session.pending = []

        self.win._active_id = slot.id
        self.win._apply_slot_ui()
        self.app.processEvents()

        card = self._cards()[0]
        self.assertEqual(card._status.text(), "Answered · This chat")
        self.assertFalse(card._input.isEnabled())
        card._buttons[1].click()
        self.assertEqual(slot.session.answers, [])

    def test_a_background_question_never_answers_the_active_chat(self) -> None:
        slot = self._ask_in_feed()
        other = self.companion.ChatSlot.new("bg")
        other.session = _StubSession(["call_2"])
        self.win._slots.append(other)

        self.win._answer_ask(other.id, "call_2", "All chats")
        self.assertEqual(other.session.answers, [("call_2", "All chats")])
        self.assertEqual(slot.session.answers, [])


class ChatPageAskCardTests(_QtCase):
    def setUp(self) -> None:
        self.setUpQt()
        from ncc_assistant.config import Settings
        from ncc_assistant.gui import ChatPage, ConfirmBridge
        from ncc_assistant.session import ChatSession

        session = ChatSession.create(
            Settings.from_env(client_mode="chat"),
            interactive_auth=False,
            refresh_models=False,
        )
        self.page = ChatPage(session, ConfirmBridge())
        # Keep the smoke off the real session store.
        self.page.session.persist = lambda: None
        self.page.sidebar.refresh = lambda *a, **k: None
        self.page._maybe_refresh_transcript = lambda: None
        self.answers: list = []
        self.page.session.answer_ask = (
            lambda ask_id, text: self.answers.append((ask_id, text)) or True
        )

    def tearDown(self) -> None:
        self.page.close()
        self.app.processEvents()

    def _cards(self) -> list:
        widgets = []
        for i in range(self.page.feed.count()):
            w = self.page.feed.itemAt(i).widget()
            if w is not None and type(w).__name__ == "AskWidget":
                widgets.append(w)
        return widgets

    def test_the_question_card_answers_the_parked_tool_call(self) -> None:
        self.page.on_event(_ask_event())
        self.app.processEvents()
        cards = self._cards()
        self.assertEqual(len(cards), 1)
        cards[0]._buttons[0].click()
        self.assertEqual(self.answers, [("call_1", "This chat")])

    def test_the_run_ending_closes_the_card(self) -> None:
        self.page.on_event(_ask_event())
        self.page.on_event({"kind": "done"})
        self.app.processEvents()
        card = self._cards()[0]
        self.assertEqual(self.page._ask_cards, {})
        self.assertEqual(card._status.text(), "No answer")
        self.assertFalse(card._buttons[0].isEnabled())


if __name__ == "__main__":
    unittest.main()
