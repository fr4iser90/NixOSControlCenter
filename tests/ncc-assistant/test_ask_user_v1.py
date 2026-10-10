#!/usr/bin/env python3
"""Native `ask_user`: the model asks, the surface answers, the answer is the tool result.

Before: a chat model had no way to stop and ask — it either guessed a scope or
ended its turn and lost the run.
Now: one tool, one `ask` event reported before the wait, one `answer_ask()` back
into the blocked worker; no interactive surface means a clear error, never a hang.
"""

from __future__ import annotations

import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.config import Settings  # noqa: E402
from ncc_assistant.runtime import (  # noqa: E402
    TOOL_DEFINITIONS,
    ToolRuntime,
    ask_payload,
    normalize_ask_options,
)
from ncc_assistant.session import ChatSession  # noqa: E402


def _settings(**over) -> Settings:
    root = Path("/tmp/ncc-assistant-ask-test")
    base = dict(
        root=root,
        knowledge_root=root / "knowledge",
        prompts_root=root / "prompts",
        config_bin="ncc-assistant-config",
        api="openai-compatible",
        model="test-model",
        endpoint="http://127.0.0.1:9/v1",
        api_key=None,
        api_header_name=None,
        max_tokens=None,
        temperature=None,
        allow_write=False,
        mcp_allow_write=False,
        allow_rebuild=False,
        client_mode="chat",
        nixos_dir="/etc/nixos",
        allow_shell=False,
        agent_max_steps=-1,
        agent_allow_write=False,
        agent_allow_rebuild=False,
        agent_confirm="never",
        agent_dry_run=True,
        agent_profile=None,
        agent_harness="native",
        agent_coding_harness="auto",
        notify_enable=False,
        notify_timeout_sec=1,
        notify_on_timeout="block",
        mcp_servers_json=None,
        extra_headers=(),
        context_window=None,
        compact_threshold=-1,
        auto_compact=True,
    )
    base.update(over)
    return Settings(**base)


def _ask_args(**over) -> dict:
    args = {
        "question": "Which window should I compact?",
        "header": "Scope",
        "options": [
            {"label": "This chat", "description": "Only the active transcript"},
            {"label": "All chats", "description": "Every stored chat"},
        ],
    }
    args.update(over)
    return args


def _tool_call(name: str, args: dict, call_id: str | None = "call_1") -> dict:
    import json

    tc = {"function": {"name": name, "arguments": json.dumps(args)}}
    if call_id is not None:
        tc["id"] = call_id
    return tc


class _Surface:
    """Drives a session the way a chat surface does, answering ask events."""

    def __init__(self, session: ChatSession, answer: str | None, *, delay: float = 0.0):
        self.session = session
        self.answer = answer
        self.delay = delay
        self.events: list[dict] = []
        self.asks: list[dict] = []
        self.answered: list[tuple[str, str | None]] = []

    def run(self, text: str = "do the thing") -> list[dict]:
        import time

        for event in self.session.send(text):
            self.events.append(event)
            if event.get("kind") != "ask":
                continue
            self.asks.append(event)
            if self.delay:
                time.sleep(self.delay)
            self.answered.append(
                (event["ask_id"], self.answer if self.answer is not None else None)
            )
            self.session.answer_ask(event["ask_id"], self.answer)
        return self.events

    def kinds(self) -> list[str]:
        return [e.get("kind") for e in self.events]

    def tool_results(self) -> list[str]:
        return [
            str(e.get("text") or "")
            for e in self.events
            if e.get("kind") == "tool_result"
        ]


def _last_text(events: list[dict]) -> str:
    """Last assistant prose of a run — the tail is `context` then `done`, not text."""
    for event in reversed(events):
        if event.get("kind") == "assistant":
            return str(event.get("text") or "")
    return ""


def _session(runtime: ToolRuntime) -> ChatSession:
    session = ChatSession(
        settings=_settings(),
        runtime=runtime,
        messages=[{"role": "system", "content": "sys"}],
    )
    return session


def _streams(*messages: dict) -> callable:
    """Fake `iter_chat_completion`: one canned done-message per LLM round."""
    calls = {"n": 0}

    def fake(settings, messages_, tools, cancel_event=None):
        index = min(calls["n"], len(messages) - 1)
        calls["n"] += 1
        yield {"type": "done", "message": messages[index]}

    return fake


