"""Two timers guessed apart are not a chain — 04:00 does not care whether 03:00 finished.

Phase 39 L12 gives ``schedule.after = "nightly-audit"`` its consumer. systemd cannot express it:
``systemd.timer(5)`` measures ``OnUnitInactiveSec=`` relative to *the unit the timer itself
activates*, so no timer can wait on a sibling schedule. The edge is therefore carried by the
upstream unit's ``ExecStartPost``, which has to ask ``ncc-assistant chain release`` before it may
wake anything, and the downstream run answers for itself at start. Three properties are the
deliverable, and each is checked on both sides of the boundary that creates it:

* the gate is **inert** for a human at the CLI and for an un-chained schedule (no
  ``NCC_ASSISTANT_CHAIN_*``);
* **unknown is not completed** — no outcome, a failed upstream and a run that never reached a
  result all hold the chain, and only ``$INVOCATION_ID`` tells this start from an earlier one;
* a completion is spent by a **finished** downstream only, so a crash keeps its wake-up.

The Nix half evaluates the real module: a chained schedule gets no timer unless it also carries a
clock, its unit carries both halves of its identity, only a schedule somebody waits on gets a wake
step, and every chain that could only sit silent is refused at evaluation.
"""

from __future__ import annotations

import json
import os
import sys
from contextlib import contextmanager
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import audit  # noqa: E402
from core.scheduling import chain_guard, idle
from core.store import paths
from core.scheduling.schedule_templates import ScheduleSpec, nix_snippet  # noqa: E402
from test_permission_ladder_v1 import grant_env  # noqa: E402
from test_run_length_budgets import _settings  # noqa: E402
from test_schedule_grant_ceiling_v1 import _eval, host, sched  # noqa: E402

UPSTREAM = "nightly-audit"
DOWNSTREAM = "ship-after-audit"


@pytest.fixture
def home(tmp_path, monkeypatch):
    """A private config home so chain-state.json and its audit lines cannot leak."""
    cfg = tmp_path / "cfg"
    monkeypatch.setenv("XDG_CONFIG_HOME", str(cfg))
    return cfg / "ncc-assistant"


@contextmanager
def chain_env(
    schedule: str | None = DOWNSTREAM,
    after: str | None = UPSTREAM,
    invocation: str | None = None,
):
    """Stand in for the unit environment a chained schedule's service is started with."""
    keys = (
        chain_guard.ENV_CHAIN_SCHEDULE,
        chain_guard.ENV_CHAIN_AFTER,
        chain_guard.ENV_INVOCATION_ID,
    )
    saved = {k: os.environ.pop(k, None) for k in keys}
    if schedule is not None:
        os.environ[chain_guard.ENV_CHAIN_SCHEDULE] = schedule
    if after is not None:
        os.environ[chain_guard.ENV_CHAIN_AFTER] = after
    if invocation is not None:
        os.environ[chain_guard.ENV_INVOCATION_ID] = invocation
    try:
        yield
    finally:
        for k, value in saved.items():
            if value is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = value


def finish(status: str, *, schedule: str = UPSTREAM, invocation: str | None = "inv-upstream") -> bool:
    """End a run the way the unit does: as ``schedule:<id>``, inside an invocation."""
    saved = os.environ.pop(chain_guard.ENV_INVOCATION_ID, None)
    if invocation is not None:
        os.environ[chain_guard.ENV_INVOCATION_ID] = invocation
    try:
        with grant_env(actor=f"schedule:{schedule}"):
            return chain_guard.record_outcome(status)
    finally:
        if saved is None:
            os.environ.pop(chain_guard.ENV_INVOCATION_ID, None)
        else:
            os.environ[chain_guard.ENV_INVOCATION_ID] = saved


def begin(schedule: str | None = DOWNSTREAM, after: str | None = UPSTREAM):
    with chain_env(schedule=schedule, after=after):
        return chain_guard.begin()


def state() -> dict:
    path = paths.chain_state_file()
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


# --- the gate is scoped to chained schedules --------------------------------------------


def test_a_human_or_an_unchained_run_is_not_gated(home):
    with chain_env(schedule=None, after=None):
        assert chain_guard.applies() is False
        assert chain_guard.begin() is None
    # A schedule with an id but no predecessor is just a schedule.
    with chain_env(schedule="nightly", after=""):
        assert chain_guard.applies() is False


