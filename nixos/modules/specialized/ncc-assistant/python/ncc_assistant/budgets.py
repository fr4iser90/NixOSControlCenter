"""Day-keyed budgets (phase 39 L8): bound blast radius before the model spends tokens.

The ladder says *how far* a run may go; a budget says *how often*. Both matter only when
the check happens before the expensive part — a breach must cost nothing, so
``check_run`` runs ahead of the LLM call and the diff cap is measured on what is already
staged rather than on what a commit might have contained.

Counters live in ``budget.json`` (0600, pruned by ``maintenance run``) as
``{"runs": {actor: {day: n}}, "prs": {repo: {day: n}}, "openPrs": {repo: n}}``. Like the
ladder itself, a budget only applies inside a grant context: a human at the CLI is not a
schedule that needs reining in.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from .paths import budget_file
from .permissions import Decision, current_grant

ENV_MAX_RUNS_PER_DAY = "NCC_ASSISTANT_BUDGET_MAX_RUNS_PER_DAY"
ENV_MAX_PRS_PER_DAY = "NCC_ASSISTANT_BUDGET_MAX_PRS_PER_DAY"
ENV_MAX_DIFF_LINES = "NCC_ASSISTANT_BUDGET_MAX_DIFF_LINES"
ENV_MAX_OPEN_AGENT_PRS = "NCC_ASSISTANT_BUDGET_MAX_OPEN_AGENT_PRS"

#: Greppable breach reasons for audit.jsonl and the skipped event.
BUDGET_RUNS = "budget_runs"
BUDGET_PRS = "budget_prs"
BUDGET_DIFF = "budget_diff"
BUDGET_OPEN_PRS = "budget_open_prs"

#: What a run gets when the host said nothing (plan 39 §5).
DEFAULT_MAX_PRS_PER_DAY = 3
DEFAULT_MAX_DIFF_LINES = 800
DEFAULT_MAX_OPEN_AGENT_PRS = 5

#: Day entries older than this are dropped by maintenance.
RETENTION_DAYS = 14


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _today() -> str:
    # UTC: the counters are compared against the unit's own day, and a schedule near
    # midnight must not get a second life from a local timezone.
    return datetime.now(timezone.utc).date().isoformat()


def _empty() -> dict[str, Any]:
    return {"runs": {}, "prs": {}, "openPrs": {}}


def _load() -> dict[str, Any]:
    path = budget_file()
    state = _empty()
    if not path.is_file():
        return state
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return state
    if not isinstance(data, dict):
        return state
    for key in state:
        value = data.get(key)
        if isinstance(value, dict):
            state[key] = value
    return state


def _save(state: dict[str, Any]) -> None:
    path = budget_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def _count(state: dict[str, Any], counter: str, key: str) -> int:
    days = (state.get(counter) or {}).get(key)
    if not isinstance(days, dict):
        return 0
    value = days.get(_today(), 0)
    return int(value) if isinstance(value, (int, float)) else 0


def _bump(state: dict[str, Any], counter: str, key: str, delta: int = 1) -> int:
    """Count on today's key and forget the keys nobody will read again."""
    bucket = state.setdefault(counter, {}).setdefault(key, {})
    day = _today()
    kept = {k: v for k, v in bucket.items() if isinstance(v, (int, float))}
    kept[day] = int(kept.get(day, 0)) + delta
    state[counter][key] = kept
    return int(kept[day])


