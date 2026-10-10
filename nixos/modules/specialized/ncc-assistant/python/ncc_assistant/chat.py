"""Terminal REPL chat (fallback). Prefer the Qt GUI via `ncc ai`. """

from __future__ import annotations

from .cli_print import print_err, print_info
from .config import Settings
from .runtime import ToolRuntime
from .session import ChatSession


def run_chat(
    settings: Settings,
    runtime: ToolRuntime | None = None,
    max_rounds: int | None = None,
) -> int:
    del runtime  # session owns runtime
    try:
        session = ChatSession.create(
            settings, interactive_auth=True, max_rounds=max_rounds
        )
    except RuntimeError as exc:
        print_err(f"auth failed: {exc}")
        return 1

    auth_label = "key" if session.settings.api_key else "none"
    print_info("NCC AI terminal chat — type exit or Ctrl-D to quit")
    print_info(
        f"api={session.settings.api} endpoint={session.settings.endpoint} "
        f"model={session.model_label} auth={auth_label} "
        f"writes={session.settings.writes_enabled} "
        f"rebuild={session.settings.allow_rebuild}"
    )
    print_info("Commands: /context /compact /reset  —  exit or Ctrl-D to quit")

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

        if user == "/context":
            print_info(_context_line(session.context_report()))
            continue
        if user == "/compact":
            for event in session.compact_now():
                _print_event(event, verbose=True)
            continue
        if user == "/reset":
            session.reset_conversation()
            print_info("new conversation")
            continue

        for event in session.send(user):
            _print_event(event)

    return 0


def _print_event(event: dict, *, verbose: bool = False) -> None:
    kind = event.get("kind")
    if kind == "assistant":
        print(f"assistant> {event.get('text', '')}\n")
    elif kind == "tool":
        print_info(f"tool {event.get('name')}({event.get('args')})")
    elif kind == "tool_result":
        text = event.get("text") or ""
        print_info(f"result {text[:500]}{'...' if len(text) > 500 else ''}")
    elif kind == "context":
        print_info(_context_line(event))
    elif kind == "status":
        text = event.get("text", "")
        if verbose and event.get("phase") == "compact":
            print(f"context> {text}")
        else:
            print_info(text)
    elif kind == "error":
        print_err(event.get("text", ""))


def _context_line(report: dict) -> str:
    """One line: how full the window is and what it was measured against."""
    used, window = report.get("used", 0), report.get("window", 0)
    wave = "~" if report.get("basis") == "estimate" else ""
    note = (
        f"compaction at {report.get('threshold', 0):,}"
        f" ({'auto' if report.get('auto') else 'manual'})"
    )
    if report.get("compactions"):
        note += f" · {report['compactions']} compacted"
    return (
        f"ctx {wave}{used:,}/{window:,} ({report.get('percent', 0)}%)"
        f" [{report.get('window_source')}] {note}"
    )
