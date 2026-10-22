"""A grant the run can never spend is a config error, not a quiet no-op.

Phase 39 L14. Two ceilings and one opener decide what a scheduled run may do:

* the system ceiling is the **lower** of the host pair (``allowWrite``/``allowRebuild``) and
  the agent pair (``agent.allowWrite``/``agent.allowRebuild``) — exactly what
  ``permissions.resolve_run_grant`` computes at runtime;
* the **profile** is what opens the write/rebuild tools. ``resolve_profile`` keeps a profile's
  built-in flags unless the grant lowers them and nothing raises them, so a grant above the
  profile's reach is a step the ladder approves and the tool catalog cannot perform.

Both disagreements are caught at evaluation. So is the display trap that hid them: a submodule
option the host never set is ``null`` rather than missing, and ``attrs.x or "-"`` does not
cover that — interpolating it aborts evaluation instead of warning, which is what the warning
was for.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

SCHEDULES_NIX = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "schedules.nix"
MODULE_MANAGER = REPO / "nixos" / "core" / "management" / "module-manager"

# schedules.nix is not a NixOS module: call it with the same shape the flake's specialArgs
# hand it. mkIf/mkMerge leave deferred { _type = "if" | "merge"; } records behind, so warnings
# and unit env only appear after flattening condition/content/contents.
TEMPLATE = """
let
  pkgs = import <nixpkgs> { };
  cfg = %(cfg)s;
  ui = { messages = { warning = m: "echo w"; info = m: "echo i"; loading = m: "echo l"; }; };
  out = import %(module)s {
    inherit pkgs cfg;
    lib = pkgs.lib;
    config = { users.users = { }; };
    systemConfig = { };
    getModuleConfig = _: cfg;
    getModuleApi = _: ui;
    # Reading a unit's environment forces pkg, whose domain-tool discovery needs the real
    # module-manager path — a {} stub dies on mm.path.
    getModuleMetadata = name: { path = "%(mm)s/" + name; };
  };
  flatten = v:
    if builtins.isList v then map flatten v
    else if !(builtins.isAttrs v) then v
    else if v ? _type && v._type == "if" then
      (if v.condition then flatten v.content else { })
    else if v ? _type && v._type == "merge" then
      builtins.foldl' (a: b: a // flatten b) { } v.contents
    else builtins.mapAttrs (_: flatten) v;
in
%(expr)s
"""

WARNINGS = "(flatten out.config).warnings or [ ]"

# Selecting the scalars keeps evaluation lazy: returning the whole environment attrset forces
# "${pkg.appRoot}" and Nix tries to build the package instead of answering.
UNIT_ENV = """
let
  svc = (flatten out.config).systemd.services or { };
  u = svc."ncc-assistant-schedule-%(unit)s" or { environment = { }; };
