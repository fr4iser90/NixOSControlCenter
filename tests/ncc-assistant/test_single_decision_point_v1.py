#!/usr/bin/env python3
"""Phase 39 L4: one place answers "may this run touch the host" — ceiling first, grant second.

Before: ``runtime`` read ``settings.writes_enabled`` / ``settings.allow_rebuild`` at six sites and
each site invented its own denial prose, while the grant ladder only ran inside ``call()``. A write
reached the host through the MCP server or a diff-apply without ever meeting the ladder, and a run
granted ``system=none`` was still shown the write tools it would be refused.
Now: ``decide_system`` weighs the host ceiling and the run's grant in one call and returns one
``Decision``; ``system_flags`` narrows the advertised catalog the same way; ``runtime._may`` is the
only reader of the two host flags. The ceiling still decides alone when there is no grant, so a
human CLI is unchanged — a grant can only ever narrow.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Any
from unittest.mock import MagicMock, patch

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant import permissions  # noqa: E402
from ncc_assistant.permissions import Decision, Grant, decide_system, system_flags  # noqa: E402
from ncc_assistant.runtime import ToolRuntime  # noqa: E402

from test_permission_ladder_v1 import grant_env  # noqa: E402
from test_run_length_budgets import _settings  # noqa: E402

WRITE_TOOLS = ("apply_module_config", "restore_config_backup")


def _runtime(**over) -> ToolRuntime:
    """A runtime whose host says "writes allowed" unless a test says otherwise."""
    base = dict(allow_write=True, mcp_allow_write=True, allow_rebuild=True)
    base.update(over)
    return ToolRuntime(_settings(**base))


def _fake_config(*_args: Any, **_kwargs: Any) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=["fake"], returncode=0, stdout="content\n", stderr="")


# --- the pure decision ---------------------------------------------------------------


def test_no_grant_the_host_ceiling_answers_alone():
    """A human CLI has no grant: the ceiling is the whole verdict, exactly as before."""
    with grant_env():
        assert decide_system(
            "config_write", writes_enabled=True, allow_rebuild=False
        ).allowed is True
        write_off = decide_system("config_write", writes_enabled=False, allow_rebuild=True)
        assert write_off.allowed is False and write_off.code == "host_writes_disabled"
        no_rebuild = decide_system("rebuild", writes_enabled=True, allow_rebuild=False)
        assert no_rebuild.allowed is False and no_rebuild.code == "host_rebuild_disabled"


def test_each_host_flag_opens_only_its_own_step():
    """allowRebuild is not a rank above allowWrite — it must not open config writes."""
    with grant_env():
        rebuild_only = decide_system(
            "rebuild", writes_enabled=False, allow_rebuild=True
        )
        assert rebuild_only.allowed is True, "allowRebuild alone opens rebuild"
        writes = decide_system("config_write", writes_enabled=False, allow_rebuild=True)
        assert writes.code == "host_writes_disabled", "…and never a config write"


def test_a_grant_narrows_an_open_ceiling():
    grant = Grant(repo="observe", system="none")
    denied = decide_system("config_write", writes_enabled=True, allow_rebuild=True, grant=grant)
    assert denied.allowed is False and denied.code == "grant_insufficient"
    assert "grant system=none" in denied.reason

    wider = decide_system("config_write", writes_enabled=True, allow_rebuild=True,
                          grant=Grant(repo="observe", system="config-write"))
    assert wider.allowed is True


def test_an_action_without_a_step_is_denied_not_allowed():
    """Fail closed: an unmapped action must never fall through to the grant's allow."""
    with grant_env():
        unknown = decide_system("rm_rf", writes_enabled=True, allow_rebuild=True)
        assert unknown.allowed is False and unknown.code == "unknown_action"


# --- system_flags: the catalog may not promise what the run cannot do ------------------


def test_system_flags_narrows_the_advertised_flags():
    with grant_env():
        assert system_flags(True, True) == (True, True)
        assert system_flags(True, False) == (True, False)
        assert system_flags(False, False) == (False, False)
    assert system_flags(True, True, grant=Grant(system="none")) == (False, False)
    assert system_flags(True, True, grant=Grant(system="config-write")) == (True, False)
    # Rebuild always needed both host flags, so a grant cannot advertise it alone.
    assert system_flags(True, True, grant=Grant(system="rebuild")) == (True, True)
    assert system_flags(False, True, grant=Grant(system="rebuild")) == (False, False)


def test_the_granted_none_run_is_not_shown_the_write_tools():
    """The catalog is a promise: a narrower grant removes the tools from the list."""
    runtime = _runtime()
    with grant_env(system="none"):
        listed = {t["canonical"] for t in runtime.list_available_tools()["tools"]}
        openai = {t["function"]["name"] for t in runtime.openai_tools()}
    assert not (set(WRITE_TOOLS) & listed), listed
    assert "apply_system" not in listed and "apply_system" not in openai

    with grant_env():
        full = {t["canonical"] for t in runtime.list_available_tools()["tools"]}
    assert set(WRITE_TOOLS) <= full and "apply_system" in full, "unchanged for a human CLI"


