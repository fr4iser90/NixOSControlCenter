"""Change-hash gate for poll schedules (phase 39 L11): a poll only runs when something moved.

A calendar schedule is allowed to fire at times it was told to fire. A poll is not: its timer
wakes every ``pollInterval`` whatever the world is doing, so without a gate "poll" is just a
cheaper-looking way to pay a model on a loop — the cost plan 39 §Risks calls out by name. The
gate therefore answers one question ahead of the job, the budget counters and the first LLM
call: *is this state one I have already acted on?*

Watch entries are the grammar schedules.nix validates (``workspace:<registered-id>`` and
``file:/absolute/path``), hashed into one digest per schedule and kept in ``poll-state.json``
(0600) so the next tick can compare. Two rules the design is not allowed to forget:

* **Absence is a state.** A watched file that is not there hashes to ``absent`` rather than to
  nothing, so the poll still fires when it appears.
* **Unknown is not unchanged.** An entry that cannot be resolved — a workspace id nobody
  registered, a directory that is not a repo, a file that cannot be read — makes the whole
  observation unknown, and an unknown observation denies the run with its own code instead of
  recording a digest. Guessing "no change" here is how a schedule ends up looking healthy and
  never running again; running anyway is how it burns a model every interval. Both are louder
  and cheaper than the guess, and the denial says which entry to fix.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .paths import poll_state_file
from .permissions import Decision

#: Set by a poll unit only (schedules.nix ``pollEnvironment``): nothing here applies to a human
#: typing ``ncc-assistant agent run``, exactly as budgets only apply inside a grant context.
ENV_POLL_SCHEDULE = "NCC_ASSISTANT_POLL_SCHEDULE"
ENV_POLL_WATCH = "NCC_ASSISTANT_POLL_WATCH"

#: Greppable codes for the skipped event and audit.jsonl.
POLL_UNCHANGED = "poll_unchanged"
POLL_STATE_UNKNOWN = "poll_state_unknown"

#: A watched path nobody registered, a repo that is not a repo, an unreadable file.
UNKNOWN = "unknown"
#: A watched file that is not there — a real state, because its appearing is the change.
ABSENT = "absent"

_GIT_TIMEOUT = 20.0


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def applies() -> bool:
    """True only for a run a poll unit started."""
    return bool((os.environ.get(ENV_POLL_SCHEDULE) or "").strip())


def _watch_entries() -> tuple[str, ...]:
    raw = os.environ.get(ENV_POLL_WATCH) or ""
    return tuple(entry.strip() for entry in raw.split(",") if entry.strip())


def _git(root: Path, *args: str) -> str | None:
    """Git output, or None when git itself could not answer (never an empty string)."""
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=_GIT_TIMEOUT,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return (proc.stdout or "").strip()


def _observe_entry(entry: str) -> tuple[str, str]:
    """Return ``fact`` for one watch entry, or ``unknown``/``absent``.

    ``unknown`` poisons the whole observation on purpose: half a state cannot prove "no change"
    any more than a missing hash can (phase 38's rule for the fact store).
    """
    kind, _, arg = entry.partition(":")
    if kind == "workspace":
        from .workspaces import get_workspace

        workspace = get_workspace(arg)
        if workspace is None:
            return UNKNOWN
        root = Path(workspace.path)
        if not root.is_dir():
            return UNKNOWN
        head = _git(root, "rev-parse", "HEAD")
        if head is None:
            return UNKNOWN
        branch = _git(root, "branch", "--show-current") or "detached"
        # The worktree counts: a poll on a working tree must notice an edit that was never
        # committed, which no HEAD-sha comparison would ever see.
        status = _git(root, "status", "--porcelain")
        if status is None:
            return UNKNOWN
        worktree = hashlib.sha256(status.encode("utf-8")).hexdigest()[:16]
        return f"head={head} branch={branch} worktree={worktree}"

    if kind == "file":
        path = Path(arg)
        try:
            data = path.read_bytes()
        except FileNotFoundError:
            return ABSENT
        except OSError:
            return UNKNOWN
        return f"bytes={hashlib.sha256(data).hexdigest()[:16]}"

    # schedules.nix rejects any other prefix at evaluation; reaching here means the entry came
    # from somewhere else entirely, so it is unknown rather than a fact about nothing.
    return UNKNOWN


@dataclass
class PollCheck:
    """One poll's observation and what the gate decided about it."""

    schedule_id: str
    digest: str
    facts: dict[str, str] = field(default_factory=dict)
    decision: Decision = Decision(True, "", "")

    @property
    def unknown(self) -> tuple[str, ...]:
        return tuple(sorted(name for name, fact in self.facts.items() if fact == UNKNOWN))


def observe(schedule_id: str, entries: tuple[str, ...]) -> PollCheck:
    facts = {entry: _observe_entry(entry) for entry in entries}
    lines = [f"{entry}={fact}" for entry, fact in sorted(facts.items())]
    digest = hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()
    return PollCheck(schedule_id=schedule_id, digest=digest, facts=facts)


def _stored_digest(schedule_id: str) -> str | None:
    try:
        state = json.loads(poll_state_file().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(state, dict):
        return None
    entry = state.get(schedule_id)
    if not isinstance(entry, dict):
        return None
    digest = entry.get("digest")
    return digest if isinstance(digest, str) and digest else None


def begin() -> PollCheck | None:
    """Observe and decide, or None when this run is not a poll.

    Nothing is written here: the digest only becomes the baseline once a run has actually
    finished with it (``record``), so a run that dies halfway retries the same state instead of
    quietly spending the change that woke it.
    """
    schedule_id = (os.environ.get(ENV_POLL_SCHEDULE) or "").strip()
    if not schedule_id:
        return None
    entries = _watch_entries()
    check = observe(schedule_id, entries)
    if not entries:
        check.decision = Decision(
            False,
            POLL_STATE_UNKNOWN,
            f"poll schedule '{schedule_id}' woke with nothing to watch",
            "Set agent.schedules.<id>.pollWatch — a poll that compares nothing runs every "
            "interval, which is the cost the trigger exists to avoid.",
        )
        return check
    if check.unknown:
        check.decision = Decision(
            False,
            POLL_STATE_UNKNOWN,
            f"poll schedule '{schedule_id}' cannot read: {', '.join(check.unknown)}",
            "Register the workspace id (ncc ai workspaces) or fix pollWatch to an existing "
            "path. Unknown is not unchanged, so nothing ran and nothing was recorded.",
        )
        return check

    last = _stored_digest(schedule_id)
    if last is None:
        # First poll since the schedule existed: there is no baseline to compare with, and the
        # honest reading of "never acted on" is "act".
        check.decision = Decision(True, "", f"first observation for {schedule_id}")
        return check
    if last == check.digest:
        check.decision = Decision(
            False,
            POLL_UNCHANGED,
            f"nothing changed since the last run of {schedule_id}",
            "Expected most ticks: the timer woke, the state matched, no model was called.",
        )
        return check
    check.decision = Decision(True, "", f"changed since the last run of {schedule_id}")
    return check


def record(check: PollCheck | None) -> bool:
    """Set the baseline the next tick compares against — only after a run finished."""
    if check is None or check.unknown or not check.digest:
        return False
    path = poll_state_file()
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        state = {}
    if not isinstance(state, dict):
        state = {}
    state[check.schedule_id] = {
        "digest": check.digest,
        "at": _now(),
        # Kept so ``ncc ai schedules``/a human can tell *which* entry moved without guessing
        # from a hash. Paths and shas only — never file contents.
        "facts": check.facts,
    }
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        os.chmod(path, 0o600)
    except OSError:
        return False
    return True


def state_for_display() -> dict[str, Any]:
    """Every stored baseline: which polls exist, when each last acted, and what it saw."""
    try:
        state = json.loads(poll_state_file().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return state if isinstance(state, dict) else {}


def display() -> dict[str, Any]:
    """One run's poll identity plus every stored baseline, for ``permissions show``.

    The identity comes from the environment rather than from a decision, so the answer is the
    same whether this tick is about to run or skip: "am I a poll, what was I told to watch, and
    when did I last act on it" is what an operator reads when a schedule looks asleep.
    """
    schedule_id = (os.environ.get(ENV_POLL_SCHEDULE) or "").strip()
    stored = state_for_display()
    entry = stored.get(schedule_id)
    return {
        "applies": bool(schedule_id),
        "schedule": schedule_id or None,
        "watch": list(_watch_entries()),
        "lastActedAt": entry.get("at") if isinstance(entry, dict) else None,
        "baselines": sorted(stored),
    }
