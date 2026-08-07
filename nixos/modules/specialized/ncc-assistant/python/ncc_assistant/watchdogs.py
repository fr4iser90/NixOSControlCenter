"""Watchdogs: event triggers that start agent jobs (not only calendar schedules)."""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .paths import config_home
from .presence import is_paused
from .paths import is_disabled


def watchdogs_file() -> Path:
    return config_home() / "watchdogs.json"


def cooldown_file() -> Path:
    return config_home() / "watchdog-cooldowns.json"


@dataclass
class Watchdog:
    id: str
    event: str
    goal: str
    enable: bool = True
    playbook: str | None = None
    profile: str = "read-only"
    dry_run: bool = True
    cooldown_sec: int = 3600
    notify_only_when_paused: bool = False

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Watchdog":
        return cls(
            id=data["id"],
            event=data.get("event", data["id"]),
            goal=data.get("goal", ""),
            enable=data.get("enable", True),
            playbook=data.get("playbook"),
            profile=data.get("profile", "read-only"),
            dry_run=data.get("dry_run", True),
            cooldown_sec=int(data.get("cooldown_sec", 3600)),
            notify_only_when_paused=bool(data.get("notify_only_when_paused", False)),
        )


def list_watchdogs() -> list[Watchdog]:
    path = watchdogs_file()
    if not path.is_file():
        # Seed defaults (disabled)
        defaults = [
            {
                "id": "rebuild-failed",
                "event": "rebuild-failed",
                "enable": False,
                "goal": "A nixos-rebuild/switch appears to have failed. Inspect logs if possible and summarize likely causes. Do not write config.",
                "profile": "read-only",
                "dry_run": True,
                "cooldown_sec": 1800,
            },
            {
                "id": "disk-root-above-90",
                "event": "disk-root-above-90",
                "enable": False,
                "goal": "Root filesystem usage is high. Summarize cleanup options for Nix store and logs. Do not delete anything.",
                "profile": "read-only",
                "dry_run": True,
                "cooldown_sec": 3600,
            },
        ]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"watchdogs": defaults}, indent=2) + "\n", encoding="utf-8")
    data = json.loads(path.read_text(encoding="utf-8"))
    items = data.get("watchdogs") or data
    if isinstance(items, dict):
        items = [{"id": k, **v} for k, v in items.items()]
    return [Watchdog.from_dict(x) for x in items if isinstance(x, dict) and x.get("id")]


def _load_cooldowns() -> dict[str, float]:
    path = cooldown_file()
    if not path.is_file():
        return {}
    try:
        return {k: float(v) for k, v in json.loads(path.read_text(encoding="utf-8")).items()}
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return {}


def _save_cooldowns(data: dict[str, float]) -> None:
    path = cooldown_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def fire_event(event: str, *, force: bool = False) -> dict[str, Any]:
    """
    Fire a watchdog event. Starts an agent job if enabled and not cooling down.
    Returns status dict.
    """
    if is_disabled():
        return {"ok": False, "error": "kill-switch DISABLE is set"}

    matches = [w for w in list_watchdogs() if w.enable and w.event == event]
    if not matches:
        return {"ok": False, "error": f"no enabled watchdog for event={event}"}

    results = []
    cool = _load_cooldowns()
    now = time.time()

    for w in matches:
        last = cool.get(w.id, 0.0)
        if not force and now - last < w.cooldown_sec:
            results.append(
                {
                    "id": w.id,
                    "ok": False,
                    "error": "cooldown",
                    "retry_in_sec": int(w.cooldown_sec - (now - last)),
                }
            )
            continue

        if is_paused():
            if w.notify_only_when_paused:
                from .notifications import notify

                notify(
                    "NCC AI watchdog",
                    f"Event {event} while paused — not starting agent ({w.id})",
                )
            results.append({"id": w.id, "ok": False, "error": "presence_paused"})
            continue

        from .agent import run_agent
        from .auth import with_cached_credentials
        from .config import Settings

        settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
        # Collect events for logging but run to completion
        events = []
        for ev in run_agent(
            goal=w.goal,
            settings=settings,
            max_steps=16,
            dry_run=w.dry_run,
            profile=w.profile,
            playbook=w.playbook,
        ):
            events.append(ev)

        cool[w.id] = now
        _save_cooldowns(cool)
        results.append(
            {
                "id": w.id,
                "ok": True,
                "event_count": len(events),
                "last_kind": (events[-1].get("kind") if events else None),
            }
        )

    return {"ok": any(r.get("ok") for r in results), "results": results}
