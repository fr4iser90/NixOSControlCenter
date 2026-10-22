"""Chain gate for scheduled chains (phase 39 L12): a schedule runs on another one's completion.

Two timers guessed apart are not a chain: the ship job that fires at 04:00 does not care whether
the audit that ran at 03:00 finished, failed, or never started. Making the dependency real needs
an answer to a question systemd cannot answer for us — ``systemd.timer(5)`` measures
``OnUnitInactiveSec=`` "relative to when the unit the timer unit is activating was last
deactivated", so a timer can only wait on *itself*, never on a sibling schedule. The chain is
therefore declared here and delivered by the upstream unit's ``ExecStartPost``, which asks
``ncc-assistant chain release`` before it is allowed to wake anything.

Two halves, both fail-closed:

* **release** — may the unit that just ended wake its dependents? Only a run of *this very unit
  invocation* that ended ``completed`` may, which is why the recorded outcome carries systemd's
  ``$INVOCATION_ID`` (``systemd.exec(5)``: the same ID goes to every process of one runtime
  cycle). A skipped run exits 0, so the unit's exit status is not evidence of anything; a
  ``completed`` left behind by an older start is not either.
* **begin** — may this chained run start? It needs an unconsumed ``completed`` outcome for the
  schedule it declared as ``after``. Consumption is written only once a run has finished, so a
  downstream that dies halfway gets its wake-up back instead of losing it.

As with the poll gate, these codes are deliberately not ``denied_``-prefixed: a held chain is the
schedule working as declared, not a permission breach, and it must not read like one in the audit.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from .paths import chain_state_file
from .permissions import Decision

#: Set on a chained unit only (schedules.nix ``chainEnvironment``): the schedule itself and the
#: one whose completion wakes it. Nothing here applies to a human typing ``agent run``.
ENV_CHAIN_SCHEDULE = "NCC_ASSISTANT_CHAIN_SCHEDULE"
ENV_CHAIN_AFTER = "NCC_ASSISTANT_CHAIN_AFTER"
#: Assigned by systemd to every process of one unit start — the token that binds "the outcome
#: this invocation recorded" to "the post-step deciding whether to wake".
ENV_INVOCATION_ID = "INVOCATION_ID"

#: Greppable codes for the skipped event and the release decision.
CHAIN_UPSTREAM_UNKNOWN = "chain_upstream_unknown"
CHAIN_UPSTREAM_NOT_COMPLETED = "chain_upstream_not_completed"
CHAIN_UPSTREAM_ACTED = "chain_upstream_acted"

STATUS_COMPLETED = "completed"
STATUS_FAILED = "failed"
STATUS_CANCELLED = "cancelled"
STATUS_SKIPPED = "skipped"

#: Only a schedule's own unit may put an outcome on the record; ``cli`` and ``idle`` runs must
#: not rewrite a chain's history — and must not be able to fake one downstream's wake-up.
SCHEDULE_ACTOR_PREFIX = "schedule:"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _actor() -> str:
    from .permissions import current_grant

    grant = current_grant()
    if grant is not None:
        return grant.actor
    return (os.environ.get("NCC_ASSISTANT_ACTOR") or "").strip() or "cli"


def own_schedule_id() -> str:
    """``nightly-audit`` for a unit whose actor is ``schedule:nightly-audit``, else ``""``."""
    actor = _actor()
    if not actor.startswith(SCHEDULE_ACTOR_PREFIX):
        return ""
    return actor[len(SCHEDULE_ACTOR_PREFIX) :].strip()


def applies() -> bool:
    """True only for a run a chained schedule started."""
    return bool((os.environ.get(ENV_CHAIN_AFTER) or "").strip())


def _load() -> dict[str, Any]:
    state: dict[str, Any] = {"outcomes": {}, "consumed": {}}
    try:
        data = json.loads(chain_state_file().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return state
    if not isinstance(data, dict):
        return state
    for key in state:
        value = data.get(key)
        if isinstance(value, dict):
            state[key] = value
    return state


def _save(state: dict[str, Any]) -> bool:
    path = chain_state_file()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        os.chmod(path, 0o600)
    except OSError:
        return False
    return True


def outcome_of(schedule_id: str) -> dict[str, Any] | None:
    """How this schedule's last run ended, or None when nothing trustworthy is recorded."""
    if not schedule_id:
        return None
    entry = _load()["outcomes"].get(schedule_id)
    return entry if isinstance(entry, dict) else None


