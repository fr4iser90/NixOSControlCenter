"""GitHub Agent campaign: arm / tick / pause / resume (multi-day autonomy).

Callers: ``cli.cli._cmd_github_agent`` (arm|tick|status|pause|resume|act),
Companion ``window.py`` PANEL_GITHUB Act/Pause handlers,
``core.scheduling.idle.maybe_sweep`` → ``idle_autopilot_step``,
``tests/ncc-assistant/test_github_agent_autonomy_v1.py``.

No existing fleet wave runner (JobStore does not resume; workflow_progress is
per-workspace). Reads/writes ``github-agent/campaign.json``; applies stubs via
policy gate; updates Daily tasks.

User: "kk den kompletten plan machen und dann implemen tieren , das der agent
dann auch autonmm mehre tage läuft , falls disconnected ausgeht er wieder
angeht vllt sogar da weitermacht etc"
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from core.policy.audit import append_audit
from core.store.github_agent_campaign import (
    empty_campaign,
    load_github_agent_campaign,
    save_github_agent_campaign,
)
from core.store.github_agent_snapshot import load_github_agent_snapshot
from core.store.preferences import (
    get_github_agent_analyze_stale_hours,
    get_github_agent_autopilot,
    get_github_agent_max_per_tick,
)
from core.store.workspaces import get_workspace
from core.workflows.github_agent_policy import (
    DOCS_GAPS,
    evaluate_write,
    is_worktree_dirty,
)
from core.workflows.github_agent_stubs import apply_gap_stub
from core.workflows.workflows import list_tasks, update_task
from core.workflows.workspace_workflow import find_task_for_gap

_PRIO = {"p0": 0, "p1": 1, "p2": 2}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def campaign_status() -> dict[str, Any]:
    camp = load_github_agent_campaign()
    return {
        "ok": True,
        "campaign": camp,
        "autopilot": get_github_agent_autopilot(),
        "queueLen": len(camp.get("queue") or []),
        "status": camp.get("status"),
    }


def pause_campaign() -> dict[str, Any]:
    camp = load_github_agent_campaign()
    if camp.get("status") == "running":
        camp["status"] = "paused"
        save_github_agent_campaign(camp)
        append_audit("github_agent_campaign_pause", actor="github-agent", result="ok")
    return campaign_status()


def resume_campaign() -> dict[str, Any]:
    camp = load_github_agent_campaign()
    if camp.get("status") == "paused" and (camp.get("queue") or []):
        camp["status"] = "running"
        save_github_agent_campaign(camp)
        append_audit("github_agent_campaign_resume", actor="github-agent", result="ok")
    elif camp.get("status") == "paused" and not (camp.get("queue") or []):
        camp["status"] = "done"
        save_github_agent_campaign(camp)
    return campaign_status()


def _build_queue(
    snapshot: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Prefer clean worktrees, then priority, then workspace id."""
    queue: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    projects = [p for p in (snapshot.get("projects") or []) if isinstance(p, dict)]
    rows: list[tuple[int, int, str, dict[str, Any]]] = []
    for p in projects:
        wid = str(p.get("workspaceId") or "")
        state = str(p.get("state") or "")
        path = str(p.get("path") or "")
        root = Path(path).expanduser() if path else None
        if state.startswith("archive"):
            continue
        if root is None or not root.is_dir():
            skipped.append(
                {
                    "workspaceId": wid,
                    "gapId": "*",
                    "reason": "path_missing",
                    "at": _now(),
                }
            )
            continue
        dirty = 1 if is_worktree_dirty(root) else 0
        for g in p.get("gaps") or []:
            if not isinstance(g, dict) or g.get("present"):
                continue
            gid = str(g.get("id") or "")
            if gid not in DOCS_GAPS:
                continue
            prio = str(g.get("priority") or "p1")
            item = {
                "workspaceId": wid,
                "gapId": gid,
                "priority": prio,
                "writeClass": "docs",
                "path": str(root),
                "state": state,
            }
            rows.append((_PRIO.get(prio, 9), dirty, wid, item))
    rows.sort(key=lambda r: (r[1], r[0], r[2], r[3]["gapId"]))
    for _pr, _d, _w, item in rows:
        queue.append(item)
    return queue, skipped


