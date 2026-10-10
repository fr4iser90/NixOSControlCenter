"""Context-window accounting and compaction, mirroring qwen-code.

This module measures and summarizes; it decides nothing. ChatSession drives when
to compact, surfaces read report() for the percentage they display.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Iterator

from .config import (
    CHARS_PER_TOKEN,
    DEFAULT_CONTEXT_WINDOW_TOKENS,
    Settings,
    compact_threshold_for,
)
from .llm import chat_completion

# A compacted history starts with this marker; it is the only way to recognise a
# summary later (no extra message keys — strict gateways reject unknown fields).
SUMMARY_PREFIX = "[Summary of earlier conversation]"

KEEP_RECENT_MESSAGES = 8
IMAGE_TOKENS = 800
# A single transcript line this long is already past the point of diminishing
# returns for the summariser.
_MAX_LINE_CHARS = 2000

SUMMARY_SYSTEM = (
    "You compress conversation history so an assistant can continue without the "
    "original turns. Keep, in this order:\n"
    "1. The user's goal and every constraint or decision they stated.\n"
    "2. Decisions made and why, plus anything explicitly ruled out.\n"
    "3. Concrete identifiers that still matter: files, hosts, units, commands, "
    "config paths, error strings.\n"
    "4. Tool findings that are still true.\n"
    "5. Open questions and the exact next step.\n"
    "Drop greetings, finished tangents, and prose that added no information. "
    "Use terse bullet lines. No preamble, no closing remark, at most 40 lines."
)


def _part_chars(content: Any) -> int:
    if isinstance(content, str):
        return len(content)
    if isinstance(content, list):
        total = 0
        for part in content:
            if not isinstance(part, dict):
                total += len(str(part))
                continue
            if part.get("type") == "image_url":
                total += IMAGE_TOKENS * CHARS_PER_TOKEN
            else:
                total += len(str(part.get("text") or ""))
        return total
    if content is None:
        return 0
    return len(str(content))


def estimate_message_tokens(msg: dict[str, Any]) -> int:
    """Rough token count for one message, tool calls included."""
    chars = _part_chars(msg.get("content"))
    for tc in msg.get("tool_calls") or []:
        if not isinstance(tc, dict):
            continue
        fn = tc.get("function") or {}
        chars += len(str(fn.get("name") or ""))
        chars += len(str(fn.get("arguments") or ""))
        chars += len(str(tc.get("id") or ""))
    if msg.get("name"):
        chars += len(str(msg["name"]))
    return max(1, chars // CHARS_PER_TOKEN + 1)


def estimate_tokens(messages: list[dict[str, Any]] | None) -> int:
    return sum(estimate_message_tokens(m) for m in (messages or []) if isinstance(m, dict))


def is_summary_message(msg: Any) -> bool:
    return (
        isinstance(msg, dict)
        and msg.get("role") == "user"
        and str(msg.get("content") or "").startswith(SUMMARY_PREFIX)
    )


def group_messages(messages: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    """Split into atomic groups — an assistant tool_calls turn glued to its results.

    Dropping a tool result whose assistant call is gone (or vice versa) makes the
    next request 400 on every strict gateway, so compaction may only cut on
    group boundaries.
    """
    groups: list[list[dict[str, Any]]] = []
    i = 0
    while i < len(messages):
        msg = messages[i]
        if isinstance(msg, dict) and msg.get("role") == "assistant" and msg.get("tool_calls"):
            group = [msg]
            i += 1
            while i < len(messages) and messages[i].get("role") == "tool":
                group.append(messages[i])
                i += 1
            groups.append(group)
        else:
            groups.append([msg])
            i += 1
    return groups


def split_for_compaction(
    messages: list[dict[str, Any]], keep: int = KEEP_RECENT_MESSAGES
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    """Return (system, older_to_summarize, kept_tail)."""
    head = messages[:1] if messages and messages[0].get("role") == "system" else []
    rest = messages[len(head) :]
    groups = group_messages(rest)

    keep_count = 0
    cut = len(groups)
    for idx in range(len(groups) - 1, -1, -1):
        keep_count += len(groups[idx])
        cut = idx
        if keep_count >= keep:
            break
    # Nothing worth summarizing (or a single group) — leave the history alone.
    if cut <= 0:
        return head, [], rest

    older = [m for g in groups[:cut] for m in g]
    tail = [m for g in groups[cut:] for m in g]
    while tail and tail[0].get("role") == "tool":
        tail.pop(0)
    return head, older, tail


def render_transcript(messages: list[dict[str, Any]]) -> str:
    lines: list[str] = []
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        role = str(msg.get("role") or "?")
        content = msg.get("content")
        if isinstance(content, list):
            content = " ".join(
                str(p.get("text") or ("[image]" if p.get("type") == "image_url" else ""))
                for p in content
                if isinstance(p, dict)
            )
        text = " ".join(str(content or "").split())
        if len(text) > _MAX_LINE_CHARS:
            text = text[:_MAX_LINE_CHARS] + "…"
        for tc in msg.get("tool_calls") or []:
            fn = (tc.get("function") or {}) if isinstance(tc, dict) else {}
            args = " ".join(str(fn.get("arguments") or "").split())[:_MAX_LINE_CHARS]
            text = f"{text} [called {fn.get('name')}({args})]".strip()
        if not text:
            continue
        lines.append(f"{role}: {text}")
    return "\n".join(lines)


def _transcript_budget_chars(window: int) -> int:
    """Keep the summarise request itself inside the window it summarizes."""
    return max(4_000, int(window * CHARS_PER_TOKEN * 0.45))


def build_summary(settings: Settings, older: list[dict[str, Any]], window: int) -> str:
    """LLM summary of `older`. Raises LLMError like any other completion."""
    transcript = render_transcript(older)
    budget = _transcript_budget_chars(window)
    if len(transcript) > budget:
        # Most recent turns carry the state; drop from the front instead of
        # failing the request outright.
        transcript = "[older turns omitted]\n" + transcript[-budget:]
    reply = chat_completion(
        settings,
        [
            {"role": "system", "content": SUMMARY_SYSTEM},
            {"role": "user", "content": transcript},
        ],
        None,
    )
    return str(reply.get("content") or "").strip()


def compact_messages(
    settings: Settings,
    messages: list[dict[str, Any]],
    window: int,
    keep: int = KEEP_RECENT_MESSAGES,
) -> tuple[list[dict[str, Any]], str]:
    """Return (new_messages, summary). Unchanged + "" when there is nothing to do."""
    head, older, tail = split_for_compaction(messages, keep)
    if not older:
        return messages, ""
    summary = build_summary(settings, older, window)
    if not summary:
        return messages, ""
    merged = head + [{"role": "user", "content": f"{SUMMARY_PREFIX}\n{summary}"}] + tail
    return merged, summary


@dataclass
class ContextMeter:
    """Tracks how full the context is for one session.

    Prefers the gateway's own numbers: the last real usage is the anchor, and
    only messages appended after it are estimated. Estimating everything from
    characters every round drifts, and drift is what trips a hard 400.
    """

    settings: Settings
    window: int = DEFAULT_CONTEXT_WINDOW_TOKENS
    window_source: str = "default"
    last_usage: dict[str, int] = field(default_factory=dict)
    anchor_count: int = 0
    anchor_tokens: int = 0
    compactions: int = 0
    # System prompt + tool schemas ride along on every request but are not in
    # `messages`; at num_ctx 4096 that floor is most of the window.
    overhead_tokens: int = 0

    def note_tools(self, tools: list[dict[str, Any]] | None) -> None:
        if not tools:
            self.overhead_tokens = 0
            return
        self.overhead_tokens = len(json.dumps(tools, ensure_ascii=False)) // CHARS_PER_TOKEN

    @classmethod
    def for_settings(cls, settings: Settings) -> "ContextMeter":
        override = settings.context_window
        if override and int(override) > 0:
            return cls(settings=settings, window=int(override), window_source="config")
        from .llm import detect_context_window

        found = detect_context_window(settings)
        if found:
            return cls(
                settings=settings,
                window=int(found["tokens"]),
                window_source=str(found.get("source") or "gateway"),
            )
        return cls(settings=settings)

    def reset_anchor(self) -> None:
        self.anchor_count = 0
        self.anchor_tokens = 0
        self.last_usage = {}

    def observe(self, sent_count: int, usage: dict[str, Any] | None) -> None:
        """Record real usage for a request that sent `sent_count` messages."""
        u = usage if isinstance(usage, dict) else {}
        if not u.get("total"):
            return
        self.last_usage = {
            "input": int(u.get("input") or 0),
            "output": int(u.get("output") or 0),
            "total": int(u.get("total") or 0),
        }
        self.anchor_tokens = self.last_usage["input"] + self.last_usage["output"]
        self.anchor_count = int(sent_count)

    def used_tokens(self, messages: list[dict[str, Any]]) -> tuple[int, str]:
        if self.anchor_count and self.anchor_count <= len(messages):
            added = estimate_tokens(messages[self.anchor_count :])
            base = self.anchor_tokens + added
            basis = "usage"
        else:
            base = estimate_tokens(messages)
            basis = "estimate"
        return base + self.overhead_tokens, basis

    def threshold(self) -> int:
        override = self.settings.compact_threshold
        if override and override > 0:
            return compact_threshold_for(self.window, override)
        return compact_threshold_for(self.window)

    def over_threshold(self, messages: list[dict[str, Any]]) -> bool:
        used, _ = self.used_tokens(messages)
        return used >= self.threshold()

    def report(self, messages: list[dict[str, Any]]) -> dict[str, Any]:
        used, basis = self.used_tokens(messages)
        window = max(1, self.window)
        return {
            "window": window,
            "window_source": self.window_source,
            "used": used,
            "free": max(0, window - used),
            "percent": min(100, int(used * 100 / window)),
            "threshold": self.threshold(),
            "threshold_percent": min(100, int(self.threshold() * 100 / window)),
            "basis": basis,
            "usage": dict(self.last_usage),
            "messages": len(messages),
            "compactions": self.compactions,
            "auto": bool(self.settings.auto_compact),
        }


def compact_stream(
    settings: Settings,
    messages: list[dict[str, Any]],
    meter: ContextMeter,
    keep: int = KEEP_RECENT_MESSAGES,
) -> Iterator[dict[str, Any]]:
    """Compaction as events, so every surface shows the same thing.

    Mutates `messages` in place on success — ChatSession keeps one list.
    """
    before = meter.report(messages)
    yield {"kind": "status", "text": "Compacting context…", "phase": "compact"}
    try:
        merged, summary = compact_messages(settings, messages, meter.window, keep)
    except Exception as exc:  # noqa: BLE001 — never break the chat
        yield {
            "kind": "status",
            "text": f"Compaction failed: {str(exc)[:160]}",
            "phase": "compact",
        }
        yield {"kind": "context", **before, "compacted": False}
        return
    if not summary:
        yield {
            "kind": "status",
            "text": "Nothing to compact yet",
            "phase": "compact",
        }
        yield {"kind": "context", **before, "compacted": False}
        return
    messages[:] = merged
    meter.compactions += 1
    meter.reset_anchor()
    after = meter.report(messages)
    saved = max(0, before["used"] - after["used"])
    yield {
        "kind": "status",
        "text": f"Context compacted: ~{saved:,} tokens freed",
        "phase": "compact",
    }
    yield {
        "kind": "context",
        **after,
        "compacted": True,
        "saved": saved,
        "summary": summary[:1200],
    }


__all__ = [
    "ContextMeter",
    "SUMMARY_PREFIX",
    "build_summary",
    "compact_messages",
    "compact_stream",
    "estimate_message_tokens",
    "estimate_tokens",
    "group_messages",
    "is_summary_message",
    "render_transcript",
    "split_for_compaction",
]