class ToolDefinitionTests(unittest.TestCase):
    def test_ask_user_is_declared_like_qwen_code(self) -> None:
        spec = next(t for t in TOOL_DEFINITIONS if t["name"] == "ask_user")
        schema = spec["inputSchema"]
        self.assertEqual(schema["required"], ["question"])
        props = schema["properties"]
        self.assertIn("header", props)
        self.assertIn("options", props)
        self.assertIn("multi_select", props)
        self.assertEqual(props["options"]["minItems"], 2)
        self.assertEqual(props["options"]["maxItems"], 4)
        # It asks, it does not approve a write — that is confirm_hook's job.
        self.assertIn("not to confirm", spec["description"].lower())

    def test_it_reaches_the_model_catalog(self) -> None:
        from ncc_assistant.registry import get_registry, reload_registry

        reload_registry()
        entry = get_registry().get("ask_user")
        self.assertIsNotNone(entry)
        self.assertEqual(entry.risk, "read", "must stay usable in the read-only profile")
        names = {t["function"]["name"] for t in get_registry().openai_tools()}
        self.assertIn("ask_user", names)


class PayloadTests(unittest.TestCase):
    def test_normal_payload(self) -> None:
        payload = ask_payload("call_9", _ask_args(multi_select=True))
        self.assertEqual(payload["ask_id"], "call_9")
        self.assertEqual(payload["question"], "Which window should I compact?")
        self.assertEqual(payload["header"], "Scope")
        self.assertTrue(payload["multi"])
        self.assertEqual(
            [o["label"] for o in payload["options"]], ["This chat", "All chats"]
        )

    def test_options_survive_a_loose_model(self) -> None:
        # Strings instead of objects, empty labels, a runaway fifth option.
        out = normalize_ask_options(
            ["Yes", {"label": " No ", "description": "x"}, {"label": "  "}, "A", "B", "C"]
        )
        self.assertEqual([o["label"] for o in out], ["Yes", "No", "A", "B"])
        self.assertEqual(out[1], {"label": "No", "description": "x"})

    def test_long_input_is_bounded(self) -> None:
        payload = ask_payload(None, {"question": "q" * 5000, "header": "h" * 100})
        self.assertEqual(len(payload["question"]), 1000)
        self.assertEqual(len(payload["header"]), 24)
        self.assertEqual(payload["ask_id"], "")


class RuntimeTests(unittest.TestCase):
    def test_headless_says_so_instead_of_blocking(self) -> None:
        runtime = ToolRuntime(_settings())  # no hook: MCP, agent runs, cron
        self.assertIsNone(runtime.ask_hook)
        result = runtime.call("ask_user", _ask_args(), ask_id="call_1")
        self.assertFalse(result["ok"])
        self.assertIn("No interactive surface", result["error"])

    def test_missing_question_is_an_error_not_a_question(self) -> None:
        runtime = ToolRuntime(_settings(), ask_hook=lambda payload: "ignored")
        result = runtime.call("ask_user", {"header": "x"}, ask_id="call_1")
        self.assertFalse(result["ok"])
        self.assertIn("question", result["error"])

    def test_answer_comes_back_as_the_tool_result(self) -> None:
        runtime = ToolRuntime(_settings(), ask_hook=lambda payload: "This chat")
        result = runtime.call("ask_user", _ask_args(), ask_id="call_1")
        self.assertTrue(result["ok"])
        self.assertTrue(result["answered"])
        self.assertEqual(result["answer"], "This chat")

    def test_no_answer_tells_the_model_not_to_ask_again(self) -> None:
        runtime = ToolRuntime(_settings(), ask_hook=lambda payload: None)
        result = runtime.call("ask_user", _ask_args(), ask_id="call_1")
        self.assertTrue(result["ok"])
        self.assertFalse(result["answered"])
        self.assertIsNone(result["answer"])
        self.assertIn("Do not ask again", result["note"])

    def test_the_hook_sees_the_payload_the_surface_will_render(self) -> None:
        seen: list[dict] = []
        runtime = ToolRuntime(_settings(), ask_hook=lambda p: (seen.append(p), "ok")[1])
        runtime.call("ask_user", _ask_args(), ask_id="call_7")
        self.assertEqual(seen[0]["ask_id"], "call_7")
        self.assertEqual(len(seen[0]["options"]), 2)

    def test_confirmation_is_not_asked_twice(self) -> None:
        # AGENT_CONFIRM=always must not stack a write prompt onto the question.
        with patch.dict("os.environ", {"AGENT_CONFIRM": "always"}):
            runtime = ToolRuntime(_settings())
            with patch.object(runtime, "_request_confirmation") as confirm:
                result = runtime.call("ask_user", _ask_args(), ask_id="call_1")
        confirm.assert_not_called()
        self.assertFalse(result["ok"])


