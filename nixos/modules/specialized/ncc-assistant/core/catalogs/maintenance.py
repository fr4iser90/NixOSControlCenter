"""Retention for state that would otherwise grow forever (jobs, audit log, approvals)."""

from __future__ import annotations

import json
import os
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

from core.store.paths import audit_file, jobs_dir

DEFAULT_JOB_KEEP = 50
DEFAULT_JOB_MAX_AGE_DAYS = 30
DEFAULT_AUDIT_KEEP = 5000
DEFAULT_APPROVAL_MAX_AGE_DAYS = 7

_TERMINAL_JOB_STATUSES = {"completed", "failed", "cancelled"}


def prune_jobs(
    *,
    keep: int = DEFAULT_JOB_KEEP,
    max_age_days: int = DEFAULT_JOB_MAX_AGE_DAYS,
) -> int:
    """Drop finished jobs beyond the newest ``keep`` or older than ``max_age_days``.

    Only dirs whose ``meta.json`` reports a terminal status are candidates, so a
    running or pending job is never removed. Returns the number of job dirs deleted.
    """
    base = jobs_dir()
    if not base.is_dir():
        return 0

    cutoff = (datetime.now(timezone.utc) - timedelta(days=max_age_days)).timestamp()
    terminal: list[tuple[float, Path]] = []
    for job_dir in base.iterdir():
        if not job_dir.is_dir():
            continue
        meta_path = job_dir / "meta.json"
        if not meta_path.is_file():
            continue
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(meta, dict):
            continue
        if str(meta.get("status") or "") not in _TERMINAL_JOB_STATUSES:
            continue
        try:
            mtime = job_dir.stat().st_mtime
        except OSError:
            mtime = 0.0
        terminal.append((mtime, job_dir))

    terminal.sort(key=lambda item: item[0], reverse=True)
    removed = 0
    for index, (mtime, job_dir) in enumerate(terminal):
        if index < keep and mtime >= cutoff:
            continue
        try:
            shutil.rmtree(job_dir)
            removed += 1
        except OSError:
            continue
    return removed


def prune_audit(*, keep: int = DEFAULT_AUDIT_KEEP) -> int:
    """Keep the newest ``keep`` audit lines. Returns how many lines were dropped."""
    path = audit_file()
    if not path.is_file():
        return 0
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return 0
    if len(lines) <= keep:
        return 0
    tail = lines[-keep:] if keep > 0 else []
    try:
        payload = "\n".join(tail) + "\n" if tail else ""
        path.write_text(payload, encoding="utf-8")
        os.chmod(path, 0o600)
    except OSError:
        return 0
    return len(lines) - len(tail)


def prune_approvals(*, max_age_days: int = DEFAULT_APPROVAL_MAX_AGE_DAYS) -> int:
    """Delete decided approvals older than ``max_age_days`` (pending ones stay visible)."""
    from core.policy.notifications import get_decision_service

    return get_decision_service().cleanup_old(max_age_days=max_age_days)


def prune_budget() -> int:
    """Drop day-keyed budget counters past their retention window."""
    from core.policy.budgets import prune

    return prune()


def run_retention() -> dict[str, int]:
    """Run every retention pass. Never raises — each pass fails closed to 0."""
    return {
        "jobs_removed": prune_jobs(),
        "audit_lines_dropped": prune_audit(),
        "approvals_removed": prune_approvals(),
        "budget_days_dropped": prune_budget(),
    }