def arm_campaign(*, snapshot: dict[str, Any] | None = None) -> dict[str, Any]:
    """Build / replace campaign queue from snapshot; set status=running."""
    snap = snapshot if isinstance(snapshot, dict) else load_github_agent_snapshot()
    if not snap:
        return {"ok": False, "error": "no_snapshot", "hint": "run analyze first"}
    queue, skipped = _build_queue(snap)
    camp = empty_campaign()
    camp["status"] = "running" if queue else "done"
    camp["mode"] = "act-safe"
    camp["startedAt"] = _now()
    camp["sourceJobId"] = str(snap.get("jobId") or "")
    camp["queue"] = queue
    camp["skipped"] = skipped
    camp["stats"] = {
        "applied": 0,
        "skipped": len(skipped),
        "errors": 0,
        "ticks": 0,
    }
    save_github_agent_campaign(camp)
    append_audit(
        "github_agent_campaign_arm",
        actor="github-agent",
        args={"queue": len(queue), "skipped": len(skipped)},
        result="ok",
    )
    return {"ok": True, "campaign": camp, "queued": len(queue), "skipped": len(skipped)}


def _complete_gap_task(workspace_id: str, gap_id: str) -> None:
    try:
        task = find_task_for_gap(workspace_id, gap_id, include_done=False)
        if task and task.get("id"):
            update_task(str(task["id"]), status="done")
            return
        for t in list_tasks():
            if str(t.get("workspaceId") or "") != workspace_id:
                continue
            links = [str(x) for x in (t.get("links") or [])]
            if f"gap:{gap_id}" in links and str(t.get("status") or "") != "done":
                update_task(str(t["id"]), status="done")
                return
    except Exception:
        pass


def apply_item(item: dict[str, Any], *, unattended: bool = True) -> dict[str, Any]:
    wid = str(item.get("workspaceId") or "")
    gid = str(item.get("gapId") or "")
    path = str(item.get("path") or "")
    state = str(item.get("state") or "")
    root = Path(path).expanduser() if path else None
    if root is None:
        ws = get_workspace(wid)
        root = Path(ws.path).expanduser() if ws else None
    verdict = evaluate_write(
        workspace_id=wid,
        gap_id=gid,
        root=root,
        state=state,
        unattended=unattended,
    )
    if not verdict.get("ok"):
        return {
            "ok": False,
            "skipped": True,
            "workspaceId": wid,
            "gapId": gid,
            "reason": verdict.get("reason"),
        }
    assert root is not None
    result = apply_gap_stub(root, gid, workspace_id=wid)
    if not result.get("ok"):
        return {
            "ok": False,
            "skipped": False,
            "workspaceId": wid,
            "gapId": gid,
            "reason": result.get("reason") or "stub_failed",
        }
    _complete_gap_task(wid, gid)
    append_audit(
        "github_agent_stub_apply",
        actor="github-agent",
        args={"workspaceId": wid, "gapId": gid, "path": result.get("path")},
        result="ok",
    )
    return {
        "ok": True,
        "skipped": False,
        "workspaceId": wid,
        "gapId": gid,
        "path": result.get("path"),
        "created": result.get("created"),
        "reason": result.get("reason"),
    }


