"""Global concurrency governor for agent / harness / template runs."""

from __future__ import annotations

import json
import os
import time
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

from .paths import capacity_state_file
from .preferences import get_max_concurrency


class CapacityError(RuntimeError):
    """Raised when max_concurrency slots are exhausted."""

    def __init__(self, message: str = "At capacity") -> None:
        super().__init__(message)


def _load() -> dict[str, Any]:
    path = capacity_state_file()
    if not path.is_file():
        return {"slots": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"slots": {}}
    if not isinstance(data, dict):
        return {"slots": {}}
    slots = data.get("slots")
    if not isinstance(slots, dict):
        slots = {}
    # Drop stale slots (> 6h)
    now = time.time()
    fresh = {
        k: v
        for k, v in slots.items()
        if isinstance(v, dict) and now - float(v.get("started", now)) < 6 * 3600
    }
    return {"slots": fresh}


def _save(state: dict[str, Any]) -> None:
    path = capacity_state_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def active_count() -> int:
    return len(_load().get("slots") or {})


def try_acquire(label: str = "job") -> str | None:
    """Reserve a slot. Returns token or None if at capacity."""
    state = _load()
    slots = state.setdefault("slots", {})
    limit = get_max_concurrency()
    if len(slots) >= limit:
        return None
    token = uuid.uuid4().hex[:12]
    slots[token] = {
        "label": str(label)[:80],
        "started": time.time(),
        "pid": os.getpid(),
    }
    _save(state)
    return token


def release(token: str | None) -> None:
    if not token:
        return
    state = _load()
    slots = state.get("slots") or {}
    if token in slots:
        del slots[token]
        state["slots"] = slots
        _save(state)


def acquire_or_raise(label: str = "job") -> str:
    token = try_acquire(label)
    if token is None:
        raise CapacityError(
            f"At capacity ({active_count()}/{get_max_concurrency()}). "
            "Wait for a run to finish or raise max_concurrency in Settings."
        )
    return token


@contextmanager
def capacity_slot(label: str = "job") -> Iterator[str]:
    token = acquire_or_raise(label)
    try:
        yield token
    finally:
        release(token)
