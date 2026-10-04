"""Harness contracts — UI/companion consume a single event shape."""

from __future__ import annotations

import threading
from dataclasses import dataclass
from typing import Any, Iterator, Protocol, runtime_checkable

# Unified event kinds (ChatSession-compatible + thinking)
# user | status | assistant_start | assistant_delta | thinking_delta |
# assistant | tool | tool_result | error | done | run_spawn
Event = dict[str, Any]


@dataclass(frozen=True)
class HarnessInfo:
    name: str
    label: str
    available: bool
    detail: str


@runtime_checkable
class HarnessBackend(Protocol):
    name: str

    def probe(self) -> HarnessInfo:
        """Whether the binary/runtime is usable on this host."""

    def send(
        self,
        text: str,
        *,
        cwd: str | None = None,
        cancel_event: threading.Event | None = None,
        session: Any | None = None,
    ) -> Iterator[Event]:
        """Run one user turn; yield unified events until done."""
