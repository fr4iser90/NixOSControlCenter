"""Pure board-row formatting for GitHub Agent companion panel (no Qt).

Callers: ``widgets.github_agent_panel._load_board``, unit tests.
No existing helper formats scanable board columns; panel previously inlined
monolith strings in ``companion.window`` PANEL_GITHUB fill.
User: "Implement the plan as specified" (GitHub Agent Panel Zoned UX).
"""

from __future__ import annotations


def format_github_board_row(
    *,
    workspace_id: str,
    state: str,
    gaps: int,
    next_title: str,
    dirty: bool,
    active: bool,
) -> str:
    """Fixed-ish columns so the board scans as name / state / gaps / next / dirty."""
    mark = "★" if active else " "
    name = (workspace_id or "?")[:18].ljust(18)
    st = (state or "?")[:8].ljust(8)
    gap = f"gaps {gaps}".ljust(8)
    nxt = (next_title or "—")[:34]
    dirty_s = " dirty" if dirty else ""
    return f"{mark} {name}  {st}  {gap}  {nxt}{dirty_s}"
