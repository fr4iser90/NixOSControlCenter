"""A timer that runs as root is not a run as you — it is a root process wearing your HOME.

``agent.runAsUser`` decides *which account a schedule's commands carry*. Three separate things
rest on that, and each is checked here on the real module rather than on a description of it:

* a read-only run gets ``User=`` and stops holding root credentials while reading your repos;
* git compares the process uid against the repository owner, so under root every workspace
  read is a "dubious ownership" refusal — the poll guard calls that ``unknown`` and ``unknown``
  is a deny, which is how a schedule silently lost the very thing it was scheduled for;
* a run whose resolved grant reaches ``system=config-write`` is the one case root is *kept*
  (/etc/nixos and nixos-rebuild both need it), and keeping it is only honest if the evaluation
  says so — otherwise the host reads "everything is unprivileged" while one unit holds root.

A declared account that no ``users.users`` entry backs is refused outright: it would give every
unit a ``User=`` systemd refuses to start, so the failure would surface on the timer at 04:00
instead of on the line that named the account.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCHEDULES_NIX = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "schedules.nix"
MODULE_MANAGER = REPO / "nixos" / "core" / "management" / "module-manager"
SYSTEM_MANAGER = REPO / "nixos" / "core" / "management" / "system-manager"
PACKAGE_NIX = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "package.nix"

# Same shape the flake's specialArgs hand the module. schedules.nix is not a NixOS module, and
# mkIf/mkMerge leave deferred records behind, so the units only appear after flattening.
# users.users is a parameter here rather than the empty set the other harnesses use: the whole
# option is about an account that must resolve.
#
# The four builders are replaced by text. `writeShellScript name text = text` is what makes the
# script a unit carries as ExecStart/ExecStartPost projectable as a string, which is the only way to
# read the generated wake line without building gui-engine and module-manager first. The
# substitution decides what a store path looks like and nothing else: the "+", the runuser drop and
# the PATH line are composed by schedules.nix and package.nix themselves.
PRELUDE = """
let
  realPkgs = import <nixpkgs> { };
  pkgs = realPkgs // {
    writeShellScript = name: text: text;
    writeShellScriptBin = name: text: "/fake-bin/${name}";
    writeText = name: text: "/fake-text/${name}";
    runCommand = name: args: script: "/fake/${name}";
    python3 = realPkgs.python3 // { withPackages = f: "/fake/python-env"; };
    makeDesktopItem = a: "/fake/desktop-item";
  };
  cfg = %(cfg)s;
  say = tag: m: "echo ${tag}";
  ui = {
    messages = {
      warning = say "w";
      info = say "i";
      loading = say "l";
      success = say "s";
      error = say "e";
    };
    text = { header = say "h"; };
  };
  modulePaths = {
    module-manager = "%(mm)s";
    system-manager = "%(sm)s";
  };
  api = name:
    if name == "cli-formatter"
    then ui
    else { package = _: { src = "/fake-src"; }; };
  metadata = name: { path = modulePaths.${name} or (throw "unmapped module ${name}"); };
"""

FLATTEN = """
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

# package.nix is a plain attrset, not a module — no deferred records to flatten.
PKG_BODY = """
in
%(expr)s
"""

TEMPLATE = (
    PRELUDE
    + """
  out = import %(module)s {
    inherit pkgs cfg;
    lib = realPkgs.lib;
    config = { users.users = %(users)s; };
    systemConfig = { };
    getModuleConfig = _: cfg;
    getModuleApi = api;
    getModuleMetadata = metadata;
  };
"""
    + FLATTEN
)

# package.nix takes five arguments and no `...`, so it cannot share the module-shaped call above.
PKG_TEMPLATE = (
    PRELUDE
    + """
  out = import %(module)s {
    inherit pkgs cfg;
    lib = realPkgs.lib;
    getModuleApi = api;
    getModuleMetadata = metadata;
  };
"""
    + PKG_BODY
)

# Only scalars: returning a unit's whole serviceConfig forces "${pkg.appRoot}" and Nix tries to
# build the package instead of answering.
UNIT_VIEW = """
let
  svc = (flatten out.config).systemd.services or { };
  u = svc."ncc-assistant-schedule-%(unit)s" or { environment = { }; serviceConfig = { }; };
  c = u.serviceConfig;
in {
  user = c.User or "-";
  post = if c ? ExecStartPost then "yes" else "-";
}
"""