def test_a_completion_needs_no_env_when_the_actor_already_names_the_schedule(home):
    """A unit that forgot its own id still knows who it is through the grant."""
    finish(chain_guard.STATUS_COMPLETED)
    with chain_env(schedule="", after=UPSTREAM), grant_env(actor=f"schedule:{DOWNSTREAM}"):
        check = chain_guard.begin()
    assert check is not None and check.schedule_id == DOWNSTREAM
    assert check.decision.allowed, check.decision


# --- unknown is never reported as completed ---------------------------------------------


def test_a_downstream_waits_for_a_completion_someone_recorded(home):
    check = begin()
    assert not check.decision.allowed
    assert check.decision.code == chain_guard.CHAIN_UPSTREAM_UNKNOWN
    assert UPSTREAM in check.decision.reason
    assert f"ncc-assistant-schedule-{UPSTREAM}.service" in check.decision.hint
    assert state() == {}, "begin() must not write a completion it did not have"


def test_an_upstream_that_failed_is_not_a_completion(home):
    finish(chain_guard.STATUS_FAILED)
    check = begin()
    assert check.decision.code == chain_guard.CHAIN_UPSTREAM_NOT_COMPLETED
    assert chain_guard.STATUS_FAILED in check.decision.reason


def test_a_cancelled_upstream_holds_the_chain(home):
    finish(chain_guard.STATUS_CANCELLED)
    assert begin().decision.code == chain_guard.CHAIN_UPSTREAM_NOT_COMPLETED


def test_a_corrupt_chain_state_is_no_completion_rather_than_a_blank_one(home):
    finish(chain_guard.STATUS_COMPLETED)
    paths.chain_state_file().write_text("{not json", encoding="utf-8")
    assert begin().decision.code == chain_guard.CHAIN_UPSTREAM_UNKNOWN


def test_only_a_schedule_run_puts_an_outcome_on_the_record(home):
    """A human's ``agent run`` and the idle sweep must not be able to fake a completion."""
    for actor in ("cli", "idle", ""):
        with grant_env(actor=actor):
            assert chain_guard.record_outcome(chain_guard.STATUS_COMPLETED) is False
    assert state() == {}
    assert finish(chain_guard.STATUS_COMPLETED) is True
    assert state()["outcomes"][UPSTREAM]["invocation"] == "inv-upstream"


# --- one completion, one downstream run --------------------------------------------------


def test_a_completion_runs_the_downstream_once(home):
    finish(chain_guard.STATUS_COMPLETED)
    first = begin()
    assert first.decision.allowed, first.decision
    assert begin().decision.allowed, "begin() must not spend the completion it just read"

    assert chain_guard.record(first) is True
    again = begin()
    assert not again.decision.allowed
    assert again.decision.code == chain_guard.CHAIN_UPSTREAM_ACTED
    assert again.decision.hint


def test_a_fresh_completion_wakes_the_downstream_again(home):
    finish(chain_guard.STATUS_COMPLETED)
    assert chain_guard.record(begin()) is True
    # The completion's timestamp is its identity, so the next run of the upstream is a new job.
    finish(chain_guard.STATUS_COMPLETED)
    assert begin().decision.allowed


def test_a_completion_is_not_spent_by_another_downstream(home):
    finish(chain_guard.STATUS_COMPLETED)
    assert chain_guard.record(begin(schedule="other", after=UPSTREAM)) is True
    assert begin().decision.allowed, "one schedule's wake-up is not another's"


def test_the_state_is_written_for_the_operator_only(home):
    finish(chain_guard.STATUS_COMPLETED)
    mode = paths.chain_state_file().stat().st_mode & 0o777
    assert mode == 0o600, oct(mode)


# --- the run path: nothing is spent or started while the chain holds ----------------------


def _run_agent(locked_events):
    """Drive Agent.run() the way the budget tests do: mocked innards, real gates."""
    from core.runtime.agent import AgentRunner, AgentSettings

    with mock.patch("core.runtime.agent.get_job_store") as store, mock.patch(
        "core.runtime.runtime.ToolRuntime"
    ), mock.patch.object(AgentRunner, "_check_preconditions", return_value=None), mock.patch.object(
        AgentRunner, "_run_with_lock", return_value=iter(locked_events)
    ) as locked, mock.patch("core.runtime.agent.AgentLock"):
        runner = AgentRunner(_settings(), AgentSettings(goal="ship what the audit found"))
        events = list(runner.run())
    return events, locked, store