in {
  write = u.environment.AGENT_ALLOW_WRITE or "unset";
  rebuild = u.environment.AGENT_ALLOW_REBUILD or "unset";
}
"""


def _eval(cfg: str, expr: str, case: str):
    nix = TEMPLATE % {"cfg": cfg, "module": str(SCHEDULES_NIX), "mm": str(MODULE_MANAGER), "expr": expr}
    path = Path("/tmp/ncc-schedule-grant-eval.nix")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(nix, encoding="utf-8")
    proc = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", str(path)],
        capture_output=True,
        text=True,
    )
    # An evaluation error must fail the test, never read as "no warnings".
    assert proc.returncode == 0, f"{case}: eval failed\n{proc.stderr[-1200:]}"
    return json.loads(proc.stdout)


def sched(**over) -> str:
    """Schedule attrs carrying options.nix's submodule defaults.

    schedules.nix reads ``schedule.model``/``maxSteps``/``dryRun``/``profile`` unguarded, so a
    bare attrs stub fails where a real host cannot — and hides the present-but-null case the
    display fix is about.
    """
    base = {
        "enable": "true",
        "onCalendar": '"daily"',
        "after": "null",
        "persistent": "true",
        "goal": "null",
        "playbook": "null",
        "kind": '"agent"',
        "probe": "null",
        "thresholdPct": "85",
        "escalatePlaybook": '"disk-nix-gc-advisor"',
        "maxSteps": "null",
        "allowWrite": "null",
        "allowRebuild": "null",
        "dryRun": "null",
        "profile": "null",
        "permissions": "{ repo = null; system = null; budget = { }; }",
        "model": "null",
    }
    base.update(over)
    return "{ " + " ".join(f"{k} = {v};" for k, v in base.items()) + " }"


def perms(**over) -> str:
    base = {"repo": "null", "system": "null", "budget": "{ }"}
    base.update(over)
    return "{ " + " ".join(f"{k} = {v};" for k, v in base.items()) + " }"


def host(schedules: str = "{}", **over) -> str:
    o = {
        "allowWrite": "true",
        "allowRebuild": "false",
        "repoCeiling": '"pr"',
        "agentAllowWrite": "false",
        "agentAllowRebuild": "false",
        "agentProfile": '"read-only"',
        "agentDryRun": "false",
    }
    o.update(over)
    return f"""{{
  enable = true;
  allowWrite = {o["allowWrite"]};
  allowRebuild = {o["allowRebuild"]};
  model = null;
  grants = {{ repoCeiling = {o["repoCeiling"]}; budget = {{ }}; }};
  agent = {{
    enable = true;
    allowWrite = {o["agentAllowWrite"]};
    allowRebuild = {o["agentAllowRebuild"]};
    dryRun = {o["agentDryRun"]};
    profile = {o["agentProfile"]};
    confirm = "writes";
    maxSteps = -1;
    schedules = {schedules};
  }};
}}"""


def warnings_for(cfg: str, case: str) -> list[str]:
    return _eval(cfg, WARNINGS, case)


def says(warnings: list[str], needle: str) -> bool:
    return any(needle in w for w in warnings)


PROFILES_WITH_REACH = ("chat", "read-only", "config-writer", "cautious", "ops", "autonomous")


# --- the profile is the opener ---------------------------------------------------------


def test_a_grant_above_its_profile_is_called_out():
    """read-only cannot open writes, however the ladder ranks the grant."""
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"read-only"', permissions=perms(system='"config-write"')),
        agentAllowWrite="true",
    )
    got = warnings_for(cfg, "profile above reach")
    assert says(got, "which reaches"), got


def test_a_profile_that_reaches_its_grant_says_nothing():
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"config-writer"', permissions=perms(system='"config-write"')),
        agentAllowWrite="true",
    )
    assert warnings_for(cfg, "profile at reach") == []


def test_the_aliases_resolve_to_their_profile_and_not_to_nothing():
    """profiles.py resolves cautious/autonomous; the check may not read them as unknown."""
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"autonomous"', permissions=perms(system='"rebuild"')),
        agentAllowRebuild="true",
        allowRebuild="true",
    )
    assert warnings_for(cfg, "alias reaches") == []


def test_an_unknown_profile_name_costs_its_writes():
    """resolve_profile falls back to read-only, so a typo must be loud, not silently accepted."""
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"readonly"', permissions=perms(system='"config-write"')),
        agentAllowWrite="true",
    )
    assert says(warnings_for(cfg, "unknown profile"), "which reaches")


def test_the_alias_names_are_not_in_the_step_derivation():
    """profileStepMap derives the steps a unit is handed: widening it would grant more, not warn."""
    nix = SCHEDULES_NIX.read_text(encoding="utf-8")
    block = nix.split("profileStepMap = {", 1)[1].split("};", 1)[0]
    for alias in ("cautious", "autonomous"):
        assert alias not in block, f"{alias} in profileStepMap would widen derived grants"


# --- the ceiling is the lower of the two pairs -----------------------------------------


def test_agent_knobs_above_a_closed_host_pair_are_an_inversion():
    cfg = host(agentAllowWrite="true", allowWrite="false")
    assert says(warnings_for(cfg, "write inversion"), "agent.allowWrite = true cannot open")


def test_rebuild_knobs_above_a_closed_host_pair_are_an_inversion():
    cfg = host(agentAllowRebuild="true", allowRebuild="false")
    assert says(warnings_for(cfg, "rebuild inversion"), "agent.allowRebuild = true cannot open")


def test_the_default_host_says_nothing():
    """The min must not turn every existing host into a warning."""
    cfg = host("{ s = %s; }" % sched(goal='"g"'))
    assert warnings_for(cfg, "default host") == []


def test_a_derived_grant_cannot_claim_writes_the_host_pair_denied():
    """The path the ceiling fix closes: config-writer derives config-write, the host pair says none."""
    derived = sched(goal='"g"', profile='"config-writer"')
    closed = _eval(
        host("{ s = %s; }" % derived, agentAllowWrite="true", allowWrite="false"),
        UNIT_ENV % {"unit": "s"},
        "derived on closed host",
    )
    assert closed["write"] == "0", closed


def test_an_open_host_pair_keeps_the_derived_write_export():
    derived = sched(goal='"g"', profile='"config-writer"')
    open_host = _eval(
        host("{ s = %s; }" % derived, agentAllowWrite="true", allowWrite="true"),
        UNIT_ENV % {"unit": "s"},
        "derived on open host",
    )
    assert open_host["write"] == "1", open_host


def test_the_default_unit_exports_neither_write_nor_rebuild():
    env = _eval(
        host("{ s = %s; }" % sched(goal='"g"')),
        UNIT_ENV % {"unit": "s"},
        "default unit",
    )
    assert (env["write"], env["rebuild"]) == ("0", "0"), env


# --- an ask above the ceiling still refuses loudly --------------------------------------


def test_an_explicit_ask_above_the_ceiling_warns_and_stays_as_asked():
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"config-writer"', permissions=perms(system='"config-write"')),
        agentAllowWrite="true",
        allowWrite="false",
    )
    got = warnings_for(cfg, "explicit above ceiling")
    assert says(got, "above this host's ceiling"), got
    # Loud refusal, not a quiet downgrade: the unit still carries the step it asked for.
    env = _eval(cfg, UNIT_ENV % {"unit": "s"}, "explicit above ceiling env")
    assert env["write"] == "1", env


def test_the_conflict_message_survives_unset_repo():
    """A host that only sets permissions.system leaves repo present-but-null.

    ``perms.repo or "-"`` returns that null — `or` covers a missing attribute only — so the
    message meant to explain the config error aborted evaluation with "cannot coerce null to
    a string" instead.
    """
    cfg = host(
        "{ s = %s; }" % sched(goal='"g"', profile='"config-writer"', permissions=perms(system='"rebuild"')),
        agentAllowWrite="true",
        allowWrite="false",
    )
    got = warnings_for(cfg, "unset repo displayed")
    ceiling_case = [w for w in got if "above this host's ceiling" in w]
    assert ceiling_case, got
    assert "repo=- system=rebuild" in ceiling_case[0], ceiling_case[0]


@pytest.mark.parametrize("name", PROFILES_WITH_REACH)
def test_every_known_profile_is_listed_once(name: str):
    nix = SCHEDULES_NIX.read_text(encoding="utf-8")
    block = nix.split("profileSystemReach = {", 1)[1].split("};", 1)[0]
    assert f'{name} = "' in block or f'"{name}" = "' in block, (name, block)
