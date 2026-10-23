"""Phase 39 L15: on a timer the grant answers the prompt, and confirm may only ask more.

Before: a schedule unit granted ``system=config-write`` still walked into
``DecisionService.wait_for_decision``, waited out ``NOTIFY_TIMEOUT_SEC`` and reported
"Cancelled by user / notification timeout." — a human refusal nobody made, which meant the
grants of L1–L14 could not be used unattended at all.

Now: the approval for a timer is the grant the operator wrote in Nix at deploy time. The mode
still decides *which* calls get asked about; on a unit it never decides whether a write is
approved, so no env value can drop the grant that authorises it. Interactive runs keep asking
a person, unchanged.
"""

from __future__ import annotations

import contextlib
import dataclasses
import json
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

from ncc_assistant import audit, cli, config, notifications, permissions  # noqa: E402
from ncc_assistant.config import Settings  # noqa: E402
from ncc_assistant.permissions import (  # noqa: E402
    CONFIRM_MODES,
    ENV_CONFIRM,
    confirm_rank,
    grant_confirms,
    narrow_confirm,
    normalise_confirm,
)
from ncc_assistant.runtime import ToolRuntime  # noqa: E402

from test_permission_ladder_v1 import grant_env  # noqa: E402
from test_run_length_budgets import _settings  # noqa: E402

SCHEDULE = "schedule:daily-write"


@pytest.fixture(autouse=True)
def fresh_audit():
    """One test, one log — ``grant_confirms`` writes a line per answered prompt."""
    audit.clear_audit()
    yield


@contextlib.contextmanager
def confirm_env(mode: str | None):
    """Only ``AGENT_CONFIRM`` is touched — the grant keys stay with ``grant_env``."""
    saved = os.environ.pop(ENV_CONFIRM, None)
    if mode is not None:
        os.environ[ENV_CONFIRM] = mode
    try:
        yield
    finally:
        os.environ.pop(ENV_CONFIRM, None)
        if saved is not None:
            os.environ[ENV_CONFIRM] = saved


def _runtime(**over) -> ToolRuntime:
    base = dict(allow_write=True, mcp_allow_write=True, allow_rebuild=True)
    base.update(over)
    return ToolRuntime(_settings(**base))


def _no_decision_service():
    """A prompt that reaches a person fails the test: nobody is awake inside a unit."""
    return patch.object(
        notifications, "get_decision_service", side_effect=AssertionError("asked a human")
    )


@contextlib.contextmanager
def _decision_service(answer: str):
    """The interactive path's service stand-in — yielded as the service, not the factory."""
    svc = MagicMock()
    svc.create.return_value = MagicMock(id="decision-1")
    svc.wait_for_decision.return_value = answer
    with patch.object(notifications, "get_decision_service", return_value=svc):
        yield svc


# --- its own rank direction -------------------------------------------------------------


def test_confirm_narrows_toward_asking_more_not_toward_capability():
    """The ladder's ``lower_step`` would narrow the wrong way, so confirm ranks alone."""
    assert confirm_rank("always") < confirm_rank("writes") < confirm_rank("never")
    assert normalise_confirm("WRITES") == "writes"
    assert normalise_confirm("sometimes") is None
    assert confirm_rank("nonsense") == confirm_rank(permissions.DEFAULT_CONFIRM)
    assert CONFIRM_MODES == ("always", "writes", "never")


@pytest.mark.parametrize(
    "ambient,want,allowed",
    [
        ("writes", "always", True),
        ("writes", "writes", True),
        ("writes", "never", False),
        ("never", "writes", True),
        ("never", "always", True),
        ("always", "writes", False),
    ],
)
def test_confirm_may_only_ask_more_than_the_host(ambient: str, want: str, allowed: bool):
    mode, violations = narrow_confirm(ambient, want)
    if allowed:
        assert (mode, violations) == (want, [])
    else:
        assert mode == ambient, "a widening must not be applied and reported as narrowed"
        assert violations and want in violations[0] and ambient in violations[0]


