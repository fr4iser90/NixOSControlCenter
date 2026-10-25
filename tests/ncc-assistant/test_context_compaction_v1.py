#!/usr/bin/env python3
"""Context window observability + qwen-code-style compaction.

Before: nothing counted tokens, nothing knew the window, and a long session just
died on the gateway's 400.
Now: real usage is anchored and extended by a char estimate; the window is probed
from the gateway (llama.cpp /props, Ollama /api/show) or set in Nix; compaction
fires at the qwen threshold, on demand, or once after a context-length 400.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))

from core.store.config import Settings, compact_threshold_for  # noqa: E402
from core.runtime import context as ctx  # noqa: E402
from core.runtime.context import ContextMeter  # noqa: E402
from core.runtime.history import title_from_messages  # noqa: E402
from core.runtime.llm import (  # noqa: E402
    LLMError,
    _openai_payload,
    _rejects_stream_options,
    detect_context_window,
    is_context_length_error,
    normalize_usage,
)
from core.runtime.session import ChatSession  # noqa: E402


def _settings(**over) -> Settings:
    root = Path("/tmp/ncc-assistant-ctx-test")
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


class FakeResponse:
    def __init__(self, payload, status=200):
        self._payload = payload
        self.status_code = status
        self.text = str(payload)

    def json(self):
        return self._payload


class FakeClient:
    """Answers only the URLs the probes use; anything else 404."""

    def __init__(self, routes, *, raise_on=None):
        self.routes = routes
        self.raise_on = raise_on or set()
        self.calls: list[str] = []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def _hit(self, method, url, payload=None):
        self.calls.append(f"{method} {url}")
        if url in self.raise_on:
            import httpx

            raise httpx.ConnectError("down")
        return FakeResponse(self.routes.get(url, {}))

    def get(self, url, headers=None):
        return self._hit("GET", url)

    def post(self, url, headers=None, json=None):
        return self._hit("POST", url, json)


def _msgs(n: int, size: int = 200, role: str = "user") -> list[dict]:
    return [{"role": role, "content": "x" * size} for _ in range(n)]


class UsageTests(unittest.TestCase):
    def test_openai_spelling(self) -> None:
        self.assertEqual(
            normalize_usage({"prompt_tokens": 100, "completion_tokens": 25, "total_tokens": 125}),
            {"input": 100, "output": 25, "total": 125},
        )

    def test_total_is_derived_when_absent(self) -> None:
        self.assertEqual(
            normalize_usage({"prompt_tokens": 100, "completion_tokens": 25}),
            {"input": 100, "output": 25, "total": 125},
        )

    def test_anthropic_and_ollama_spellings(self) -> None:
        self.assertEqual(normalize_usage({"input_tokens": 9, "output_tokens": 4}),
                         {"input": 9, "output": 4, "total": 13})
        self.assertEqual(normalize_usage({"prompt_eval_count": 120, "eval_count": 30}),
                         {"input": 120, "output": 30, "total": 150})

    def test_input_backfilled_from_total(self) -> None:
        self.assertEqual(normalize_usage({"total_tokens": 130, "completion_tokens": 30}),
                         {"input": 100, "output": 30, "total": 130})

    def test_empty_payloads_yield_nothing(self) -> None:
        self.assertEqual(normalize_usage({}), {})
        self.assertEqual(normalize_usage(None), {})
        self.assertEqual(normalize_usage({"prompt_tokens": 0}), {})


class ThresholdTests(unittest.TestCase):
    """Numbers measured in the qwen-code 0.23.4 bundle (computeThresholds)."""

    def test_absolute_ceiling_applies_on_large_windows(self) -> None:
        # min(0.85*200000, 200000-20000-13000) — the ceiling wins above 33k.
        self.assertEqual(compact_threshold_for(200_000), 167_000)
        self.assertEqual(compact_threshold_for(64_000), 31_000)

    def test_small_window_uses_the_fraction(self) -> None:
        # Ceiling negative → 0.85 of num_ctx, so local gateways still compact.
        self.assertEqual(compact_threshold_for(4096), 3481)
        self.assertEqual(compact_threshold_for(8192), 6963)
        self.assertEqual(compact_threshold_for(32_768), 27_852)

    def test_threshold_always_below_window(self) -> None:
        for window in (1024, 2048, 4096, 8192, 32_768, 128_000, 1_000_000):
            self.assertLess(compact_threshold_for(window), window, window)

    def test_explicit_override_wins(self) -> None:
        self.assertEqual(compact_threshold_for(200_000, 50_000), 50_000)
        # -1/0 means "derive", not "compact at zero".
        self.assertEqual(compact_threshold_for(200_000, -1), 167_000)


class WindowProbeTests(unittest.TestCase):
    def test_llamacpp_props_wins(self) -> None:
        client = FakeClient({"http://127.0.0.1:9/props": {"n_ctx": 16384}})
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            found = detect_context_window(_settings(), use_cache=False)
        self.assertEqual(found, {"tokens": 16384, "source": "/props n_ctx"})

    def test_runtime_num_ctx_beats_trained_length(self) -> None:
        client = FakeClient(
            {
                "http://127.0.0.1:9/api/show": {
                    "model_info": {"llama.context_length": 131072},
                    "parameters": "from llamacpp\nPARAM num_ctx 4096\n",
                }
            }
        )
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            found = detect_context_window(_settings(), use_cache=False)
        self.assertEqual(found, {"tokens": 4096, "source": "ollama num_ctx"})

    def test_trained_length_used_when_no_runtime_cap(self) -> None:
        client = FakeClient(
            {"http://127.0.0.1:9/api/show": {"model_info": {"llama.context_length": 131072}}}
        )
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            found = detect_context_window(_settings(), use_cache=False)
        self.assertEqual(found, {"tokens": 131072, "source": "ollama context_length"})

    def test_gateway_metadata_fallback(self) -> None:
        client = FakeClient(
            {
                "http://127.0.0.1:9/v1/models": {
                    "data": [{"id": "test-model", "max_model_len": 32768}]
                }
            }
        )
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            found = detect_context_window(_settings(), use_cache=False)
        self.assertEqual(found, {"tokens": 32768, "source": "/models metadata"})

    def test_unreachable_gateway_returns_none_and_never_raises(self) -> None:
        client = FakeClient({}, raise_on={
            "http://127.0.0.1:9/props",
            "http://127.0.0.1:9/v1/props",
            "http://127.0.0.1:9/api/show",
            "http://127.0.0.1:9/v1/models",
        })
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            self.assertIsNone(detect_context_window(_settings(), use_cache=False))

    def test_anthropic_is_not_probed(self) -> None:
        client = FakeClient({})
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            self.assertIsNone(detect_context_window(_settings(api="anthropic"), use_cache=False))
        self.assertEqual(client.calls, [])

    def test_cache_skips_second_probe(self) -> None:
        routes = {"http://127.0.0.1:9/props": {"n_ctx": 8192}}
        with patch("core.runtime.llm.httpx.Client", return_value=FakeClient(routes)):
            detect_context_window(_settings(), use_cache=True)
        client = FakeClient(routes)
        with patch("core.runtime.llm.httpx.Client", return_value=client):
            found = detect_context_window(_settings(), use_cache=True)
        self.assertEqual(found, {"tokens": 8192, "source": "/props n_ctx"})
        self.assertEqual(client.calls, [])

    def test_meter_prefers_nix_override_then_probe_then_default(self) -> None:
        with patch("core.runtime.llm.detect_context_window", return_value=None):
            meter = ContextMeter.for_settings(_settings())
        self.assertEqual(meter.window, 8192)
        self.assertEqual(meter.window_source, "default")
        meter = ContextMeter.for_settings(_settings(context_window=65536))
        self.assertEqual((meter.window, meter.window_source), (65536, "config"))
        with patch(
            "core.runtime.llm.detect_context_window",
            return_value={"tokens": 4096, "source": "/props n_ctx"},
        ):
            meter = ContextMeter.for_settings(_settings())
        self.assertEqual((meter.window, meter.window_source), (4096, "/props n_ctx"))


class ContextLengthErrorTests(unittest.TestCase):
    def test_recognises_common_wording(self) -> None:
        for text in (
            "HTTP 400: {'error': {'code': 'context_length_exceeded'}}",
            "The prompt is too long: 31000 tokens over the model's maximum context",
            "CUDA out of memory: not enough space for num_ctx 4096",
            "reduce the length of the input",
        ):
            self.assertTrue(is_context_length_error(LLMError(text, status_code=400)), text)

    def test_ignores_unrelated_errors(self) -> None:
        self.assertFalse(is_context_length_error(LLMError("HTTP 500: gateway blew up")))
        self.assertFalse(is_context_length_error(LLMError("HTTP 429: rate limited", status_code=429)))

    def test_stream_options_only_rejects_those(self) -> None:
        self.assertTrue(_rejects_stream_options(LLMError("unknown field 'stream_options'")))
        self.assertFalse(_rejects_stream_options(LLMError("HTTP 400: bad tool schema")))


class StreamOptionsTests(unittest.TestCase):
    def test_only_streaming_payloads_ask_for_usage(self) -> None:
        s = _settings()
        self.assertEqual(_openai_payload(s, "m", [], None, stream=False).get("stream_options"), None)
        self.assertEqual(
            _openai_payload(s, "m", [], None, stream=True).get("stream_options"),
            {"include_usage": True},
        )

    def test_rejecting_gateway_is_not_asked_twice(self) -> None:
        from core.runtime import llm

        llm._STREAM_OPTIONS_REJECTORS.add("grumpy-model")
        try:
            self.assertIsNone(
                _openai_payload(_settings(), "grumpy-model", [], None, stream=True).get(
                    "stream_options"
                )
            )
        finally:
            llm._STREAM_OPTIONS_REJECTORS.discard("grumpy-model")


class EstimateTests(unittest.TestCase):
    def test_tool_calls_count(self) -> None:
        msg = {
            "role": "assistant",
            "content": "hi",
            "tool_calls": [
                {
                    "id": "call_1",
                    "type": "function",
                    "function": {"name": "run_command", "arguments": "{\"cmd\": \"ls -la\"}"},
                }
            ],
        }
        self.assertGreater(estimate := ctx.estimate_message_tokens(msg), 1)
        self.assertGreater(estimate, ctx.estimate_message_tokens({"role": "assistant", "content": "hi"}))

    def test_images_use_a_flat_allowance(self) -> None:
        text = ctx.estimate_message_tokens({"role": "user", "content": "hello"})
        img = ctx.estimate_message_tokens(
            {"role": "user", "content": [{"type": "image_url", "image_url": {"url": "data:image/png;base64,AAAA"}}]}
        )
        self.assertEqual(img, ctx.IMAGE_TOKENS + 1)
        self.assertGreater(img, text)


class GroupingTests(unittest.TestCase):
    def test_tool_group_is_atomic(self) -> None:
        msgs = [
            {"role": "system", "content": "sys"},
            {"role": "user", "content": "q"},
            {"role": "assistant", "content": "", "tool_calls": [{"id": "c1", "function": {"name": "a", "arguments": "{}"}}]},
            {"role": "tool", "tool_call_id": "c1", "content": "r1"},
            {"role": "tool", "tool_call_id": "c2", "content": "r2"},
            {"role": "assistant", "content": "done"},
        ]
        groups = ctx.group_messages(msgs[1:])
        self.assertEqual([len(g) for g in groups], [1, 3, 1])

    def test_compaction_never_orphans_a_tool_result(self) -> None:
        msgs = [{"role": "system", "content": "sys"}]
        for i in range(6):
            msgs.append({"role": "user", "content": f"q{i}"})
            msgs.append(
                {
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [{"id": f"c{i}", "function": {"name": "t", "arguments": "{}"}}],
                }
            )
            msgs.append({"role": "tool", "tool_call_id": f"c{i}", "content": "r" * 400})
        head, older, tail = ctx.split_for_compaction(msgs, keep=4)
        self.assertEqual(head[0]["role"], "system")
        self.assertTrue(older)
        self.assertEqual(tail[0]["role"], "assistant")
        # Every assistant with tool_calls in the tail keeps its tool result.
        for i, msg in enumerate(tail):
            if msg.get("tool_calls"):
                self.assertEqual(tail[i + 1]["role"], "tool")

    def test_short_history_is_left_alone(self) -> None:
        msgs = [
            {"role": "system", "content": "sys"},
            {"role": "user", "content": "hi"},
            {"role": "assistant", "content": "hello"},
        ]
        head, older, tail = ctx.split_for_compaction(msgs)
        self.assertEqual(older, [])
        self.assertEqual(tail, msgs[1:])


class MeterTests(unittest.TestCase):
    def test_usage_anchor_extends_inst_of_reestimating(self) -> None:
        meter = ContextMeter(settings=_settings(), window=200_000)
        msgs = _msgs(40, 400)
        naive = ctx.estimate_tokens(msgs)
        meter.observe(40, {"input": 90_000, "output": 1_000, "total": 91_000})
        used, basis = meter.used_tokens(msgs)
        self.assertEqual(basis, "usage")
        self.assertGreater(used, naive)

    def test_estimate_only_before_first_usage(self) -> None:
        meter = ContextMeter(settings=_settings(), window=200_000)
        used, basis = meter.used_tokens(_msgs(3))
        self.assertEqual(basis, "estimate")
        self.assertEqual(used, ctx.estimate_tokens(_msgs(3)))

    def test_tool_schemas_count_toward_used(self) -> None:
        meter = ContextMeter(settings=_settings(), window=200_000)
        before = meter.used_tokens([])[0]
        meter.note_tools([{"function": {"name": "x", "parameters": {}}}])
        self.assertGreater(meter.used_tokens([])[0], before)

    def test_over_threshold(self) -> None:
        meter = ContextMeter(settings=_settings(), window=4096)
        self.assertFalse(meter.over_threshold(_msgs(1)))
        self.assertTrue(meter.over_threshold(_msgs(60, 400)))

    def test_report_shape(self) -> None:
        meter = ContextMeter(settings=_settings(), window=10_000, window_source="config")
        report = meter.report(_msgs(10, 400))
        self.assertEqual(report["window"], 10_000)
        self.assertEqual(report["window_source"], "config")
        self.assertEqual(report["used"], ctx.estimate_tokens(_msgs(10, 400)))
        self.assertEqual(report["free"], 10_000 - report["used"])
        self.assertEqual(report["threshold"], compact_threshold_for(10_000))
        self.assertEqual(report["messages"], 10)
        self.assertEqual(report["compactions"], 0)
        self.assertTrue(report["auto"])
        self.assertEqual(report["used"] + report["free"], report["window"])


class CompactionTests(unittest.TestCase):
    def _long_history(self) -> list[dict]:
        msgs = [{"role": "system", "content": "sys prompt"}]
        for i in range(10):
            msgs.append({"role": "user", "content": f"question {i} " + "u" * 500})
            msgs.append({"role": "assistant", "content": f"answer {i} " + "a" * 500})
        return msgs

    def test_summary_replaces_older_turns(self) -> None:
        msgs = self._long_history()
        with patch("core.runtime.context.chat_completion", return_value={"content": "SUMMARY BODY"}):
            merged, summary = ctx.compact_messages(_settings(), msgs, 200_000, keep=4)
        self.assertEqual(summary, "SUMMARY BODY")
        self.assertEqual(merged[0]["role"], "system")
        self.assertTrue(merged[1]["content"].startswith(ctx.SUMMARY_PREFIX))
        self.assertIn("SUMMARY BODY", merged[1]["content"])
        self.assertLess(len(merged), len(msgs))
        self.assertEqual(merged[-1]["content"], msgs[-1]["content"])

    def test_no_extra_message_keys(self) -> None:
        # Strict gateways 400 on unknown message fields — recognising a summary
        # must stay a content-prefix check.
        with patch("core.runtime.context.chat_completion", return_value={"content": "S"}):
            merged, _ = ctx.compact_messages(_settings(), self._long_history(), 200_000, keep=4)
        self.assertEqual(set(merged[1]), {"role", "content"})
        self.assertTrue(ctx.is_summary_message(merged[1]))

    def test_summary_never_becomes_the_title(self) -> None:
        msgs = self._long_history()
        with patch("core.runtime.context.chat_completion", return_value={"content": "S"}):
            merged, _ = ctx.compact_messages(_settings(), msgs, 200_000, keep=4)
        derived = title_from_messages(merged)
        self.assertTrue(ctx.is_summary_message(merged[1]))
        self.assertFalse(derived.startswith("[Summary"))
        self.assertTrue(derived.startswith("question 8"), derived)

    def test_session_title_survives_compaction(self) -> None:
        # The message a title came from is exactly what compaction deletes, so the
        # title is latched on the session rather than re-read from the survivors.
        msgs = [{"role": "system", "content": "sys"}] + self._long_history()[1:]
        runtime = MagicMock()
        runtime.openai_tools.return_value = []
        session = ChatSession(settings=_settings(), runtime=runtime, messages=msgs)
        with patch("core.runtime.session.save_session"):
            session.persist()
            self.assertTrue(session.title.startswith("question 0"))
            self.assertTrue(session.title_locked)
            with patch("core.runtime.context.chat_completion", return_value={"content": "S"}):
                list(session.compact_now())
            saved_title = session.title
            self.assertTrue(ctx.is_summary_message(session.messages[1]))
        self.assertEqual(session.title, saved_title)

    def test_transcript_is_capped_below_the_window(self) -> None:
        huge = [{"role": "user", "content": "z" * 100_000} for _ in range(10)]
        sent: dict = {}

        def capture(_settings, messages, tools):
            sent["text"] = messages[1]["content"]
            return {"content": "S"}

        with patch("core.runtime.context.chat_completion", side_effect=capture):
            ctx.compact_messages(_settings(), huge, 8192, keep=2)
        self.assertLess(len(sent["text"]), ctx._transcript_budget_chars(8192) + 40)
        self.assertTrue(sent["text"].startswith("[older turns omitted]"))

    def test_stream_reports_freed_tokens(self) -> None:
        msgs = self._long_history()
        meter = ContextMeter(settings=_settings(), window=200_000)
        before = meter.report(msgs)["used"]
        with patch("core.runtime.context.chat_completion", return_value={"content": "S"}):
            events = list(ctx.compact_stream(_settings(), msgs, meter))
        kinds = [e.get("kind") for e in events]
        self.assertEqual(kinds[0], "status")
        self.assertIn("context", kinds)
        final = events[-1]
        self.assertTrue(final["compacted"])
        self.assertEqual(final["saved"], before - final["used"])
        self.assertEqual(meter.compactions, 1)
        self.assertEqual(meter.anchor_count, 0)

    def test_empty_summary_leaves_history_untouched(self) -> None:
        msgs = self._long_history()
        snapshot = [dict(m) for m in msgs]
        meter = ContextMeter(settings=_settings(), window=200_000)
        with patch("core.runtime.context.chat_completion", return_value={"content": "  "}):
            events = list(ctx.compact_stream(_settings(), msgs, meter))
        self.assertEqual(msgs, snapshot)
        self.assertFalse(events[-1]["compacted"])
        self.assertEqual(meter.compactions, 0)

    def test_summariser_failure_does_not_raise(self) -> None:
        msgs = self._long_history()
        snapshot = [dict(m) for m in msgs]
        meter = ContextMeter(settings=_settings(), window=200_000)
        with patch(
            "core.runtime.context.chat_completion",
            side_effect=LLMError("HTTP 503: summariser down"),
        ):
            events = list(ctx.compact_stream(_settings(), msgs, meter))
        self.assertFalse(events[-1]["compacted"])
        # Half-compacted history would be worse than no compaction at all.
        self.assertEqual(msgs, snapshot)
        self.assertEqual(meter.compactions, 0)
        self.assertIn("Compaction failed", events[1]["text"])


class SessionIntegrationTests(unittest.TestCase):
    def _session(self, **over) -> ChatSession:
        settings = _settings(**over)
        runtime = MagicMock()
        runtime.openai_tools.return_value = []
        session = ChatSession(
            settings=settings,
            runtime=runtime,
            messages=[
                {"role": "system", "content": "sys"},
                *[
                    {"role": "user" if i % 2 == 0 else "assistant", "content": "y" * 400}
                    for i in range(30)
                ],
            ],
        )
        session.meter = ContextMeter(settings=settings, window=2048)
        return session

    def test_auto_compact_runs_before_the_request(self) -> None:
        session = self._session()
        seen: dict[str, list[int]] = {"sizes": []}

        def fake_stream(settings, messages, tools, cancel_event=None):
            seen["sizes"].append(len(messages))
            yield {"type": "done", "message": {"content": "ok", "tool_calls": []}}

        with patch("core.runtime.session.iter_chat_completion", side_effect=fake_stream), patch(
            "core.runtime.context.chat_completion", return_value={"content": "S"}
        ):
            events = list(session._run_turn([]))

        # 1 system + 1 summary + the 8 kept messages — compaction ran first.
        self.assertEqual(seen["sizes"], [10], "request must go out after compaction")
        self.assertTrue(any(e.get("phase") == "compact" for e in events))
        contexts = [e for e in events if e.get("kind") == "context"]
        self.assertTrue(any(c.get("compacted") for c in contexts), contexts)
        # The turn's final reading is the post-compaction one, not the old 31 msgs.
        self.assertEqual(contexts[-1]["messages"], 11)
        self.assertLess(contexts[-1]["percent"], 100)

    def test_auto_compact_can_be_disabled(self) -> None:
        session = self._session(auto_compact=False)
        seen: dict[str, int] = {}

        def fake_stream(settings, messages, tools, cancel_event=None):
            seen["size"] = len(messages)
            yield {"type": "done", "message": {"content": "ok", "tool_calls": []}}

        with patch("core.runtime.session.iter_chat_completion", side_effect=fake_stream), patch(
            "core.runtime.context.chat_completion", return_value={"content": "S"}
        ):
            list(session._run_turn([]))

        self.assertEqual(seen["size"], 31)

    def test_usage_from_reply_is_recorded(self) -> None:
        session = self._session(auto_compact=False)

        def fake_stream(settings, messages, tools, cancel_event=None):
            yield {"type": "delta", "text": "ok"}
            yield {
                "type": "done",
                "message": {
                    "content": "ok",
                    "tool_calls": [],
                    "model": "m-2",
                    "usage": {"input": 4321, "output": 99, "total": 4420},
                },
            }

        with patch("core.runtime.session.iter_chat_completion", side_effect=fake_stream):
            events = list(session._run_turn([]))

        self.assertEqual(session.model_label, "m-2")
        self.assertEqual(session.meter.last_usage["input"], 4321)
        used, basis = session.meter.used_tokens(session.messages)
        self.assertEqual(basis, "usage")
        self.assertGreater(used, 4420)
        self.assertEqual([e for e in events if e.get("kind") == "context"][-1]["usage"]["total"], 4420)

    def test_compact_now_is_manual_and_persists(self) -> None:
        session = self._session(auto_compact=False)
        with patch("core.runtime.context.chat_completion", return_value={"content": "S"}), patch(
            "core.runtime.session.save_session"
        ) as save:
            events = list(session.compact_now())
        self.assertTrue(events[-1]["compacted"])
        self.assertTrue(session.messages[1]["content"].startswith(ctx.SUMMARY_PREFIX))
        save.assert_called_once()

    def test_context_length_400_compacts_and_retries_once(self) -> None:
        session = self._session(auto_compact=False)
        calls: list[int] = []

        def fake_stream(settings, messages, tools, cancel_event=None):
            calls.append(len(messages))
            if len(calls) == 1:
                raise LLMError(
                    "HTTP 400: this exceeds the model's maximum context length",
                    status_code=400,
                )
            yield {"type": "done", "message": {"content": "recovered", "tool_calls": []}}

        with patch("core.runtime.session.iter_chat_completion", side_effect=fake_stream), patch(
            "core.runtime.context.chat_completion", return_value={"content": "S"}
        ), patch.object(session, "persist"):
            events = list(session.send("hello"))

        texts = [e.get("text", "") for e in events if e.get("kind") == "status"]
        self.assertTrue(any("compacting" in t.lower() for t in texts), texts)
        self.assertNotIn("hello", [e.get("text") for e in events if e.get("kind") == "error"])
        self.assertEqual(len(calls), 2)
        # 32 messages went out the first time; the retry runs on the compacted
        # history (system + summary + 8 kept).
        self.assertEqual(calls, [32, 10])


if __name__ == "__main__":
    unittest.main()
