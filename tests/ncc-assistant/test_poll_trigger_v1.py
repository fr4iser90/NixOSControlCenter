"""A poll that cannot tell changed from unchanged is a subscription to a model call.

Phase 39 L11 gives ``scheduleKind: "poll"`` its consumer: a monotonic timer
(``OnBootSec``/``OnUnitActiveSec``) plus one question answered before the budget counters, the
lock and the first LLM call — *is this state one I already acted on?* Three properties are the
deliverable, and each is checked on both sides of the boundary that creates it:

* the gate is **inert** for a human at the CLI and for a calendar schedule (no ``NCC_ASSISTANT_POLL_*``);
* **unknown is not unchanged** — an unresolvable watch denies, and denies without writing a
  baseline, so the schedule is loud instead of quietly never running again;
* the baseline is spent by a **finished** run only, so a crash retries the same state.

The Nix half evaluates the real module: a poll must get a timer that actually fires (no
``OnCalendar``), carry its own id so two polls cannot overwrite each other's hash, and refuse
at evaluation the shapes that would silently burn a model every interval.
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
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

from ncc_assistant import idle, paths, poll_guard, workspaces  # noqa: E402
from ncc_assistant.schedule_templates import ScheduleSpec, nix_snippet  # noqa: E402
from test_permission_ladder_v1 import _repo, grant_env  # noqa: E402
from test_run_length_budgets import _settings  # noqa: E402
from test_schedule_grant_ceiling_v1 import _eval, host, sched  # noqa: E402


@pytest.fixture
def home(tmp_path, monkeypatch):
    """A private config home so poll-state.json cannot leak between tests."""
    cfg = tmp_path / "cfg"
    monkeypatch.setenv("XDG_CONFIG_HOME", str(cfg))
    return cfg / "ncc-assistant"


@contextmanager
def poll_env(schedule: str | None = "watch-tree", watch: str | None = ""):
    """Stand in for the unit environment a poll timer hands its service."""
    keys = (poll_guard.ENV_POLL_SCHEDULE, poll_guard.ENV_POLL_WATCH)
    saved = {k: os.environ.pop(k, None) for k in keys}
    if schedule is not None:
        os.environ[poll_guard.ENV_POLL_SCHEDULE] = schedule
    if watch is not None:
        os.environ[poll_guard.ENV_POLL_WATCH] = watch
    try:
        yield
    finally:
        for k, value in saved.items():
            if value is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = value


def watched_file(tmp_path: Path) -> Path:
    path = tmp_path / "watched.json"
    path.write_text('{"state": "one"}\n', encoding="utf-8")
    return path


def begin(schedule: str, watch: str):
    with poll_env(schedule=schedule, watch=watch):
        return poll_guard.begin()


def state() -> dict:
    path = paths.poll_state_file()
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


# --- the gate is scoped to polls --------------------------------------------------------


def test_a_human_or_a_calendar_run_is_not_gated(home):
    with poll_env(schedule=None):
        assert poll_guard.applies() is False
        assert poll_guard.begin() is None
    # A calendar schedule has the schedule id in its name and no watch: still not a poll.
    with poll_env(schedule="", watch=""):
        assert poll_guard.applies() is False


def test_a_poll_wakes_on_its_first_tick_and_then_only_on_change(tmp_path, home):
    path = watched_file(tmp_path)
    first = begin("tree", f"file:{path}")
    assert first is not None and first.decision.allowed, first.decision
    assert state() == {}, "begin() must not spend the change it just observed"

    assert poll_guard.record(first) is True
    assert "tree" in state()

    same = begin("tree", f"file:{path}")
    assert same is not None and not same.decision.allowed
    assert same.decision.code == poll_guard.POLL_UNCHANGED
    assert same.decision.hint, "the operator has to learn this tick is expected, not broken"

    path.write_text('{"state": "two"}\n', encoding="utf-8")
    changed = begin("tree", f"file:{path}")
    assert changed.decision.allowed, "an edit to a watched file is exactly what the poll is for"


def test_absence_is_a_state_so_the_day_it_appears_is_not_skipped(tmp_path, home):
    path = tmp_path / "not-yet.json"
    first = begin("appears", f"file:{path}")
    assert first.decision.allowed
    assert poll_guard.record(first) is True

    assert begin("appears", f"file:{path}").decision.code == poll_guard.POLL_UNCHANGED

    path.write_text("created\n", encoding="utf-8")
    assert begin("appears", f"file:{path}").decision.allowed


def test_a_workspace_watch_notices_an_edit_that_was_never_committed(tmp_path, home):
    repo = _repo(tmp_path)
    workspaces.upsert_workspace("ncc", str(repo))
    entry = "workspace:ncc"

    first = begin("tree", entry)
    assert first.decision.allowed and first.facts[entry] != poll_guard.UNKNOWN
    assert poll_guard.record(first) is True
    assert begin("tree", entry).decision.code == poll_guard.POLL_UNCHANGED

    (repo / "README.md").write_text("dirty\n", encoding="utf-8")
    assert begin("tree", entry).decision.allowed, (
        "HEAD alone would call a dirty worktree unchanged"
    )


def test_a_corrupt_state_file_is_no_baseline_rather_than_a_blank_one(tmp_path, home):
    path = watched_file(tmp_path)
    first = begin("tree", f"file:{path}")
    poll_guard.record(first)
    paths.poll_state_file().write_text("{not json", encoding="utf-8")
    assert begin("tree", f"file:{path}").decision.allowed


# --- unknown is not unchanged -----------------------------------------------------------


def test_an_unresolvable_watch_refuses_instead_of_guessing(home):
    check = begin("tree", "workspace:never-registered")
    assert not check.decision.allowed
    assert check.decision.code == poll_guard.POLL_STATE_UNKNOWN
    assert "never-registered" in check.decision.reason
    assert poll_guard.record(check) is False
    assert state() == {}, "a poisoned observation must never become the baseline"


def test_one_unknown_entry_poisons_a_watch_that_else_resolves(tmp_path, home):
    path = watched_file(tmp_path)
    check = begin("tree", f"file:{path},workspace:never-registered")
    assert check.unknown == ("workspace:never-registered",)
    assert not check.decision.allowed


def test_a_poll_with_nothing_to_watch_is_refused(home):
    check = begin("tree", "")
    assert not check.decision.allowed
    assert check.decision.code == poll_guard.POLL_STATE_UNKNOWN
    assert "pollWatch" in check.decision.hint


def test_the_baseline_is_written_for_the_operator_only(tmp_path, home):
    path = watched_file(tmp_path)
    assert poll_guard.record(begin("tree", f"file:{path}")) is True
    mode = paths.poll_state_file().stat().st_mode & 0o777
    assert mode == 0o600, oct(mode)


# --- the run path: nothing is spent on an unchanged tick --------------------------------


def _run_agent(locked_events):
    """Drive Agent.run() the way the budget tests do: mocked innards, real gates."""
    from ncc_assistant.agent import AgentRunner, AgentSettings

    with mock.patch("ncc_assistant.agent.get_job_store") as store, mock.patch(
        "ncc_assistant.runtime.ToolRuntime"
    ), mock.patch.object(AgentRunner, "_check_preconditions", return_value=None), mock.patch.object(
        AgentRunner, "_run_with_lock", return_value=iter(locked_events)
    ) as locked, mock.patch("ncc_assistant.agent.AgentLock"):
        runner = AgentRunner(_settings(), AgentSettings(goal="sweep the tree"))
        events = list(runner.run())
    return events, locked, store


def test_an_unchanged_poll_never_reaches_the_job_store_or_the_llm(tmp_path, home):
    path = watched_file(tmp_path)
    watch = f"file:{path}"
    assert poll_guard.record(begin("tree", watch)) is True

    with poll_env(schedule="tree", watch=watch):
        # Ask only what the stub host allows: a grant above the ceiling fails earlier and loudly,
        # which would prove nothing about where the poll gate sits.
        with grant_env(repo="pr", system="none", actor="schedule:tree"):
            events, locked, store = _run_agent([])

    assert len(events) == 1 and events[0]["kind"] == "skipped"
    assert events[0]["reason"] == poll_guard.POLL_UNCHANGED
    assert events[0]["hint"]
    locked.assert_not_called()
    store.return_value.create.assert_not_called()


def test_an_unchanged_tick_is_not_charged_to_the_days_budget(tmp_path, home):
    """The poll gate runs before the budget one: a busy tree must not eat its own allowance."""
    from ncc_assistant import budgets

    path = watched_file(tmp_path)
    watch = f"file:{path}"
    assert poll_guard.record(begin("tree", watch)) is True

    with mock.patch.object(budgets, "record_run") as counted, mock.patch.object(
        budgets, "check_run"
    ) as checked:
        with poll_env(schedule="tree", watch=watch), grant_env(
            repo="pr", actor="schedule:tree"
        ):
            events, _locked, _store = _run_agent([])

    assert events[0]["reason"] == poll_guard.POLL_UNCHANGED
    checked.assert_not_called()
    counted.assert_not_called()


def test_only_a_finished_run_spends_the_change(tmp_path, home):
    path = watched_file(tmp_path)
    watch = f"file:{path}"
    assert poll_guard.record(begin("tree", watch)) is True
    path.write_text('{"state": "three"}\n', encoding="utf-8")

    for kind, recorded in (("job_failed", False), ("job_cancelled", False), ("job_finished", True)):
        paths.poll_state_file().unlink(missing_ok=True)
        event = {"kind": kind, "success": kind == "job_finished"}
        with poll_env(schedule="tree", watch=watch), grant_env(repo="pr", actor="schedule:tree"):
            _events, _locked, _store = _run_agent([{"kind": "job_started", "job_id": 1}, event])
        assert ("tree" in state()) is recorded, f"{kind} must not settle the baseline"


def test_a_recorded_change_becomes_the_baseline_the_next_tick_sees(tmp_path, home):
    path = watched_file(tmp_path)
    watch = f"file:{path}"
    with poll_env(schedule="tree", watch=watch), grant_env(repo="pr", actor="schedule:tree"):
        _events, _locked, _store = _run_agent(
            [{"kind": "job_started", "job_id": 1}, {"kind": "job_finished", "success": True}]
        )
    assert state()["tree"]["digest"]
    assert begin("tree", watch).decision.code == poll_guard.POLL_UNCHANGED


# --- the idle sweep carries its own poll identity ---------------------------------------


def test_the_sweep_hands_a_poll_candidate_its_watch_and_nobody_else_gets_one(home):
    candidate = {"id": "tree", "trigger": "poll", "pollWatch": ["workspace:ncc", "file:/x/y"]}
    with poll_env(schedule=None, watch=None):
        with idle._run_scoped_poll(candidate):
            assert os.environ[poll_guard.ENV_POLL_SCHEDULE] == "tree"
            assert os.environ[poll_guard.ENV_POLL_WATCH] == "workspace:ncc,file:/x/y"
            with idle._run_scoped_poll({"id": "nightly", "trigger": "calendar"}):
                assert poll_guard.applies() is False, (
                    "a calendar candidate after a poll must not answer about the poll's tree"
                )
            assert os.environ[poll_guard.ENV_POLL_SCHEDULE] == "tree"
        assert poll_guard.applies() is False, "a sweep must not leave a poll identity in the companion"


def test_the_sweep_reports_an_unchanged_poll_as_skipped_not_finished(tmp_path, home):
    path = watched_file(tmp_path)
    candidate = {
        "kind": "schedule",
        "id": "tree",
        "title": "tree",
        "playbook": None,
        "goal": "check the tree",
        "profile": "read-only",
        "dryRun": True,
        "trigger": "poll",
        "pollWatch": [f"file:{path}"],
    }
    assert poll_guard.record(begin("tree", f"file:{path}")) is True

    seen: dict[str, object] = {}

    def fake_run_agent(goal, settings, **kwargs):
        # The real gate is inert without this env, so "applies" is the proof the sweep handed
        # the candidate its own watch instead of running the schedule blind.
        seen["applies"] = poll_guard.applies()
        seen["watch"] = os.environ.get(poll_guard.ENV_POLL_WATCH)
        return iter(
            [
                {
                    "kind": "skipped",
                    "reason": poll_guard.POLL_UNCHANGED,
                    "text": "nothing changed since the last run of tree",
                    "hint": "expected most ticks",
                }
            ]
        )

    with mock.patch.object(idle, "is_idle_eligible", return_value=True), mock.patch.object(
        idle, "list_idle_candidates", return_value=[candidate]
    ), mock.patch("ncc_assistant.capacity.try_acquire", return_value="token"), mock.patch(
        "ncc_assistant.capacity.release"
    ), mock.patch(
        "ncc_assistant.agent.run_agent", side_effect=fake_run_agent
    ), mock.patch(
        "ncc_assistant.auth.with_cached_credentials", side_effect=lambda s: s
    ):
        report = idle.maybe_sweep(start=True)

    started = report["started"][0]
    assert seen["applies"] is True, seen
    assert seen["watch"] == f"file:{path}", seen
    assert started["status"] == "skipped", started
    assert started["reason"] == poll_guard.POLL_UNCHANGED
    assert poll_guard.applies() is False, "the sweep left a poll identity in the companion"


def test_the_operator_reads_the_poll_back_from_permissions_show(tmp_path, home, capsys):
    """A schedule that skips most ticks looks broken unless the tool says what it is doing."""
    from ncc_assistant import cli

    path = watched_file(tmp_path)
    watch = f"file:{path}"
    assert poll_guard.record(begin("tree", watch)) is True

    with poll_env(schedule="tree", watch=watch), grant_env(repo="pr", actor="schedule:tree"):
        assert cli.main(["permissions", "show", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)

    assert payload["poll"]["applies"] is True
    assert payload["poll"]["schedule"] == "tree"
    assert payload["poll"]["watch"] == [watch]
    assert payload["poll"]["lastActedAt"]
    assert payload["poll"]["baselines"] == ["tree"]

    # Outside a poll unit the section must say "not a poll", not describe somebody else's run.
    with poll_env(schedule=None, watch=None):
        assert cli.main(["permissions", "show", "--json"]) == 0
    quiet = json.loads(capsys.readouterr().out)
    assert quiet["poll"]["applies"] is False and quiet["poll"]["schedule"] is None


# --- the Nix side: the timer, the unit env, the refusals --------------------------------

TIMER = """
let
  t = ((flatten out.config).systemd.timers or { })."ncc-assistant-schedule-%(unit)s" or { };
  c = t.timerConfig or { };