def record_outcome(status: str, code: str = "") -> bool:
    """Put this run's ending on the record — for a schedule's own unit, and nobody else.

    A human's ``agent run`` and the idle sweep deliberately write nothing: their ending says
    nothing about whether the schedule's chain may move.
    """
    schedule_id = own_schedule_id()
    if not schedule_id or not status:
        return False
    state = _load()
    state["outcomes"][schedule_id] = {
        "status": status,
        "code": code or None,
        "at": _now(),
        "invocation": (os.environ.get(ENV_INVOCATION_ID) or "").strip() or None,
        "actor": _actor(),
    }
    return _save(state)


@dataclass
class ChainCheck:
    """One chained run's view of the upstream it waits for, and what the gate decided."""

    schedule_id: str
    upstream_id: str
    status: str | None = None
    upstream_at: str | None = None
    decision: Decision = Decision(True, "", "")


def _acted_on(upstream_id: str, schedule_id: str, upstream_at: str | None) -> bool:
    """Has this downstream already spent this particular completion?

    The completion's timestamp is its identity: it changes with every outcome the upstream
    records, so a second wake-up for the same completion is a repeat run, not a new job.
    """
    consumed = _load()["consumed"].get(schedule_id)
    if not isinstance(consumed, dict) or consumed.get("upstream") != upstream_id:
        return False
    return bool(upstream_at) and consumed.get("upstreamAt") == upstream_at


def begin() -> ChainCheck | None:
    """Decide whether a chained schedule may run, or None when this run is not chained.

    Nothing is written here — consumption happens in ``record``, after the run, so a downstream
    that crashes still owes its wake-up to the next attempt rather than having burned it.
    """
    upstream_id = (os.environ.get(ENV_CHAIN_AFTER) or "").strip()
    if not upstream_id:
        return None
    schedule_id = (os.environ.get(ENV_CHAIN_SCHEDULE) or "").strip() or own_schedule_id()
    check = ChainCheck(schedule_id=schedule_id, upstream_id=upstream_id)
    if not schedule_id:
        check.decision = Decision(
            False,
            CHAIN_UPSTREAM_UNKNOWN,
            f"a run waiting on '{upstream_id}' did not say which schedule it is",
            "Set agent.schedules.<id>.after on the downstream schedule — its unit needs its own "
            "id to tell a completion it already acted on from one it has not.",
        )
        return check

    outcome = outcome_of(upstream_id)
    if outcome is None:
        check.decision = Decision(
            False,
            CHAIN_UPSTREAM_UNKNOWN,
            f"no recorded outcome for '{upstream_id}', so nothing proves it completed",
            f"Check the run before this one: journalctl -u ncc-assistant-schedule-{upstream_id}.service. "
            "Unknown is never reported as completed — nothing ran and nothing was recorded.",
        )
        return check

    status = outcome.get("status")
    check.status = status if isinstance(status, str) else None
    at = outcome.get("at")
    check.upstream_at = at if isinstance(at, str) else None

    if check.status != STATUS_COMPLETED:
        check.decision = Decision(
            False,
            CHAIN_UPSTREAM_NOT_COMPLETED,
            f"'{upstream_id}' last ended '{check.status or 'unknown'}', not completed",
            f"Fix the upstream first — journalctl -u ncc-assistant-schedule-{upstream_id}.service. "
            "A chain holds work; it does not replace a failed run with the next stage's.",
        )
        return check

    if _acted_on(upstream_id, schedule_id, check.upstream_at):
        check.decision = Decision(
            False,
            CHAIN_UPSTREAM_ACTED,
            f"{schedule_id} already acted on the completion from {check.upstream_at}",
            "Expected when the schedule has a calendar as well as an `after`: the completion is "
            "spent once, so the earlier wake-up was the run.",
        )
        return check

    check.decision = Decision(True, "", f"'{upstream_id}' completed and {schedule_id} has not acted on it")
    return check