# --- the direct call path (mcp_server, diff_review) is now gated -----------------------


def test_direct_write_is_refused_below_its_grant():
    """``mcp_server`` / ``diff_review`` call the method, not ``call()`` — the gate moved down."""
    runtime = _runtime()
    with grant_env(system="none"), patch.object(
        ToolRuntime, "_config_cmd", side_effect=_fake_config
    ) as cmd:
        result = runtime.apply_module_config("services/foo", "{ enable = true; }", True)
    assert result["ok"] is False
    assert result["denied"] == "grant_insufficient"
    assert "grant system=none" in result["reason"]
    cmd.assert_not_called()


def test_direct_write_proceeds_when_the_grant_covers_it():
    runtime = _runtime()
    with grant_env(system="config-write"), patch.object(
        ToolRuntime, "_config_cmd", side_effect=_fake_config
    ) as cmd:
        result = runtime.apply_module_config("services/foo", "{ enable = true; }", True)
    assert result["ok"] is True
    assert cmd.called, "the ladder stays out of the way once the run may write"


def test_direct_rebuild_is_refused_below_its_grant():
    runtime = _runtime()
    with grant_env(system="config-write"), patch.object(subprocess, "run") as run:
        result = runtime.apply_system("CONFIRM")
    assert result["ok"] is False and result["denied"] == "grant_insufficient"
    assert "rebuild" in result["reason"]
    run.assert_not_called()


def test_restore_from_backup_is_a_config_write():
    runtime = _runtime()
    with grant_env(system="none"):
        result = runtime.restore_config_backup("/var/backup/nixos/conf-1.nix", confirm=True)
    assert result["ok"] is False and result["denied"] == "grant_insufficient"


def test_the_host_refusal_keeps_its_own_code_not_the_grants():
    """Greppable apart: "the host forbids this" is not "this run asked for more"."""
    writes_off = _runtime(allow_write=False, mcp_allow_write=False, allow_rebuild=False)
    with grant_env(), patch.object(subprocess, "run") as run:
        assert writes_off.apply_module_config("services/foo", "{}", True)["error"] == (
            "host_writes_disabled"
        )
        assert writes_off.apply_system("CONFIRM")["error"] == "host_rebuild_disabled"
    run.assert_not_called()


def test_the_mcp_client_mode_ceiling_still_applies():
    """mcpAllowWrite is the flag for an MCP session; the ladder must not route around it."""
    runtime = _runtime(client_mode="mcp", allow_write=True, mcp_allow_write=False)
    with grant_env():
        denied = runtime.apply_module_config("services/foo", "{}", True)
    assert denied["ok"] is False and denied["error"] == "host_writes_disabled"


# --- domain tools ----------------------------------------------------------------------


class _Entry:
    """The attributes ``_call_domain_tool`` reads off a registry entry."""

    name = "domain.things.wipe"
    kind = "domain"
    risk = "rebuild"
    permission = None
    input_schema: dict[str, Any] = {"type": "object", "properties": {}}
    argv: list[str] = ["ncc", "things", "wipe"]
    confirm = False


def test_a_rebuild_risk_domain_tool_needs_both_host_flags():
    """Historically rebuild-risk meant writes_enabled AND allow_rebuild — kept, in that order."""
    runtime = _runtime(allow_write=False, mcp_allow_write=False, allow_rebuild=True)
    with grant_env():
        denied = runtime._call_domain_tool(_Entry(), {})
    assert denied["ok"] is False
    assert denied["error"] == "host_writes_disabled", "the write ceiling is asked first"

    no_rebuild = _runtime(allow_write=True, mcp_allow_write=True, allow_rebuild=False)
    with grant_env():
        second = no_rebuild._call_domain_tool(_Entry(), {})
    assert second["ok"] is False and second["error"] == "host_rebuild_disabled"

    granted = _runtime()
    with grant_env(system="config-write"):
        third = granted._call_domain_tool(_Entry(), {})
    assert third["ok"] is False and third["denied"] == "grant_insufficient"


def test_a_read_risk_domain_tool_is_not_blocked_by_the_write_ceiling():
    """Verb matching in ``call()`` must not become a new ceiling for declared-read tools."""
    entry = _Entry()
    entry.risk = "read"
    runtime = _runtime(allow_write=False, mcp_allow_write=False, allow_rebuild=False)
    with grant_env(), patch.object(ToolRuntime, "_request_confirmation", return_value=True):
        result = runtime._call_domain_tool(entry, {})
    assert result.get("error") not in ("host_writes_disabled", "host_rebuild_disabled")
    assert result.get("error") != "grant_insufficient"


def test_decision_payload_carries_the_code_and_the_prose_together():
    """A tool result must stay actionable: a code the log can grep, prose the model can read."""
    denied: Decision = decide_system(
        "config_write", writes_enabled=False, allow_rebuild=False, client_mode="chat"
    )
    payload = {"ok": False, **denied.as_dict()}
    assert payload["error"] == "host_writes_disabled"
    assert "allowWrite" in payload["reason"] and "chat" in payload["reason"]
