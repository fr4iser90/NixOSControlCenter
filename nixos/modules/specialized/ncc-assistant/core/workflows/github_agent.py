"""GitHub Agent orchestrator — fleet audit, tasks, drift, snapshot (deterministic).

Callers: ``cli.cli._cmd_github_agent`` (analyze), Companion PANEL_GITHUB Start/
analyze QThread worker, ``tests/ncc-assistant/test_github_agent_v1.py``.

Reuses only: ``list_workspaces``, ``fleet_lifecycle``, ``audit_workspace``,
``plan_from_audit``, ``portfolio_drift_report``, ``list_tasks`` / ``load_daily``,
``JobStore``, ``append_audit``. No second audit/lifecycle implementation.

Writes: ``github-agent/snapshot.json`` (0600), Daily tasks via plan_from_audit,
jobs/ + audit.jsonl. Repo writes stay gated by rights (allowWrite) — v1 analyze
is read+task-extract only.

User intent: Companion rail GitHub → Start agent → board of projects/gaps/next.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from core.catalogs.portfolio import portfolio_drift_report
from core.policy.audit import append_audit
from core.store.github_agent_snapshot import save_github_agent_snapshot
from core.store.jobs import JobEvent, get_job_store
from core.store.operator_facts import is_dach_country, load_operator_facts
from core.store.preferences import get_github_agent_include_archived
from core.store.workspaces import list_workspaces
from core.workflows.workspace_lifecycle import fleet_lifecycle
from core.workflows.workspace_workflow import (
    GAP_META,
    audit_workspace,
    next_open_task,
    plan_from_audit,
)
from core.workflows.workflows import list_tasks, load_daily, update_task

LEGAL_GAP_IDS = frozenset({"impressum", "privacy"})
WORKFLOW_ID = "github-agent"


def format_github_agent_chat_brief(snapshot: dict[str, Any] | None) -> str:
    """Compact fleet brief for Companion chat (before LLM narrates).

    Callers: ``_CompanionGithubAgentWorker.run`` in companion/window.py;
    ``tests/ncc-assistant/test_github_agent_v1.py``. No other chat-brief
    formatter exists (snapshot JSON alone is too large for the feed).
    Reads snapshot schema from ``save_github_agent_snapshot``; writes nothing.
    User: "korregiere das !??!!? es muss dann chat session öffnen und er muss arbeiten!?!?"
    """
    if not snapshot or not isinstance(snapshot, dict):
        return "GitHub Agent: no snapshot."
    projects = [p for p in (snapshot.get("projects") or []) if isinstance(p, dict)]
    facts = snapshot.get("operatorFacts") or {}
    lines = [
        f"GitHub Agent · {len(projects)} project(s) · job {snapshot.get('jobId') or '—'}",
        f"Operator: country={facts.get('country') or '?'} locale={facts.get('locale') or '?'}",
        "",
    ]
    for p in projects:
        wid = str(p.get("workspaceId") or "?")
        state = str(p.get("state") or "?")
        missing = [
            g
            for g in (p.get("gaps") or [])
            if isinstance(g, dict) and not g.get("present")
        ]
        gap_bits = [
            f"{g.get('id')}:{g.get('priority') or '?'}" for g in missing[:8]
        ]
        gap_s = ",".join(gap_bits) if gap_bits else "none"
        if len(missing) > 8:
            gap_s += f"+{len(missing) - 8}"
        nxt = p.get("nextTask") if isinstance(p.get("nextTask"), dict) else {}
        nxt_t = str(nxt.get("title") or "—")
        drift = ",".join(str(x) for x in (p.get("driftFlags") or [])[:4]) or "—"
        lines.append(
            f"- {wid} [{state}] gaps={gap_s} next={nxt_t} drift={drift}"
        )
    drift = snapshot.get("drift") if isinstance(snapshot.get("drift"), dict) else {}
    if drift.get("counts"):
        lines.append("")
        lines.append(f"Drift counts: {drift.get('counts')}")
    return "\n".join(lines)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _gap_priority(gap_id: str, *, dach: bool) -> str:
    if dach and gap_id in LEGAL_GAP_IDS:
        return "p0"
    meta = GAP_META.get(gap_id) or {}
    return str(meta.get("priority") or "p1")


def _elevate_legal_task_priorities(workspace_id: str, *, dach: bool) -> None:
    """After plan_from_audit, bump impressum/privacy tasks to p0 for DACH."""
    if not dach:
        return
    from core.workflows.workspace_workflow import find_task_for_gap

    for gid in LEGAL_GAP_IDS:
        task = find_task_for_gap(workspace_id, gid, include_done=False)
        if task is None:
            continue
        if str(task.get("priority") or "") != "p0":
            update_task(str(task["id"]), priority="p0")


def _drift_flags_for_workspace(
    wid: str, path: str, drift_report: dict[str, Any]
) -> list[str]:
    flags: list[str] = []
    try:
        resolved = str(Path(path).expanduser().resolve())
    except OSError:
        resolved = path
    for proj in drift_report.get("projects") or []:
        if not isinstance(proj, dict):
            continue
        ppath = str(proj.get("path") or "")
        rid = str(proj.get("registry_id") or "")
        try:
            same = str(Path(ppath).resolve()) == resolved
        except OSError:
            same = ppath == path
        if rid == wid or same:
            flags.extend(str(d) for d in (proj.get("drifts") or []) if d)
            break
    for missing in drift_report.get("registered_but_missing") or []:
        if isinstance(missing, dict) and str(missing.get("id") or "") == wid:
            flags.extend(str(d) for d in (missing.get("drifts") or []) if d)
    seen: set[str] = set()
    out: list[str] = []
    for f in flags:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return out


def _drift_summary(drift_report: dict[str, Any]) -> dict[str, Any]:
    if not drift_report.get("ok"):
        return {
            "ok": False,
            "error": drift_report.get("error"),
            "counts": {},
        }
    return {
        "ok": True,
        "root": drift_report.get("root"),
        "counts": dict(drift_report.get("counts") or {}),
        "summary": drift_report.get("summary"),
        "github": drift_report.get("github"),
    }


def run_github_agent(
    *,
    extract_tasks: bool = True,
    include_archived: bool | None = None,
) -> dict[str, Any]:
    """Run fleet GitHub Agent analyze; write snapshot + optional Daily tasks."""
    errors: list[str] = []
    facts = load_operator_facts()
    dach = is_dach_country(str(facts.get("country") or ""))
    if include_archived is None:
        include_archived = get_github_agent_include_archived()

    store = get_job_store()
    job = store.create(
        goal="GitHub Agent: fleet audit / lifecycle / drift / tasks",
        profile="read-only",
        dry_run=True,
        workflow=WORKFLOW_ID,
    )
    store.start(job.id)
    append_audit(
        "github_agent_start",
        actor="github-agent",
        job_id=job.id,
        args={
            "extract_tasks": extract_tasks,
            "include_archived": include_archived,
            "country": facts.get("country"),
        },
        result="ok",
    )
    store.append_event(
        job.id,
        JobEvent(kind="status", data={"phase": "start", "workflow": WORKFLOW_ID}),
    )

    try:
        fleet = fleet_lifecycle()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"fleet_lifecycle: {exc}")
        fleet = {"ok": False, "workspaces": [], "error": str(exc)}

    state_by_id: dict[str, str] = {}
    for row in fleet.get("workspaces") or []:
        if isinstance(row, dict):
            wid = str(row.get("workspace_id") or "")
            if wid:
                state_by_id[wid] = str(row.get("state") or "unknown")

    try:
        drift_report = portfolio_drift_report()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"portfolio_drift_report: {exc}")
        drift_report = {"ok": False, "error": str(exc), "projects": [], "counts": {}}

    projects: list[dict[str, Any]] = []
    for ws in list_workspaces():
        state = state_by_id.get(ws.id, "unknown")
        is_archive = state == "archive-candidate"
        try:
            report = audit_workspace(ws.id)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"audit:{ws.id}: {exc}")
            projects.append(
                {
                    "workspaceId": ws.id,
                    "path": ws.path,
                    "github": ws.github,
                    "state": state,
                    "gaps": [],
                    "nextTask": None,
                    "driftFlags": _drift_flags_for_workspace(
                        ws.id, ws.path, drift_report
                    ),
                    "error": str(exc),
                }
            )
            continue

        gaps: list[dict[str, Any]] = []
        for g in report.gaps:
            gaps.append(
                {
                    "id": g.id,
                    "present": g.present,
                    "detail": g.detail,
                    "priority": _gap_priority(g.id, dach=dach),
                }
            )

        planned = False
        if extract_tasks and (not is_archive or include_archived):
            try:
                plan_from_audit(ws.id)
                _elevate_legal_task_priorities(ws.id, dach=dach)
                planned = True
            except Exception as exc:  # noqa: BLE001
                errors.append(f"plan:{ws.id}: {exc}")

        nxt = None
        try:
            task = next_open_task(ws.id)
            if task is not None:
                nxt = {
                    "id": task.get("id"),
                    "title": task.get("title"),
                    "status": task.get("status"),
                    "priority": task.get("priority"),
                }
        except Exception as exc:  # noqa: BLE001
            errors.append(f"next:{ws.id}: {exc}")

        projects.append(
            {
                "workspaceId": ws.id,
                "path": report.path,
                "github": report.github or ws.github,
                "state": state,
                "gaps": gaps,
                "nextTask": nxt,
                "driftFlags": _drift_flags_for_workspace(ws.id, ws.path, drift_report),
                "planned": planned,
                "archiveSkippedPlan": bool(
                    is_archive and extract_tasks and not include_archived
                ),
            }
        )

    try:
        load_daily()
        _ = list_tasks()
    except Exception as exc:  # noqa: BLE001
        errors.append(f"daily: {exc}")

    snapshot = {
        "version": 1,
        "updatedAt": _now(),
        "operatorFacts": {
            "country": facts.get("country"),
            "locale": facts.get("locale"),
            "notes": facts.get("notes") or "",
        },
        "projects": projects,
        "drift": _drift_summary(drift_report),
        "jobId": job.id,
    }
    try:
        save_github_agent_snapshot(snapshot)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"snapshot: {exc}")

    ok = len(errors) == 0 and bool(fleet.get("ok", True))
    with_gaps = sum(
        1
        for p in projects
        if any(not g.get("present") for g in (p.get("gaps") or []))
    )
    summary = (
        f"GitHub Agent: {len(projects)} project(s), "
        f"{with_gaps} with gaps, errors={len(errors)}"
    )
    store.finalize(
        job.id,
        success=ok,
        summary=summary,
        output={"projectCount": len(projects), "errors": errors},
        error="; ".join(errors) if errors else None,
    )
    append_audit(
        "github_agent_finish",
        actor="github-agent",
        job_id=job.id,
        args={"projectCount": len(projects), "errorCount": len(errors)},
        result="ok" if ok else "error",
        detail=summary,
    )
    store.append_event(
        job.id,
        JobEvent(
            kind="status",
            data={"phase": "finish", "ok": ok, "errors": errors},
        ),
    )

    return {
        "ok": ok,
        "snapshot": snapshot,
        "job_id": job.id,
        "errors": errors,
    }