def run_downstream(events: list[dict]):
    """Run the chained schedule the way its unit would: named actor, its own chain env."""
    with chain_env(schedule=DOWNSTREAM, after=UPSTREAM, invocation="inv-downstream"), grant_env(
        repo="pr", actor=f"schedule:{DOWNSTREAM}"
    ):
        return _run_agent(events)


def test_a_held_chain_never_reaches_the_job_store_or_the_llm(home):
    events, locked, store = run_downstream([])

    assert len(events) == 1 and events[0]["kind"] == "skipped"
    assert events[0]["reason"] == chain_guard.CHAIN_UPSTREAM_UNKNOWN
    assert events[0]["hint"]
    locked.assert_not_called()
    store.return_value.create.assert_not_called()


def test_a_held_chain_is_not_charged_to_the_days_budget(home):
    """The chain gate runs ahead of the budget ones: a held run must not eat its own allowance."""
    from core.policy import budgets

    with mock.patch.object(budgets, "record_run") as counted, mock.patch.object(
        budgets, "check_run"
    ) as checked:
        events, _locked, _store = run_downstream([])

    assert events[0]["reason"] == chain_guard.CHAIN_UPSTREAM_UNKNOWN
    checked.assert_not_called()
    counted.assert_not_called()


def test_a_held_downstream_records_skipped_not_completed(home):
    """Its own dependents must not read a held run as a finished stage of the chain."""
    run_downstream([])
    entry = state()["outcomes"][DOWNSTREAM]
    assert entry["status"] == chain_guard.STATUS_SKIPPED
    assert entry["code"] == chain_guard.CHAIN_UPSTREAM_UNKNOWN


def test_a_completed_downstream_tells_the_next_link_and_spends_the_completion(home):
    finish(chain_guard.STATUS_COMPLETED)
    run_downstream([{"kind": "job_started", "job_id": 1}, {"kind": "job_finished", "success": True}])

    assert state()["outcomes"][DOWNSTREAM]["status"] == chain_guard.STATUS_COMPLETED
    assert state()["consumed"][DOWNSTREAM]["upstream"] == UPSTREAM


@pytest.mark.parametrize(
    "kind,consumed",
    [("job_failed", False), ("job_cancelled", False), ("job_finished", True)],
)
def test_only_a_finished_run_spends_the_completion(home, kind, consumed):
    finish(chain_guard.STATUS_COMPLETED)
    event = {"kind": kind, "success": kind == "job_finished"}
    run_downstream([{"kind": "job_started", "job_id": 1}, event])
    assert (DOWNSTREAM in state().get("consumed", {})) is consumed, f"{kind} must not settle a chain"


# --- the upstream's ExecStartPost has to ask, and only about its own invocation ----------


def release(schedule: str = UPSTREAM, *, invocation: str | None = "inv-upstream"):
    saved = os.environ.pop(chain_guard.ENV_INVOCATION_ID, None)
    if invocation is not None:
        os.environ[chain_guard.ENV_INVOCATION_ID] = invocation
    try:
        return chain_guard.release_decision(schedule)
    finally:
        if saved is None:
            os.environ.pop(chain_guard.ENV_INVOCATION_ID, None)
        else:
            os.environ[chain_guard.ENV_INVOCATION_ID] = saved


def test_a_completed_run_of_this_very_invocation_may_wake(home):
    finish(chain_guard.STATUS_COMPLETED)
    decision = release()
    assert decision.allowed, decision
    assert "inv-upstream" in decision.reason


def test_a_release_from_a_shell_is_refused(home):
    """No ``$INVOCATION_ID`` means nothing proves which run ended — waking is the whole point."""
    finish(chain_guard.STATUS_COMPLETED)
    decision = release(invocation=None)
    assert not decision.allowed
    assert decision.code == chain_guard.CHAIN_UPSTREAM_UNKNOWN
    assert "INVOCATION_ID" in decision.reason


