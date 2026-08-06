"""Terminal REPL chat (fallback). Prefer the Qt GUI via `ncc ai`. """

from __future__ import annotations

import sys

from .config import Settings
from .runtime import ToolRuntime
from .session import ChatSession


def run_chat(settings: Settings, runtime: ToolRuntime | None = None) -> int:
    del runtime  # session owns runtime
    try:
        session = ChatSession.create(settings, interactive_auth=True)
    except RuntimeError as exc:
        print(f"auth-error> {exc}", file=sys.stderr)
        return 1

    auth_label = "key" if session.settings.api_key else "none"
    print("NCC AI Assistant (terminal) — type 'exit' or Ctrl-D to quit.")
    print(
        f"api={session.settings.api} endpoint={session.settings.endpoint} "
        f"model={session.model_label} auth={auth_label} "
        f"writes={session.settings.writes_enabled} "
        f"rebuild={session.settings.allow_rebuild}"
    )
    print("Tip: run `ncc ai` for the graphical chat window.\n")

    while True:
        try:
            user = input("you> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not user:
            continue
        if user.lower() in ("exit", "quit", ":q"):
            return 0

        for event in session.send(user):
            kind = event.get("kind")
            if kind == "assistant":
                print(f"assistant> {event.get('text', '')}\n")
            elif kind == "tool":
                print(f"tool> {event.get('name')}({event.get('args')})")
            elif kind == "tool_result":
                text = event.get("text") or ""
                print(f"result> {text[:500]}{'...' if len(text) > 500 else ''}")
            elif kind == "status":
                print(f"… {event.get('text', '')}")
            elif kind == "error":
                print(f"llm-error> {event.get('text', '')}", file=sys.stderr)

    return 0