class SessionTests(unittest.TestCase):
    def test_question_is_reported_then_answered(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {
                "content": "",
                "tool_calls": [_tool_call("ask_user", _ask_args())],
            },
            {"content": "Compacting this chat only.", "tool_calls": []},
        )
        surface = _Surface(session, "This chat")
        with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
            "ncc_assistant.session.save_session"
        ):
            surface.run()

        self.assertEqual(surface.kinds().count("ask"), 1)
        ask = surface.asks[0]
        self.assertEqual(ask["ask_id"], "call_1")
        self.assertEqual(ask["question"], "Which window should I compact?")
        self.assertEqual(ask["header"], "Scope")
        self.assertFalse(ask["multi"])
        # The question is on screen before anything blocks, so the chip is live.
        self.assertLess(surface.kinds().index("ask"), surface.kinds().index("tool_result"))
        self.assertIn("This chat", surface.tool_results()[0])
        self.assertIn('"answered": true', surface.tool_results()[0])
        self.assertEqual(_last_text(surface.events), "Compacting this chat only.")
        self.assertEqual(session.pending_ask_ids(), [])

    def test_the_answer_reaches_the_model_as_a_tool_message(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {"content": "", "tool_calls": [_tool_call("ask_user", _ask_args())]},
            {"content": "done", "tool_calls": []},
        )
        # Driven like a surface: an unanswered question holds the worker until timeout.
        surface = _Surface(session, "This chat")
        with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
            "ncc_assistant.session.save_session"
        ):
            surface.run()

        tool_msgs = [m for m in session.messages if m.get("role") == "tool"]
        self.assertEqual(len(tool_msgs), 1)
        self.assertEqual(tool_msgs[0]["tool_call_id"], "call_1")
        self.assertIn("This chat", tool_msgs[0]["content"])

    def test_skipping_the_question_frees_the_worker(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {"content": "", "tool_calls": [_tool_call("ask_user", _ask_args())]},
            {"content": "proceeded on assumptions", "tool_calls": []},
        )

        def no_answer(event):
            # The human dismissed the card: release the tool with nothing.
            session.abandon_asks()

        events = []
        with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
            "ncc_assistant.session.save_session"
        ):
            for event in session.send("go"):
                events.append(event)
                if event.get("kind") == "ask":
                    no_answer(event)

        self.assertIn('"answered": false', events[[e.get("kind") for e in events].index("tool_result")]["text"])
        self.assertEqual(_last_text(events), "proceeded on assumptions")

    def test_missing_tool_call_id_still_gets_one(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {
                "content": "",
                "tool_calls": [_tool_call("ask_user", _ask_args(), call_id=None)],
            },
            {"content": "ok", "tool_calls": []},
        )
        surface = _Surface(session, "picked it")
        with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
            "ncc_assistant.session.save_session"
        ):
            surface.run()
        self.assertTrue(surface.asks[0]["ask_id"].startswith("ask-"))
        self.assertIn("picked it", surface.tool_results()[0])

    def test_other_tools_do_not_produce_ask_events(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {"content": "", "tool_calls": [_tool_call("list_modules", {})]},
            {"content": "ok", "tool_calls": []},
        )
        with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
            "ncc_assistant.session.save_session"
        ):
            kinds = [e.get("kind") for e in session.send("go")]
        self.assertNotIn("ask", kinds)

    def test_answering_a_dead_question_is_false(self) -> None:
        session = _session(ToolRuntime(_settings()))
        self.assertFalse(session.answer_ask("nope", "late"))

    def test_cancel_releases_a_waiting_worker(self) -> None:
        session = _session(ToolRuntime(_settings()))
        stream = _streams(
            {"content": "", "tool_calls": [_tool_call("ask_user", _ask_args())]},
            {"content": "never", "tool_calls": []},
        )
        done = threading.Event()
        collected: list[dict] = []

        def worker():
            with patch("ncc_assistant.session.iter_chat_completion", side_effect=stream), patch(
                "ncc_assistant.session.save_session"
            ):
                for event in session.send("go"):
                    collected.append(event)
                    if event.get("kind") == "ask":
                        # The stop button: only cancel_event is set by the surface.
                        threading.Timer(0.05, session.request_cancel).start()
            done.set()

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()
        self.assertTrue(done.wait(timeout=5), "cancel must free the blocked worker")
        thread.join(timeout=1)
        self.assertIn("error", [e.get("kind") for e in collected])
        self.assertEqual(session.pending_ask_ids(), [])

    def test_a_new_question_orphans_the_previous_one(self) -> None:
        session = _session(ToolRuntime(_settings()))
        first = session._begin_ask("ask_user", "call_a", _ask_args())
        second = session._begin_ask("ask_user", "call_b", _ask_args())
        self.assertEqual(session.pending_ask_ids(), [second["ask_id"]])
        self.assertFalse(session.answer_ask(first["ask_id"], "too late"))

    def test_rebuilt_runtime_keeps_the_hook(self) -> None:
        session = _session(ToolRuntime(_settings()))
        with patch("ncc_assistant.session.list_models", return_value=[]):
            session.set_model("other-model")
        self.assertEqual(session.runtime.ask_hook, session._wait_ask)

    def test_a_swapped_runtime_can_still_be_answered(self) -> None:
        # Reauth / provider change rebuilds the runtime; a question must not answer
        # "No interactive surface" in the middle of a live chat.
        session = _session(ToolRuntime(_settings()))
        fresh = ToolRuntime(_settings(), confirm_hook=lambda *a, **k: False)
        session.attach_runtime(fresh)
        self.assertEqual(session.runtime.ask_hook, session._wait_ask)

        ask = session._begin_ask("ask_user", "call_c", _ask_args())
        got: list = []
        worker = threading.Thread(
            target=lambda: got.append(
                session.runtime.call("ask_user", _ask_args(), ask_id=ask["ask_id"])
            ),
            daemon=True,
        )
        worker.start()
        self.assertTrue(session.answer_ask(ask["ask_id"], "after reauth"))
        worker.join(timeout=5)
        self.assertTrue(got[0]["answered"])
        self.assertEqual(got[0]["answer"], "after reauth")


