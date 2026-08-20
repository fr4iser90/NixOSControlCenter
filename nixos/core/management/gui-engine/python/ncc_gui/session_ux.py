"""Session scope UX — LOCAL vs REMOTE is first-class (selection ≠ connection).

Modes (for chrome chip / tint / write gates):
  local     — idle on this machine
  pending   — host selected, not connected (still LOCAL)
  connecting
  remote    — connected (ready / needs_install / needs_update / blocked-while-connected)
  failed    — Connect failed; still LOCAL, candidate kept
"""

from __future__ import annotations

import socket
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from ncc_gui.target_session import TargetSession


def local_hostname() -> str:
    try:
        name = (socket.gethostname() or "").strip()
    except OSError:
        name = ""
    return name or "this machine"


def session_mode(session: TargetSession) -> str:
    """Return local | pending | connecting | remote | failed."""
    if session.state == "connecting":
        return "connecting"
    if session.connected:
        return "remote"
    if session.state == "blocked" and session.candidate:
        return "failed"
    if session.candidate or session.state == "candidate":
        return "pending"
    return "local"


def chip_text(session: TargetSession) -> str:
    """Short badge for the Target bar (always the truth: where writes go)."""
    local = local_hostname()
    mode = session_mode(session)
    if mode == "remote":
        host = session.connected or "?"
        return f"REMOTE · {host}"
    if mode == "connecting":
        host = session.candidate or "?"
        return f"CONNECTING · {host}"
    if mode == "failed":
        host = session.candidate or "?"
        return f"LOCAL · {local}  ·  failed: {host}"
    if mode == "pending":
        host = session.candidate or "?"
        return f"LOCAL · {local}  ·  pending: {host}"
    return f"LOCAL · {local}"


def operating_on_line(session: TargetSession) -> str:
    """Page-level provenance line under the subtitle."""
    local = local_hostname()
    mode = session_mode(session)
    if mode == "remote":
        host = session.connected or "?"
        return f"Operating on: REMOTE ({host})"
    if mode == "connecting":
        host = session.candidate or "?"
        return f"Operating on: LOCAL ({local}) — connecting to {host}…"
    if mode == "failed":
        host = session.candidate or "?"
        return (
            f"Operating on: LOCAL ({local}) — "
            f"not connected to {host} (Connect failed)"
        )
    if mode == "pending":
        host = session.candidate or "?"
        return (
            f"Operating on: LOCAL ({local}) — "
            f"{host} selected, press Connect to switch"
        )
    return f"Operating on: LOCAL ({local})"


def needs_local_write_confirm(session: TargetSession) -> bool:
    """True when UI suggests a remote host but session is still local."""
    mode = session_mode(session)
    return mode in ("pending", "failed", "connecting")


def confirm_session_write(
    parent: Any,
    session: TargetSession,
    *,
    action: str = "This action",
) -> bool:
    """Gate mutations when a remote host is selected but not connected.

    Returns True if the caller should proceed (on LOCAL or confirmed).
    """
    from ncc_gui.dialogs import confirm

    if not needs_local_write_confirm(session):
        return True
    if session.state == "connecting":
        return confirm(
            parent,
            "Still connecting",
            f"{action} would run on LOCAL ({local_hostname()}) while "
            f"Connect to {session.candidate} is still in progress.\n\n"
            "Continue on this machine anyway?",
        )
    host = session.candidate or "the selected host"
    why = (
        "Connect failed"
        if session_mode(session) == "failed"
        else "not connected yet"
    )
    return confirm(
        parent,
        "Still on this machine",
        f"{action} runs on LOCAL ({local_hostname()}).\n\n"
        f"Target {host} is {why}.\n"
        "Remote is only active after a successful Connect.\n\n"
        "Continue on this machine?",
    )
