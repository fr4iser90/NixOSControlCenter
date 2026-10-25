"""Phase 39 §7: an idle sweep inherits the day's narrowest grant, never a schedule's wider one.

The sweep is the one trigger with nobody watching, so it may hold what this host already let
run today and nothing above it. Read back from ``grant_resolved`` lines, because "what the
day already carried" has to be a fact about the log rather than a guess about a profile.
"""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import audit, permissions
from core.scheduling import idle
from core.store import paths


@pytest.fixture(autouse=True)
def fresh_audit():
    """One test, one log — the suite shares the session's throwaway XDG home."""
    audit.clear_audit()
    yield


def _resolved(*, repo: str, system: str, actor: str = "schedule:nightly-ship",
              when: datetime | None = None) -> None:
    """A run-level line as ``agent`` writes it, optionally filed on an earlier day."""
    if when is None:
        audit.append_audit("grant_resolved", actor=actor, args={"repo": repo, "system": system})
        return
    path = paths.audit_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    row = {
        "timestamp": when.astimezone(timezone.utc).isoformat(),
        "event": "grant_resolved",
        "actor": actor,
        "args": {"repo": repo, "system": system},
    }
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


# --- the day floor --------------------------------------------------------------------


def test_a_day_without_a_grant_floors_at_the_narrowest_pair():
    floor = permissions.lowest_grant_today()
    assert (floor.repo, floor.system) == ("observe", "none")


def test_each_axis_takes_its_own_minimum():
    _resolved(repo="merge", system="none")
    _resolved(repo="pr", system="config-write")
    floor = permissions.lowest_grant_today()
    assert (floor.repo, floor.system) == ("pr", "none")


def test_yesterdays_wider_grant_is_not_inheritable():
    _resolved(repo="merge", system="rebuild", when=datetime.now(timezone.utc) - timedelta(days=1))
    floor = permissions.lowest_grant_today()
    assert (floor.repo, floor.system) == ("observe", "none"), "the window is one UTC day"


def test_a_decision_line_is_not_evidence_of_a_grant():
    audit.append_audit(
        "grant_evaluated",
        actor="cli",
        tool="commit",
        result="granted",
        detail="axis=repo repo=merge action=commit need=commit",
    )
    audit.append_audit("grant_resolved", actor="cli", detail="host default (no grant requested)")
    assert permissions.lowest_grant_today().repo == "observe"


def test_the_floor_reads_past_a_capped_window():
    # One run writes a line per decision, so a capped read is the newest afternoon only.
    # Missing the narrow morning run would hand the sweep the afternoon's merges instead.
    _resolved(repo="observe", system="none")
    for _ in range(150):
        audit.append_audit("grant_evaluated", actor="cli", tool="read", result="granted")
    assert len(audit.read_audit()) < 151, "the cap really does drop the morning line"
    floor = permissions.lowest_grant_today()
    assert (floor.repo, floor.system) == ("observe", "none")


# --- the sweep ------------------------------------------------------------------------


def _candidate(**over):
    c = {
        "kind": "schedule",
        "id": "nightly-audit",
        "title": "nightly-audit",
        "playbook": None,
        "goal": "audit the tree",
        "profile": "read-only",
        "dryRun": True,
    }
    c.update(over)
    return c


class _Runs:
    """Records what the sweep handed ``run_agent``, including the env it ran inside."""

    def __init__(self):
        self.kwargs: dict | None = None
        self.actor_during: str | None = None

    def __call__(self, goal, settings, **kwargs):
        self.kwargs = kwargs
        self.actor_during = os.environ.get(permissions.ENV_ACTOR)
        return ()


@contextmanager
def _sweeping(candidate, ran):
    with mock.patch.object(idle, "is_idle_eligible", return_value=True), mock.patch.object(
        idle, "list_idle_candidates", return_value=[candidate]
    ), mock.patch("core.runtime.capacity.try_acquire", return_value="token"), mock.patch(
        "core.runtime.capacity.release"
    ), mock.patch(
        "core.runtime.agent.run_agent", side_effect=ran
    ), mock.patch(
        "core.policy.auth.with_cached_credentials", side_effect=lambda s: s
    ), mock.patch(
        "core.catalogs.agent_templates.run_instance", return_value=()
    ):
        yield


def test_an_idle_run_inherits_the_days_floor_and_reports_it():
    _resolved(repo="merge", system="none")
    _resolved(repo="pr", system="config-write")
    ran = _Runs()
    with _sweeping(_candidate(), ran):
        out = idle.maybe_sweep(start=True)

    assert ran.kwargs is not None and ran.kwargs["grant"] == ("repo=pr", "system=none")
    assert out["started"][0]["status"] == "finished"
    assert out["started"][0]["grant"] == ["repo=pr", "system=none"]


def test_the_sweep_is_named_idle_while_it_runs_and_leaves_nothing_behind():
    _resolved(repo="commit", system="config-write")
    before = {name: os.environ.get(name) for name in idle._GRANT_ENV}
    ran = _Runs()
    with _sweeping(_candidate(), ran):
        idle.maybe_sweep(start=True)

    assert ran.actor_during == idle.IDLE_ACTOR, "the run must not be billed to cli"
    assert {name: os.environ.get(name) for name in idle._GRANT_ENV} == before
    assert permissions.current_grant() is None, "the operator's next chat is not a schedule"


def test_a_write_profile_still_needs_idle_allow_write():
    _resolved(repo="merge", system="rebuild")
    ran = _Runs()
    with _sweeping(_candidate(profile="ops"), ran):
        out = idle.maybe_sweep(start=True)

    assert ran.kwargs is None, "the day's floor is not what lets a write profile run"
    assert out["started"][0]["status"] == "skipped"


def test_a_day_that_only_ran_read_only_idle_runs_read_only():
    _resolved(repo="observe", system="none", actor="cli")
    ran = _Runs()
    with _sweeping(_candidate(), ran):
        idle.maybe_sweep(start=True)

    assert ran.kwargs["grant"] == ("repo=observe", "system=none")
    with mock.patch.dict(os.environ, dict(zip(idle._GRANT_ENV, ("observe", "none", "idle")))):
        assert permissions.evaluate_repo("commit").allowed is False


def test_an_instance_only_sweep_does_not_read_the_whole_log():
    ran = _Runs()
    instance = {"kind": "instance", "id": "i1", "title": "t", "template_id": "tpl"}
    with mock.patch.object(idle, "lowest_grant_today") as floor, _sweeping(instance, ran):
        idle.maybe_sweep(start=True)

    assert floor.called is False, "no grant to inherit means no audit read"