# The generated wake script itself. Both lines are read, because the claim is about the pair:
# ExecStart keeps every restriction while ExecStartPost is the one line systemd lifts.
WAKE_VIEW = """
let
  svc = (flatten out.config).systemd.services or { };
  u = svc."ncc-assistant-schedule-%(unit)s" or { serviceConfig = { }; };
  c = u.serviceConfig;
in {
  user = c.User or "-";
  start = c.ExecStart or "-";
  post = c.ExecStartPost or "-";
}
"""

# The env script a schedule's run inherits, with the three tool directories it has to carry.
# Resolved store paths come back next to the text so the assertion is about this evaluation, not
# about a spelling in package.nix.
PATH_VIEW = """
{
  env = out.envExports;
  gh = "${pkgs.gh}/bin";
  git = "${pkgs.git}/bin";
  uv = "${pkgs.uv}/bin";
}
"""

WARNINGS = "(flatten out.config).warnings or [ ]"
ASSERTIONS = "map (a: a.assertion) (flatten out.config).assertions or [ ]"

USER = "alice"
HOME = "/home/alice"
SCHEDULES_WITH_USER = f'{{ {USER} = {{ home = "{HOME}"; isNormalUser = true; }}; }}'


def _eval(
    cfg: str,
    expr: str,
    case: str,
    users: str = SCHEDULES_WITH_USER,
    module: Path = SCHEDULES_NIX,
    template: str = TEMPLATE,
) -> object:
    nix = template % {
        "module": str(module),
        "mm": str(MODULE_MANAGER),
        "sm": str(SYSTEM_MANAGER),
        "cfg": cfg,
        "users": users,
        "expr": expr,
    }
    path = Path("/tmp/ncc-run-as-user-eval.nix")
    path.write_text(nix, encoding="utf-8")
    proc = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", str(path)],
        capture_output=True,
        text=True,
    )
    # An evaluation error must fail the test, never read as "nothing to report".
    assert proc.returncode == 0, f"{case}: eval failed\n{proc.stderr[-1500:]}"
    return json.loads(proc.stdout)


def sched(**over) -> str:
    """A schedule carrying options.nix's submodule defaults — a bare attrs stub dies on the
    unguarded reads and skips the present-but-null case a real host produces."""
    base = {
        "enable": "true",
        "onCalendar": '"daily"',
        "after": "null",
        "persistent": "true",
        "goal": '"audit"',
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
        "confirm": "null",
        "permissions": "{ repo = null; system = null; budget = { }; }",
        "model": "null",
    }
    base.update(over)
    return "{ " + " ".join(f"{k} = {v};" for k, v in base.items()) + " }"


def host(run_as_user: str = "null", schedules: str = "{ nightly = %s; }" % sched()) -> str:
    return f"""{{
  enable = true;
  allowWrite = true;
  allowRebuild = false;
  model = null;
  grants = {{ repoCeiling = "pr"; budget = {{ }}; }};
  agent = {{
    enable = true;
    allowWrite = false;
    allowRebuild = false;
    dryRun = false;
    profile = "read-only";
    confirm = "writes";
    maxSteps = -1;
    runAsUser = {run_as_user};
    schedules = {schedules};
  }};
}}"""


def view(cfg: str, case: str, unit: str = "nightly") -> dict:
    return _eval(cfg, UNIT_VIEW % {"unit": unit}, case)


def says(cfg: str, case: str, needle: str) -> bool:
    return any(needle in w for w in _eval(cfg, WARNINGS, case))


# --- the account lands on the unit ---------------------------------------------------------


def test_a_read_only_schedule_runs_as_the_declared_account():
    got = view(host(f'"{USER}"'), "declared account")
    assert got["user"] == USER, got


def test_an_undeclared_runAsUser_leaves_the_unit_root_as_before():
    # null is today's behaviour, and it has to stay exactly that: a host that never set the
    # option must not find its timers unprivileged by an unrelated edit.
    assert view(host("null"), "option unset")["user"] == "-"


# --- the two cases where the account is deliberately not applied ---------------------------


def test_a_schedule_that_writes_the_host_keeps_root_and_says_so():
    cfg = host(
        f'"{USER}"',
        "{ nightly = %s; }" % sched(
            permissions='{ repo = "pr"; system = "config-write"; budget = { }; }'
        ),
    )
    assert view(cfg, "write grant")["user"] == "-", (
        "config-write needs root for /etc/nixos and nixos-rebuild; dropping it would fail the "
        "write the schedule's own grant authorised"
    )
    # Root kept silently is root unreported: the host would otherwise read "every run is
    # unprivileged" while this one still holds root credentials.
    assert says(cfg, "write grant", "keeps running as root")
    assert says(cfg, "write grant", USER), "the warning must name the account that went unused"


