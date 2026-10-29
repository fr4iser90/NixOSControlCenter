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
PACKAGE_NIX = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "package.nix"

# Same shape the flake's specialArgs hand the module. schedules.nix is not a NixOS module, and
# mkIf/mkMerge leave deferred records behind, so the units only appear after flattening.
# users.users is a parameter here rather than the empty set the other harnesses use: the whole
# option is about an account that must resolve.
TEMPLATE = """
let
  pkgs = import <nixpkgs> { };
  cfg = %(cfg)s;
  ui = { messages = { warning = m: "echo w"; info = m: "echo i"; loading = m: "echo l"; }; };
  out = import %(module)s {
    inherit pkgs cfg;
    lib = pkgs.lib;
    config = { users.users = %(users)s; };
    systemConfig = { };
    getModuleConfig = _: cfg;
    getModuleApi = _: ui;
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

WARNINGS = "(flatten out.config).warnings or [ ]"
ASSERTIONS = "map (a: a.assertion) (flatten out.config).assertions or [ ]"

USER = "alice"
HOME = "/home/alice"
SCHEDULES_WITH_USER = f'{{ {USER} = {{ home = "{HOME}"; isNormalUser = true; }}; }}'


def _eval(cfg: str, expr: str, case: str, users: str = SCHEDULES_WITH_USER) -> object:
    nix = TEMPLATE % {
        "module": str(SCHEDULES_NIX),
        "mm": str(MODULE_MANAGER),
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


# --- gh and git are dependencies, not weather ------------------------------------------------


def test_the_wrapper_declares_gh_and_git():
    # workflows.py and cli/workspace_lifecycle.py call gh (5 sites), poll_guard/permissions/
    # workspaces call git. A host whose environment happens to carry git hides that the
    # dependency was never stated; on one that does not, every GitHub verb dies with
    # "gh CLI not on PATH" in a run that looked correctly configured.
    text = PACKAGE_NIX.read_text(encoding="utf-8")
    assert "${pkgs.gh}/bin" in text, "gh is called by 5 sites and declared by none"
    assert "${pkgs.git}/bin" in text, "git is called by the guards and declared by none"


# --- the wake line: root for systemctl only, never for the audit it writes ----------------


def test_the_wake_line_lifts_only_itself_and_drops_back_for_the_decision():
    """Anchored rather than evaluated, and that is the honest limit here.

    Forcing a unit's ``ExecStartPost`` value forces ``"${pkg.appRoot}"``, which is only reachable
    by building gui-engine and module-manager for real — the same reason the chain suite projects
    nothing about that line beyond its existence. Evaluation *does* prove the condition the prefix
    hangs on (``User=`` above), so what is pinned here is the other half, the two literals that
    carry the capability boundary:

    * ``+`` (systemd.service(5)) lifts this one line back to root, because a plain account may not
      ask systemd to start a sibling unit — while ``ExecStart=`` keeps every restriction, so the
      agent's own shell tools still never get systemctl;
    * the decision itself is asked through ``runuser``: ``chain release`` appends to audit.jsonl,
      and a root-owned audit file inside the account it was meant to stop impersonating would lock
      the GUI out of the history this run made.
    """
    src = SCHEDULES_NIX.read_text(encoding="utf-8")
    assert '"${optionalString (identity.user != null) "+"}' in src, (
        "without the prefix a chained schedule cannot wake anything once its run is unprivileged"
    )
    assert "/bin/runuser -u ${lib.escapeShellArg identity.user}" in src, (
        "without the drop, the wake line writes root-owned audit lines into the run's own home"
    )
