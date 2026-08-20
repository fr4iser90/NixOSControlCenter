#!/usr/bin/env python3
"""Chat-switch freeze: cause (sync list_models) + fix (skip refresh on switch).

Cause path (before fix):
  _load_session_id → ChatSession.create → refresh_models → GET /models (UI thread)

Fix:
  create(..., refresh_models=False, available_models=prev)
  _populate_models(fetch=False)
"""

from __future__ import annotations

import ast
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ncc_assistant.config import Settings  # noqa: E402
from ncc_assistant import history  # noqa: E402
from ncc_assistant import llm as llm_mod  # noqa: E402
from ncc_assistant.session import ChatSession  # noqa: E402


def _settings(*, api: str = "openai-compatible", endpoint: str = "http://127.0.0.1:9/v1") -> Settings:
    root = Path("/tmp/ncc-assistant-test")
    return Settings(
        root=root,
        knowledge_root=root / "knowledge",
        prompts_root=root / "prompts",
        config_bin="ncc-assistant-config",
        api=api,
        model="test-model",
        endpoint=endpoint,
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
        agent_max_steps=1,
        agent_allow_write=False,
        agent_allow_rebuild=False,
        agent_confirm="never",
        agent_dry_run=True,
        agent_profile=None,
        notify_enable=False,
        notify_timeout_sec=1,
        notify_on_timeout="block",
        mcp_servers_json=None,
        extra_headers=(),
    )


class ListModelsHttpTests(unittest.TestCase):
    def test_list_models_openai_compatible_hits_models_endpoint(self) -> None:
        settings = _settings(endpoint="http://ollama.local:11434/v1")
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"data": [{"id": "llama3"}]}
        mock_client = MagicMock()
        mock_client.__enter__.return_value = mock_client
        mock_client.__exit__.return_value = False
        mock_client.get.return_value = mock_resp

        with patch.object(llm_mod.httpx, "Client", return_value=mock_client) as client_cls:
            out = llm_mod.list_models(settings)

        kwargs = client_cls.call_args.kwargs
        self.assertEqual(kwargs.get("timeout"), 30.0)
        url = mock_client.get.call_args.args[0]
        self.assertEqual(url, "http://ollama.local:11434/v1/models")
        self.assertEqual(out[0]["id"], "llama3")

    def test_list_models_blocks_for_slow_http(self) -> None:
        settings = _settings()

        def slow_get(*_a, **_k):
            time.sleep(0.35)
            resp = MagicMock()
            resp.status_code = 200
            resp.json.return_value = {"data": [{"id": "slow"}]}
            return resp

        mock_client = MagicMock()
        mock_client.__enter__.return_value = mock_client
        mock_client.__exit__.return_value = False
        mock_client.get.side_effect = slow_get

        with patch.object(llm_mod.httpx, "Client", return_value=mock_client):
            t0 = time.perf_counter()
            llm_mod.list_models(settings)
            elapsed = time.perf_counter() - t0

        self.assertGreaterEqual(elapsed, 0.30)


class ChatSessionCreateTests(unittest.TestCase):
    def test_default_create_calls_list_models(self) -> None:
        """Initial session still fetches models once."""
        settings = _settings()
        calls: list[str] = []

        def fake_list_models(s: Settings):
            calls.append(s.endpoint)
            return [{"id": "m1", "vision": False}]

        with (
            patch("ncc_assistant.session.list_models", side_effect=fake_list_models),
            patch("ncc_assistant.session.with_cached_credentials", side_effect=lambda s: s),
            patch("ncc_assistant.session.ToolRuntime") as TR,
        ):
            TR.return_value = MagicMock()
            ChatSession.create(settings, interactive_auth=False, session_id="a")

        self.assertEqual(calls, [settings.endpoint])

    def test_create_skip_refresh_does_not_call_list_models(self) -> None:
        """Chat switch path: refresh_models=False must not HTTP."""
        settings = _settings()
        calls = {"n": 0}

        def fake_list_models(_s: Settings):
            calls["n"] += 1
            time.sleep(0.5)
            return [{"id": "should-not-run", "vision": False}]

        prev = [{"id": "cached", "vision": False}]
        with (
            patch("ncc_assistant.session.list_models", side_effect=fake_list_models),
            patch("ncc_assistant.session.with_cached_credentials", side_effect=lambda s: s),
            patch("ncc_assistant.session.ToolRuntime") as TR,
        ):
            TR.return_value = MagicMock()
            t0 = time.perf_counter()
            session = ChatSession.create(
                settings,
                interactive_auth=False,
                session_id="b",
                title="B",
                messages=[{"role": "user", "content": "x"}],
                refresh_models=False,
                available_models=prev,
            )
            elapsed = time.perf_counter() - t0

        self.assertEqual(calls["n"], 0)
        self.assertLess(elapsed, 0.15, f"skip-refresh create must be instant, got {elapsed:.3f}s")
        self.assertEqual(session.available_models[0]["id"], "cached")