def test_an_unset_ask_inherits_the_host_and_says_nothing():
    assert narrow_confirm("never", None) == ("never", [])
    assert narrow_confirm(None, None) == (permissions.DEFAULT_CONFIRM, [])
    assert narrow_confirm("garbage", None) == (permissions.DEFAULT_CONFIRM, [])


# --- the grant answers a prompt nobody is there for -------------------------------------


def test_a_granted_write_is_answered_by_the_grant():
    with grant_env(system="config-write", actor=SCHEDULE):
        assert grant_confirms("write", tool="apply_module_config").allowed is True


def test_an_ungranted_write_is_refused_by_name_not_by_timeout():
    with grant_env(system="none", actor=SCHEDULE):
        decision = grant_confirms("write")
    assert decision.allowed is False
    assert decision.code == "grant_insufficient"
    assert "grant system=none" in decision.reason


def test_a_config_write_grant_does_not_cover_a_rebuild():
    with grant_env(system="config-write", actor=SCHEDULE):
        refused = grant_confirms("rebuild")
        assert refused.allowed is False and refused.code == "grant_insufficient"
    with grant_env(system="rebuild", actor=SCHEDULE):
        assert grant_confirms("rebuild").allowed is True


def test_a_prompt_with_no_grant_on_it_is_refused():
    """Fail closed: nothing approved this write, so a timer may not perform it."""
    with grant_env(actor=SCHEDULE):
        decision = grant_confirms("write")
    assert decision.allowed is False and decision.code == "confirm_without_grant"


def test_a_step_the_ladder_cannot_speak_in_needs_a_person():
    """``confirm=always`` asks about plain tools; the grant has no word for that."""
    with grant_env(system="rebuild", actor=SCHEDULE):
        decision = grant_confirms("tool", tool="shell_run")
    assert decision.allowed is False and decision.code == "confirm_needs_human"
    assert "--confirm" in decision.hint


@pytest.mark.parametrize(
    "system,level,expected",
    [("config-write", "write", "granted"), ("none", "write", "denied")],
)
def test_the_answer_is_audited_with_the_grant_as_approver(
    system: str, level: str, expected: str
):
    with grant_env(system=system, actor=SCHEDULE):
        grant_confirms(level, tool="apply_module_config")
    lines = [e for e in audit.read_audit(limit=None) if e.event == "confirm_answered"]
    assert len(lines) == 1
    line = lines[0]
    assert line.result == expected
    assert line.actor == SCHEDULE and line.tool == "apply_module_config"
    assert f"level={level}" in line.detail and f"system={system}" in line.detail
    assert ("code=grant_insufficient" in line.detail) == (expected == "denied")


# --- the runtime on a timer -------------------------------------------------------------


def test_a_schedule_write_never_reaches_a_decision_service():
    runtime = _runtime()
    with grant_env(system="config-write", actor=SCHEDULE), confirm_env("writes"), _no_decision_service():
        assert runtime._request_confirmation({"level": "write", "tool": "apply_system"}) is True
    assert runtime._confirm_refusal == "", "a granted prompt records no refusal"


def test_a_refused_schedule_write_says_which_rule_said_no():
    runtime = _runtime()
    with grant_env(system="none", actor=SCHEDULE), confirm_env("writes"), _no_decision_service():
        assert runtime._request_confirmation({"level": "write"}) is False
    message = runtime._confirm_refusal_message()
    assert "grant_insufficient" in message
    assert "Cancelled by user" not in message, "a grant refusal must not read like a human click"


def test_the_mode_cannot_drop_the_grant_that_allows_the_write():
    """``AGENT_CONFIRM=never`` inside a unit must not smuggle a write past system=none."""
    runtime = _runtime()
    with grant_env(system="none", actor=SCHEDULE), confirm_env("never"), _no_decision_service():
        assert runtime._request_confirmation({"level": "write"}) is False


def test_a_non_ladder_prompt_on_a_timer_is_not_the_grants_business():
    runtime = _runtime()
    with grant_env(system="none", actor=SCHEDULE), confirm_env("writes"), _no_decision_service():
        assert runtime._request_confirmation({"level": "read"}) is True


