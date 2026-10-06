"""Daily workflows store: GitHub digest + local tasks / roadmap."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import uuid
from datetime import datetime, timezone
from typing import Any

from .paths import workflows_daily_file, workflows_dir
from .preferences import get_active_workspace_id, get_workflow_providers

TASK_STATUSES = ("todo", "doing", "done")
TASK_PRIORITIES = ("p0", "p1", "p2")
ROADMAP_HORIZONS = ("now", "next", "later")
CHECK_STATES = ("pending", "pass", "fail", "unknown")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _empty_digest(workspace_id: str | None = None) -> dict[str, Any]:
    return {
        "version": 1,
        "updatedAt": _now(),
        "workspaceId": workspace_id or get_active_workspace_id() or "",
        "issues": [],
        "pullRequests": [],
        "tasks": [],
        "roadmap": [],
    }


def load_daily() -> dict[str, Any]:
    path = workflows_daily_file()
    if not path.is_file():
        return _empty_digest()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return _empty_digest()
    if not isinstance(data, dict):
        return _empty_digest()
    base = _empty_digest(str(data.get("workspaceId") or ""))
    for key in ("issues", "pullRequests", "tasks", "roadmap"):
        val = data.get(key)
        if isinstance(val, list):
            base[key] = [x for x in val if isinstance(x, dict)]
    base["updatedAt"] = str(data.get("updatedAt") or base["updatedAt"])
    base["version"] = int(data.get("version") or 1)
    return base


def save_daily(data: dict[str, Any]) -> None:
    workflows_dir()
    path = workflows_daily_file()
    payload = dict(data)
    payload["version"] = 1
    payload["updatedAt"] = _now()
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def list_tasks() -> list[dict[str, Any]]:
    return list(load_daily().get("tasks") or [])


def list_roadmap() -> list[dict[str, Any]]:
    return list(load_daily().get("roadmap") or [])


def add_task(
    title: str,
    *,
    body: str = "",
    status: str = "todo",
    priority: str = "p1",
    workspace_id: str | None = None,
    links: list[str] | None = None,
) -> dict[str, Any]:
    st = status if status in TASK_STATUSES else "todo"
    pr = priority if priority in TASK_PRIORITIES else "p1"
    task = {
        "id": uuid.uuid4().hex[:10],
        "title": str(title).strip()[:200],
        "body": str(body or "")[:4000],
        "status": st,
        "priority": pr,
        "workspaceId": workspace_id or get_active_workspace_id() or "",
        "links": [str(x) for x in (links or [])][:20],
        "createdAt": _now(),
    }
    data = load_daily()
    data["tasks"] = list(data.get("tasks") or []) + [task]
    save_daily(data)
    return task


def update_task(task_id: str, **fields: Any) -> dict[str, Any] | None:
    data = load_daily()
    tasks = list(data.get("tasks") or [])
    for i, t in enumerate(tasks):
        if str(t.get("id")) != str(task_id):
            continue
        if "title" in fields and fields["title"] is not None:
            t["title"] = str(fields["title"]).strip()[:200]
        if "body" in fields and fields["body"] is not None:
            t["body"] = str(fields["body"])[:4000]
        if "status" in fields and fields["status"] in TASK_STATUSES:
            t["status"] = fields["status"]
        if "priority" in fields and fields["priority"] in TASK_PRIORITIES:
            t["priority"] = fields["priority"]
        if "links" in fields and isinstance(fields["links"], list):
            t["links"] = [str(x) for x in fields["links"]][:20]
        if "workspaceId" in fields and fields["workspaceId"] is not None:
            t["workspaceId"] = str(fields["workspaceId"])
        tasks[i] = t
        data["tasks"] = tasks
        save_daily(data)
        return t
    return None


def append_task_link(task_id: str, link: str) -> dict[str, Any] | None:
    task = next((t for t in list_tasks() if str(t.get("id")) == str(task_id)), None)
    if task is None:
        return None
    links = [str(x) for x in (task.get("links") or [])]
    s = str(link).strip()
    if s and s not in links:
        links.append(s)
    return update_task(task_id, links=links)


def complete_task(task_id: str) -> dict[str, Any] | None:
    return update_task(task_id, status="done")


def get_task(task_id: str) -> dict[str, Any] | None:
    return next((t for t in list_tasks() if str(t.get("id")) == str(task_id)), None)


def add_roadmap_item(
    title: str,
    *,
    horizon: str = "now",
    parent_id: str | None = None,
    task_ids: list[str] | None = None,
) -> dict[str, Any]:
    hz = horizon if horizon in ROADMAP_HORIZONS else "now"
    item = {
        "id": uuid.uuid4().hex[:10],
        "title": str(title).strip()[:200],
        "horizon": hz,
        "parentId": parent_id,
        "taskIds": [str(x) for x in (task_ids or [])][:40],
    }
    data = load_daily()
    data["roadmap"] = list(data.get("roadmap") or []) + [item]
    save_daily(data)
    return item


def update_roadmap_item(item_id: str, **fields: Any) -> dict[str, Any] | None:
    data = load_daily()
    items = list(data.get("roadmap") or [])
    for i, it in enumerate(items):
        if str(it.get("id")) != str(item_id):
            continue
        if "title" in fields and fields["title"] is not None:
            it["title"] = str(fields["title"]).strip()[:200]
        if "horizon" in fields and fields["horizon"] in ROADMAP_HORIZONS:
            it["horizon"] = fields["horizon"]
        if "taskIds" in fields and isinstance(fields["taskIds"], list):
            it["taskIds"] = [str(x) for x in fields["taskIds"]][:40]
        items[i] = it
        data["roadmap"] = items
        save_daily(data)
        return it
    return None


def _gh_json(args: list[str], *, cwd: str | None = None) -> Any | None:
    if not shutil.which("gh"):
        return None
    try:
        proc = subprocess.run(
            ["gh", *args],
            capture_output=True,
            text=True,
            timeout=45,
            cwd=cwd,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None


def _workspace_cwd(workspace_id: str | None) -> str | None:
    wid = workspace_id or get_active_workspace_id()
    if not wid:
        return None
    try:
        from .workspaces import get_workspace

        ws = get_workspace(wid)
        if ws and getattr(ws, "path", None):
            return str(ws.path)
    except Exception:
        pass
    return None


def refresh_github_digest(*, workspace_id: str | None = None) -> dict[str, Any]:
    """Pull Issues/PRs via gh into daily.json (keeps local tasks/roadmap)."""
    data = load_daily()
    wid = workspace_id or get_active_workspace_id() or data.get("workspaceId") or ""
    data["workspaceId"] = wid
    if not str(wid).strip():
        save_daily(data)
        return {
            **data,
            "ok": False,
            "error": "no_active_workspace",
            "hint": "Set an active workspace (★) before refreshing Daily.",
        }
    providers = get_workflow_providers()
    if "github" not in providers:
        save_daily(data)
        return {
            **data,
            "ok": False,
            "error": "github_provider_disabled",
            "hint": "Enable GitHub as workflow provider in Daily brief settings.",
        }

    cwd = _workspace_cwd(str(wid) if wid else None)
    if not cwd:
        save_daily(data)
        return {
            **data,
            "ok": False,
            "error": "workspace_path_missing",
            "hint": f"Workspace {wid!r} has no path — re-add it under Workspaces.",
        }
    issues_raw = _gh_json(
        [
            "issue",
            "list",
            "--state",
            "open",
            "--limit",
            "30",
            "--json",
            "number,title,url,labels,state",
        ],
        cwd=cwd,
    )
    prs_raw = _gh_json(
        [
            "pr",
            "list",
            "--state",
            "open",
            "--limit",
            "30",
            "--json",
            "number,title,url,isDraft,statusCheckRollup",
        ],
        cwd=cwd,
    )
    if issues_raw is None and prs_raw is None:
        save_daily(data)
        return {
            **data,
            "ok": False,
            "error": "gh_failed",
            "hint": (
                "gh could not list issues/PRs (auth? remote? wrong folder?). "
                "Fix GitHub login, then Refresh again."
            ),
            "path": cwd,
        }

    issues: list[dict[str, Any]] = []
    if isinstance(issues_raw, list):
        for it in issues_raw:
            if not isinstance(it, dict):
                continue
            labels = it.get("labels") or []
            label_names = [
                str(x.get("name") if isinstance(x, dict) else x)
                for x in labels
            ]
            issues.append(
                {
                    "id": str(it.get("number") or ""),
                    "title": str(it.get("title") or ""),
                    "url": str(it.get("url") or ""),
                    "labels": label_names,
                    "state": str(it.get("state") or "open").lower(),
                }
            )

    pull_requests: list[dict[str, Any]] = []
    if isinstance(prs_raw, list):
        for pr in prs_raw:
            if not isinstance(pr, dict):
                continue
            checks = "unknown"
            rollup = pr.get("statusCheckRollup")
            if isinstance(rollup, list) and rollup:
                states = [
                    str(x.get("state") or x.get("conclusion") or "").upper()
                    for x in rollup
                    if isinstance(x, dict)
                ]
                if any(s in ("FAILURE", "ERROR", "FAIL") for s in states):
                    checks = "fail"
                elif all(
                    s in ("SUCCESS", "NEUTRAL", "SKIPPED", "") for s in states
                ) and states:
                    checks = "pass"
                else:
                    checks = "pending"
            elif rollup is None:
                checks = "pending"
            pull_requests.append(
                {
                    "id": str(pr.get("number") or ""),
                    "title": str(pr.get("title") or ""),
                    "url": str(pr.get("url") or ""),
                    "draft": bool(pr.get("isDraft")),
                    "checks": checks if checks in CHECK_STATES else "unknown",
                }
            )

    data["issues"] = issues
    data["pullRequests"] = pull_requests
    save_daily(data)
    return {
        **data,
        "ok": True,
        "error": None,
        "path": cwd,
        "issue_count": len(issues),
        "pr_count": len(pull_requests),
    }


def daily_summary_lines(limit: int = 12) -> list[str]:
    """Compact lines for Companion Daily panel."""
    data = load_daily()
    lines: list[str] = []
    for pr in (data.get("pullRequests") or [])[:6]:
        mark = {"fail": "✗", "pass": "✓", "pending": "…", "unknown": "?"}.get(
            str(pr.get("checks")), "?"
        )
        draft = " (draft)" if pr.get("draft") else ""
        lines.append(f"PR#{pr.get('id')} {mark}{draft} {pr.get('title')}")
    for issue in (data.get("issues") or [])[:4]:
        lines.append(f"Issue#{issue.get('id')} {issue.get('title')}")
    open_tasks = [
        t
        for t in (data.get("tasks") or [])
        if str(t.get("status")) in ("todo", "doing")
    ]
    open_tasks.sort(key=lambda t: str(t.get("priority") or "p2"))
    for t in open_tasks[:4]:
        lines.append(f"Task[{t.get('priority')}] {t.get('title')}")
    for r in (data.get("roadmap") or [])[:3]:
        if str(r.get("horizon")) == "now":
            lines.append(f"Roadmap·now {r.get('title')}")
    if not lines:
        lines.append("(empty — Refresh daily digest)")
    return lines[:limit]
