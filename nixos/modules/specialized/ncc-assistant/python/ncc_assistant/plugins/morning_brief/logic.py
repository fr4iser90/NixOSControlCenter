"""Compat shim — SSOT is ncc_assistant.morning_brief."""

from __future__ import annotations

from ...morning_brief import (  # noqa: F401
    build_brief_lines,
    due_for_brief,
    maybe_fire_brief,
    parse_digest_hhmm,
)