in {
  onCalendar = if c ? OnCalendar then toString c.OnCalendar else "-";
  persistent = if c ? Persistent then toString c.Persistent else "-";
  onBootSec = if c ? OnBootSec then toString c.OnBootSec else "-";
  onUnitActiveSec = if c ? OnUnitActiveSec then toString c.OnUnitActiveSec else "-";
  jitter = if c ? RandomizedDelaySec then toString c.RandomizedDelaySec else "-";
  wanted = builtins.concatStringsSep "," (t.wantedBy or [ ]);
}
"""

UNIT_POLL_ENV = """
let
  u = ((flatten out.config).systemd.services or { })."ncc-assistant-schedule-%(unit)s" or { environment = { }; };
  e = u.environment;
in {
  id = e.NCC_ASSISTANT_POLL_SCHEDULE or "-";
  interval = e.NCC_ASSISTANT_POLL_INTERVAL or "-";
  watch = e.NCC_ASSISTANT_POLL_WATCH or "-";
}
"""

ASSERTIONS = """
map (a: { ok = a.assertion; message = a.message; }) (flatten out.config).assertions or [ ]
"""


def poll_sched(**over) -> str:
    base = {
        "trigger": '"poll"',
        "pollInterval": '"15min"',
        "pollWatch": '[ "workspace:ncc" ]',
        "onCalendar": "null",
    }
    base.update(over)
    return sched(**base)


def timer_for(name: str, cfg: str, case: str) -> dict:
    return _eval(cfg, TIMER % {"unit": name}, case)


def failing_assertions(cfg: str, case: str) -> list[str]:
    return [a["message"] for a in _eval(cfg, ASSERTIONS, case) if not a["ok"]]


def test_a_poll_timer_is_monotonic_and_has_no_calendar_to_miss():
    cfg = host("{ s = %s; }" % poll_sched(goal='"g"'))
    got = timer_for("s", cfg, "poll timer")
    assert got["onBootSec"] == "15min", got
    assert got["onUnitActiveSec"] == "15min", got
    assert got["onCalendar"] == "-", "a poll with OnCalendar would fire on the clock too"
    assert got["persistent"] == "-", "Persistent means 'catch up missed slots'; a poll has none"
    assert got["wanted"] == "timers.target", got
    assert got["jitter"] == "5min", got


def test_a_calendar_timer_is_left_exactly_as_it_was():
    cfg = host("{ s = %s; }" % sched(goal='"g"'))
    got = timer_for("s", cfg, "calendar timer")
    assert got["onCalendar"] == "daily", got
    assert got["persistent"] == "1", got  # Nix renders toString true as 1, not "true"
    assert got["onBootSec"] == "-" and got["onUnitActiveSec"] == "-", got


def test_a_poll_carries_its_id_so_two_polls_cannot_share_one_hash():
    cfg = host(
        "{ a = %s; b = %s; }"
        % (
            poll_sched(goal='"g"', pollWatch='[ "workspace:ncc" "file:/var/lib/x" ]'),
            poll_sched(goal='"g"', pollInterval='"hourly"', pollWatch='[ "file:/etc/hosts" ]'),
        )
    )
    a = _eval(cfg, UNIT_POLL_ENV % {"unit": "a"}, "poll a env")
    b = _eval(cfg, UNIT_POLL_ENV % {"unit": "b"}, "poll b env")
    assert a["id"] == "a" and b["id"] == "b", (a, b)
    assert a["watch"] == "workspace:ncc,file:/var/lib/x", a
    assert b["interval"] == "hourly" and b["watch"] == "file:/etc/hosts", b


def test_a_calendar_unit_carries_no_poll_identity():
    cfg = host("{ s = %s; }" % sched(goal='"g"'))
    got = _eval(cfg, UNIT_POLL_ENV % {"unit": "s"}, "calendar env")
    assert got == {"id": "-", "interval": "-", "watch": "-"}, got


@pytest.mark.parametrize(
    "stub,needle",
    [
        ({"pollInterval": "null"}, "needs pollInterval"),
        ({"pollWatch": "[ ]"}, "needs a non-empty pollWatch"),
        ({"pollWatch": '[ "workspace:/nope" ]'}, "pollWatch entries unusable"),
        ({"kind": '"probe"', "probe": '"disk"'}, 'trigger = poll needs kind = "agent"'),
        ({"onCalendar": '"daily"'}, "ignores onCalendar"),
        ({"goal": "null", "probe": "null"}, "need goal/playbook"),
    ],
)
def test_a_trigger_that_could_only_burn_a_model_is_refused_at_evaluation(stub, needle):
    cfg = host("{ s = %s; }" % poll_sched(**stub))
    got = "\n".join(failing_assertions(cfg, f"refuse {stub}"))
    assert needle in got, (needle, got)


def test_a_calendar_schedule_that_supplies_a_watch_is_refused_too():
    """The reverse trap: config that reads change-driven and runs on the clock."""
    cfg = host("{ s = %s; }" % sched(goal='"g"', pollWatch='[ "workspace:ncc" ]'))
    assert "only read by a poll" in "\n".join(failing_assertions(cfg, "calendar with watch"))


def test_a_sensible_host_passes_every_trigger_assertion():
    cfg = host(
        "{ poll = %s; cal = %s; probe = %s; }"
        % (
            poll_sched(goal='"g"'),
            sched(goal='"g"'),
            sched(kind='"probe"', probe='"disk"', goal="null"),
        )
    )
    assert failing_assertions(cfg, "sane host") == []


def test_a_calendar_schedule_without_on_calendar_is_refused_too():
    """onCalendar became nullable so a poll need not fake it; a calendar still has to say when."""
    cfg = host("{ s = %s; }" % sched(goal='"g"', onCalendar="null"))
    assert "needs onCalendar" in "\n".join(failing_assertions(cfg, "calendar without a date"))


def test_the_poll_options_are_documented_where_the_operator_reads_them():
    options = (REPO / "nixos/modules/specialized/ncc-assistant/options.nix").read_text(
        encoding="utf-8"
    )
    for opt in ("trigger =", "pollInterval =", "pollWatch ="):
        assert f"{opt} mkOption" in options or f"{opt} mkEnableOption" in options, opt
    plan = next(
        (REPO / "nixos/modules/specialized/ncc-assistant/doc/plans").glob("39-permission-ladder*")
    )
    assert "L11" in plan.read_text(encoding="utf-8")


def test_a_poll_schedule_is_not_displayed_as_a_calendar_one():
    from ncc_assistant.schedule_templates import ScheduleSpec

    spec = ScheduleSpec.from_dict(
        {"trigger": "poll", "pollInterval": "15min", "pollWatch": ["workspace:ncc"], "goal": "g"},
        name="tree",
        source="nix",
    )
    assert spec.onCalendar is None, "from_dict's 'daily' fallback would show a poll as daily"
    assert spec.frequency == "every 15min", spec.frequency
    assert 'trigger = "poll";' in __import__(
        "ncc_assistant.schedule_templates", fromlist=["nix_snippet"]
    ).nix_snippet(spec)
    assert ScheduleSpec(name="nightly").frequency == "daily"
