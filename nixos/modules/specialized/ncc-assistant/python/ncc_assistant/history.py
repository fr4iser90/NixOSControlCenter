"""Persist and resume NCC AI chat sessions under ~/.config/ncc-assistant/sessions/."""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def sessions_dir() -> Path:
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    path = base / "ncc-assistant" / "sessions"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def new_session_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]


def session_path(session_id: str) -> Path:
    return sessions_dir() / f"{session_id}.json"


def _visible_message_count(messages: list[Any]) -> int:
    n = 0
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        if msg.get("role") in ("user", "assistant"):
            n += 1
    return n


def list_sessions(limit: int = 40) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in sessions_dir().glob("*.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        msgs = data.get("messages") or []
        items.append(
            {
                "id": data.get("id") or path.stem,
                "title": data.get("title") or "Untitled",
                "updated": data.get("updated") or data.get("created") or "",
                "model": data.get("model") or "",
                "endpoint": data.get("endpoint") or "",
                "provider": data.get("provider") or "",
                "api": data.get("api") or "",
                "message_count": _visible_message_count(msgs)
                if isinstance(msgs, list)
                else 0,
                "path": str(path),
            }
        )
    items.sort(key=lambda x: x.get("updated") or "", reverse=True)
    return items[:limit]


def load_session(session_id: str) -> dict[str, Any] | None:
    path = session_path(session_id)
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def save_session(data: dict[str, Any]) -> Path:
    sid = data.get("id") or new_session_id()
    data["id"] = sid
    data["updated"] = _now()
    if not data.get("created"):
        data["created"] = data["updated"]
    path = session_path(sid)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return path


def delete_session(session_id: str) -> bool:
    path = session_path(session_id)
    if path.is_file():
        path.unlink()
        return True
    return False


def session_plaintext(session_id: str, *, include_system: bool = False) -> str:
    """Plaintext transcript for clipboard copy."""
    data = load_session(session_id)
    if not data:
        return ""
    lines: list[str] = [
        data.get("title") or "Untitled",
        f"model={data.get('model') or '?'}  provider={data.get('provider') or data.get('endpoint') or '?'}",
        "",
    ]
    for msg in data.get("messages") or []:
        if not isinstance(msg, dict):
            continue
        role = msg.get("role") or "?"
        if role == "system" and not include_system:
            continue
        content = msg.get("content") or ""
        if isinstance(content, list):
            parts = []
            for p in content:
                if isinstance(p, dict) and p.get("type") == "text":
                    parts.append(str(p.get("text") or ""))
            content = "\n".join(parts)
        if role == "tool":
            lines.append(f"[tool {msg.get('name') or ''}]\n{content}\n")
        else:
            lines.append(f"[{role}]\n{content}\n")
    return "\n".join(lines).strip() + "\n"


def title_from_messages(messages: list[dict[str, Any]]) -> str:
    for msg in messages:
        if msg.get("role") != "user":
            continue
        content = msg.get("content")
        if isinstance(content, str) and content.strip():
            t = content.strip().replace("\n", " ")
            return t[:72] + ("…" if len(t) > 72 else "")
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    t = str(part.get("text") or "").strip().replace("\n", " ")
                    if t:
                        return t[:72] + ("…" if len(t) > 72 else "")
            return "(image message)"
    return "New chat"


def strip_heavy_content(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Drop huge base64 image payloads from saved history (keep text stubs)."""
    out: list[dict[str, Any]] = []
    for msg in messages:
        m = dict(msg)
        c = m.get("content")
        if isinstance(c, list):
            parts = []
            for p in c:
                if not isinstance(p, dict):
                    continue
                if p.get("type") == "image_url":
                    parts.append({"type": "text", "text": "[image omitted from saved history]"})
                else:
                    parts.append(p)
            m["content"] = parts
        out.append(m)
    return out