def tick_campaign(
    *,
    max_items: int | None = None,
    unattended: bool = True,
) -> dict[str, Any]:
    """Apply up to N queue items; persist after each (resume-safe)."""
    camp = load_github_agent_campaign()
    if camp.get("status") == "paused":
        return {"ok": True, "paused": True, "campaign": camp, "applied": []}
    if camp.get("status") not in ("running", "idle", "done"):
        camp["status"] = "running"
    if not (camp.get("queue") or []):
        camp["status"] = "done"
        save_github_agent_campaign(camp)
        return {"ok": True, "done": True, "campaign": camp, "applied": []}

    limit = max_items if max_items is not None else get_github_agent_max_per_tick()
    limit = max(1, min(int(limit), 20))
    applied: list[dict[str, Any]] = []
    aborted = False

    while limit > 0 and (camp.get("queue") or []):
        item = camp["queue"].pop(0)
        camp["cursor"] = {
            "workspaceId": item.get("workspaceId"),
            "gapId": item.get("gapId"),
        }
        save_github_agent_campaign(camp)
        outcome = apply_item(item, unattended=unattended)
        if outcome.get("ok"):
            camp["done"].append({**item, "at": _now(), "path": outcome.get("path")})
            camp["stats"]["applied"] = int(camp["stats"].get("applied") or 0) + 1
            applied.append(outcome)
            limit -= 1
        elif outcome.get("skipped"):
            reason = str(outcome.get("reason") or "skipped")
            camp["skipped"].append({**item, "reason": reason, "at": _now()})
            camp["stats"]["skipped"] = int(camp["stats"].get("skipped") or 0) + 1
            if reason == "dirty_abort":
                camp["status"] = "paused"
                aborted = True
                save_github_agent_campaign(camp)
                break
            if reason in (
                "dirty_skip",
                "denylist",
                "not_in_allowlist",
                "archive",
                "path_missing",
                "unsupported_gap",
                "allowWrite_false",
                "confirm_always",
                "write_class_blocked",
            ):
                continue
            limit -= 1
        else:
            camp["errors"].append(
                {**item, "reason": outcome.get("reason"), "at": _now()}
            )
            camp["stats"]["errors"] = int(camp["stats"].get("errors") or 0) + 1
            limit -= 1
        camp["status"] = "running"
        save_github_agent_campaign(camp)

    camp["lastTickAt"] = _now()
    camp["stats"]["ticks"] = int(camp["stats"].get("ticks") or 0) + 1
    camp["cursor"] = None
    if not (camp.get("queue") or []) and not aborted:
        camp["status"] = "done"
    elif not aborted:
        camp["status"] = "running"
    save_github_agent_campaign(camp)
    append_audit(
        "github_agent_campaign_tick",
        actor="github-agent",
        args={"applied": len(applied), "queueLeft": len(camp.get("queue") or [])},
        result="ok",
    )
    return {
        "ok": True,
        "applied": applied,
        "campaign": camp,
        "aborted": aborted,
        "done": camp.get("status") == "done",
    }


def act_campaign(
    *, analyze_first: bool = False, unattended: bool = False
) -> dict[str, Any]:
    """Arm from snapshot (optional analyze) then one tick — Companion Act."""
    if analyze_first:
        from core.workflows.github_agent import run_github_agent

        run_github_agent(extract_tasks=True)
    armed = arm_campaign()
    if not armed.get("ok"):
        return armed
    tick = tick_campaign(unattended=unattended)
    return {"ok": True, "arm": armed, "tick": tick}


def snapshot_is_stale() -> bool:
    snap = load_github_agent_snapshot()
    if not snap:
        return True
    raw = str(snap.get("updatedAt") or "")
    if not raw:
        return True
    try:
        ts = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return True
    age_h = (
        datetime.now(timezone.utc) - ts.astimezone(timezone.utc)
    ).total_seconds() / 3600.0
    return age_h >= float(get_github_agent_analyze_stale_hours())


def idle_autopilot_step() -> dict[str, Any]:
    """One idle step: stale analyze and/or campaign tick (act-safe)."""
    mode = get_github_agent_autopilot()
    if mode == "off":
        return {"ok": True, "skipped": True, "reason": "autopilot_off"}
    out: dict[str, Any] = {"ok": True, "mode": mode, "actions": []}
    if mode in ("analyze", "act-safe") and snapshot_is_stale():
        from core.workflows.github_agent import run_github_agent

        result = run_github_agent(extract_tasks=True)
        out["actions"].append({"kind": "analyze", "jobId": result.get("job_id")})
        if mode == "act-safe":
            arm_campaign(snapshot=result.get("snapshot"))
    if mode == "act-safe":
        camp = load_github_agent_campaign()
        if camp.get("status") == "idle" and not (camp.get("queue") or []):
            arm_campaign()
        if load_github_agent_campaign().get("status") == "running":
            tick = tick_campaign(unattended=True)
            out["actions"].append(
                {
                    "kind": "tick",
                    "applied": len(tick.get("applied") or []),
                    "done": tick.get("done"),
                }
            )
    return out