def test_always_on_a_timer_refuses_instead_of_waiting():
    runtime = _runtime()
    with grant_env(system="rebuild", actor=SCHEDULE), confirm_env("always"), _no_decision_service():
        assert runtime._request_confirmation({"level": "tool", "tool": "shell_run"}) is False
    assert "confirm_needs_human" in runtime._confirm_refusal_message()


def test_the_per_tool_prompt_on_a_timer_uses_the_grant_too():
    """``confirm=always`` for a write level must not resurrect the 300 s wait either."""
    runtime = _runtime()
    with grant_env(system="config-write", actor=SCHEDULE), confirm_env("always"), _no_decision_service():
        assert runtime._request_confirmation({"level": "write"}) is True


# --- the interactive path is untouched ---------------------------------------------------


def test_a_chat_run_still_asks_the_person():
    runtime = _runtime()
    with grant_env(), confirm_env("writes"), _decision_service("allow") as svc:
        assert runtime._request_confirmation({"level": "write", "tool": "apply_module_config"})
    svc.create.assert_called_once()
    svc.wait_for_decision.assert_called_once()


def test_a_human_block_still_reads_like_a_block():
    runtime = _runtime()
    with grant_env(), confirm_env("writes"), _decision_service("deny"):
        assert runtime._request_confirmation({"level": "write"}) is False
    assert runtime._confirm_refusal_message() == "Cancelled by user / notification timeout."


def test_a_cli_run_in_never_mode_asks_nobody():
    runtime = _runtime()
    with grant_env(), confirm_env("never"), _no_decision_service():
        assert runtime._request_confirmation({"level": "rebuild"}) is True


# --- the CLI ----------------------------------------------------------------------------


def _agent_run(*argv: str):
    """``agent run`` without an LLM: the run itself is not under test here."""
    return patch("ncc_assistant.agent.run_agent", return_value=iter([]))


def test_confirm_asking_less_than_the_host_exits_two(capsys):
    with patch.dict(os.environ, {ENV_CONFIRM: "writes"}, clear=False), _agent_run() as run:
        rc = cli.main(["agent", "run", "--goal", "x", "--confirm", "never"])
    assert rc == 2
    assert not run.called, "a refused confirm must stop before the run starts"
    assert "--confirm may ask more" in capsys.readouterr().err


def test_the_effective_mode_is_published_for_the_runtime_and_children(capsys):
    with patch.dict(os.environ, {ENV_CONFIRM: "writes"}, clear=False), _agent_run() as run:
        rc = cli.main(["agent", "run", "--goal", "x", "--confirm", "always"])
        # Inside the patch: it is the run's own env that carries the narrowed mode.
        assert rc == 0 and run.called
        assert os.environ[ENV_CONFIRM] == "always", "what this process answers prompts with"
    assert "Confirm: always" in capsys.readouterr().out


def test_no_ask_keeps_the_host_mode_rather_than_a_default_of_its_own(capsys):
    with patch.dict(os.environ, {ENV_CONFIRM: "never"}, clear=False), _agent_run():
        rc = cli.main(["agent", "run", "--goal", "x"])
        assert rc == 0
        assert os.environ[ENV_CONFIRM] == "never"
    assert "Confirm: never" in capsys.readouterr().out


def test_permissions_show_reports_the_confirm_mode(capsys):
    with patch.dict(os.environ, {ENV_CONFIRM: "always"}, clear=False):
        assert cli.main(["permissions", "show", "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["confirm"] == "always"


# --- the inert prefixed trio is gone -----------------------------------------------------


@pytest.mark.parametrize("name", ["agent_confirm", "agent_dry_run", "agent_profile"])
def test_settings_no_longer_carries_the_dead_prefixed_fields(name: str):
    """Only ``AGENT_CONFIRM`` ever had a producer; the Settings copy was read by nobody."""
    fields = {f.name for f in dataclasses.fields(Settings)}
    assert name not in fields
    assert not hasattr(Settings.from_env(client_mode="chat"), name)


def test_the_live_confirm_variable_is_the_unsuffixed_one():
    assert ENV_CONFIRM == "AGENT_CONFIRM"
    source = Path(config.__file__).read_text(encoding="utf-8")
    assert "NCC_ASSISTANT_AGENT_CONFIRM" not in source
