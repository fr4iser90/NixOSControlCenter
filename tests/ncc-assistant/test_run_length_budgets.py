#!/usr/bin/env python3
"""Run-length budgets are opt-in: unlimited by default (qwen-code parity).

Before: ChatSession hard-capped tool rounds at 8 per message and the agent path
fell back to 50 / 24 / 15 depending on surface.
Now: UNLIMITED (-1) default; a budget exists only when Env/Nix sets one.
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.config import Settings, UNLIMITED, is_unlimited  # noqa: E402
from ncc_assistant.agent import AgentRunner, AgentSettings, run_agent  # noqa: E402
from ncc_assistant.session import ChatSession  # noqa: E402


def _settings(**over) -> Settings:
    root = Path("/tmp/ncc-assistant-test")
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
        agent_max_steps=UNLIMITED,
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
    )
    base.update(over)
    return Settings(**base)


def _tool_calls_round(n: int) -> dict:
    return {
        "type": "done",
        "message": {
            "content": "",
            "tool_calls": [
                {
                    "id": f"call_{n}",
                    "type": "function",
                    "function": {"name": "list_modules", "arguments": "{}"},
                }
            ],
        },
    }


def _final_round() -> dict:
    return {"type": "done", "message": {"content": "final answer", "tool_calls": []}}


class SentinelTests(unittest.TestCase):
    def test_default_settings_are_unlimited(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            s = Settings.from_env()
        self.assertEqual(s.agent_max_steps, UNLIMITED)
        self.assertEqual(s.chat_max_rounds, UNLIMITED)

    def test_env_opts_into_a_budget(self) -> None:
        env = {
            "NCC_ASSISTANT_AGENT_MAX_STEPS": "12",
            "NCC_ASSISTANT_CHAT_MAX_ROUNDS": "3",
        }
        with patch.dict(os.environ, env, clear=True):
            s = Settings.from_env()
        self.assertEqual(s.agent_max_steps, 12)
        self.assertEqual(s.chat_max_rounds, 3)

    def test_zero_and_negative_are_unlimited(self) -> None:
        for value in (-1, 0, None):
            self.assertTrue(is_unlimited(value), f"{value} must mean unlimited")
        self.assertFalse(is_unlimited(1))

    def test_nix_default_env_matches_sentinel(self) -> None:
        pkg = (
            REPO
            / "nixos/modules/specialized/ncc-assistant/package.nix"
        ).read_text(encoding="utf-8")
        options = (REPO / "nixos/modules/specialized/ncc-assistant/options.nix").read_text(
            encoding="utf-8"
        )
        # `expr or -1` is a syntax error for the parser used by nix build / nix eval
        # (legacy nix-instantiate --parse accepted it) — keep the literal parenthesised.
        self.assertIn(
            'export NCC_ASSISTANT_AGENT_MAX_STEPS="${toString (cfg.agent.maxSteps or (-1))}"', pkg
        )
        self.assertIn(
            'export NCC_ASSISTANT_CHAT_MAX_ROUNDS="${toString (cfg.agent.chatMaxRounds or (-1))}"',
            pkg,
        )
        self.assertIn("chatMaxRounds", options)
        for rel in (
            "nixos/modules/specialized/ncc-assistant/package.nix",
            "nixos/modules/specialized/ncc-assistant/schedules.nix",
        ):
            self.assertNotIn("or -1", (REPO / rel).read_text(encoding="utf-8"), rel)


class ChatRoundBudgetTests(unittest.TestCase):
    def _session(self, **over) -> ChatSession:
        runtime = MagicMock()
        runtime.openai_tools.return_value = []
        runtime.call.return_value = {"ok": True}
        with patch.object(ChatSession, "_system_prompt", return_value="sys"):
            return ChatSession(settings=_settings(**over), runtime=runtime)

    def test_default_keeps_rounding_past_the_old_limit_of_8(self) -> None:
        """Old code stopped at 8 rounds with the model mid-task."""
        calls: list[int] = []
        after = 12

        def fake_iter(_settings, _messages, _tools, **_kwargs):
            calls.append(1)
            yield _tool_calls_round(len(calls)) if len(calls) < after else _final_round()

        session = self._session()
        self.assertTrue(is_unlimited(session.max_rounds))

        with (
            patch("ncc_assistant.session.iter_chat_completion", side_effect=fake_iter),
            patch.object(ChatSession, "persist", lambda self: None),
            patch.object(ChatSession, "refresh_system_prompt", lambda self: None),
        ):
            events = list(session.send("do the thing"))

        self.assertEqual(len(calls), after, "loop must not stop before the model does")
        texts = [e.get("text") for e in events if e.get("kind") == "assistant"]
        self.assertIn("final answer", texts)
        self.assertFalse([t for t in texts if t and "stopped after" in t])

    def test_explicit_budget_stops_and_notices(self) -> None:
        calls: list[int] = []

        def fake_iter(_settings, _messages, _tools, **_kwargs):
            calls.append(1)
            yield _tool_calls_round(len(calls))

        session = self._session()
        session.max_rounds = 2

        with (
            patch("ncc_assistant.session.iter_chat_completion", side_effect=fake_iter),
            patch.object(ChatSession, "persist", lambda self: None),
            patch.object(ChatSession, "refresh_system_prompt", lambda self: None),
        ):
            events = list(session.send("do the thing"))

        self.assertEqual(len(calls), 2)
        self.assertIn(
            {"kind": "assistant", "text": "(stopped after 2 tool rounds)"},
            events,
        )

    def test_settings_budget_reaches_new_session(self) -> None:
        with (
            patch("ncc_assistant.session.list_models", return_value=[]),
            patch("ncc_assistant.session.with_cached_credentials", side_effect=lambda s: s),
            patch("ncc_assistant.session.ToolRuntime") as runtime,
        ):
            runtime.return_value = MagicMock()
            session = ChatSession.create(
                _settings(chat_max_rounds=5),
                interactive_auth=False,
                refresh_models=False,
            )
        self.assertEqual(session.max_rounds, 5)

    def test_cli_flag_is_wired_into_run_chat(self) -> None:
        """`ncc-assistant chat --max-rounds` was decorative; it must reach the session."""
        import ast

        for rel, needles in (
            ("ncc_assistant/cli.py", ('"--max-rounds"', "max_rounds=getattr(args")),
            ("ncc_assistant/chat.py", ("max_rounds=max_rounds",)),
        ):
            text = (ROOT / rel).read_text(encoding="utf-8")
            for needle in needles:
                self.assertIn(needle, text, f"{rel} must forward max_rounds")
            ast.parse(text)


class AgentStepBudgetTests(unittest.TestCase):
    def _runner(self, max_steps: int) -> AgentRunner:
        with (
            patch("ncc_assistant.agent.get_job_store", return_value=MagicMock()),
            patch("ncc_assistant.runtime.ToolRuntime", return_value=MagicMock()),
        ):
            return AgentRunner(
                _settings(),
                AgentSettings(goal="test goal", max_steps=max_steps),
            )

    def _run(self, runner: AgentRunner, stop_after: int) -> tuple[list[dict], int]:
        """Drive the loop with a step stub that finishes after `stop_after` steps."""
        seen = {"n": 0}

        def fake_step(_tools):
            seen["n"] += 1
            yield {"kind": "status", "text": "step"}
            if seen["n"] >= stop_after:
                runner._finished = True

        with (
            patch.object(AgentRunner, "_check_preconditions", return_value=None),
            patch.object(AgentRunner, "_build_system_prompt", return_value="sys"),
            patch.object(AgentRunner, "_get_tools", return_value=[]),
            patch.object(AgentRunner, "_run_step", side_effect=fake_step),
            patch.object(AgentRunner, "_log_event", lambda self, event: None),
            patch("ncc_assistant.agent.AgentLock", return_value=MagicMock()),
            patch("ncc_assistant.agent.append_audit"),
        ):
            events = list(runner.run())
        return events, seen["n"]

    def test_unlimited_runs_past_the_old_cap_of_50(self) -> None:
        runner = self._runner(UNLIMITED)
        events, steps = self._run(runner, stop_after=60)
        self.assertEqual(steps, 60)
        self.assertEqual(runner._step, 60)
        self.assertFalse([e for e in events if e.get("kind") == "budget_exhausted"])

    def test_explicit_budget_still_reports_exhausted(self) -> None:
        runner = self._runner(2)
        events, steps = self._run(runner, stop_after=99)
        self.assertEqual(steps, 2, "budget must cut the loop")
        self.assertEqual(runner._step, 2)
        self.assertTrue([e for e in events if e.get("kind") == "budget_exhausted"])

    def test_step_budget_label_never_shows_the_sentinel(self) -> None:
        self.assertEqual(AgentSettings(goal="g").step_budget_label, "unlimited")
        self.assertEqual(AgentSettings(goal="g", max_steps=5).step_budget_label, "5")

    def test_run_agent_default_is_unlimited(self) -> None:
        import inspect

        self.assertEqual(inspect.signature(run_agent).parameters["max_steps"].default, UNLIMITED)


if __name__ == "__main__":
    unittest.main()
