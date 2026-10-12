"""Phase 39 L2: the wrapper may narrow a run's write gates, never widen them.

Non-gate values (model) follow the other half of the same rule from plan 39 §1 — envExports
exports defaults, not verdicts, so what a schedule unit declared survives the wrapper."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PACKAGE = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "package.nix"
SCHEDULES = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "schedules.nix"
TEXT = PACKAGE.read_text(encoding="utf-8")

# Names a schedule unit sets and that the wrapper also exports: without a `:-` default the
# wrapper (inlined into every entry point) overwrites the unit value.
GATE_NAMES = (
    "AGENT_ALLOW_WRITE",
    "AGENT_ALLOW_REBUILD",
    "NCC_ASSISTANT_AGENT_ALLOW_WRITE",
    "NCC_ASSISTANT_AGENT_ALLOW_REBUILD",
)

HELPER_RE = re.compile(
    r"narrowBoolExport = name: hostValue:\n\s+(if hostValue then.+?);\n"
)


def _helper_line() -> str:
    match = HELPER_RE.search(TEXT)
    assert match, "narrowBoolExport helper missing from package.nix"
    return match.group(1)


def _render(host_allows: bool) -> str:
    """Evaluate the real helper text out of package.nix."""
    nix = (
        "let\n"
        f"  narrowBoolExport = name: hostValue:\n    {_helper_line()};\n"
        'in { on = narrowBoolExport "GATE" true; off = narrowBoolExport "GATE" false; }\n'
    )
    path = Path("/tmp/ncc-narrow-export.nix")
    path.write_text(nix, encoding="utf-8")
    out = subprocess.run(
        ["nix", "eval", "--impure", "--raw", "--file", str(path), "on" if host_allows else "off"],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout


def _sourced(host_allows: bool, inherited: str | None) -> str:
    line = _render(host_allows).replace("GATE", "NCC_TEST_GATE")
    script = Path("/tmp/ncc-narrow-env.sh")
    script.write_text(line + "\n", encoding="utf-8")
    pre = "unset NCC_TEST_GATE" if inherited is None else f"export NCC_TEST_GATE={inherited}"
    out = subprocess.run(
        ["bash", "-c", f'{pre}; source "{script}"; echo "$NCC_TEST_GATE"'],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout.strip()


def test_every_write_gate_uses_the_narrow_helper():
    for name in GATE_NAMES:
        assert f'narrowBoolExport "{name}"' in TEXT, f"{name} is not narrowed via the helper"
        assert f'export {name}="' not in TEXT, f"{name} is still hard-assigned by the wrapper"


def test_host_false_stays_a_hard_zero():
    assert _render(False) == 'export GATE="0"'


def test_host_true_lets_the_unit_narrow():
    assert _render(True) == 'export GATE="${GATE:-1}"'


def test_unit_env_narrows_but_inherited_env_cannot_widen():
    assert _sourced(True, None) == "1"
    assert _sourced(True, "0") == "0"
    assert _sourced(False, None) == "0"
    assert _sourced(False, "1") == "0", "an inherited value widened a closed host gate"


def test_schedule_units_actually_set_those_gates():
    """A narrow default is pointless if the unit never sets the value it is meant to respect."""
    schedules = SCHEDULES.read_text(encoding="utf-8")
    unit_env = re.search(r"      environment = \{\n(.*?)\n      \}", schedules, re.S)
    assert unit_env, "schedule unit env not found"
    set_by_unit = set(re.findall(r"^\s+([A-Z0-9_]+) =", unit_env.group(1), re.M))
    missing = [name for name in GATE_NAMES if name not in set_by_unit]
    assert not missing, f"grant-derived gate env not exported by the unit: {missing}"


# A model is not a permission: the host value is a default, so the unit's own model must win
# here instead of being clamped.
DEFAULT_NAMES = ("NCC_ASSISTANT_MODEL",)
RESPECT_RE = re.compile(r"^  (respectUnitExport = name: defaultValue: .+;)$", re.M)


def _respect_binding() -> str:
    match = RESPECT_RE.search(TEXT)
    assert match, "respectUnitExport helper missing from package.nix"
    return match.group(1).rstrip(";")


def _render_default(host_value: str) -> str:
    """Evaluate the real helper text out of package.nix."""
    nix = (
        "let\n"
        f"  {_respect_binding()};\n"
        f'in {{ d = respectUnitExport "GATE" "{host_value}"; }}\n'
    )
    path = Path("/tmp/ncc-respect-export.nix")
    path.write_text(nix, encoding="utf-8")
    out = subprocess.run(
        ["nix", "eval", "--impure", "--raw", "--file", str(path), "d"],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout


def _sourced_default(inherited: str | None) -> str:
    line = _render_default("host-model").replace("GATE", "NCC_TEST_DEFAULT")
    script = Path("/tmp/ncc-respect-env.sh")
    script.write_text(line + "\n", encoding="utf-8")
    pre = "unset NCC_TEST_DEFAULT" if inherited is None else f"export NCC_TEST_DEFAULT={inherited}"
    out = subprocess.run(
        ["bash", "-c", f'{pre}; source "{script}"; echo "$NCC_TEST_DEFAULT"'],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout.strip()


def test_per_unit_defaults_use_the_default_helper():
    for name in DEFAULT_NAMES:
        assert f'respectUnitExport "{name}"' in TEXT, f"{name} is not defaulted via the helper"
        assert f'export {name}="' not in TEXT, f"{name} is still hard-assigned by the wrapper"


def test_host_model_is_only_a_default():
    assert _render_default("host-model") == 'export GATE="${GATE:-host-model}"'


def test_unit_model_survives_the_wrapper():
    assert _sourced_default(None) == "host-model"
    assert _sourced_default("unit-model") == "unit-model", "the wrapper overwrote the unit's model"


def test_schedule_units_actually_set_the_model():
    schedules = SCHEDULES.read_text(encoding="utf-8")
    assert re.search(r"^\s+NCC_ASSISTANT_MODEL = schedule\.model;$", schedules, re.M), (
        "no schedule sets its own model — respecting one would be untested in the unit"
    )
