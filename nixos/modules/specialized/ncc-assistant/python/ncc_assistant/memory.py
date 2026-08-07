"""Persistent memory/notes for agent context."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from typing import Any

from .paths import memory_file
from .audit import redact_secrets


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class MemoryNote:
    """A single memory note."""
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])
    content: str = ""
    tags: list[str] = field(default_factory=list)
    created_at: str = field(default_factory=_now_iso)
    source: str = "user"  # user | agent | system
    job_id: str | None = None
    session_id: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "MemoryNote":
        return cls(
            id=data.get("id", ""),
            content=data.get("content", ""),
            tags=data.get("tags", []),
            created_at=data.get("created_at", _now_iso()),
            source=data.get("source", "user"),
            job_id=data.get("job_id"),
            session_id=data.get("session_id"),
        )


def list_notes(
    *,
    tag: str | None = None,
    limit: int = 100,
    source: str | None = None,
) -> list[MemoryNote]:
    """List memory notes with optional filtering."""
    path = memory_file()
    if not path.is_file():
        return []

    notes: list[MemoryNote] = []
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    note = MemoryNote.from_dict(data)

                    if tag and tag not in note.tags:
                        continue
                    if source and note.source != source:
                        continue

                    notes.append(note)
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass

    notes.reverse()
    return notes[:limit]


def add_note(
    content: str,
    *,
    tags: list[str] | None = None,
    source: str = "user",
    job_id: str | None = None,
    session_id: str | None = None,
    redact: bool = True,
) -> MemoryNote:
    """Add a new memory note."""
    if redact:
        content = redact_secrets(content)

    note = MemoryNote(
        content=content,
        tags=tags or [],
        source=source,
        job_id=job_id,
        session_id=session_id,
    )

    path = memory_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(note.to_dict(), ensure_ascii=False) + "\n")

    return note


def forget_note(note_id: str) -> bool:
    """Remove a note by ID (rewrites file without that note)."""
    path = memory_file()
    if not path.is_file():
        return False

    lines: list[str] = []
    found = False
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line_stripped = line.strip()
                if not line_stripped:
                    continue
                try:
                    data = json.loads(line_stripped)
                    if data.get("id") == note_id:
                        found = True
                        continue
                    lines.append(line_stripped)
                except json.JSONDecodeError:
                    lines.append(line_stripped)
    except OSError:
        return False

    if not found:
        return False

    with path.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")

    return True


def forget_by_tag(tag: str) -> int:
    """Remove all notes with a specific tag."""
    path = memory_file()
    if not path.is_file():
        return 0

    lines: list[str] = []
    count = 0
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line_stripped = line.strip()
                if not line_stripped:
                    continue
                try:
                    data = json.loads(line_stripped)
                    if tag in data.get("tags", []):
                        count += 1
                        continue
                    lines.append(line_stripped)
                except json.JSONDecodeError:
                    lines.append(line_stripped)
    except OSError:
        return 0

    with path.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")

    return count


def clear_all() -> bool:
    """Clear all memory notes."""
    path = memory_file()
    if path.is_file():
        path.unlink()
        return True
    return False


def for_prompt(limit: int = 20, max_chars: int = 4000) -> str:
    """
    Format recent notes for inclusion in a prompt.
    Returns a string suitable for system prompt context.
    """
    notes = list_notes(limit=limit)
    if not notes:
        return ""

    lines: list[str] = ["## Agent Memory Notes", ""]
    total_chars = 0

    for note in notes:
        tags_str = f" [{', '.join(note.tags)}]" if note.tags else ""
        line = f"- {note.content}{tags_str}"
        if total_chars + len(line) > max_chars:
            lines.append("- ... (more notes truncated)")
            break
        lines.append(line)
        total_chars += len(line)

    return "\n".join(lines)


def search_notes(query: str, limit: int = 20) -> list[MemoryNote]:
    """Search notes by content substring."""
    query_lower = query.lower()
    notes = list_notes(limit=1000)
    matches = [n for n in notes if query_lower in n.content.lower()]
    return matches[:limit]
