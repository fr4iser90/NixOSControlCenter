"""Phase 39 L7: red-team cases for every floor rule, and proof nothing re-opens them.

plan-39 §4 refuses six things in code with no option to re-enable any of them. "In code" is
only worth something if the pack that attacks them (a) covers each rule, (b) attacks it from
the top of the ladder rather than from the bottom, and (c) cannot be turned green by a host
setting. These cases are the guard on all three, and they run without touching git: the same
report backs ``ncc ai red-team`` and the GUI button.
"""

from __future__ import annotations

import inspect
import os
import re
import subprocess
import sys
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy import permissions, red_team

MODULE_DIR = REPO / "nixos/modules/specialized/ncc-assistant"

#: Every refusal §4 puts below the ladder — nine codes across its four bullets. A rule may be
#: added to the floor, never quietly dropped from here.
FLOOR_RULES = {
    "force_push",
    "hook_bypass",
    "protected_branch",
    "secret_path",
    "blanket_path",
    "path_outside_repo",
    "non_agent_branch",
    "shell_git_write",
    "repo_ceiling_path",
}
FLOOR_CODES = {
    "denied_force_push",
    "denied_hook_bypass",
    "denied_protected_branch",
    "denied_secret_path",
    "denied_blanket_path",
    "denied_path_outside_repo",
    "denied_non_agent_branch",
    "denied_shell_git_write",
    "denied_repo_ceiling_path",
}


class _StubRuntime:
    """Enough of ToolRuntime for the guard half of the report, without a real runtime."""

    def __init__(self, blocked: bool = True) -> None:
        self.confirm_hook = None
        self.dry_run = False
        self.blocked = blocked
        self.calls: list[tuple[str, dict]] = []

    def call(self, tool: str, args: dict) -> dict:
        self.calls.append((tool, args))
        if self.blocked:
            return {"ok": False, "error": "confirm_denied"}
        return {"ok": True, "written": tool}


# --- coverage: every §4 rule is attacked, with its own code --------------------------


def test_every_floor_rule_is_attacked_and_refused():
    results = red_team.run_floor_checks()
    failed = [f"{r.name}: {r.detail}" for r in results if not r.passed]
    assert failed == [], failed

    attacked = {r.name.split(".")[1] for r in results if r.name.startswith("floor.")}
    assert attacked - {"ordinary_work"} == FLOOR_RULES, attacked
    assert red_team.floor_rules() == FLOOR_RULES


def test_the_code_that_answers_a_rule_is_the_one_the_plan_names():
    """A refusal without its greppable code is unauditable, so each detail carries one."""
    by_code: dict[str, int] = {}
    for result in red_team.run_floor_checks():
        if not result.name.startswith("floor.") or result.name.split(".")[1] == "ordinary_work":
            continue
        by_code[result.detail] = by_code.get(result.detail, 0) + 1

    assert set(by_code) == FLOOR_CODES, set(by_code)


def test_a_new_floor_code_without_a_case_is_a_failing_test():
    """The completeness gate: adding ``denied_*`` to the floor means adding a red-team case."""
    claimed = {attempt.code for attempt in red_team.FLOOR_ATTEMPTS}
    for name in ("core/policy/permissions.py", "core/workflows/workflow_execute.py"):
        source = (MODULE_DIR / name).read_text(encoding="utf-8")
        found = set(re.findall(r'"(denied_[a-z_]+)"', source))
        assert found, name
        assert found - claimed == set(), f"{name} refuses with {found - claimed} and red_team never asks"


def test_ordinary_work_is_not_refused():
    """A floor that denied everything would pass the list above while making NCC useless."""
    controls = [r for r in red_team.run_floor_checks() if ".ordinary_work." in r.name]
    assert len(controls) >= 6, controls
    broken = [f"{r.name}: {r.detail}" for r in controls if not r.passed]
    assert broken == [], broken


# --- immunity: the top of the ladder, and no grant at all ----------------------------


def test_the_release_grant_is_really_published_while_the_floor_is_probed():
    seen = {}

    def spy():
        seen["grant"] = permissions.current_grant()
        return permissions.Decision(allowed=False, code="denied_force_push", reason="spy")

    attempt = red_team.FloorAttempt("force_push", "spy", "denied_force_push", "git push --force", spy)
    with red_team._published_env(red_team.TOP_OF_LADDER):
        judged = red_team._judge(attempt)

    assert judged.passed is True
    assert seen["grant"] is not None and seen["grant"].repo == "release"
    assert seen["grant"].system == "rebuild"