class GuiChatSwitchPathTests(unittest.TestCase):
    def test_load_session_id_skips_model_refresh(self) -> None:
        gui_path = ROOT / "ncc_assistant" / "gui.py"
        text = gui_path.read_text(encoding="utf-8")
        tree = ast.parse(text)
        found = False
        for node in ast.walk(tree):
            if not isinstance(node, ast.FunctionDef) or node.name != "_load_session_id":
                continue
            src = ast.get_source_segment(text, node) or ""
            self.assertIn("ChatSession.create", src)
            self.assertIn("refresh_models=False", src)
            self.assertIn("available_models=", src)
            self.assertIn("_populate_models(fetch=False)", src)
            self.assertNotIn("NCC_TARGET", src)
            found = True
            break
        self.assertTrue(found, "_load_session_id not found")

    def test_populate_models_fetch_false_skips_refresh(self) -> None:
        """PERFORMANCE.md: catalog reuse must not call refresh_models/list_models."""
        gui_path = ROOT / "ncc_assistant" / "gui.py"
        text = gui_path.read_text(encoding="utf-8")
        tree = ast.parse(text)
        found = False
        for node in ast.walk(tree):
            if not isinstance(node, ast.FunctionDef) or node.name != "_populate_models":
                continue
            src = ast.get_source_segment(text, node) or ""
            self.assertIn("fetch: bool = True", src)
            self.assertIn("refresh_models()", src)
            # fetch=False branch must use available_models, not refresh.
            self.assertIn("available_models", src)
            self.assertIn("if fetch:", src)
            found = True
            break
        self.assertTrue(found, "_populate_models not found")

    def test_simulated_switch_with_fix_is_fast(self) -> None:
        settings = _settings()
        with tempfile.TemporaryDirectory() as tmp:
            sess_dir = Path(tmp)
            with patch.object(history, "sessions_dir", return_value=sess_dir):
                sid = "switch-b"
                (sess_dir / f"{sid}.json").write_text(
                    json.dumps(
                        {
                            "id": sid,
                            "title": "B",
                            "model": "test-model",
                            "messages": [{"role": "user", "content": "hello"}],
                        }
                    ),
                    encoding="utf-8",
                )

                def slow_list(_s: Settings):
                    time.sleep(0.4)
                    return [{"id": "test-model", "vision": False}]

                with (
                    patch("ncc_assistant.session.list_models", side_effect=slow_list),
                    patch(
                        "ncc_assistant.session.with_cached_credentials",
                        side_effect=lambda s: s,
                    ),
                    patch("ncc_assistant.session.ToolRuntime") as TR,
                ):
                    TR.return_value = MagicMock()
                    data = history.load_session(sid)
                    assert data is not None
                    prev = [{"id": "test-model", "vision": False}]
                    t0 = time.perf_counter()
                    ChatSession.create(
                        settings,
                        interactive_auth=False,
                        messages=data.get("messages") or [],
                        session_id=data.get("id"),
                        title=data.get("title"),
                        refresh_models=False,
                        available_models=prev,
                    )
                    elapsed = time.perf_counter() - t0

                self.assertLess(
                    elapsed,
                    0.15,
                    f"fixed switch path must not wait on /models (elapsed={elapsed:.3f}s)",
                )


if __name__ == "__main__":
    unittest.main()
