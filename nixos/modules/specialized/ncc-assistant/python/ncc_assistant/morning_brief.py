"""Brief helpers (digest lines / schedule prefs).

Product surface: workflow template ``workspace-brief`` + Cron — not a plugin.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from .preferences import (
    get_active_workspace_id,
    get_daily_digest_enable,
    get_daily_digest_on_calendar,
    get_morning_brief_auto_refresh,
    get_morning_brief_last_fired,
    get_morning_brief_sources,
    set_morning_brief_last_fired,
)

# HH:MM from OnCalendar forms like "*-*-* 08:30:00" or "Mon *-*-* 09:00:00"
_TIME_RE = re.compile(r"\b(\d{1,2}):(\d{2})(?::\d{2})?\b")


def parse_digest_hhmm(cal: str) -> tuple[int, int] | None:
    """Extract hour/minute from stored OnCalendar / daily-at string."""
    c = (cal or "").strip().lower()
    if c in ("daily", "weekly"):
        return (0, 0)
    m = _TIME_RE.search(cal or "")
    if not m:
        return None
    return max(0, min(int(m.group(1)), 23)), max(0, min(int(m.group(2)), 59))


def due_for_brief(*, now: datetime | None = None) -> bool:
    """True once per local day after the scheduled clock time."""
    if not get_daily_digest_enable():
        return False
    now = now or datetime.now().astimezone()
    today = now.strftime("%Y-%m-%d")
    if get_morning_brief_last_fired() == today:
        return False
    hhmm = parse_digest_hhmm(get_daily_digest_on_calendar())
    if hhmm is None:
        hhmm = (8, 30)
    hour, minute = hhmm
    if (now.hour, now.minute) < (hour, minute):
        return False
    return True


def build_brief_lines(*, limit: int = 12) -> list[str]:
    from .workflows import daily_summary_lines, load_daily

    sources = set(get_morning_brief_sources())
    data = load_daily()
    lines: list[str] = []

    if "github-prs" in sources:
        for pr in (data.get("pullRequests") or [])[:6]:
            mark = {"fail": "✗", "pass": "✓", "pending": "…", "unknown": "?"}.get(
                str(pr.get("checks")), "?"
            )
            draft = " (draft)" if pr.get("draft") else ""
            lines.append(f"PR#{pr.get('id')} {mark}{draft} {pr.get('title')}")
    if "github-issues" in sources:
        for issue in (data.get("issues") or [])[:4]:
            lines.append(f"Issue#{issue.get('id')} {issue.get('title')}")
    if "tasks" in sources:
        open_tasks = [
            t
            for t in (data.get("tasks") or [])
            if str(t.get("status")) in ("todo", "doing")
        ]
        open_tasks.sort(key=lambda t: str(t.get("priority") or "p2"))
        for t in open_tasks[:4]:
            lines.append(f"Task[{t.get('priority')}] {t.get('title')}")
    if "roadmap" in sources:
        for r in (data.get("roadmap") or [])[:3]:
            if str(r.get("horizon")) == "now":
                lines.append(f"Roadmap·now {r.get('title')}")

    if not lines:
        # Only real content from summary — strip the "(empty — …)" placeholder
        for ln in daily_summary_lines(limit=limit):
            if str(ln).startswith("(empty"):
                continue
            lines.append(ln)
    return lines[:limit]


def _brief_payload(
    *,
    host: str,
    lines: list[str],
    refreshed: bool,
    today: str,
    error: str | None = None,
) -> dict[str, Any]:
    title = "Morning Brief" if not error else "Morning Brief (needs setup)"
    body_lines = list(lines)
    if error:
        body_lines = [error, *body_lines]
    body = title + "\n" + "\n".join(f"• {ln}" for ln in body_lines)
    brief = {
        "title": title,
        "lines": body_lines,
        "refreshed": refreshed,
        "date": today,
        "error": error,
    }
    out: dict[str, Any] = {"brief": brief, "message": body}
    if host == "companion":
        out["companion_brief"] = brief
    if host == "tray":
        out["tray_message"] = {
            "title": "NCC · Morning Brief",
            "body": (
                error
                if error
                else (" · ".join(body_lines[:3]) if body_lines else "Open Daily cockpit.")
            ),
        }
    return out


def maybe_fire_brief(*, host: str) -> dict[str, Any] | None:
    """
    Daily cockpit brief. Never popup empty noise.

    - Refresh digest first (when auto-refresh on; default).
    - On refresh/workspace failure: show error once, do NOT mark fired (retry).
    - On success with zero items: mark fired, no popup.
    - On success with items: popup + mark fired.
    """
    if not due_for_brief():
        return None

    today = datetime.now().astimezone().strftime("%Y-%m-%d")
    wid = get_active_workspace_id()
    if not wid:
        # Retry later until user sets ★ workspace
        return _brief_payload(
            host=host,
            lines=[],
            refreshed=False,
            today=today,
            error=(
                "No active workspace (★). "
                "Companion → Workspaces → set active, then open Daily."
            ),
        )

    refreshed = False
    refresh_error: str | None = None
    if get_morning_brief_auto_refresh():
        try:
            from .workflows import refresh_github_digest

            result = refresh_github_digest(workspace_id=wid)
            if not result.get("ok", True):
                refresh_error = str(
                    result.get("error")
                    or result.get("hint")
                    or "GitHub digest refresh failed"
                )
            else:
                refreshed = True
        except Exception as exc:  # noqa: BLE001
            refresh_error = f"Digest refresh failed: {exc}"

    if refresh_error:
        # Do not mark fired — fix workspace/gh and retry next tick
        return _brief_payload(
            host=host,
            lines=[],
            refreshed=False,
            today=today,
            error=refresh_error,
        )

    lines = build_brief_lines()
    if not lines:
        # Nothing to say — quiet success, don't spam empty popup
        set_morning_brief_last_fired(today)
        return None

    set_morning_brief_last_fired(today)
    return _brief_payload(
        host=host, lines=lines, refreshed=refreshed, today=today, error=None
    )