# --- a name that resolves to nobody is a config error, not a 04:00 surprise ----------------


def test_an_account_that_does_not_exist_is_refused_at_evaluation():
    cfg = host('"ghost"')
    flags = _eval(cfg, ASSERTIONS, "ghost account", users="{ }")
    assert False in flags, (
        "a User= systemd cannot resolve starts no unit at all — evaluation has to refuse the "
        "name on the spot instead of leaving it to the timer"
    )


def test_the_same_name_is_accepted_once_the_account_exists():
    assert all(_eval(host(f'"{USER}"'), ASSERTIONS, "known account")), "the guard must not fire on a real account"


# --- gh, git and uv are dependencies, not weather -------------------------------------------


def test_the_wrapper_puts_gh_git_and_uv_on_the_path_of_every_run():
    """Read out of the generated env script, not out of package.nix.

    workflows.py and cli/workspace_lifecycle.py call gh (5 sites), poll_guard/permissions/
    workspaces call git, and three of the four packaged MCP templates name ``uvx`` as their
    command. A host whose environment happens to carry git hides that the dependency was never
    stated; on one that does not, every GitHub verb dies with "gh CLI not on PATH" in a run that
    looked correctly configured. What has to be true is what the script the run inherits says —
    spelling in package.nix proves nothing, since the line could sit in a branch nothing reads.
    """
    got = _eval(
        host(f'"{USER}"'),
        PATH_VIEW,
        "wrapper PATH",
        module=PACKAGE_NIX,
        template=PKG_TEMPLATE,
    )
    line = next((ln for ln in got["env"].splitlines() if ln.startswith("export PATH=")), "")
    assert line, "the env script the run inherits carries no PATH export at all"
    for tool in ("gh", "git", "uv"):
        assert got[tool] in line, f"{tool} is not on the PATH a scheduled run inherits: {line}"


# --- the wake line: root for systemctl only, never for the audit it writes ------------------


def _chain() -> str:
    """Two schedules where the first one owns a dependent: only ``prep`` gets a wake line."""
    return "{ prep = %s; nightly = %s; }" % (sched(), sched(after='"prep"'))


def test_the_wake_line_lifts_only_itself_and_drops_back_for_the_decision():
    """Every part of this is read off the generated ``ExecStartPost``.

    * ``+`` (systemd.service(5)) lifts this one line back to root, because a plain account may not
      ask systemd to start a sibling unit — while ``ExecStart=`` keeps every restriction, so the
      agent's own shell tools still never get systemctl;
    * the decision itself is asked through ``runuser``: ``chain release`` appends to audit.jsonl,
      and a root-owned audit file inside the account it was meant to stop impersonating would lock
      the GUI out of the history this run made.
    """
    got = _eval(host(f'"{USER}"', _chain()), WAKE_VIEW % {"unit": "prep"}, "wake line")
    assert got["user"] == USER, got
    post = got["post"]

    assert post.startswith("+"), (
        "without the prefix a chained schedule cannot wake anything once its run is unprivileged: "
        f"{post[:120]!r}"
    )
    assert f"runuser -u {USER} -- " in post, (
        "without the drop, the wake line writes root-owned audit lines into the run's own home: "
        f"{post[:200]!r}"
    )
    assert "chain release --schedule" in post, "the wake must ask the decision, not assume it"
    assert (
        "systemctl --no-block start ncc-assistant-schedule-nightly.service" in post
    ), "the dependent the chain names has to be the one the line starts"

    # The lift belongs to this line alone. ExecStart carrying "+" would hand the agent's own shell
    # tools root, which is the whole capability boundary this option exists to keep.
    assert not got["start"].startswith("+"), "ExecStart= must keep every restriction"
    assert "systemctl" not in got["start"], "the run itself must never be able to wake a unit"


def test_the_root_run_needs_neither_the_lift_nor_the_drop():
    """Undeclared ``runAsUser``: the unit is already root, so both halves must stay absent.

    A ``+`` here would be a no-op that reads like a boundary, and ``runuser`` would drop the wake
    below the root the schedule was granted — silently un-waking the chain on every host that never
    set the option.
    """
    post = _eval(host("null", _chain()), WAKE_VIEW % {"unit": "prep"}, "root wake line")["post"]
    assert not post.startswith("+"), f"root needs no lift: {post[:120]!r}"
    assert "runuser" not in post, f"dropping below root would break the wake it just asked for"
