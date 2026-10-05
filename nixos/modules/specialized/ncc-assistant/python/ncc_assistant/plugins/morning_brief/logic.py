"""Morning Brief schedule + payload (no Qt)."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from ...preferences import (
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
    from ...workflows import daily_summary_lines, load_daily

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
        # Fallback to full summary if filters empty or store empty
        lines = daily_summary_lines(limit=limit)
    return lines[:limit]


def maybe_fire_brief(*, host: str) -> dict[str, Any] | None:
    if not due_for_brief():
        return None

    refreshed = False
    if get_morning_brief_auto_refresh():
        try:
            from ...workflows import refresh_github_digest

            refresh_github_digest()
            refreshed = True
        except Exception:
            refreshed = False

    lines = build_brief_lines()
    today = datetime.now().astimezone().strftime("%Y-%m-%d")
    set_morning_brief_last_fired(today)

    body = "Morning Brief\n" + "\n".join(f"• {ln}" for ln in lines)
    out: dict[str, Any] = {
        "brief": {
            "title": "Morning Brief",
            "lines": lines,
            "refreshed": refreshed,
            "date": today,
        }
    }
    if host == "companion":
        out["companion_brief"] = out["brief"]
    if host == "tray":
        out["tray_message"] = {
            "title": "NCC · Morning Brief",
            "body": " · ".join(lines[:3]) if lines else "Open Companion Daily.",
        }
    out["message"] = body
    return out
