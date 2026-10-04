"""Native NCC harness — ChatSession + ToolRuntime (default)."""

from __future__ import annotations

import threading
from typing import Any, Iterator

from .types import Event, HarnessInfo


class NativeHarness:
    name = "native"

    def probe(self) -> HarnessInfo:
        return HarnessInfo(
            name=self.name,
            label="NCC native",
            available=True,
            detail="ChatSession + ToolRuntime (NixOS tools, MCP client)",
        )

    def send(
        self,
        text: str,
        *,
        cwd: str | None = None,
        cancel_event: threading.Event | None = None,
        session: Any | None = None,
        history: list[dict[str, Any]] | None = None,
    ) -> Iterator[Event]:
        del cwd  # native uses Settings / workspaces, not process cwd
        del history  # native ChatSession already holds messages
        if session is None:
            from ..config import Settings
            from ..preferences import apply_startup_preferences
            from ..session import ChatSession

            settings = apply_startup_preferences(Settings.from_env(client_mode="chat"))
            session = ChatSession.create(
                settings,
                interactive_auth=False,
                refresh_models=False,
            )
        if cancel_event is not None:
            session.cancel_event = cancel_event
        yield from session.send(text, images=None, prompt_auth=None)
