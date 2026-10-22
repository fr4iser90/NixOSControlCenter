"""Idle-mode activity tracking and sweep (schedules / idle-ok templates)."""

from __future__ import annotations

import json
import os
import time
from contextlib import contextmanager
from typing import Any, Iterator

from .chain_guard import ENV_CHAIN_AFTER, ENV_CHAIN_SCHEDULE
from .paths import activity_file
from .permissions import (
    ENV_ACTOR,
    ENV_REPO,
    ENV_SYSTEM,
    Grant,
    lowest_grant_today,
)
from .poll_guard import ENV_POLL_SCHEDULE, ENV_POLL_WATCH
from .preferences import (
    get_idle_after_min,
    get_idle_max_jobs,
    get_idle_mode,
)

#: The env ``set_process_grant`` writes for one run; a sweep in a long-lived process owns
#: them only for the duration of the run it started.
_GRANT_ENV = (ENV_REPO, ENV_SYSTEM, ENV_ACTOR)
#: A poll schedule's watch is part of its identity: set it for the run it belongs to, clear
#: it for every other candidate, or the sweep would answer "unchanged" about the wrong tree.
_POLL_ENV = (ENV_POLL_SCHEDULE, ENV_POLL_WATCH)
#: An idle sweep is its own actor: idle runs must not spend a human's or a schedule's budget.
IDLE_ACTOR = "idle"


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
                        "trigger": getattr(s, "trigger", "calendar") or "calendar",
                        "pollWatch": list(getattr(s, "pollWatch", []) or []),
                        "chainAfter": getattr(s, "after", None),
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


def _grant_pairs(grant: Grant) -> tuple[str, str]:
    return (f"repo={grant.repo}", f"system={grant.system}")


@contextmanager
def _run_scoped_poll(candidate: dict[str, Any]) -> Iterator[None]:
    """Give one candidate its own poll identity — or take it away.

    A timer unit carries ``NCC_ASSISTANT_POLL_*`` for the whole process because it is a
    one-shot unit for exactly one schedule. A sweep is the opposite: one process, several
    candidates back to back. Without this, a poll schedule picked up while the operator is
    away would run ungated — burning the model on an unchanged tree, which is the whole cost
    the trigger exists to refuse — and the calendar schedules after it would inherit its env.
    """
    saved = {name: os.environ.get(name) for name in _POLL_ENV}
    try:
        if str(candidate.get("trigger") or "calendar") == "poll":
            os.environ[ENV_POLL_SCHEDULE] = str(candidate.get("id") or "")
            os.environ[ENV_POLL_WATCH] = ",".join(str(e) for e in (candidate.get("pollWatch") or []))
        else:
            for name in _POLL_ENV:
                os.environ.pop(name, None)
        yield
    finally:
        for name, value in saved.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


_CHAIN_ENV = (ENV_CHAIN_SCHEDULE, ENV_CHAIN_AFTER)


@contextmanager
def _run_scoped_chain(candidate: dict[str, Any]) -> Iterator[None]:
    """Give one candidate its own chain identity — or take it away.

    Same reason as the poll identity, opposite risk: a chained schedule left in a companion's
    environment would make every later run wait on a schedule the operator never asked about,
    and a chained schedule swept *without* it would run with the gate off — the one path where
    "ship after audit" could be skipped by picking the idle moment.
    """
    saved = {name: os.environ.get(name) for name in _CHAIN_ENV}
    try:
        after = str(candidate.get("chainAfter") or "").strip()
        if after:
            os.environ[ENV_CHAIN_SCHEDULE] = str(candidate.get("id") or "")
            os.environ[ENV_CHAIN_AFTER] = after
        else:
            for name in _CHAIN_ENV:
                os.environ.pop(name, None)
        yield
    finally:
        for name, value in saved.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


@contextmanager
def _run_scoped_grant() -> Iterator[None]:
    """Hold one sweep's grant env for exactly as long as the run it started.

    ``set_process_grant`` writes the grant into ``os.environ`` so the run's child git
    helpers inherit it — right for a one-shot unit, wrong for the companion, which keeps
    living after the sweep. An unattended ``repo=observe system=none`` left in the process
    would bind the operator's next chat: the ladder would treat a human as a schedule.
    """
    saved = {name: os.environ.get(name) for name in _GRANT_ENV}
    os.environ[ENV_ACTOR] = IDLE_ACTOR
    try:
        yield
    finally:
        for name, value in saved.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


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

    #: What an unattended run may hold, read off the day once so a sweep cannot walk its own
    #: floor down as its runs get logged. Computed on the first schedule candidate: an
    #: instance-only sweep has no grant to inherit and must not read the whole audit log.
    day_floor: Grant | None = None

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
                    # Nobody is here to approve a wider step, so the sweep inherits the
                    # narrowest grant this host already carried today instead of the
                    # schedule's own — an idle ship cannot outrank the morning's audit.
                    if day_floor is None:
                        day_floor = lowest_grant_today()
                    grant = _grant_pairs(day_floor)
                    # A sweep that swallows every event would report an unchanged poll as
                    # "finished": the operator would read work done where none happened.
                    skipped: dict[str, Any] = {}
                    with _run_scoped_grant(), _run_scoped_poll(c), _run_scoped_chain(c):
                        for ev in run_agent(
                            str(goal),
                            settings,
                            dry_run=bool(c.get("dryRun", True)),
                            profile=profile,
                            playbook=str(playbook) if playbook else None,
                            grant=grant,
                        ):
                            if isinstance(ev, dict) and ev.get("kind") == "skipped" and not skipped:
                                skipped = {
                                    "reason": str(ev.get("reason") or ""),
                                    "detail": str(ev.get("text") or ""),
                                }
                    if skipped:
                        started.append({**c, "status": "skipped", **skipped})
                    else:
                        started.append({**c, "status": "finished", "grant": list(grant)})
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
