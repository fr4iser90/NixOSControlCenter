"""Phase 39 L15 (Nix): a unit's confirm may only ask more, in eval and in the shell.

Two layers widen a timer by accident, and both are checked here on the real sources:

* ``schedules.nix`` resolves the value the unit is handed (``effectiveConfirm``) and reports a
  schedule that asks for less than the host declared;
* ``package.nix`` inlines ``envExports`` into every wrapper *after* systemd applied
  ``Environment=``, so an unconditional ``export AGENT_CONFIRM=…`` would overwrite whatever the
  unit declared — which is how a schedule ended up running ``never`` and skipping the prompts
  its own grant exists to answer.

confirm narrows toward ``always``, the opposite direction to the permission ladder, so neither
check may borrow the ladder's ranks: the shell clamp asks for a rank of its own.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "ncc-assistant"))

from test_schedule_grant_ceiling_v1 import _eval, host, says, sched  # noqa: E402

PACKAGE = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "package.nix"
SCHEDULES = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "schedules.nix"
OPTIONS = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "options.nix"

WARNINGS = "(flatten out.config).warnings or [ ]"
UNIT_CONFIRM = """
let
  svc = (flatten out.config).systemd.services or { };
  u = svc."ncc-assistant-schedule-%(unit)s" or { environment = { }; };
