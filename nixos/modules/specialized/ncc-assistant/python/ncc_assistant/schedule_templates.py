"""Schedule templates (builtin) and user-local schedules under ~/.config/ncc-assistant/schedules/."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Any

from .paths import schedules_dir


@dataclass
class ScheduleSpec:
    """A schedule definition (template or user instance)."""
    name: str
    onCalendar: str | None = "daily"
    playbook: str | None = None
    goal: str | None = None
    profile: str = "read-only"
    dryRun: bool = True
    maxSteps: int | None = 15
    enable: bool = True
    description: str = ""
    kind: str = "agent"  # agent | probe
    probe: str | None = None
    thresholdPct: float | None = None
    escalatePlaybook: str | None = None
    trigger: str = "calendar"  # calendar | poll (phase 39 L11)
    pollInterval: str | None = None
    pollWatch: list[str] = field(default_factory=list)
    after: str | None = None  # schedule id whose completion wakes this one (phase 39 L12)
    source: str = "user"  # builtin | user | nix
    path: str | None = None

    @property
    def frequency(self) -> str:
        """How often it fires, stated honestly: a poll has no calendar to quote, and a chain
        with no calendar of its own has no time at all — only a predecessor."""
        if (self.trigger or "calendar") == "poll":
            return f"every {self.pollInterval or 'poll interval'}"
        if self.onCalendar:
            return self.onCalendar
        if self.after:
            return f"after {self.after} completes"
        return "daily"

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d.pop("source", None)
        d.pop("path", None)
        return {k: v for k, v in d.items() if v is not None}

    @classmethod
    def from_dict(
        cls,
        data: dict[str, Any],
        *,
        name: str | None = None,
        source: str = "user",
        path: str | None = None,
    ) -> "ScheduleSpec":
        trigger = data.get("trigger") or "calendar"
        watch = data.get("pollWatch", data.get("poll_watch"))
        after = data.get("after")
        return cls(
            name=name or data.get("name", ""),
            # A poll has no calendar; inventing "daily" here would show a poll as a schedule
            # that never fires at the times its own timer says it does. Same for a chained
            # schedule: what wakes it is another schedule's completion, so a clock it does not
            # have must not be shown — nor written back by ``nix_snippet``.
            onCalendar=data.get("onCalendar")
            or data.get("on_calendar")
            or (None if (trigger == "poll" or after) else "daily"),
            playbook=data.get("playbook"),
            goal=data.get("goal"),
            profile=data.get("profile") or "read-only",
            dryRun=bool(data.get("dryRun", data.get("dry_run", True))),
            maxSteps=data.get("maxSteps", data.get("max_steps")),
            enable=bool(data.get("enable", True)),
            description=data.get("description", ""),
            kind=data.get("kind") or "agent",
            probe=data.get("probe"),
            thresholdPct=data.get("thresholdPct", data.get("threshold_pct")),
            escalatePlaybook=data.get("escalatePlaybook", data.get("escalate_playbook")),
            trigger=trigger,
            pollInterval=data.get("pollInterval", data.get("poll_interval")),
            pollWatch=[str(entry) for entry in watch] if isinstance(watch, list) else [],
            after=data.get("after"),
            source=source,
            path=path,
        )


BUILTIN_TEMPLATES: list[ScheduleSpec] = [
    ScheduleSpec(
        name="daily-health",
        description="Nightly config health via agent (LLM). Prefer probe schedules when no narrative needed.",
        onCalendar="*-*-* 03:15:00",
        playbook="health-report",
        profile="read-only",
        dryRun=True,
        maxSteps=15,
        enable=True,
        kind="agent",
        source="builtin",
    ),
    ScheduleSpec(
        name="weekly-module-audit",
        description="Weekly unused/unconfigured modules audit (agent, read-only)",
        onCalendar="Sun *-*-* 04:00:00",
        playbook="unused-modules-dry-run",
        profile="read-only",
        dryRun=True,
        maxSteps=30,
        enable=True,
        kind="agent",
        source="builtin",
    ),
    ScheduleSpec(
        name="daily-disk-probe",
        description="Tool-only disk/Nix probe; escalate to GC advisor agent only if root ≥ threshold",
        onCalendar="*-*-* 02:45:00",
        kind="probe",
        probe="disk-nix",
        thresholdPct=85,
        escalatePlaybook="disk-nix-gc-advisor",
        profile="read-only",
        dryRun=True,
        enable=True,
        source="builtin",
    ),
]


def _safe_name(name: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9._-]+", "-", name.strip())
    return cleaned.strip("-._") or "schedule"


def list_templates() -> list[ScheduleSpec]:
    """Builtin schedule templates (not yet user instances)."""
    return list(BUILTIN_TEMPLATES)


def get_template(name: str) -> ScheduleSpec | None:
    for t in BUILTIN_TEMPLATES:
        if t.name == name:
            return t
    return None


def list_user_schedules() -> list[ScheduleSpec]:
    """User schedules from ~/.config/ncc-assistant/schedules/*.json."""
    out: list[ScheduleSpec] = []
    root = schedules_dir()
    if not root.is_dir():
        return out
    for path in sorted(root.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                continue
            if not data.get("name"):
                data["name"] = path.stem
            out.append(ScheduleSpec.from_dict(data, source="user", path=str(path)))
        except (OSError, json.JSONDecodeError):
            continue
    return out


def get_user_schedule(name: str) -> ScheduleSpec | None:
    for s in list_user_schedules():
        if s.name == name:
            return s
    return None


def save_user_schedule(spec: ScheduleSpec) -> Path:
    """Create or overwrite a user schedule JSON file."""
    root = schedules_dir()
    root.mkdir(parents=True, exist_ok=True)
    safe = _safe_name(spec.name)
    path = root / f"{safe}.json"
    payload = spec.to_dict()
    payload["name"] = safe
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    spec.name = safe
    spec.path = str(path)
    spec.source = "user"
    return path


def delete_user_schedule(name: str) -> bool:
    spec = get_user_schedule(name)
    if not spec or not spec.path:
        # try by filename
        path = schedules_dir() / f"{_safe_name(name)}.json"
        if path.is_file():
            path.unlink()
            return True
        return False
    path = Path(spec.path)
    if path.is_file():
        path.unlink()
        return True
    return False


def load_template_as_user(template_name: str, *, rename: str | None = None) -> ScheduleSpec:
    """
    Instantiate a builtin template into the user schedules directory.
    Overwrites if the same name already exists.
    """
    tmpl = get_template(template_name)
    if tmpl is None:
        raise KeyError(f"Unknown schedule template: {template_name}")
    name = rename or tmpl.name
    spec = ScheduleSpec(
        name=name,
        onCalendar=tmpl.onCalendar,
        playbook=tmpl.playbook,
        goal=tmpl.goal,
        profile=tmpl.profile,
        dryRun=tmpl.dryRun,
        maxSteps=tmpl.maxSteps,
        enable=tmpl.enable,
        description=tmpl.description,
        kind=tmpl.kind,
        probe=tmpl.probe,
        thresholdPct=tmpl.thresholdPct,
        escalatePlaybook=tmpl.escalatePlaybook,
        source="user",
    )
    save_user_schedule(spec)
    return spec


def list_nix_schedules() -> list[ScheduleSpec]:
    """Schedules declared in Nix (exported via NCC_ASSISTANT_SCHEDULES_JSON)."""
    import os

    raw = os.environ.get("NCC_ASSISTANT_SCHEDULES_JSON", "{}")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, dict):
        return []
    out: list[ScheduleSpec] = []
    for name, cfg in data.items():
        if not isinstance(cfg, dict):
            continue
        out.append(ScheduleSpec.from_dict(cfg, name=name, source="nix"))
    return out


def nix_snippet(spec: ScheduleSpec) -> str:
    """Nix attrset fragment to paste into agent.schedules."""
    poll = (spec.trigger or "calendar") == "poll"
    lines = [
        f"agent.schedules.{spec.name} = {{",
        f"  enable = {'true' if spec.enable else 'false'};",
    ]
    if poll:
        lines.append('  trigger = "poll";')
        if spec.pollInterval:
            lines.append(f'  pollInterval = "{spec.pollInterval}";')
        if spec.pollWatch:
            lines.append("  pollWatch = [ " + " ".join(f'"{entry}"' for entry in spec.pollWatch) + " ];")
    elif spec.onCalendar or not spec.after:
        # A chained schedule with no clock of its own must not get one pasted back: the paste
        # would give it a timer that fires regardless of the run it declares it waits for.
        lines.append(f'  onCalendar = "{spec.onCalendar or "daily"}";')
    if spec.after:
        lines.append(f'  after = "{spec.after}";')
    lines.append(f'  kind = "{spec.kind or "agent"}";')
    if (spec.kind or "agent") == "probe":
        if spec.probe:
            lines.append(f'  probe = "{spec.probe}";')
        if spec.thresholdPct is not None:
            lines.append(f"  thresholdPct = {spec.thresholdPct};")
        if spec.escalatePlaybook:
            lines.append(f'  escalatePlaybook = "{spec.escalatePlaybook}";')
    else:
        if spec.playbook:
            lines.append(f'  playbook = "{spec.playbook}";')
        if spec.goal:
            goal = spec.goal.replace("\\", "\\\\").replace('"', '\\"')
            lines.append(f'  goal = "{goal}";')
        lines.append(f'  profile = "{spec.profile}";')
        lines.append(f"  dryRun = {'true' if spec.dryRun else 'false'};")
        if spec.maxSteps is not None:
            lines.append(f"  maxSteps = {int(spec.maxSteps)};")
    lines.append("};")
    return "\n".join(lines)