def record(check: ChainCheck | None) -> bool:
    """Spend the completion this run acted on — only once the run has actually finished."""
    if check is None or not check.decision.allowed or not check.upstream_at:
        return False
    state = _load()
    state["consumed"][check.schedule_id] = {
        "upstream": check.upstream_id,
        "upstreamAt": check.upstream_at,
        "at": _now(),
        "actor": _actor(),
    }
    return _save(state)


def release_decision(schedule_id: str) -> Decision:
    """May the unit that just ended wake the schedules that declared ``after = schedule_id``?

    Called by the upstream unit's ``ExecStartPost``, so the answer has to survive the two ways a
    chain could otherwise wake on air: a run that was skipped (its unit still exits 0) and a
    ``completed`` left on disk by an earlier start of the same unit.
    """
    from .audit import append_audit

    schedule_id = (schedule_id or "").strip()
    invocation = (os.environ.get(ENV_INVOCATION_ID) or "").strip()
    if not schedule_id:
        decision = Decision(
            False,
            CHAIN_UPSTREAM_UNKNOWN,
            "release asked without a schedule id",
            "The unit's ExecStartPost passes its own name: ncc-assistant chain release --schedule <id>.",
        )
    elif not invocation:
        decision = Decision(
            False,
            CHAIN_UPSTREAM_UNKNOWN,
            f"no $INVOCATION_ID, so '{schedule_id}' is not running inside a unit start",
            "Run it as the schedule's unit — waking a chain from a shell cannot prove which run "
            "ended, which is the whole point of the chain.",
        )
    else:
        outcome = outcome_of(schedule_id)
        if outcome is None:
            decision = Decision(
                False,
                CHAIN_UPSTREAM_UNKNOWN,
                f"'{schedule_id}' recorded no outcome, so this run never reached a result",
                "Nothing woke. If the run itself looked like it worked, check whether it was "
                "skipped by the chain or poll gate, or denied by a budget.",
            )
        elif outcome.get("invocation") != invocation:
            decision = Decision(
                False,
                CHAIN_UPSTREAM_NOT_COMPLETED,
                f"the outcome on record for '{schedule_id}' belongs to an earlier run of this unit",
                "Nothing woke: this start did not finish a run, so it does not get to release the "
                "chain on the last one's behalf.",
            )
        elif outcome.get("status") != STATUS_COMPLETED:
            decision = Decision(
                False,
                CHAIN_UPSTREAM_NOT_COMPLETED,
                f"'{schedule_id}' ended '{outcome.get('status')}', not completed",
                "Nothing woke — a chain is only as good as the run before it.",
            )
        else:
            decision = Decision(
                True,
                "",
                f"'{schedule_id}' completed in this invocation ({invocation})",
            )
    append_audit(
        "chain_released" if decision.allowed else "chain_held",
        actor=f"schedule:{schedule_id}" if schedule_id else _actor(),
        tool=decision.code or "wake",
        result="allowed" if decision.allowed else "denied",
        detail=decision.reason,
    )
    return decision


def display() -> dict[str, Any]:
    """This run's chain identity plus every recorded outcome, for ``permissions show``.

    An operator reading this after a schedule seemed to do nothing needs both halves at once:
    what this run was waiting for, and how each schedule's last run actually ended.
    """
    upstream_id = (os.environ.get(ENV_CHAIN_AFTER) or "").strip()
    schedule_id = (os.environ.get(ENV_CHAIN_SCHEDULE) or "").strip() or own_schedule_id()
    state = _load()
    outcome = outcome_of(upstream_id) if upstream_id else None
    consumed = state["consumed"].get(schedule_id) if schedule_id else None
    return {
        "applies": bool(upstream_id),
        "schedule": schedule_id or None,
        "after": upstream_id or None,
        "upstreamStatus": outcome.get("status") if isinstance(outcome, dict) else None,
        "upstreamAt": outcome.get("at") if isinstance(outcome, dict) else None,
        "actedAt": consumed.get("at") if isinstance(consumed, dict) else None,
        "outcomes": {
            name: {"status": entry.get("status"), "at": entry.get("at")}
            for name, entry in sorted(state["outcomes"].items())
            if isinstance(entry, dict)
        },
    }
