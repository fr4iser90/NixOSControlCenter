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
        seed_history(session, history)
        if cancel_event is not None:
            session.cancel_event = cancel_event
        yield from session.send(text, images=None, prompt_auth=None)


def seed_history(
    session: Any, history: list[dict[str, Any]] | None
) -> None:
    """Fold the caller's turns into a ChatSession that has none of its own.

    Companion restores chats from its own store, so the native session may start
    empty while the surface still shows earlier turns — without this the model
    would lose context the user can see.
    """
    if session is None or not history:
        return
    turns = [
        {"role": str(t.get("role") or ""), "content": str(t.get("content") or "")}
        for t in list(history)[-24:]
        if isinstance(t, dict)
        and str(t.get("role") or "") in ("user", "assistant")
        and str(t.get("content") or "").strip()
    ]
    if not turns:
        return
    has_turns = any(m.get("role") != "system" for m in session.messages or [])
    if has_turns:
        return
    session.messages.extend(turns)
    session.refresh_system_prompt()