def test_every_refusal_survives_the_widest_host_configuration():
    """The published environment is the whole permissive surface a host can reach."""
    with red_team._published_env(red_team.TOP_OF_LADDER):
        assert permissions.current_grant() is not None
        for attempt in red_team.FLOOR_ATTEMPTS:
            verdict = attempt.probe()
            assert verdict.allowed is False, attempt.attempt
            assert verdict.code == attempt.code, (attempt.attempt, verdict.code)


def test_the_probes_leave_the_process_environment_as_they_found_it():
    """The GUI runs this in-process; a leaked release grant would outlive the button press."""
    before = dict(os.environ)
    red_team.run_floor_checks()
    assert os.environ == before
    assert permissions.current_grant() is None


def test_a_human_with_no_grant_is_refused_by_the_same_rules():
    results = [r for r in red_team.run_floor_checks() if r.name.endswith(".without_grant")]
    assert {r.name.split(".")[1] for r in results} == FLOOR_RULES, results
    assert [r.name for r in results if not r.passed] == []


# --- nothing in Nix can re-open the floor -------------------------------------------

#: What an override would have to be called to be worth adding. Deliberately shaped after
#: the rules themselves, so the honest answer to "can a host widen the floor" stays no.
OVERRIDE_SHAPED = re.compile(
    r"(?i)(force.?push|no.?verify|gpg.?sign|skip.?hook|bypass|allow.?protected"
    r"|disable.?floor|floor.?override|unsafe.?path|allow.?secret)"
)


def test_no_nix_option_is_shaped_like_a_floor_override():
    options = (MODULE_DIR / "options.nix").read_text(encoding="utf-8")
    names = re.findall(r"^\s*([A-Za-z_][A-Za-z0-9_]*) = mkOption", options, re.M)
    assert names, "option parsing went wrong, not the check"
    assert [name for name in names if OVERRIDE_SHAPED.search(name)] == []


def test_no_nix_option_describes_reaching_the_floor():
    options = (MODULE_DIR / "options.nix").read_text(encoding="utf-8").lower()
    for needle in ("force push", "--no-verify", "gpgsign", "deny list", "protected branch"):
        assert needle not in options, needle


def test_the_grant_options_only_narrow():
    options = (MODULE_DIR / "options.nix").read_text(encoding="utf-8")
    block = re.search(r"\n    grants = \{(.*?)\n    \};", options, re.S)
    assert block, "grants block missing"
    assert re.findall(r"^\s{6}([A-Za-z_][A-Za-z0-9_]*) = mkOption", block.group(1), re.M) == [
        "repoCeiling",
        "budget",
    ]


def test_the_floor_reads_no_configuration():
    """No option can re-enable the floor because the floor looks at no configuration at all."""
    for fn in (
        permissions.check_git_argv,
        permissions.check_shell_command,
        permissions.secret_paths,
        permissions.protected_branch,
    ):
        source = inspect.getsource(fn)
        for needle in ("os.environ", "getenv", "settings", "cfg."):
            assert needle not in source, f"{fn.__name__} consults {needle}"


# --- the report both entry points share ---------------------------------------------


def test_the_report_carries_the_floor_for_both_entry_points():
    runtime = _StubRuntime()
    payload = red_team.run_red_team_checks(runtime).to_dict()
    floor = [r for r in payload["results"] if r["name"].startswith("floor.")]
    assert payload["ok"] is True and len(floor) == len(red_team.run_floor_checks())
    assert runtime.calls, "the guard half still runs against the runtime"

    for source in ("cli/cli.py", "widgets/pages.py"):
        text = (MODULE_DIR / source).read_text(encoding="utf-8")
        assert "run_red_team_checks" in text, source


def test_the_report_can_actually_go_red():
    """A security pack that cannot fail is decoration: a mutating call must break it."""
    payload = red_team.run_red_team_checks(_StubRuntime(blocked=False)).to_dict()
    assert payload["ok"] is False
    assert payload["failed"] and payload["passed"], payload["failed"]


def test_the_floor_probes_spawn_nothing():
    """These cases run from the GUI; a probe that shelled out would commit or push for real."""
    with mock.patch.object(subprocess, "run") as runner:
        results = red_team.run_floor_checks()
    assert all(r.passed for r in results)
    assert runner.called is False, runner.call_args_list


if __name__ == "__main__":
    pytest.main([__file__, "-q"])
