"""Idle-mode activity tracking and sweep (schedules / idle-ok templates)."""

from __future__ import annotations

import json
import os
import time
from typing import Any

from .paths import activity_file
from .preferences import (
    get_idle_after_min,
    get_idle_max_jobs,
    get_idle_mode,
)


def touch_activity(reason: str = "ui") -> None:
    path = activity_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"ts": time.time(), "reason": str(reason)[:64]}
    path.write_text(json.dumps(payload) + "\n", encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def last_activity_ts() -> float | None:
    path = activity_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if isinstance(data, dict) and "ts" in data:
        try:
            return float(data["ts"])
        except (TypeError, ValueError):
            return None
    return None


def idle_seconds() -> float:
    ts = last_activity_ts()
    if ts is None:
        return 0.0
    return max(0.0, time.time() - ts)


def is_idle_eligible() -> bool:
    mode = get_idle_mode()
    if mode == "off":
        return False
    try:
        from .presence import get_presence

        if get_presence().state == "paused":
            return False
    except Exception:
        pass
    return idle_seconds() >= float(get_idle_after_min()) * 60.0


def list_idle_candidates() -> list[dict[str, Any]]:
    """Candidates for an idle sweep (does not start jobs)."""
    mode = get_idle_mode()
    out: list[dict[str, Any]] = []
    if mode in ("schedules", "schedules+backlog"):
        try:
            from .schedule_templates import list_nix_schedules, list_user_schedules

            for s in list_user_schedules() + list_nix_schedules():
                if not getattr(s, "enable", True):
                    continue
                out.append(
                    {
                        "kind": "schedule",
                        "id": s.name,
                        "title": s.name,
                        "playbook": getattr(s, "playbook", None),
                        "goal": getattr(s, "goal", None),
                        "profile": getattr(s, "profile", None) or "read-only",
                        "dryRun": bool(getattr(s, "dryRun", True)),
                    }
                )
        except Exception:
            pass
    if mode == "schedules+backlog":
        try:
            from .agent_templates import list_agent_templates, list_instances

            idle_tmpl = {
                t.id
                for t in list_agent_templates()
                if "idle-ok" in (t.tags or []) or "maintenance" in (t.tags or [])
            }
            for inst in list_instances():
                if inst.template_id in idle_tmpl:
                    out.append(
                        {
                            "kind": "instance",
                            "id": inst.id,
                            "title": inst.title,
                            "template_id": inst.template_id,
                        }
                    )
        except Exception:
            pass
    return out


def maybe_sweep(*, start: bool = False) -> dict[str, Any]:
    """
    If idle-eligible, return (and optionally start) up to idle_max_jobs work items.
    Starts are best-effort; failures are recorded, not raised.
    """
    if not is_idle_eligible():
        return {
            "ok": True,
            "eligible": False,
            "idle_seconds": idle_seconds(),
            "started": [],
            "candidates": [],
        }
    from .capacity import CapacityError, release, try_acquire

    candidates = list_idle_candidates()
    limit = get_idle_max_jobs()
    started: list[dict[str, Any]] = []
    picked = candidates[:limit]
    if not start:
        return {
            "ok": True,
            "eligible": True,
            "idle_seconds": idle_seconds(),
            "started": [],
            "candidates": picked,
        }

    for c in picked:
        try:
            if c["kind"] == "instance":
                from .agent_templates import run_instance

                # run_instance acquires its own capacity slot.
                for _ev in run_instance(str(c["id"])):
                    pass
                started.append({**c, "status": "finished"})
            elif c["kind"] == "schedule":
                profile = str(c.get("profile") or "read-only")
                if profile in ("ops", "config-writer", "autonomous") and not c.get(
                    "idleAllowWrite"
                ):
                    started.append(
                        {
                            **c,
                            "status": "skipped",
                            "error": "write profile blocked without idleAllowWrite",
                        }
                    )
                    continue
                token = try_acquire(f"idle:schedule:{c.get('id')}")
                if token is None:
                    break
                try:
                    from .agent import run_agent
                    from .auth import with_cached_credentials
                    from .config import Settings

                    goal = c.get("goal")
                    playbook = c.get("playbook")
                    settings = with_cached_credentials(
                        Settings.from_env(client_mode="chat")
                    )
                    if playbook and not goal:
                        from .playbooks import get_playbook

                        pb = get_playbook(str(playbook))
                        goal = pb.goal if pb else None
                    if not goal:
                        started.append({**c, "status": "skipped", "error": "no goal"})
                        continue
                    for _ev in run_agent(
                        str(goal),
                        settings,
                        dry_run=bool(c.get("dryRun", True)),
                        profile=profile,
                        playbook=str(playbook) if playbook else None,
                    ):
                        pass
                    started.append({**c, "status": "finished"})
                finally:
                    release(token)
        except CapacityError:
            break
        except Exception as exc:  # noqa: BLE001
            started.append({**c, "status": "error", "error": str(exc)})

    return {
        "ok": True,
        "eligible": True,
        "idle_seconds": idle_seconds(),
        "started": started,
        "candidates": picked,
    }
