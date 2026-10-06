"""Workspace lifecycle: active / once / later / archive-candidate (deterministic)."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .preferences import get_active_workspace_id
from .workspace_workflow import open_tasks_ordered, resolve_workspace_id
from .workspaces import get_workspace, list_workspaces

# Classification thresholds (days)
DEFAULT_ACTIVE_DAYS = 14
DEFAULT_ONCE_DAYS = 90
DEFAULT_ARCHIVE_DAYS = 180

LIFECYCLE_STATES = (
    "active",
    "once",
    "later",
    "archive-candidate",
    "unknown",
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _git(root: Path, *args: str, timeout: float = 30.0) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "stdout": "", "stderr": str(exc), "returncode": -1}
    return {
        "ok": proc.returncode == 0,
        "stdout": (proc.stdout or "").strip(),
        "stderr": (proc.stderr or "").strip(),
        "returncode": proc.returncode,
    }


def _parse_unix(ts: str) -> datetime | None:
    try:
        return datetime.fromtimestamp(int(ts), tz=timezone.utc)
    except (TypeError, ValueError, OSError):
        return None


def _days_ago(when: datetime | None) -> int | None:
    if when is None:
        return None
    return max(0, int((_now() - when).total_seconds() // 86400))


def _gh_open_pr_count(root: Path) -> int | None:
    import shutil

    if not shutil.which("gh"):
        return None
    try:
        proc = subprocess.run(
            ["gh", "pr", "list", "--state", "open", "--json", "number", "--limit", "20"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        return None
    return len(data) if isinstance(data, list) else None


def probe_git_activity(root: Path) -> dict[str, Any]:
    """Collect last commit age, dirty, branch count, optional open PRs."""
    out: dict[str, Any] = {
        "is_git": (root / ".git").exists(),
        "dirty": False,
        "last_commit_at": None,
        "last_commit_days": None,
        "last_commit_subject": None,
        "branch_count": 0,
        "stale_local_branches": 0,
        "open_prs": None,
        "default_hint": None,
    }
    if not out["is_git"]:
        return out
    dirty = _git(root, "status", "--porcelain")
    out["dirty"] = bool(dirty.get("stdout"))
    log = _git(root, "log", "-1", "--format=%ct%n%s")
    if log.get("ok") and log.get("stdout"):
        lines = log["stdout"].splitlines()
        when = _parse_unix(lines[0]) if lines else None
        out["last_commit_at"] = when.isoformat() if when else None
        out["last_commit_days"] = _days_ago(when)
        out["last_commit_subject"] = lines[1] if len(lines) > 1 else None
    branches = _git(root, "for-each-ref", "--format=%(refname:short)|%(committerdate:unix)", "refs/heads/")
    stale = 0
    count = 0
    if branches.get("ok") and branches.get("stdout"):
        for line in branches["stdout"].splitlines():
            if "|" not in line:
                continue
            count += 1
            _, ts = line.rsplit("|", 1)
            days = _days_ago(_parse_unix(ts))
            if days is not None and days >= DEFAULT_ONCE_DAYS:
                stale += 1
    out["branch_count"] = count
    out["stale_local_branches"] = stale
    out["open_prs"] = _gh_open_pr_count(root)
    return out


def classify_lifecycle(
    *,
    git: dict[str, Any],
    open_tasks: list[dict[str, Any]],
    active_days: int = DEFAULT_ACTIVE_DAYS,
    once_days: int = DEFAULT_ONCE_DAYS,
    archive_days: int = DEFAULT_ARCHIVE_DAYS,
) -> tuple[str, list[str]]:
    """
    Return (state, reasons).

    - active: recent commits, dirty tree, doing tasks, or open PRs
    - later: open todo tasks but quiet git (parked backlog)
    - once: quiet, no open work — looks like a finished one-shot
    - archive-candidate: very old + no open work
    """
    reasons: list[str] = []
    days = git.get("last_commit_days")
    doing = [t for t in open_tasks if str(t.get("status")) == "doing"]
    todos = [t for t in open_tasks if str(t.get("status")) == "todo"]
    open_prs = git.get("open_prs")

    if not git.get("is_git"):
        return "unknown", ["not a git repo"]

    if git.get("dirty"):
        reasons.append("dirty worktree")
    if doing:
        reasons.append(f"{len(doing)} task(s) in doing")
    if open_prs:
        reasons.append(f"{open_prs} open PR(s)")
    if days is not None and days <= active_days:
        reasons.append(f"commit {days}d ago (≤{active_days}d)")

    if reasons and (
        git.get("dirty")
        or doing
        or (open_prs or 0) > 0
        or (days is not None and days <= active_days)
    ):
        return "active", reasons

    if todos:
        reasons.append(f"{len(todos)} open todo task(s)")
        if days is None or days > active_days:
            reasons.append("git quiet — backlog for later")
        return "later", reasons

    if days is not None and days >= archive_days:
        reasons.append(f"last commit {days}d ago (≥{archive_days}d)")
        if git.get("stale_local_branches"):
            reasons.append(f"{git['stale_local_branches']} stale local branch(es)")
        return "archive-candidate", reasons

    if days is not None and days >= once_days:
        reasons.append(f"last commit {days}d ago (≥{once_days}d, <{archive_days}d)")
        reasons.append("no open tasks/PRs — likely one-shot / finished")
        return "once", reasons

    if days is not None:
        reasons.append(f"last commit {days}d ago — idle but not archive yet")
        return "once", reasons

    return "unknown", ["no commit history"]


def lifecycle_report(
    workspace_id: str | None = None,
    *,
    active_days: int = DEFAULT_ACTIVE_DAYS,
    once_days: int = DEFAULT_ONCE_DAYS,
    archive_days: int = DEFAULT_ARCHIVE_DAYS,
) -> dict[str, Any]:
    wid = resolve_workspace_id(workspace_id)
    ws = get_workspace(wid)
    assert ws is not None
    root = Path(ws.path).expanduser().resolve()
    git = probe_git_activity(root) if root.is_dir() else {"is_git": False}
    tasks = open_tasks_ordered(wid, priorities=("p0", "p1", "p2"))
    state, reasons = classify_lifecycle(
        git=git,
        open_tasks=tasks,
        active_days=active_days,
        once_days=once_days,
        archive_days=archive_days,
    )
    suggestions: list[str] = []
    if state == "active":
        suggestions.append("Continue with workflow resume / task-start.")
        suggestions.append("Template: autonomous-agent-run (maxTasks=1–2).")
    elif state == "later":
        suggestions.append("Parked backlog — reopen when ready: workflow next.")
        suggestions.append("Or schedule idle-ok maintenance templates.")
    elif state == "once":
        suggestions.append("Looks finished — leave as reference or tag a release.")
        suggestions.append("Optional: changelog-creator / contributing-creator once.")
    elif state == "archive-candidate":
        suggestions.append("Candidate to archive on GitHub (Settings → Danger zone).")
        suggestions.append("Or mark read-only; remove from NCC active workspaces.")
        suggestions.append("Template: workspace-archive-suggest for a written plan.")

    return {
        "ok": True,
        "workspace_id": wid,
        "label": ws.label,
        "path": str(root),
        "github": ws.github,
        "state": state,
        "reasons": reasons,
        "suggestions": suggestions,
        "git": git,
        "open_tasks": len(tasks),
        "tasks": [
            {
                "id": t.get("id"),
                "title": t.get("title"),
                "status": t.get("status"),
                "priority": t.get("priority"),
            }
            for t in tasks[:10]
        ],
        "thresholds": {
            "active_days": active_days,
            "once_days": once_days,
            "archive_days": archive_days,
        },
    }


def fleet_lifecycle(
    *,
    active_days: int = DEFAULT_ACTIVE_DAYS,
    once_days: int = DEFAULT_ONCE_DAYS,
    archive_days: int = DEFAULT_ARCHIVE_DAYS,
) -> dict[str, Any]:
    """Classify all registered workspaces; highlight archive candidates."""
    rows: list[dict[str, Any]] = []
    by_state: dict[str, list[str]] = {s: [] for s in LIFECYCLE_STATES}
    for ws in list_workspaces():
        try:
            rep = lifecycle_report(
                ws.id,
                active_days=active_days,
                once_days=once_days,
                archive_days=archive_days,
            )
        except (ValueError, RuntimeError) as exc:
            rep = {
                "ok": False,
                "workspace_id": ws.id,
                "label": ws.label,
                "state": "unknown",
                "error": str(exc),
            }
        rows.append(rep)
        st = str(rep.get("state") or "unknown")
        by_state.setdefault(st, []).append(ws.id)

    archive = [r for r in rows if r.get("state") == "archive-candidate"]
    later = [r for r in rows if r.get("state") == "later"]
    active = [r for r in rows if r.get("state") == "active"]
    once = [r for r in rows if r.get("state") == "once"]

    return {
        "ok": True,
        "count": len(rows),
        "by_state": {k: v for k, v in by_state.items() if v},
        "active": [{"id": r["workspace_id"], "label": r.get("label")} for r in active],
        "later": [{"id": r["workspace_id"], "label": r.get("label")} for r in later],
        "once": [{"id": r["workspace_id"], "label": r.get("label")} for r in once],
        "archive_candidates": [
            {
                "id": r["workspace_id"],
                "label": r.get("label"),
                "github": r.get("github"),
                "days": (r.get("git") or {}).get("last_commit_days"),
                "reasons": r.get("reasons"),
            }
            for r in archive
        ],
        "workspaces": rows,
        "hints": [
            "Archive candidates: review then GitHub archive or drop from NCC workspaces.",
            "later = open tasks but quiet git — resume when you want.",
            "once = finished one-shot — keep as reference.",
            f"Active workspace hint: {get_active_workspace_id() or '(none)'}",
        ],
    }


def format_lifecycle_text(report: dict[str, Any]) -> str:
    lines = [
        f"Workspace: {report.get('workspace_id')} ({report.get('label')})",
        f"State: {report.get('state')}",
        f"Path: {report.get('path')}",
        f"GitHub: {report.get('github') or '(none)'}",
        "",
        "Reasons:",
    ]
    for r in report.get("reasons") or []:
        lines.append(f"  · {r}")
    if report.get("suggestions"):
        lines.append("")
        lines.append("Suggestions:")
        for s in report["suggestions"]:
            lines.append(f"  → {s}")
    git = report.get("git") or {}
    lines.append("")
    lines.append(
        f"Git: commit_days={git.get('last_commit_days')} "
        f"dirty={git.get('dirty')} branches={git.get('branch_count')} "
        f"open_prs={git.get('open_prs')}"
    )
    if git.get("last_commit_subject"):
        lines.append(f"Last: {git['last_commit_subject']}")
    return "\n".join(lines)


def format_fleet_text(fleet: dict[str, Any]) -> str:
    lines = [f"Fleet lifecycle · {fleet.get('count')} workspace(s)", ""]
    for key, label in (
        ("active", "Active"),
        ("later", "Later / paused backlog"),
        ("once", "One-shot / finished"),
        ("archive_candidates", "Archive candidates"),
    ):
        items = fleet.get(key) or []
        lines.append(f"{label} ({len(items)}):")
        if not items:
            lines.append("  (none)")
        for it in items:
            extra = ""
            if key == "archive_candidates" and it.get("days") is not None:
                extra = f" · {it['days']}d"
            lines.append(f"  · {it.get('id')} ({it.get('label')}){extra}")
        lines.append("")
    for h in fleet.get("hints") or []:
        lines.append(f"Hint: {h}")
    return "\n".join(lines)
