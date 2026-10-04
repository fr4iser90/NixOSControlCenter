"""Check-frequency presets → systemd OnCalendar (+ optional display helpers)."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

# Top-level schedule mode for UI (enums — not free text).
# Daily/Weekly modes always include a clock time (local system timezone).
SCHEDULE_MODES: list[tuple[str, str]] = [
    ("simple", "Simple preset (no clock — midnight/hourly)"),
    ("daily-at", "Daily at clock time"),
    ("weekly-at", "Weekly: weekday + clock time"),
    ("cron", "Cron (field pickers)"),
    ("advanced", "Advanced (raw OnCalendar)"),
]

# Simple presets only (no free-text / daily-at — those are separate modes).
FREQUENCY_PRESETS: list[tuple[str, str, str]] = [
    ("hourly", "Every hour", "hourly"),
    ("every-15m", "Every 15 minutes", "*:0/15"),
    ("every-30m", "Every 30 minutes", "*:0/30"),
    ("daily", "Daily (midnight)", "daily"),
    ("weekly", "Weekly (Sunday midnight)", "weekly"),
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

# Cron field enums (value, label) — * and common steps only.
CRON_MINUTES: list[tuple[str, str]] = [
    *[(str(m), f":{m:02d}") for m in range(0, 60, 5)],
    ("*/5", "every 5 min"),
    ("*/10", "every 10 min"),
    ("*/15", "every 15 min"),
    ("*", "every minute (*)"),
]
CRON_HOURS: list[tuple[str, str]] = [
    ("*", "every hour (*)"),
    *[(str(h), f"{h:02d}:xx") for h in range(24)],
]
CRON_DOM: list[tuple[str, str]] = [
    ("*", "every day-of-month (*)"),
    *[(str(d), str(d)) for d in range(1, 32)],
]
CRON_MONTH: list[tuple[str, str]] = [
    ("*", "every month (*)"),
    ("1", "Jan"),
    ("2", "Feb"),
    ("3", "Mar"),
    ("4", "Apr"),
    ("5", "May"),
    ("6", "Jun"),
    ("7", "Jul"),
    ("8", "Aug"),
    ("9", "Sep"),
    ("10", "Oct"),
    ("11", "Nov"),
    ("12", "Dec"),
]
CRON_DOW: list[tuple[str, str]] = [
    ("*", "every weekday (*)"),
    ("0", "Sunday"),
    ("1", "Monday"),
    ("2", "Tuesday"),
    ("3", "Wednesday"),
    ("4", "Thursday"),
    ("5", "Friday"),
    ("6", "Saturday"),
    ("1-5", "Mon–Fri"),
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


def cron_fields_to_on_calendar(
    minute: str,
    hour: str,
    dom: str = "*",
    month: str = "*",
    dow: str = "*",
) -> str:
    """Map constrained cron field enums → systemd OnCalendar (best-effort)."""
    minute = (minute or "0").strip()
    hour = (hour or "*").strip()
    dom = (dom or "*").strip()
    month = (month or "*").strip()
    dow = (dow or "*").strip()

    # Interval minutes with any hour
    if minute.startswith("*/") and hour == "*" and dom == "*" and month == "*" and dow == "*":
        step = minute[2:]
        if step.isdigit():
            return f"*:0/{int(step)}"
    if minute == "*" and hour == "*" and dom == "*" and month == "*" and dow == "*":
        return "minutely"

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

    # Every hour at :MM
    if minute.isdigit() and hour == "*" and dom == "*" and month == "*" and dow == "*":
        mm = int(minute)
        if mm == 0:
            return "hourly"
        return f"*:{mm:02d}:00"

    # Fixed minute + hour, any day/month
    if minute.isdigit() and hour.isdigit() and dom == "*" and month == "*":
        hh, mm = int(hour), int(minute)
        if dow in ("*", "?"):
            return f"*-*-* {hh:02d}:{mm:02d}:00"
        if dow == "1-5":
            return f"Mon..Fri *-*-* {hh:02d}:{mm:02d}:00"
        mapped = cron_dow.get(dow, "Sun")
        return f"{mapped} *-*-* {hh:02d}:{mm:02d}:00"

    # Fallback: keep as 5-field cron string for advanced cases
    return f"{minute} {hour} {dom} {month} {dow}"


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
    with hour/minute/weekday, or a raw OnCalendar / 5-field cron string.
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

    # 5-field cron → OnCalendar when possible
    cron = re.split(r"\s+", text)
    if len(cron) == 5:
        return cron_fields_to_on_calendar(cron[0], cron[1], cron[2], cron[3], cron[4])

    # Already looks like OnCalendar / systemd calendar
    if any(ch in text for ch in ("*", ":", "-", ".")) or text.lower() in (
        "minutely",
        "hourly",
        "daily",
        "weekly",
        "monthly",
        "yearly",
    ):
        return text

    return text


def system_local_tz_label() -> str:
    """Host local timezone label (what systemd user timers use for OnCalendar)."""
    try:
        now = datetime.now().astimezone()
        key = getattr(now.tzinfo, "key", None)
        name = now.tzname() or ""
        if key and name:
            return f"{key} ({name})"
        if key:
            return str(key)
        if name:
            return name
    except Exception:
        pass
    return "local system time"


def describe_frequency(on_calendar: str) -> str:
    for key, label, tmpl in FREQUENCY_PRESETS:
        if tmpl and tmpl == on_calendar:
            return label
        if key == on_calendar:
            return label
    for mode, label in SCHEDULE_MODES:
        if mode == on_calendar:
            return label
    return on_calendar


def describe_schedule_human(on_calendar: str) -> str:
    """Human line for UI preview, e.g. 'Every Monday at 08:30'."""
    p = parse_stored_frequency(on_calendar)
    mode = p.get("mode")
    if mode == "daily-at" and p.get("hour") is not None:
        return f"Every day at {int(p['hour']):02d}:{int(p.get('minute') or 0):02d}"
    if mode == "weekly-at" and p.get("hour") is not None:
        dow_map = dict(WEEKDAYS)
        day = dow_map.get(str(p.get("weekday") or "Mon"), str(p.get("weekday") or "Monday"))
        return f"Every {day} at {int(p['hour']):02d}:{int(p.get('minute') or 0):02d}"
    if mode == "cron":
        hh = p.get("cron_hour")
        mm = p.get("cron_minute")
        dow = p.get("cron_dow")
        if str(mm or "").isdigit() and str(hh or "").isdigit():
            time_s = f"{int(hh):02d}:{int(mm):02d}"
            if dow == "1-5":
                return f"Mon–Fri at {time_s}"
            if dow in ("0", "7"):
                return f"Every Sunday at {time_s}"
            dow_names = {
                "1": "Monday",
                "2": "Tuesday",
                "3": "Wednesday",
                "4": "Thursday",
                "5": "Friday",
                "6": "Saturday",
            }
            if dow in dow_names:
                return f"Every {dow_names[dow]} at {time_s}"
            if dow in ("*", "?"):
                return f"Every day at {time_s}"
    if mode == "simple":
        return describe_frequency(str(p.get("on_calendar") or on_calendar))
    return describe_frequency(on_calendar)


def parse_stored_frequency(value: str) -> dict[str, Any]:
    """Best-effort reverse map for editing UI defaults."""
    v = (value or "").strip()
    low = v.lower()
    if low in ("hourly", "daily", "weekly") or low in _ALIAS:
        preset = low if low in ("hourly", "daily", "weekly") else low
        if preset in _ALIAS:
            # reverse: value might be alias key
            for k, mapped in _ALIAS.items():
                if k == low or mapped == v:
                    if k in ("hourly", "daily", "weekly", "every-15m", "every-30m"):
                        preset = k if k.startswith("every") or k in ("hourly", "daily", "weekly") else preset
                    break
        if low in ("every-15m", "every15m", "15m"):
            return {"mode": "simple", "preset": "every-15m", "on_calendar": "*:0/15"}
        if low in ("every-30m", "every30m", "30m"):
            return {"mode": "simple", "preset": "every-30m", "on_calendar": "*:0/30"}
        if low in ("hourly", "hour", "every-hour"):
            return {"mode": "simple", "preset": "hourly", "on_calendar": "hourly"}
        if low in ("daily", "day"):
            return {"mode": "simple", "preset": "daily", "on_calendar": "daily"}
        if low in ("weekly", "week"):
            return {"mode": "simple", "preset": "weekly", "on_calendar": "weekly"}
    if low in ("every-15m", "*:0/15"):
        return {"mode": "simple", "preset": "every-15m", "on_calendar": "*:0/15"}
    if low in ("every-30m", "*:0/30"):
        return {"mode": "simple", "preset": "every-30m", "on_calendar": "*:0/30"}
    # OnCalendar like: "Sun *-*-* 04:00:00" or "*-*-* 03:15:00" or Mon..Fri
    m = re.fullmatch(
        r"(?:(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Mon\.\.Fri)\s+)?\*-\*-\*\s+(\d{1,2}):(\d{2}):00",
        v,
    )
    if m:
        dow, hh, mm = m.group(1), int(m.group(2)), int(m.group(3))
        if dow == "Mon..Fri":
            return {
                "mode": "cron",
                "cron_minute": str(mm),
                "cron_hour": str(hh),
                "cron_dom": "*",
                "cron_month": "*",
                "cron_dow": "1-5",
                "on_calendar": v,
            }
        if dow:
            return {
                "mode": "weekly-at",
                "preset": "weekly-at",
                "weekday": dow,
                "hour": hh,
                "minute": mm,
                "on_calendar": v,
            }
        return {
            "mode": "daily-at",
            "preset": "daily-at",
            "hour": hh,
            "minute": mm,
            "on_calendar": v,
        }
    # 5-field cron stored as-is
    parts = re.split(r"\s+", v)
    if len(parts) == 5:
        return {
            "mode": "cron",
            "cron_minute": parts[0],
            "cron_hour": parts[1],
            "cron_dom": parts[2],
            "cron_month": parts[3],
            "cron_dow": parts[4],
            "on_calendar": normalize_on_calendar(v),
        }
    return {"mode": "advanced", "preset": "advanced", "on_calendar": v, "custom": v}