class GuiRuntimeSwapTests(unittest.TestCase):
    """Rebuilding the runtime without the hook would silently kill ask_user."""

    def test_the_gui_swaps_runtimes_through_the_session(self) -> None:
        text = (ROOT / "ncc_assistant" / "gui.py").read_text(encoding="utf-8")
        self.assertNotIn(
            "session.runtime = ToolRuntime(",
            text,
            "raw runtime assignment drops session.ask_hook — use attach_runtime()",
        )
        self.assertGreaterEqual(text.count("attach_runtime("), 4)


class ReplTests(unittest.TestCase):
    """`ncc ai` without Qt: the question still has to become an answer."""

    def _ask(self, typed: str | None, **over) -> str | None:
        from ncc_assistant.chat import _ask_answer

        event = {
            "ask_id": "a1",
            "question": "Which window?",
            "header": "Scope",
            "options": [
                {"label": "This chat", "description": "only this"},
                {"label": "All chats", "description": "everything"},
            ],
            "multi": False,
        }
        event.update(over)
        with patch("builtins.input", return_value=typed):
            return _ask_answer(event)

    def test_number_picks_the_option_label(self) -> None:
        self.assertEqual(self._ask("2"), "All chats")

    def test_free_text_beats_an_unparsable_choice(self) -> None:
        self.assertEqual(self._ask("the small one please"), "the small one please")

    def test_enter_skips(self) -> None:
        self.assertIsNone(self._ask(""))

    def test_multi_select_joins_labels(self) -> None:
        self.assertEqual(self._ask("1,2", multi=True), "This chat, All chats")

    def test_eof_is_a_skip_not_a_crash(self) -> None:
        from ncc_assistant.chat import _ask_answer

        with patch("builtins.input", side_effect=EOFError):
            self.assertIsNone(_ask_answer({"ask_id": "a1", "question": "q"}))


class StoreTests(unittest.TestCase):
    """A reloaded companion chat must show the question and what was answered."""

    def test_ask_item_survives_the_store(self) -> None:
        from ncc_assistant.companion_store import transcript_for_store

        kept = transcript_for_store(
            [
                {
                    "kind": "ask",
                    "ask_id": "call_1",
                    "question": "Which window?",
                    "header": "Scope",
                    "options": [
                        {"label": "This chat", "description": "only this"},
                        {"label": "  ", "description": "dropped"},
                    ],
                    "multi": True,
                    "answer": "This chat",
                },
                {"kind": "ask", "ask_id": "call_2", "question": "unanswered"},
            ]
        )
        self.assertEqual(kept[0]["ask_id"], "call_1")
        self.assertEqual(kept[0]["question"], "Which window?")
        self.assertEqual(kept[0]["header"], "Scope")
        self.assertEqual([o["label"] for o in kept[0]["options"]], ["This chat"])
        self.assertTrue(kept[0]["multi"])
        self.assertEqual(kept[0]["answer"], "This chat")
        self.assertNotIn("answer", kept[1])
        self.assertEqual(kept[1]["options"], [])


class SurfaceWiringTests(unittest.TestCase):
    """Every surface that streams chat must be able to answer the question."""

    def test_surfaces_call_answer_ask(self) -> None:
        pkg = ROOT / "ncc_assistant"
        for name in ("chat.py", "gui.py", "companion.py"):
            text = (pkg / name).read_text(encoding="utf-8")
            self.assertIn("answer_ask", text, f"{name} cannot answer ask_user")
            self.assertIn('"ask"', text, f"{name} never looks at the ask event")


if __name__ == "__main__":
    unittest.main()
