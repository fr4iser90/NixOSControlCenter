"""Shared conversation → text formatters (Transcript view, sidebar copy, export).

Single source: a list of OpenAI-style message dicts (ChatSession.messages).
No second message store.
"""

from __future__ import annotations

import json
from typing import Any


def _content_text(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for p in content:
            if isinstance(p, dict) and p.get("type") == "text":
                parts.append(str(p.get("text") or ""))
            elif isinstance(p, dict) and p.get("type") == "image_url":
                parts.append("[image]")
        return "\n".join(parts)
    return str(content)


def _is_tool_only_assistant(msg: dict[str, Any]) -> bool:
    text = _content_text(msg.get("content")).strip()
    return (not text) and bool(msg.get("tool_calls"))


def iter_visible_messages(
    messages: list[dict[str, Any]],
    *,
    include_system: bool = False,
    include_tools: bool = True,
) -> list[tuple[int, dict[str, Any]]]:
    """Return (original_index, msg) for messages that appear in a transcript."""
    out: list[tuple[int, dict[str, Any]]] = []
    for i, msg in enumerate(messages):
        if not isinstance(msg, dict):
            continue
        role = msg.get("role") or ""
        if role == "system" and not include_system:
            continue
        if role == "tool" and not include_tools:
            continue
        if role == "assistant" and _is_tool_only_assistant(msg):
            # Tool-only shells are represented by following tool messages.
            continue
        out.append((i, msg))
    return out


def format_messages_plaintext(
    messages: list[dict[str, Any]],
    *,
    include_system: bool = False,
    include_tools: bool = True,
    header: str | None = None,
) -> str:
    """Plain transcript for clipboard / sidebar copy."""
    lines: list[str] = []
    if header:
        lines.append(header.rstrip())
        lines.append("")
    for _i, msg in iter_visible_messages(
        messages, include_system=include_system, include_tools=include_tools
    ):
        role = msg.get("role") or "?"
        if role == "tool":
            name = msg.get("name") or ""
            body = _content_text(msg.get("content"))
            lines.append(f"[tool {name}]\n{body}\n")
            continue
        if role == "assistant":
            lines.append(f"[assistant]\n{_content_text(msg.get('content'))}\n")
            continue
        if role == "user":
            lines.append(f"[user]\n{_content_text(msg.get('content'))}\n")
            continue
        if role == "system":
            lines.append(f"[system]\n{_content_text(msg.get('content'))}\n")
            continue
        lines.append(f"[{role}]\n{_content_text(msg.get('content'))}\n")
    text = "\n".join(lines).strip()
    return (text + "\n") if text else ""


def format_messages_markdown(
    messages: list[dict[str, Any]],
    *,
    include_system: bool = False,
    include_tools: bool = True,
    title: str | None = None,
) -> str:
    """Readable markdown transcript for the Transcript working view / export body."""
    lines: list[str] = []
    if title:
        lines.append(f"# {title}")
        lines.append("")

    for _i, msg in iter_visible_messages(
        messages, include_system=include_system, include_tools=include_tools
    ):
        role = msg.get("role") or "?"
        body = _content_text(msg.get("content"))

        if role == "user":
            lines.append("### You")
            lines.append("")
            lines.append(body or "_(empty)_")
            lines.append("")
            continue

        if role == "assistant":
            lines.append("### Assistant")
            lines.append("")
            lines.append(body or "_(empty)_")
            lines.append("")
            continue

        if role == "tool":
            name = msg.get("name") or "tool"
            lines.append(f"### Tool · `{name}`")
            lines.append("")
            fence = "json" if body.strip().startswith(("{", "[")) else ""
            lines.append(f"```{fence}".rstrip())
            lines.append(body if body else "_(empty)_")
            lines.append("```")
            lines.append("")
            continue

        if role == "system":
            lines.append("### System")
            lines.append("")
            lines.append(body)
            lines.append("")
            continue

        lines.append(f"### {role}")
        lines.append("")
        lines.append(body)
        lines.append("")

    return "\n".join(lines).rstrip() + ("\n" if lines else "")


def format_from_index_plaintext(
    messages: list[dict[str, Any]],
    start_index: int,
    *,
    include_system: bool = False,
    include_tools: bool = True,
) -> str:
    """Plaintext from message index (inclusive) to end — for 'copy from here'."""
    if start_index < 0:
        start_index = 0
    sliced = messages[start_index:]
    return format_messages_plaintext(
        sliced, include_system=include_system, include_tools=include_tools
    )


def message_plaintext(msg: dict[str, Any]) -> str:
    """Single message as plaintext (bubble / context 'copy message')."""
    role = msg.get("role") or "?"
    if role == "tool":
        name = msg.get("name") or ""
        return f"[tool {name}]\n{_content_text(msg.get('content'))}\n"
    if role == "assistant" and _is_tool_only_assistant(msg):
        names = []
        for tc in msg.get("tool_calls") or []:
            if isinstance(tc, dict):
                fn = tc.get("function") or {}
                names.append(str(fn.get("name") or ""))
        return "[assistant tools]\n" + ", ".join(n for n in names if n) + "\n"
    label = {"user": "user", "assistant": "assistant", "system": "system"}.get(
        role, role
    )
    return f"[{label}]\n{_content_text(msg.get('content'))}\n"


def tool_args_json(msg: dict[str, Any]) -> str:
    """Pretty-print tool_calls arguments for debugging (optional)."""
    calls = msg.get("tool_calls") or []
    if not calls:
        return ""
    try:
        return json.dumps(calls, indent=2, ensure_ascii=False)
    except (TypeError, ValueError):
        return str(calls)