def test_an_earlier_runs_completion_does_not_get_to_wake(home):
    finish(chain_guard.STATUS_COMPLETED, invocation="inv-yesterday")
    decision = release()
    assert decision.code == chain_guard.CHAIN_UPSTREAM_NOT_COMPLETED
    assert "earlier run" in decision.reason


def test_a_run_that_never_reached_a_result_wakes_nothing(home):
    decision = release()
    assert decision.code == chain_guard.CHAIN_UPSTREAM_UNKNOWN
    assert "no outcome" in decision.reason


def test_a_release_without_a_schedule_id_is_refused(home):
    finish(chain_guard.STATUS_COMPLETED)
    assert not release("").allowed


def test_every_release_decision_reaches_the_audit(home):
    finish(chain_guard.STATUS_COMPLETED)
    release()
    release("never-ran")
    events = [(e.event, e.result) for e in audit.read_audit()]
    assert ("chain_released", "allowed") in events, events
    assert ("chain_held", "denied") in events, events


# --- what the operator can read back ------------------------------------------------------


def test_chain_release_exits_zero_only_when_waking_is_allowed(home, capsys):
    from cli import cli

    with chain_env(schedule=None, after=None, invocation="inv-upstream"):
        assert cli.main(["chain", "release", "--schedule", UPSTREAM, "--json"]) == 1
        held = json.loads(capsys.readouterr().out)
        assert held["wake"] is False and held["code"] == chain_guard.CHAIN_UPSTREAM_UNKNOWN

        finish(chain_guard.STATUS_COMPLETED)
        assert cli.main(["chain", "release", "--schedule", UPSTREAM]) == 0
        assert "Chain release" in capsys.readouterr().out

        finish(chain_guard.STATUS_FAILED)
        assert cli.main(["chain", "release", "--schedule", UPSTREAM]) == 1
        out = capsys.readouterr().out
        assert "Chain held" in out and "chain held" in out.lower()


