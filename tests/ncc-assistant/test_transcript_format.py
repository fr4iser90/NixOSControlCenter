"""Tests for shared conversation transcript formatters."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(PKG))

from ncc_assistant.transcript import (  # noqa: E402
    format_from_index_plaintext,
    format_messages_markdown,
    format_messages_plaintext,
    iter_visible_messages,
    message_plaintext,
)


SAMPLES = [
    {"role": "system", "content": "sys"},
    {"role": "user", "content": "hi"},
    {
        "role": "assistant",
        "content": "",
        "tool_calls": [
            {
                "id": "1",
                "type": "function",
                "function": {"name": "list_available_tools", "arguments": "{}"},
            }
        ],
    },
    {
        "role": "tool",
        "tool_call_id": "1",
        "name": "list_available_tools",
        "content": '{"ok": true, "count": 2}',
    },
    {
        "role": "assistant",
        "content": "You have **2** tools.",
    },
]


def test_iter_visible_skips_system_and_tool_only_shell():
    vis = iter_visible_messages(SAMPLES, include_system=False, include_tools=True)
    roles = [m.get("role") for _, m in vis]
    assert roles == ["user", "tool", "assistant"]


def test_plaintext_keeps_tools_and_skips_empty_assistant_shell():
    text = format_messages_plaintext(SAMPLES)
    assert "[user]" in text
    assert "hi" in text
    assert "[tool list_available_tools]" in text
    assert '"ok": true' in text
    assert "[assistant]" in text
    assert "You have **2** tools." in text
    # empty tool-only assistant shell must not appear as blank [assistant]
    assert text.count("[assistant]") == 1


def test_markdown_roles_and_code_fence():
    md = format_messages_markdown(SAMPLES, title="Conversation")
    assert md.startswith("# Conversation")
    assert "### You" in md
    assert "### Tool · `list_available_tools`" in md
    assert "```json" in md
    assert "### Assistant" in md
    assert "You have **2** tools." in md


def test_copy_from_index():
    # from tool message onward
    tool_idx = next(i for i, m in enumerate(SAMPLES) if m.get("role") == "tool")
    text = format_from_index_plaintext(SAMPLES, tool_idx)
    assert "[tool list_available_tools]" in text
    assert "[assistant]" in text
    assert "[user]" not in text


def test_message_plaintext_user():
    assert "hello" in message_plaintext({"role": "user", "content": "hello"})


def test_multimodal_user_text_only():
    msg = {
        "role": "user",
        "content": [
            {"type": "text", "text": "see this"},
            {"type": "image_url", "image_url": {"url": "data:…"}},
        ],
    }
    text = format_messages_plaintext([msg])
    assert "see this" in text
    assert "[image]" in text
