"""Unit tests for session scope UX helpers (no Qt display)."""

from __future__ import annotations

from ncc_gui.session_ux import (
    chip_text,
    needs_local_write_confirm,
    operating_on_line,
    session_mode,
)
from ncc_gui.target_session import TargetSession


def _s(**kwargs) -> TargetSession:
    base = dict(
        state="idle",
        candidate=None,
        connected=None,
        probe=None,
        message="",
    )
    base.update(kwargs)
    return TargetSession(**base)


def test_idle_is_local() -> None:
    s = _s()
    assert session_mode(s) == "local"
    assert not needs_local_write_confirm(s)
    assert chip_text(s).startswith("LOCAL ·")
    assert "Operating on: LOCAL" in operating_on_line(s)


def test_candidate_is_pending() -> None:
    s = _s(state="candidate", candidate="u@host")
    assert session_mode(s) == "pending"
    assert needs_local_write_confirm(s)
    assert "pending: u@host" in chip_text(s)
    assert "press Connect" in operating_on_line(s)


def test_unreachable_is_failed_still_local() -> None:
    s = _s(
        state="blocked",
        candidate="u@192.168.1.1",
        connected=None,
        message="Still on LOCAL …",
    )
    assert session_mode(s) == "failed"
    assert needs_local_write_confirm(s)
    assert "failed: u@192.168.1.1" in chip_text(s)
    assert "not connected" in operating_on_line(s)


def test_ready_is_remote() -> None:
    s = _s(state="ready", candidate="u@h", connected="u@h")
    assert session_mode(s) == "remote"
    assert not needs_local_write_confirm(s)
    assert chip_text(s) == "REMOTE · u@h"
    assert "REMOTE (u@h)" in operating_on_line(s)


def test_connecting() -> None:
    s = _s(state="connecting", candidate="u@h")
    assert session_mode(s) == "connecting"
    assert needs_local_write_confirm(s)