in u.environment.AGENT_CONFIRM or "unset"
"""


def confirm_of(cfg: str, unit: str = "s") -> str:
    return _eval(cfg, UNIT_CONFIRM % {"unit": unit}, f"unit {unit} confirm")


def warns(cfg: str, case: str) -> list[str]:
    return _eval(cfg, WARNINGS, case)


# --- the value the unit is handed -------------------------------------------------------


def test_an_unset_schedule_inherits_the_host_mode():
    cfg = host("{ s = %s; }" % sched(goal='"g"'))
    assert confirm_of(cfg) == "writes"


def test_a_host_declaring_another_mode_reaches_the_unit():
    cfg = host("{ s = %s; }" % sched(goal='"g"'), agentConfirm='"never"')
    assert confirm_of(cfg) == "never"


def test_a_schedule_asking_more_keeps_its_narrower_mode():
    """always asks per tool, so it is the narrower value and must survive."""
    cfg = host("{ s = %s; }" % sched(goal='"g"', confirm='"always"'))
    assert confirm_of(cfg) == "always"


def test_a_schedule_asking_less_is_clamped_to_the_host():
    cfg = host("{ s = %s; }" % sched(goal='"g"', confirm='"never"'))
    assert confirm_of(cfg) == "writes"


def test_the_direction_holds_on_an_always_host():
    """Host always: writes is wider, so it is refused; never stays refused too."""
    for asked in ("writes", "never"):
        cfg = host(
            "{ s = %s; }" % sched(goal='"g"', confirm=f'"{asked}"'), agentConfirm='"always"'
        )
        assert confirm_of(cfg) == "always", f"{asked} widened a host that declared always"


# --- the disagreement is reported -------------------------------------------------------


def test_a_wider_ask_than_the_host_is_a_warning():
    cfg = host("{ s = %s; }" % sched(goal='"g"', confirm='"never"'))
    got = warns(cfg, "wider ask")
    assert says(got, "asks confirm=never"), got
    assert says(got, "agent.confirm=writes"), got


def test_a_narrower_ask_says_nothing():
    cfg = host("{ s = %s; }" % sched(goal='"g"', confirm='"always"'))
    assert warns(cfg, "narrower ask") == []


def test_the_default_host_still_says_nothing():
    """The axis may not turn every existing host into a warning."""
    cfg = host("{ s = %s; }" % sched(goal='"g"'))
    assert warns(cfg, "default host") == []


def test_a_disabled_unit_is_not_reported():
    cfg = host("{ s = %s; }" % sched(goal='"g"', enable="false", confirm='"never"'))
    assert warns(cfg, "disabled unit") == []


# --- argv: the value that cannot be overwritten -----------------------------------------


def _agent_args() -> str:
    """The argv block of mkAgentExec — what the unit execs, verbatim from the source."""
    text = SCHEDULES.read_text(encoding="utf-8")
    start = text.index("agentArgs = [")
    return text[start : text.index("pkgs.writeShellScript", start)]


def test_the_run_is_handed_its_confirm_as_argv():
    """The wrapper's exports run after systemd's, so only argv cannot be widened later."""
    args = _agent_args()
    assert '"--confirm"' in args, args
    assert "(effectiveConfirm schedule)" in args, "argv must carry the resolved value, not the ask"


def test_the_unit_also_declares_the_mode_for_its_children():
    text = SCHEDULES.read_text(encoding="utf-8")
    assert "AGENT_CONFIRM = effectiveConfirm schedule;" in text


def test_the_schedule_module_declares_the_option_as_null_default():
    text = OPTIONS.read_text(encoding="utf-8")
    option = text.split("      confirm = mkOption {", 1)[1].split("};", 1)[0]
    assert 'default = null;' in option, "a non-null default would overwrite the host everywhere"
    assert '"always" "writes" "never"' in " ".join(option.split())


# --- the wrapper clamp, evaluated and sourced --------------------------------------------

HELPER_START = "narrowConfirmExport = name: hostValue:"


def _helper_text() -> str:
    text = PACKAGE.read_text(encoding="utf-8")
    start = text.index(HELPER_START)
    end = text.index("\n    '';", start)
    return text[start : end + len("\n    '';")]


def _render(host_value: str) -> str:
    nix = (
        "let\n"
        "  lib = (import <nixpkgs> { }).lib;\n"
        f"  {_helper_text()}\n"
        f'in {{ s = narrowConfirmExport "AGENT_CONFIRM" "{host_value}"; }}\n'
    )
    path = Path("/tmp/ncc-narrow-confirm.nix")
    path.write_text(nix, encoding="utf-8")
    out = subprocess.run(
        ["nix", "eval", "--impure", "--raw", "--file", str(path), "s"],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout


def _sourced(host_value: str, inherited: str | None) -> str:
    script = Path("/tmp/ncc-narrow-confirm.sh")
    script.write_text(_render(host_value) + "\n", encoding="utf-8")
    pre = (
        "unset AGENT_CONFIRM"
        if inherited is None
        else f"export AGENT_CONFIRM={inherited}"
    )
    out = subprocess.run(
        ["bash", "-c", f'{pre}; source "{script}"; echo "$AGENT_CONFIRM"'],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout.strip()


def test_the_wrapper_no_longer_hard_assigns_the_mode():
    text = PACKAGE.read_text(encoding="utf-8")
    assert 'narrowConfirmExport "AGENT_CONFIRM"' in text
    assert 'export AGENT_CONFIRM="' not in text, "the wrapper would overwrite every unit value"


def test_unset_env_gets_the_host_mode():
    assert _sourced("writes", None) == "writes"
    assert _sourced("always", None) == "always"


def test_a_unit_asking_more_survives_the_wrapper():
    assert _sourced("writes", "always") == "always"
    assert _sourced("never", "writes") == "writes"
    assert _sourced("never", "always") == "always"


def test_a_unit_asking_less_is_pushed_back_to_the_host():
    assert _sourced("writes", "never") == "writes", "a timer skipped the prompts its grant answers"
    assert _sourced("always", "writes") == "always"
    assert _sourced("always", "never") == "always"


def test_an_unknown_value_falls_back_instead_of_trusting_the_caller():
    assert _sourced("writes", "occasionally") == "writes"
    assert _sourced("writes", "") == "writes"


def test_the_shell_rank_is_not_the_ladder_rank():
    """confirm narrows toward always; a ladder step narrows toward none. Opposite tables."""
    from core.policy.permissions import SYSTEM_STEPS, confirm_rank

    assert confirm_rank("always") < confirm_rank("never")
    assert SYSTEM_STEPS[0] == "none" and SYSTEM_STEPS[-1] == "rebuild"


def test_no_deployed_test_file_lives_under_nixos():
    """A test under nixos/** would deploy to every host — this suite stays in repo-root tests/."""
    stray = list((REPO / "nixos").rglob("test_*.py"))
    assert stray == [], stray