@dataclass(frozen=True)
class BudgetLimits:
    """Ceiling per counter; None (or anything below 1) means the counter does not apply."""

    max_runs_per_day: int | None = None
    max_prs_per_day: int | None = DEFAULT_MAX_PRS_PER_DAY
    max_diff_lines: int | None = DEFAULT_MAX_DIFF_LINES
    max_open_agent_prs: int | None = DEFAULT_MAX_OPEN_AGENT_PRS

    @staticmethod
    def _limit(value: int | None) -> int | None:
        return value if value is not None and value > 0 else None

    def applied(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for name, value in (
            ("maxRunsPerDay", self.max_runs_per_day),
            ("maxPrsPerDay", self.max_prs_per_day),
            ("maxDiffLines", self.max_diff_lines),
            ("maxOpenAgentPrs", self.max_open_agent_prs),
        ):
            limit = self._limit(value)
            if limit is not None:
                out[name] = limit
        return out


def _env_limit(name: str, default: int | None) -> int | None:
    raw = (os.environ.get(name) or "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _limit_of(limits: BudgetLimits | None, attr: str) -> int | None:
    lim = limits if limits is not None else limits_from_env()
    return lim._limit(getattr(lim, attr))


def limits_from_env() -> BudgetLimits:
    """Budget for this process: the unit's env is the narrowest scope, as with the ladder."""
    return BudgetLimits(
        max_runs_per_day=_env_limit(ENV_MAX_RUNS_PER_DAY, None),
        max_prs_per_day=_env_limit(ENV_MAX_PRS_PER_DAY, DEFAULT_MAX_PRS_PER_DAY),
        max_diff_lines=_env_limit(ENV_MAX_DIFF_LINES, DEFAULT_MAX_DIFF_LINES),
        max_open_agent_prs=_env_limit(ENV_MAX_OPEN_AGENT_PRS, DEFAULT_MAX_OPEN_AGENT_PRS),
    )


def _actor() -> str:
    grant = current_grant()
    if grant is not None:
        return grant.actor
    return (os.environ.get("NCC_ASSISTANT_ACTOR") or "").strip() or "cli"


def applies() -> bool:
    """Budgets rein in runs that were granted rights, not a human typing at the CLI."""
    return current_grant() is not None


def _breach(code: str, reason: str, hint: str) -> Decision:
    from .audit import append_audit

    append_audit("budget_exceeded", actor=_actor(), tool=code, result="denied", detail=reason)
    return Decision(False, code, reason, hint)


# --- runs/day ------------------------------------------------------------------------


def runs_today(actor: str | None = None) -> int:
    return _count(_load(), "runs", actor or _actor())


def check_run(limits: BudgetLimits | None = None, *, actor: str | None = None) -> Decision:
    """May this actor start another run today? Checked before the LLM call."""
    lim = _limit_of(limits, "max_runs_per_day")
    who = actor or _actor()
    if lim is None:
        return Decision(True, "", "")
    used = runs_today(who)
    if used < lim:
        return Decision(True, "", "")
    return _breach(
        BUDGET_RUNS,
        f"{who} already ran {used}/{lim} times today",
        "Wait for the next day, or raise agent.grants.budget.maxRunsPerDay / the schedule's.",
    )


def record_run(actor: str | None = None) -> int:
    state = _load()
    count = _bump(state, "runs", actor or _actor())
    _save(state)
    return count


# --- PRs/day and open agent PRs ------------------------------------------------------


def prs_today(repo_id: str) -> int:
    return _count(_load(), "prs", repo_id)


def open_agent_prs(repo_id: str) -> int:
    return _open_count(_load(), repo_id)


def check_prs(repo_id: str, limits: BudgetLimits | None = None) -> Decision:
    """PRs/day per repo — a breach holds the work at ``push``, it does not lose it."""
    lim = _limit_of(limits, "max_prs_per_day")
    if lim is None:
        return Decision(True, "", "")
    used = prs_today(repo_id)
    if used < lim:
        return Decision(True, "", "")
    return _breach(
        BUDGET_PRS,
        f"{used}/{lim} agent PRs opened on {repo_id} today",
        "The branch is pushed; open the PR tomorrow or raise budget.maxPrsPerDay.",
    )


def check_open_agent_prs(repo_id: str, limits: BudgetLimits | None = None) -> Decision:
    lim = _limit_of(limits, "max_open_agent_prs")
    if lim is None:
        return Decision(True, "", "")
    open_count = open_agent_prs(repo_id)
    if open_count < lim:
        return Decision(True, "", "")
    return _breach(
        BUDGET_OPEN_PRS,
        f"{open_count}/{lim} agent PRs already open on {repo_id}",
        "Close or merge one first — a pile of open PRs is the blast radius, not one PR.",
    )


def _open_count(state: dict[str, Any], repo_id: str) -> int:
    value = (state.get("openPrs") or {}).get(repo_id, 0)
    return int(value) if isinstance(value, (int, float)) else 0


def record_pr(repo_id: str) -> int:
    state = _load()
    _bump(state, "prs", repo_id)
    state.setdefault("openPrs", {})[repo_id] = _open_count(state, repo_id) + 1
    _save(state)
    return _open_count(state, repo_id)


def record_merge(repo_id: str) -> int:
    """An agent PR that lands frees a slot in the open-PR budget."""
    state = _load()
    state.setdefault("openPrs", {})[repo_id] = max(0, _open_count(state, repo_id) - 1)
    _save(state)
    return _open_count(state, repo_id)


# --- diff lines per run --------------------------------------------------------------


def check_diff_lines(lines: int, limits: BudgetLimits | None = None) -> Decision:
    lim = _limit_of(limits, "max_diff_lines")
    if lim is None or lines <= lim:
        return Decision(True, "", "")
    return _breach(
        BUDGET_DIFF,
        f"{lines} changed lines exceed {lim}",
        "Commit a smaller slice; the work stays local and the task stays open.",
    )


def staged_diff_lines(numstat_stdout: str) -> int:
    """Sum of added+deleted from ``git diff --cached --numstat`` (binary = "-")."""
    total = 0
    for line in (numstat_stdout or "").splitlines():
        fields = line.split("\t")
        if len(fields) < 2:
            continue
        for value in fields[:2]:
            if value.isdigit():
                total += int(value)
    return total


# --- reporting and retention ---------------------------------------------------------


def summary(limits: BudgetLimits | None = None) -> dict[str, Any]:
    """What ``ncc ai permissions show`` prints — counters only, never a check."""
    state = _load()
    lim = limits or limits_from_env()
    who = _actor()
    return {
        "applies": applies(),
        "actor": who,
        "limits": lim.applied(),
        "today": {
            "runsByActor": {k: _count(state, "runs", k) for k in sorted((state.get("runs") or {}))},
            "prsByRepo": {k: _count(state, "prs", k) for k in sorted((state.get("prs") or {}))},
        },
        "openAgentPrs": {k: int(v) for k, v in sorted((state.get("openPrs") or {}).items()) if isinstance(v, (int, float))},
    }


def prune(keep_days: int = RETENTION_DAYS) -> int:
    """Drop day counters older than ``keep_days``; returns how many entries went."""
    cutoff = (datetime.now(timezone.utc).date() - timedelta(days=max(0, keep_days - 1))).isoformat()
    state = _load()
    dropped = 0
    for counter in ("runs", "prs"):
        buckets = state.get(counter) or {}
        for key in list(buckets):
            days = buckets.get(key)
            if not isinstance(days, dict):
                del buckets[key]
                dropped += 1
                continue
            fresh = {d: v for d, v in days.items() if str(d) >= cutoff}
            dropped += len(days) - len(fresh)
            if fresh:
                buckets[key] = fresh
            else:
                del buckets[key]
    if dropped:
        _save(state)
    return dropped
