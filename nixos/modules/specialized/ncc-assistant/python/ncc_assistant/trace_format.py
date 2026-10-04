"""Pure helpers for compact thinking/tool headers (no Qt)."""

from __future__ import annotations


def format_tool_header(name: str, *, ms: int | None = None, status: str = "…") -> str:
    """Compact one-line tool header (collapsed default)."""
    parts = [str(name or "tool")]
    if ms is not None and ms >= 0:
        parts.append(f"{ms}ms")
    parts.append(status)
    return " · ".join(parts)


def format_thinking_header(*, seconds: float | None = None, streaming: bool = False) -> str:
    if streaming:
        return "Thinking…"
    if seconds is not None and seconds >= 0:
        return f"Thinking · {seconds:.1f}s"
    return "Thinking"