def test_the_operator_reads_the_chain_back_from_permissions_show(home, capsys):
    from cli import cli

    finish(chain_guard.STATUS_COMPLETED)
    with chain_env(schedule=DOWNSTREAM, after=UPSTREAM):
        assert cli.main(["permissions", "show", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)

    assert payload["chain"]["applies"] is True
    assert payload["chain"]["schedule"] == DOWNSTREAM
    assert payload["chain"]["after"] == UPSTREAM
    assert payload["chain"]["upstreamStatus"] == chain_guard.STATUS_COMPLETED
    assert payload["chain"]["outcomes"][UPSTREAM]["status"] == chain_guard.STATUS_COMPLETED

    with chain_env(schedule=None, after=None):
        assert cli.main(["permissions", "show", "--json"]) == 0
    quiet = json.loads(capsys.readouterr().out)
    assert quiet["chain"]["applies"] is False and quiet["chain"]["after"] is None

    with chain_env(schedule=DOWNSTREAM, after=UPSTREAM), grant_env(actor=f"schedule:{DOWNSTREAM}"):
        check = chain_guard.begin()
        chain_guard.record(check)
        assert cli.main(["permissions", "show"]) == 0
    shown = capsys.readouterr().out
    assert f"{DOWNSTREAM} waits on {UPSTREAM}" in shown
    assert "acted on it" in shown


# --- the idle sweep carries its own chain identity ----------------------------------------


def test_the_sweep_hands_a_chain_candidate_its_upstream_and_nobody_else_gets_one(home):
    candidate = {"id": DOWNSTREAM, "chainAfter": UPSTREAM}
    with chain_env(schedule=None, after=None):
        with idle._run_scoped_chain(candidate):
            assert os.environ[chain_guard.ENV_CHAIN_SCHEDULE] == DOWNSTREAM
            assert os.environ[chain_guard.ENV_CHAIN_AFTER] == UPSTREAM
            with idle._run_scoped_chain({"id": "nightly", "chainAfter": None}):
                assert chain_guard.applies() is False, (
                    "a schedule after a chained one must not still wait on its predecessor"
                )
            assert os.environ[chain_guard.ENV_CHAIN_AFTER] == UPSTREAM
        assert chain_guard.applies() is False, "a sweep must not leave a chain identity in the companion"


def test_a_chained_candidate_shows_up_in_the_idle_list(home, monkeypatch):
    monkeypatch.setattr(idle, "get_idle_mode", lambda: "schedules")
    monkeypatch.setenv(
        "NCC_ASSISTANT_SCHEDULES_JSON",
        json.dumps({DOWNSTREAM: {"after": UPSTREAM, "goal": "ship it", "onCalendar": None}}),
    )
    candidate = next(c for c in idle.list_idle_candidates() if c["id"] == DOWNSTREAM)
    assert candidate["chainAfter"] == UPSTREAM


# --- the display says what wakes it, not a clock it does not have -------------------------


def test_a_chained_schedule_is_not_displayed_with_a_clock_it_does_not_have():
    spec = ScheduleSpec.from_dict(
        {"after": UPSTREAM, "goal": "ship it", "onCalendar": None}, name=DOWNSTREAM, source="nix"
    )
    assert spec.after == UPSTREAM
    assert spec.frequency == f"after {UPSTREAM} completes", spec.frequency
    snippet = nix_snippet(spec)
    assert f'after = "{UPSTREAM}";' in snippet, snippet
    assert 'onCalendar = "daily";' not in snippet, "the fallback would re-add the clock it dropped"
    assert ScheduleSpec(name="nightly").frequency == "daily"


# --- the Nix side: the units, the wake step, the refusals --------------------------------


UNIT_CHAIN = """
let
  svc = (flatten out.config).systemd.services or { };
  tmr = (flatten out.config).systemd.timers or { };
  n = "ncc-assistant-schedule-%(unit)s";
  u = svc.${n} or { environment = { }; serviceConfig = { }; };
  c = u.serviceConfig;
in {
  service = if svc ? "${n}" then "yes" else "-";
  timer = if tmr ? "${n}" then "yes" else "-";
  id = u.environment.NCC_ASSISTANT_CHAIN_SCHEDULE or "-";
  after = u.environment.NCC_ASSISTANT_CHAIN_AFTER or "-";
  # Only presence: the wake script interpolates the real ncc-assistant package, so forcing its
  # value would build the world. "Does this unit get to wake anything" is the capability here.
  post = if c ? ExecStartPost then "yes" else "-";
}
"""

TIMER = """
let
  t = ((flatten out.config).systemd.timers or { })."ncc-assistant-schedule-%(unit)s" or { };
  c = t.timerConfig or { };
in {
  onCalendar = if c ? OnCalendar then toString c.OnCalendar else "-";
}
"""

ASSERTIONS = """
map (a: { ok = a.assertion; message = a.message; }) (flatten out.config).assertions or [ ]
"""


def chained(**over) -> str:
    """A schedule whose only trigger is another schedule's completion."""
    base = {"onCalendar": "null", "after": '"%s"' % UPSTREAM}
    base.update(over)
    return sched(**base)


def unit_view(name: str, cfg: str, case: str) -> dict:
    return _eval(cfg, UNIT_CHAIN % {"unit": name}, case)


def failing_assertions(cfg: str, case: str) -> list[str]:
    return [a["message"] for a in _eval(cfg, ASSERTIONS, case) if not a["ok"]]


def test_a_chained_schedule_gets_a_service_but_no_timer_to_miss():
    cfg = host(
        "{ %s = %s; %s = %s; }"
        % (UPSTREAM, sched(goal='"audit"'), DOWNSTREAM, chained(goal='"ship"'))
    )
    got = unit_view(DOWNSTREAM, cfg, "chained unit")
    assert got["service"] == "yes", "the wake step starts this unit, so it has to exist"
    assert got["timer"] == "-", "a chained schedule with no clock must not get an empty OnCalendar="
    assert got["id"] == DOWNSTREAM and got["after"] == UPSTREAM, got


def test_a_chained_schedule_with_a_calendar_of_its_own_keeps_that_timer():
    cfg = host(
        "{ %s = %s; %s = %s; }"
        % (UPSTREAM, sched(goal='"audit"'), DOWNSTREAM, chained(goal='"ship"', onCalendar='"daily"'))
    )
    assert unit_view(DOWNSTREAM, cfg, "chained with clock")["timer"] == "yes"
    assert _eval(cfg, TIMER % {"unit": DOWNSTREAM}, "chained timer")["onCalendar"] == "daily"


def test_only_a_schedule_somebody_waits_on_gets_a_wake_step():
    cfg = host(
        "{ %s = %s; %s = %s; loner = %s; }"
        % (UPSTREAM, sched(goal='"audit"'), DOWNSTREAM, chained(goal='"ship"'), sched(goal='"g"'))
    )
    upstream = unit_view(UPSTREAM, cfg, "upstream unit")
    assert upstream["post"] == "yes", "somebody waits on this run, so it needs the wake step"
    assert upstream["id"] == "-", "the upstream is not itself chained"
    assert unit_view(DOWNSTREAM, cfg, "downstream unit")["post"] == "-", (
        "a chained schedule must not wake anything of its own from the same step"
    )
    assert unit_view("loner", cfg, "loner unit")["post"] == "-"


def test_a_dependent_that_is_switched_off_is_not_on_any_wake_list():
    """``systemctl start`` runs a disabled unit too, so it must never be named."""
    cfg = host(
        "{ %s = %s; %s = %s; }"
        % (UPSTREAM, sched(goal='"audit"'), DOWNSTREAM, chained(goal='"ship"', enable="false"))
    )
    assert unit_view(UPSTREAM, cfg, "no enabled dependents")["post"] == "-"


def test_a_chained_schedule_without_on_calendar_is_not_read_as_misconfigured():
    cfg = host(
        "{ %s = %s; %s = %s; }"
        % (UPSTREAM, sched(goal='"audit"'), DOWNSTREAM, chained(goal='"ship"'))
    )
    messages = "\n".join(failing_assertions(cfg, "chained without a clock"))
    assert "needs onCalendar" not in messages, messages


def test_a_sane_host_with_a_chain_passes_every_assertion():
    cfg = host(
        "{ %s = %s; %s = %s; probe = %s; }"
        % (
            UPSTREAM,
            sched(goal='"audit"'),
            DOWNSTREAM,
            chained(goal='"ship"'),
            sched(kind='"probe"', probe='"disk"', goal="null"),
        )
    )
    assert failing_assertions(cfg, "sane chained host") == []


def plain(**over) -> str:
    attrs = {"goal": '"g"'}
    attrs.update(over)
    return sched(**attrs)


#: Each body is real Nix: the schedule attrs have to be the submodule's shape or the eval fails
#: for the wrong reason and the refusal below never gets read.
@pytest.mark.parametrize(
    "body,needle",
    [
        ("ship = %s; audit = %s;" % (chained(goal='"ship"', after='"ghost"'), plain()),
         "is not a schedule on this host"),
        ("self = %s;" % chained(goal='"ship"', after='"self"'), "points at this schedule itself"),
        ('off = %s; ship = %s;' % (plain(enable="false"), chained(goal='"ship"', after='"off"')),
         "is switched off"),
        ('probe = %s; ship = %s;' % (plain(kind='"probe"', probe='"disk"', goal="null"),
                                     chained(goal='"ship"', after='"probe"')),
         'is kind = "probe"'),
        # b → a → b: nobody in a loop can be first, so nobody ever ends completed for the next.
        ('a = %s; b = %s;' % (chained(goal='"ship"', after='"b"'), chained(goal='"ship"', after='"a"')),
         "forms a loop"),
    ],
    ids=["unknown-id", "self-chain", "disabled-upstream", "probe-upstream", "loop"],
)
def test_a_chain_that_could_only_sit_silent_is_refused_at_evaluation(body, needle):
    cfg = host("{ %s }" % body)
    assert needle in "\n".join(failing_assertions(cfg, f"refuse {needle}")), needle


def test_an_after_that_names_nothing_lists_the_ids_the_host_has():
    cfg = host("{ s = %s; }" % chained(goal='"ship"'))
    messages = "\n".join(failing_assertions(cfg, "unknown upstream"))
    assert "declared: s" in messages, messages


def test_the_chain_option_is_documented_where_the_operator_reads_it():
    options = (REPO / "nixos/modules/specialized/ncc-assistant/options.nix").read_text(
        encoding="utf-8"
    )
    assert "after = mkOption" in options
    plan = next(
        (REPO / "nixos/modules/specialized/ncc-assistant/doc/plans").glob("39-permission-ladder*")
    )
    assert "L12" in plan.read_text(encoding="utf-8")
