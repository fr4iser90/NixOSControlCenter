"""Persist companion chat slots across restarts."""

from __future__ import annotations

import json
import os
from typing import Any

from .paths import companion_store_file


def record_has_content(rec: dict[str, Any]) -> bool:
    """True once the user actually started a turn (skip empty 'New chat' shells)."""
    if not isinstance(rec, dict):
        return False
    hist = rec.get("history") or []
    if isinstance(hist, list) and len(hist) > 0:
        return True
    if str(rec.get("user_prompt") or "").strip():
        return True
    if str(rec.get("reply_buf") or "").strip():
        return True
    if str(rec.get("thinking_buf") or "").strip():
        return True
    traces = rec.get("tool_traces") or []
    return isinstance(traces, list) and len(traces) > 0


def load_companion_chats() -> list[dict[str, Any]]:
    path = companion_store_file()
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    if not isinstance(data, dict):
        return []
    chats = data.get("chats")
    if not isinstance(chats, list):
        return []
    return [
        c
        for c in chats
        if isinstance(c, dict) and c.get("id") and record_has_content(c)
    ]


def save_companion_chats(chats: list[dict[str, Any]]) -> None:
    path = companion_store_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    kept = [c for c in chats if record_has_content(c)]
    payload = {"version": 1, "chats": kept}
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def slot_to_record(slot: Any) -> dict[str, Any]:
    return {
        "id": slot.id,
        "title": slot.title,
        "title_locked": bool(getattr(slot, "title_locked", False)),
        "workspace_id": getattr(slot, "workspace_id", None),
        "harness_mode": getattr(slot, "harness_mode", "auto"),
        "harness": getattr(slot, "harness", "native"),
        "parent_id": getattr(slot, "parent_id", None),
        "user_prompt": getattr(slot, "user_prompt", "") or "",
        "reply_buf": (getattr(slot, "reply_buf", "") or "")[-8000:],
        "thinking_buf": (getattr(slot, "thinking_buf", "") or "")[-4000:],
        "history": list(getattr(slot, "history", None) or [])[-40:],
        "tool_traces": list(getattr(slot, "tool_traces", None) or [])[-30:],
    }
