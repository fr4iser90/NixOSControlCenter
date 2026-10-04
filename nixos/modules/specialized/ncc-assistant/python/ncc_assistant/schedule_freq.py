"""Check-frequency presets → systemd OnCalendar (+ optional display helpers)."""

from __future__ import annotations

import re
from typing import Any

# (value_key, label, on_calendar_template)
# Templates may include {HH} {MM} for daily/weekly-at-time modes.
FREQUENCY_PRESETS: list[tuple[str, str, str]] = [
    ("hourly", "Every hour", "hourly"),
    ("every-15m", "Every 15 minutes", "*:0/15"),
    ("every-30m", "Every 30 minutes", "*:0/30"),
    ("daily", "Daily (midnight)", "daily"),
    ("daily-at", "Daily at time…", "*-*-* {HH}:{MM}:00"),
    ("weekly", "Weekly (Sunday midnight)", "weekly"),
    ("weekly-at", "Weekly on day + time…", "{DOW} *-*-* {HH}:{MM}:00"),
    ("custom", "Custom OnCalendar / cron…", ""),
]

WEEKDAYS: list[tuple[str, str]] = [
    ("Mon", "Monday"),
    ("Tue", "Tuesday"),
    ("Wed", "Wednesday"),
    ("Thu", "Thursday"),
    ("Fri", "Friday"),
    ("Sat", "Saturday"),
    ("Sun", "Sunday"),
]

COMMON_TIMEZONES: list[str] = [
    "Europe/Berlin",
    "Europe/Vienna",
    "Europe/Zurich",
    "UTC",
    "Europe/London",
    "America/New_York",
    "America/Los_Angeles",
    "Asia/Tokyo",
]

_ALIAS: dict[str, str] = {
    "hourly": "hourly",
    "hour": "hourly",
    "every-hour": "hourly",
    "daily": "daily",
    "day": "daily",
    "weekly": "weekly",
    "week": "weekly",
    "every-15m": "*:0/15",
    "every15m": "*:0/15",
    "15m": "*:0/15",
    "every-30m": "*:0/30",
    "every30m": "*:0/30",
    "30m": "*:0/30",
}


def normalize_on_calendar(
    raw: str,
    *,
    hour: int | None = None,
    minute: int | None = None,
    weekday: str | None = None,
) -> str:
    """
    Turn UI / alias input into a systemd OnCalendar expression.

    Accepts presets (hourly, daily, weekly, every-15m), daily-at / weekly-at
    with hour/minute/weekday, or a raw OnCalendar string.
    """
    text = (raw or "").strip()
    if not text:
        return "daily"

    key = text.lower().replace(" ", "")
    if key in ("daily-at", "dailyat"):
        hh = max(0, min(23, int(hour if hour is not None else 3)))
        mm = max(0, min(59, int(minute if minute is not None else 0)))
        return f"*-*-* {hh:02d}:{mm:02d}:00"
    if key in ("weekly-at", "weeklyat"):
        dow = (weekday or "Sun").strip() or "Sun"
        if dow not in {w for w, _ in WEEKDAYS}:
            dow = "Sun"
        hh = max(0, min(23, int(hour if hour is not None else 4)))
        mm = max(0, min(59, int(minute if minute is not None else 0)))
        return f"{dow} *-*-* {hh:02d}:{mm:02d}:00"

    if key in _ALIAS:
        return _ALIAS[key]

    # 5-field cron → rough OnCalendar (min hour dom mon dow)
    cron = re.split(r"\s+", text)
    if len(cron) == 5 and cron[0].isdigit() and cron[1].isdigit():
        minute_c, hour_c, dom, mon, dow = cron
        if dom == "*" and mon == "*":
            hh = int(hour_c)
            mm = int(minute_c)
            if dow in ("*", "?"):
                return f"*-*-* {hh:02d}:{mm:02d}:00"
            cron_dow = {
                "0": "Sun",
                "7": "Sun",
                "1": "Mon",
                "2": "Tue",
                "3": "Wed",
                "4": "Thu",
                "5": "Fri",
                "6": "Sat",
            }
            mapped = cron_dow.get(dow, dow[:3].title() if dow.isalpha() else "Sun")
            return f"{mapped} *-*-* {hh:02d}:{mm:02d}:00"

    # Already looks like OnCalendar / systemd calendar
    if any(ch in text for ch in ("*", ":", "-")) or text.lower() in (
        "minutely",
        "hourly",
        "daily",
        "weekly",
        "monthly",
        "yearly",
    ):
        return text

    return text


def describe_frequency(on_calendar: str) -> str:
    for key, label, tmpl in FREQUENCY_PRESETS:
        if tmpl and tmpl == on_calendar:
            return label
        if key == on_calendar:
            return label
    return on_calendar


def parse_stored_frequency(value: str) -> dict[str, Any]:
    """Best-effort reverse map for editing UI defaults."""
    v = (value or "").strip()
    low = v.lower()
    if low in _ALIAS or low in ("hourly", "daily", "weekly"):
        return {"preset": low if low not in _ALIAS else low, "on_calendar": normalize_on_calendar(v)}
    if low in ("every-15m", "*:0/15"):
        return {"preset": "every-15m", "on_calendar": "*:0/15"}
    if low in ("every-30m", "*:0/30"):
        return {"preset": "every-30m", "on_calendar": "*:0/30"}
    # OnCalendar like: "Sun *-*-* 04:00:00" or "*-*-* 03:15:00"
    m = re.fullmatch(
        r"(?:(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+)?\*-\*-\*\s+(\d{1,2}):(\d{2}):00",
        v,
    )
    if m:
        dow, hh, mm = m.group(1), int(m.group(2)), int(m.group(3))
        if dow:
            return {
                "preset": "weekly-at",
                "weekday": dow,
                "hour": hh,
                "minute": mm,
                "on_calendar": v,
            }
        return {"preset": "daily-at", "hour": hh, "minute": mm, "on_calendar": v}
    return {"preset": "custom", "on_calendar": v, "custom": v}
