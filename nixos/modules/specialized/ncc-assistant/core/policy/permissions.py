"""NCC role → capability checks for domain AI tools (mirrors user/api.nix).

Two models live here on purpose (phase 39):

* **Roles** — ``ROLE_CAPABILITIES`` / ``role_has_permission``: what the invoking NCC
  user may do at all (mirrors ``nixos/core/base/user/api.nix``).
* **Permission ladder** — ``Grant`` / ``resolve_grant`` / ``evaluate_repo``: how far a
  single run may go, expressed as *actions* (commit, push, PR, merge) instead of tool
  names. ``check_git_argv`` / ``check_shell_command`` are the floor below the ladder:
  they deny by code, and no option re-enables them.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

# Keep in sync with nixos/core/base/user/api.nix roleCapabilities
ROLE_CAPABILITIES: dict[str, list[str]] = {
    "admin": [
        "system.update",
        "system.build",
        "system.check.*",
        "module.*",
        "user.*",
        "package.*",
        "network.*",
        "hardware.*",
        "boot.*",
        "desktop.*",
        "audio.*",
        "localization.*",
    ],
    "guest": [
        "system.check.self",
        "user.read.self",
        "package.user.self",
        "desktop.read",
    ],
    "restricted-admin": [
        "system.update",
        "system.build",
        "system.check.*",
        "module.*",
        "user.*",
        "network.read",
        "package.user.*",
        "package.system",
        "desktop.*",
    ],
    "virtualization": [
        "system.check.self",
        "user.read.self",
        "package.user.self",
        "package.docker",
        "package.podman",
        "desktop.read",
    ],
}


def has_permission(caps: list[str], required: str) -> bool:
    for cap in caps:
        if cap == required:
            return True
        if cap.endswith(".*") and required.startswith(cap[:-1]):
            return True
    return False


def role_has_permission(role: str, permission: str | None) -> bool:
    """True if role may use a tool requiring ``permission`` (None = always)."""
    if not permission:
        return True
    caps = ROLE_CAPABILITIES.get(role or "guest") or ROLE_CAPABILITIES["guest"]
    return has_permission(caps, permission)


@lru_cache(maxsize=4)
def invoker_whoami() -> dict[str, Any]:
    """``ncc user whoami --json`` for the process user."""
    try:
        proc = subprocess.run(
            ["ncc", "user", "whoami", "--json"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {"user": "", "role": "guest", "canManage": False}
    if proc.returncode != 0:
        return {"user": "", "role": "guest", "canManage": False}
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return {"user": "", "role": "guest", "canManage": False}
    if not isinstance(data, dict):
        return {"user": "", "role": "guest", "canManage": False}
    role = str(data.get("role") or "guest")
    return {
        "user": str(data.get("user") or ""),
        "role": role,
        "canManage": bool(data.get("canManage"))
        or role in ("admin", "restricted-admin"),
    }


def invoker_role() -> str:
    return str(invoker_whoami().get("role") or "guest")


def clear_whoami_cache() -> None:
    invoker_whoami.cache_clear()


# --------------------------------------------------------------------------
# Permission ladder (phase 39) — actions, not tool names
# --------------------------------------------------------------------------

#: What a run may do to *someone's repository*. Each step includes the ones above it.
REPO_STEPS: tuple[str, ...] = (
    "observe",
    "propose",
    "commit",
    "push",
    "pr",
    "merge",
    "release",
)
#: What a run may do to *this machine*.
SYSTEM_STEPS: tuple[str, ...] = ("none", "config-write", "rebuild")

#: Minimum step per repo action. An action missing here is a bug, not an open door.
REPO_ACTIONS: dict[str, str] = {
    "read": "observe",
    "plan_write": "propose",
    "propose": "propose",
    "commit": "commit",
    "push": "push",
    "pr": "pr",
    "merge": "merge",
    "release": "release",
}
SYSTEM_ACTIONS: dict[str, str] = {
    "config_write": "config-write",
    "rebuild": "rebuild",
}

ENV_REPO = "NCC_ASSISTANT_GRANT_REPO"
ENV_SYSTEM = "NCC_ASSISTANT_GRANT_SYSTEM"
ENV_REPO_CEILING = "NCC_ASSISTANT_GRANT_REPO_CEILING"
ENV_ACTOR = "NCC_ASSISTANT_ACTOR"

#: Host default ceiling. ``pr`` is what the workflow tools could already do before the
#: ladder existed (merge still needs the human ``CONFIRM`` token), so a host that sets
#: nothing keeps behaving as it always did.
DEFAULT_REPO_CEILING = "pr"

#: Where a repository lowers the ladder for everybody who works in it (L13). Committed, and
#: read out of ``HEAD`` — the working tree is exactly what the bounded run is allowed to edit.
REPO_CEILING_PATH = ".ncc/permissions.json"
#: Nothing else is in the file. A ``system`` key would speak for the machine rather than the
#: repository, and an unread key would read back as "a rule nobody applied" — both refused.
REPO_CEILING_KEYS = frozenset({"version", "repo"})
REPO_CEILING_VERSION = 1

#: Branches an agent may never push to or merge into without a human in the loop.
PROTECTED_BRANCHES: tuple[str, ...] = ("main", "master")
AGENT_BRANCH_PREFIX = "ncc/"

_HOOK_BYPASS_FLAGS = frozenset({"--no-verify", "--no-gpg-sign"})
# ``\.env[^/]*`` rather than ``\.env(\..*)?$``: the deny list is the plan's ``.env*``, and a
# suffix-less credential file (``.envrc`` for direnv, ``.envlocal``) is the same secret.
_SECRET_PATH_RE = re.compile(
    r"(^|/)(\.env[^/]*$|.*\.(pem|p12|pfx|key)$|.*id_(rsa|ed25519|ecdsa).*$"
    r"|secrets\.json$|.*credentials.*$|.*\.npmrc$|.*\.netrc$)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Grant:
    """Effective permission for one run, one step per axis."""

    repo: str = "observe"
    system: str = "none"
    actor: str = "cli"

    def as_dict(self) -> dict[str, str]:
        return {"repo": self.repo, "system": self.system, "actor": self.actor}


@dataclass(frozen=True)
class Decision:
    """Answer to ``may this action happen`` with a greppable code."""

    allowed: bool
    code: str
    reason: str
    hint: str = ""

    def as_dict(self) -> dict[str, Any]:
        if self.allowed:
            return {"allowed": True}
        out: dict[str, Any] = {"allowed": False, "error": self.code, "denied": self.code}
        if self.reason:
            out["reason"] = self.reason
        if self.hint:
            out["hint"] = self.hint
        return out


def _rank(steps: Sequence[str], name: str) -> int:
    try:
        return steps.index(name)
    except ValueError:
        return -1


def normalise_step(axis: str, raw: str | None) -> str | None:
    """``repo``/``system`` step name, or None when unknown."""
    if raw is None:
        return None
    name = str(raw).strip().lower().replace("_", "-")
    steps = REPO_STEPS if axis == "repo" else SYSTEM_STEPS
    return name if name in steps else None


def step_rank(axis: str, name: str) -> int:
    """Position of ``name`` on its axis (-1 when unknown) — for comparisons."""
    return _rank(REPO_STEPS if axis == "repo" else SYSTEM_STEPS, str(name or "").strip().lower())


def lower_step(axis: str, a: str, b: str) -> str:
    """The narrower of two steps — how every ceiling gets narrowed by another ceiling."""
    return a if step_rank(axis, a) <= step_rank(axis, b) else b


def parse_grant_pairs(values: Iterable[str] | None) -> dict[str, str]:
    """Parse ``repo=pr`` / ``system=none`` pairs; raises ValueError with a hint."""
    out: dict[str, str] = {}
    for raw in values or ():
        text = str(raw).strip()
        if not text:
            continue
        axis, _, value = text.partition("=")
        axis = axis.strip().lower()
        if axis not in ("repo", "system") or not value:
            raise ValueError(
                f"bad --grant {raw!r}: expected repo=<{'|'.join(REPO_STEPS)}>"
                f" or system=<{'|'.join(SYSTEM_STEPS)}>"
            )
        step = normalise_step(axis, value)
        if step is None:
            raise ValueError(
                f"bad --grant {raw!r}: unknown {axis} step "
                f"{value!r} (allowed: {'|'.join(REPO_STEPS if axis == 'repo' else SYSTEM_STEPS)})"
            )
        out[axis] = step
    return out


def system_ceiling(writes_enabled: bool, allow_rebuild: bool) -> str:
    """Highest system step the host allows: rebuild > config-write > none."""
    if allow_rebuild:
        return "rebuild"
    if writes_enabled:
        return "config-write"
    return "none"


def agent_axis_ceiling(
    allow_write: bool | None, allow_rebuild: bool | None
) -> str | None:
    """The system step ``agent.allowWrite``/``agent.allowRebuild`` declare, or None.

    ``schedules.nix`` derives a schedule's ceiling from those two options while the run's
    own ceiling comes from the host-wide ``allowWrite``/``allowRebuild``. Reading the agent
    pair here too closes the gap where eval said ``system=config-write`` and the runtime
    answered a different question. ``None`` on both means nothing was declared — a bare
    shell, a harness — so only the host ceiling applies rather than a default of "no".
    """
    if allow_write is None and allow_rebuild is None:
        return None
    if allow_rebuild:
        return "rebuild"
    if allow_write:
        return "config-write"
    return "none"


def resolve_grant(
    *,
    requested: Mapping[str, str] | None = None,
    repo_ceiling: str = "observe",
    system_ceiling_step: str = "none",
    system_ceiling_origin: str | None = None,
    actor: str = "cli",
    env: Mapping[str, str] | None = None,
) -> tuple[Grant, list[str]]:
    """Narrow the host ceiling to one step per axis.

    ``requested`` (CLI flags) wins over the environment, and both may only *lower*
    the ceiling — a step above it is returned in ``violations`` so the caller can
    refuse loudly instead of silently running with less.

    ``system_ceiling_origin`` names the option that set the system ceiling when more than
    one knob could have set it, so a refusal points at the option worth raising.
    """
    environ = os.environ if env is None else env
    violations: list[str] = []

    def one(
        axis: str,
        steps: tuple[str, ...],
        ceiling: str,
        env_var: str,
        ceiling_origin: str | None = None,
    ) -> str:
        want = normalise_step(axis, (requested or {}).get(axis))
        origin = "--grant"
        if want is None:
            want = normalise_step(axis, environ.get(env_var))
            origin = env_var
        if want is None:
            return ceiling
        if _rank(steps, want) > _rank(steps, ceiling):
            violations.append(
                f"{axis}={want} exceeds host ceiling {ceiling} (from {origin}); "
                "raise the host option or lower the grant"
                + (f" — that ceiling is agent.allowWrite/agent.allowRebuild ({ceiling_origin})"
                   if ceiling_origin
                   else "")
            )
            return ceiling
        return want

    repo = one("repo", REPO_STEPS, normalise_step("repo", repo_ceiling) or "observe", ENV_REPO)
    system = one(
        "system",
        SYSTEM_STEPS,
        normalise_step("system", system_ceiling_step) or "none",
        ENV_SYSTEM,
        system_ceiling_origin,
    )
    return Grant(repo=repo, system=system, actor=actor), violations


def set_process_grant(grant: Grant) -> None:
    """Publish the grant so child processes (git helpers, harnesses) inherit it."""
    os.environ[ENV_REPO] = grant.repo
    os.environ[ENV_SYSTEM] = grant.system
    os.environ[ENV_ACTOR] = grant.actor


def current_grant() -> Grant | None:
    """The active grant, or None when no run set one (chat, plain CLI)."""
    repo = normalise_step("repo", os.environ.get(ENV_REPO))
    system = normalise_step("system", os.environ.get(ENV_SYSTEM))
    if repo is None and system is None:
        return None
    return Grant(
        repo=repo or "observe",
        system=system or "none",
        actor=os.environ.get(ENV_ACTOR) or "cli",
    )


def audit_actor() -> str:
    """Whose audit line a refusal is, for the callers that log outside ``workflow_execute``."""
    grant = current_grant()
    if grant is not None:
        return grant.actor
    return (os.environ.get(ENV_ACTOR) or "").strip() or "cli"


# --------------------------------------------------------------------------
# Confirm axis (phase 39 L15) — who answers a prompt, and who may skip it
# --------------------------------------------------------------------------

#: Ordered by how much a run may do unasked: ``always`` asks for every tool, ``never`` for
#: none. Narrowing therefore moves *toward* ``always`` — the opposite direction to a ladder
#: step, which is why confirm gets its own rank instead of riding on ``lower_step``.
CONFIRM_MODES: tuple[str, ...] = ("always", "writes", "never")
DEFAULT_CONFIRM = "writes"
#: The wrapper sets the unsuffixed name and ``Settings`` used to read a prefixed one that
#: nothing ever wrote; the unsuffixed one is the live variable and stays the single source.
ENV_CONFIRM = "AGENT_CONFIRM"

#: The prompt for a mutating tool is a question about one ladder step, so the level the
#: runtime speaks in maps onto ``SYSTEM_ACTIONS`` rather than inventing a third vocabulary.
CONFIRM_LEVEL_ACTIONS: dict[str, str] = {"write": "config_write", "rebuild": "rebuild"}


def normalise_confirm(raw: str | None) -> str | None:
    mode = str(raw or "").strip().lower()
    return mode if mode in CONFIRM_MODES else None


def confirm_rank(mode: str | None) -> int:
    """How freely a mode lets a run act: 0 asks for everything, 2 for nothing."""
    return _rank(CONFIRM_MODES, normalise_confirm(mode) or DEFAULT_CONFIRM)


def narrow_confirm(declared: str | None, requested: str | None) -> tuple[str, list[str]]:
    """This process's confirm mode: the narrower of what was declared and what was asked.

    ``requested`` (``--confirm``) that asks *less* than ``declared`` comes back in
    ``violations`` instead of quietly loosening a host that declared ``writes`` — the same
    shape as a ``--grant`` above the ceiling, because the failure mode is the same: the
    operator believes the tighter rule is in force.
    """
    ambient = normalise_confirm(declared) or DEFAULT_CONFIRM
    want = normalise_confirm(requested)
    if want is None:
        return ambient, []
    if confirm_rank(want) > confirm_rank(ambient):
        return ambient, [
            f"confirm={want} asks less than the declared confirm={ambient}; "
            "--confirm may only narrow a run (always asks more than writes, writes more than never)"
        ]
    return want, []


def set_process_confirm(mode: str) -> None:
    """Publish the effective mode so the runtime and any harness child get the same answer."""
    os.environ[ENV_CONFIRM] = normalise_confirm(mode) or DEFAULT_CONFIRM


def current_confirm() -> str:
    """The mode this process answers prompts in."""
    return normalise_confirm(os.environ.get(ENV_CONFIRM)) or DEFAULT_CONFIRM


def grant_confirms(level: str, *, tool: str = "") -> Decision:
    """Answer a prompt from the run's grant instead of from a person who is not there.

    A schedule unit has nobody to click Allow. Asking anyway held the unit for
    ``NOTIFY_TIMEOUT_SEC`` and returned "Cancelled by user / notification timeout" — a human
    refusal nobody made, which also meant a schedule granted ``system=config-write`` could
    not actually write. The approval for a timer is the grant the operator wrote in Nix at
    deploy time, so the verdict is the system step covering that level, and one audit line
    names the grant as the approver.

    Fails closed both ways: a mutating prompt with no grant is refused (nothing approved it),
    and a step the prompt asks about that the ladder cannot speak in — ``tool`` under
    ``confirm=always`` — is refused too rather than waiting out the clock. Interactive runs
    keep asking a person; this answers only where no person can be reached.
    """
    from core.policy.audit import append_audit  # local: importing policy must not pull in state paths

    action = CONFIRM_LEVEL_ACTIONS.get(str(level or ""))
    active = current_grant()
    if action is None:
        decision = Decision(
            False,
            "confirm_needs_human",
            f"confirm mode asks about {level or 'tool'} calls and this run has no one to ask",
            hint="A schedule answers its own prompts from its grant, which covers writes and "
            "rebuilds only. Lower agent.confirm / --confirm to writes, or run interactively.",
        )
    elif active is None:
        decision = Decision(
            False,
            "confirm_without_grant",
            f"nothing approved this {level}: the run carries no grant",
            hint="A scheduled unit is approved by its grant — set permissions.system / "
            "--grant system=… up to the host ceiling, or run interactively.",
        )
    else:
        decision = _cover(action, axis="system", grant=active)

    detail = f"level={level or 'tool'}"
    if action is not None:
        detail += f" action={action}"
    if active is not None:
        detail += f" system={active.system}"
    if not decision.allowed:
        detail = f"code={decision.code} {detail}"
    append_audit(
        "confirm_answered",
        actor=active.actor if active is not None else audit_actor(),
        tool=tool or str(level or "confirm"),
        result="granted" if decision.allowed else "denied",
        detail=detail[:240],
    )
    return decision


def lowest_grant_today() -> Grant:
    """The narrowest grant this host already carried today — the floor for an unattended run.

    An idle sweep has nobody to ask, so it inherits this instead of choosing a step: what
    the machine let run while someone was watching bounds what it may do with nobody there.
    Each axis takes its own minimum, so the answer sits at or below every run of the day,
    and a day with no grant-carrying run floors at ``repo=observe system=none``.

    Only ``grant_resolved`` lines count, read whole (``limit=None``): a capped read keeps
    the newest lines, which is exactly how an afternoon of merges would be mistaken for the
    whole day. The window is UTC — the day ``budgets`` counts in — so a run near midnight
    cannot inherit yesterday's rights or hand its own to tomorrow.
    """
    from core.policy.audit import read_audit  # local: importing policy must not pull in state paths

    day = datetime.now(timezone.utc).date().isoformat()
    floor: dict[str, str] = {}
    for entry in read_audit(limit=None):
        if entry.event != "grant_resolved" or not str(entry.timestamp)[:10] == day:
            continue
        steps = entry.args if isinstance(entry.args, dict) else {}
        for axis in ("repo", "system"):
            step = normalise_step(axis, steps.get(axis))
            if step is None:
                continue
            held = floor.get(axis)
            floor[axis] = step if held is None else lower_step(axis, step, held)
    # The actor is a placeholder for the pair: the run that inherits it is named by its own
    # NCC_ASSISTANT_ACTOR, and only these two steps are read back here.
    return Grant(
        repo=floor.get("repo", REPO_STEPS[0]),
        system=floor.get("system", SYSTEM_STEPS[0]),
        actor="idle",
    )


# --------------------------------------------------------------------------
# Per-repo ceiling (phase 39 L13) — a repository may only narrow the ladder
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class RepoCeiling:
    """What one repository narrowed its own ladder to.

    Three answers exist and nothing else: no committed file (``step`` None, nothing narrows),
    a committed file that parses (a step), and a file that cannot be trusted (``code`` set).
    The last one floors the repo axis at ``observe`` rather than reading as absent — a
    narrowing nobody can parse is the same guess the ladder refuses everywhere else.
    """

    step: str | None = None
    code: str = ""
    reason: str = ""
    hint: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": REPO_CEILING_PATH,
            "ceiling": self.step or "",
            "code": self.code,
            "reason": self.reason,
        }


def _ceiling_invalid(what: str) -> RepoCeiling:
    return RepoCeiling(
        code="repo_ceiling_invalid",
        reason=f"{REPO_CEILING_PATH} {what}",
        hint=f"The repo owner fixes or deletes {REPO_CEILING_PATH} and commits it by hand.",
    )


def _ceiling_unknown(what: str) -> RepoCeiling:
    return RepoCeiling(
        code="repo_ceiling_unknown",
        reason=f"{REPO_CEILING_PATH} could not be read ({what})",
        hint="Read the repository again, or have the owner remove the file.",
    )


def parse_repo_ceiling(raw: str) -> RepoCeiling:
    """``{"version": 1, "repo": "commit"}`` → the step this repository lowered itself to.

    The repo axis only: a repository can refuse to be merged, never grant itself a rebuild.
    Anything that is not exactly that — bad JSON, an unknown key, a step that does not exist —
    is refused, because a file the owner wrote in good faith that nobody applied is the worst
    of the three answers: it looks like an opt-down and behaves like none.
    """
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return _ceiling_invalid(f"is not JSON ({exc.msg})")
    if not isinstance(data, dict):
        return _ceiling_invalid("is not a JSON object")
    unknown = sorted(set(str(key) for key in data) - set(REPO_CEILING_KEYS))
    if unknown:
        return _ceiling_invalid(
            f"names {', '.join(unknown)}, which a repository does not own "
            f"(only {', '.join(sorted(REPO_CEILING_KEYS))})"
        )
    version = data.get("version", REPO_CEILING_VERSION)
    if str(version) != str(REPO_CEILING_VERSION):
        return _ceiling_invalid(f"is version {version!r}; this reads version {REPO_CEILING_VERSION}")
    step = normalise_step("repo", data.get("repo"))
    if step is None:
        return _ceiling_invalid(
            f"repo={data.get('repo')!r} is not a step ({' > '.join(REPO_STEPS)})"
        )
    return RepoCeiling(step=step)


def _read_git(root: Path, *args: str) -> tuple[int, str] | None:
    """``(returncode, stdout)`` of a read-only git call, or None when git could not run."""
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return proc.returncode, proc.stdout or ""


def read_repo_ceiling(root: Path | str | None) -> RepoCeiling:
    """The ceiling ``root`` committed for itself, read out of ``HEAD``.

    Not out of the working tree, and that choice is the whole point: the tree is what the run
    this file bounds may write, so a tree reader would let a run delete its own narrowing — or
    rewrite it wider — between two tool calls. Committed content is the only thing a human
    changed, so committed content is what decides.
    """
    if root is None:
        return RepoCeiling()
    root = Path(root)
    listed = _read_git(root, "ls-tree", "HEAD", "--", REPO_CEILING_PATH)
    if listed is None:
        return _ceiling_unknown("git ls-tree could not run")
    if listed[0] != 0:
        head = _read_git(root, "rev-parse", "--verify", "-q", "HEAD")
        if head is not None and head[0] != 0:
            return RepoCeiling()  # nothing committed yet, so nothing was ever lowered
        return _ceiling_unknown("HEAD could not be listed")
    entry = listed[1].strip()
    if not entry:
        return RepoCeiling()
    fields = entry.split()
    if len(fields) < 3 or fields[1] != "blob":
        return _ceiling_invalid("is committed as something other than a file")
    body = _read_git(root, "show", fields[2])
    if body is None or body[0] != 0:
        return _ceiling_unknown("the committed blob would not read back")
    return parse_repo_ceiling(body[1])


def _held_step(axis: str, grant: Grant) -> str:
    return grant.repo if axis == "repo" else grant.system


def _needed_step(axis: str, action: str) -> str | None:
    return (REPO_ACTIONS if axis == "repo" else SYSTEM_ACTIONS).get(action)


def _cover(
    action: str,
    *,
    axis: str,
    grant: Grant | None = None,
    ceiling: RepoCeiling | None = None,
) -> Decision:
    """The ladder's answer, unrecorded — the half of ``evaluate`` a catalog may call.

    Kept apart on purpose: ``system_flags`` asks about every tool in the registry to
    decide what to *advertise*, and a listing of tools nobody ran must not read afterwards
    like a list of decisions that were made.

    ``ceiling`` is the repository's own lowering of the repo axis (L13). It can only narrow
    what the run holds; a file that could widen it would be a repository granting itself
    rights its host never gave, so a step above the grant simply never applies — and the audit
    line says so rather than leaving the owner to guess which of the two ceilings answered.
    """
    active = grant if grant is not None else current_grant()
    if active is None:
        return Decision(True, "", "")
    steps = REPO_STEPS if axis == "repo" else SYSTEM_STEPS
    need = _needed_step(axis, action)
    if need is None:
        return Decision(False, "unknown_action", f"no {axis} step defined for {action!r}")
    have = _held_step(axis, active)
    by_repo = ""
    if axis == "repo" and ceiling is not None:
        if ceiling.code:
            return Decision(False, ceiling.code, ceiling.reason, hint=ceiling.hint)
        if ceiling.step is not None and step_rank("repo", ceiling.step) < step_rank("repo", have):
            have, by_repo = ceiling.step, REPO_CEILING_PATH
    if _rank(steps, have) >= _rank(steps, need):
        return Decision(True, "", "")
    if by_repo:
        return Decision(
            False,
            "grant_insufficient",
            f"grant {axis}={have} does not cover {action} (needs {need})",
            hint=f"{by_repo} lowers this repository below its host grant — only a human "
            "commit there raises it again.",
        )
    return Decision(
        False,
        "grant_insufficient",
        f"grant {axis}={have} does not cover {action} (needs {need})",
        hint=f"Run with --grant {axis}={need} (bounded by the host ceiling).",
    )


def _ceiling_note(ceiling: RepoCeiling | None, active: Grant | None) -> str:
    """How the repo file gets written into the audit line, in whichever of its states it is."""
    if ceiling is None:
        return ""
    if ceiling.code:
        return f" ceiling={ceiling.code}"
    if ceiling.step is None or active is None:
        return ""
    if step_rank("repo", ceiling.step) > step_rank("repo", active.repo):
        return f" ceiling_ignored={ceiling.step}"
    return f" ceiling={ceiling.step}"


def _record(
    decision: Decision,
    axis: str,
    action: str,
    *,
    grant: Grant | None = None,
    tool: str = "",
    ceiling: RepoCeiling | None = None,
) -> Decision:
    """Write the line that answers "why did this run merge?" the next morning.

    Silent in exactly one case: no grant and an allowed answer, which is a human at the
    CLI and not a decision the ladder weighed — a line per read would bury the few lines
    that matter. Everything the ladder refused is recorded, grant or not.
    """
    active = grant if grant is not None else current_grant()
    if active is None and decision.allowed:
        return decision

    from core.policy.audit import append_audit  # local: importing policy must not pull in state paths

    have = _held_step(axis, active) if active is not None else "?"
    need = _needed_step(axis, action) or "?"
    detail = f"axis={axis} {axis}={have} action={action} need={need}"
    if axis == "repo":
        detail += _ceiling_note(ceiling, active)
    if not decision.allowed:
        detail = f"code={decision.code} {detail}"
    append_audit(
        "grant_evaluated",
        actor=active.actor if active is not None else audit_actor(),
        tool=tool or action,
        result="granted" if decision.allowed else "denied",
        detail=detail[:240],
    )
    return decision


def evaluate(
    action: str,
    *,
    axis: str,
    grant: Grant | None = None,
    tool: str = "",
    ceiling: RepoCeiling | None = None,
) -> Decision:
    """May ``action`` run under the active (or given) grant? One audit line per answer.

    No grant context at all means "not an agent run" — the ladder stays out of the
    way and the caller's own ceiling (profile / allowWrite / confirm) decides.
    """
    decision = _cover(action, axis=axis, grant=grant, ceiling=ceiling)
    return _record(decision, axis, action, grant=grant, tool=tool, ceiling=ceiling)


def evaluate_repo(
    action: str,
    *,
    grant: Grant | None = None,
    tool: str = "",
    ceiling: RepoCeiling | None = None,
) -> Decision:
    return evaluate(action, axis="repo", grant=grant, tool=tool, ceiling=ceiling)


def evaluate_system(action: str, *, grant: Grant | None = None, tool: str = "") -> Decision:
    return evaluate(action, axis="system", grant=grant, tool=tool)


def peek_system(action: str, *, grant: Grant | None = None) -> Decision:
    """The system-axis verdict, *without* recording it.

    For a check that sits in front of a route which records its own decision — the
    ``call()`` dispatcher gates and then hands over to a method that asks again. Callers
    of this must record a refusal themselves (``record_denial``); one that passes has
    already been written down by the route it let through.
    """
    return _cover(action, axis="system", grant=grant)


def record_denial(decision: Decision, axis: str, action: str, *, tool: str = "") -> Decision:
    """Write the line for a refusal reached outside ``evaluate`` — never for an allow.

    A pre-check that says no has to leave the same trace as the routes that say no, or the
    log reads as if the run never asked.
    """
    if decision.allowed:
        return decision
    return _record(decision, axis, action, grant=current_grant(), tool=tool)


def decide_system(
    action: str,
    *,
    writes_enabled: bool,
    allow_rebuild: bool,
    client_mode: str = "",
    grant: Grant | None = None,
    tool: str = "",
) -> Decision:
    """The one decision for a host-mutating action: host ceiling first, run grant second.

    ``evaluate`` steps aside when there is no grant, so callers that ask only it would
    let a plain CLI rebuild. The ceiling is applied here so every route — dispatcher,
    direct tool entry, catalog listing — reaches the same verdict, and a granted run can
    only narrow what the host already allows.

    Each answer is recorded once, including the host's own refusal: "the operator forbids
    rebuilds" is a fact the audit trail should hold even when no grant was in play.
    """
    need = SYSTEM_ACTIONS.get(action)
    if need is None:
        return _record(
            Decision(False, "unknown_action", f"no system step defined for {action!r}"),
            "system",
            action,
            grant=grant,
            tool=tool,
        )
    # One host flag per step, deliberately not a rank: allowRebuild opens rebuild,
    # allowWrite opens config-write, and neither implies the other.
    if need == "rebuild":
        if not allow_rebuild:
            return _record(
                Decision(
                    False,
                    "host_rebuild_disabled",
                    "Rebuild disabled. Set allowRebuild = true in "
                    "systemConfig.modules.specialized.ncc-assistant.",
                ),
                "system",
                action,
                grant=grant,
                tool=tool,
            )
    elif not writes_enabled:
        return _record(
            Decision(
                False,
                "host_writes_disabled",
                f"Writes disabled for this client (mode={client_mode}). "
                "Enable allowWrite / mcpAllowWrite in module config.",
            ),
            "system",
            action,
            grant=grant,
            tool=tool,
        )
    return evaluate_system(action, grant=grant, tool=tool)


def system_flags(
    writes_enabled: bool,
    allow_rebuild: bool,
    *,
    grant: Grant | None = None,
) -> tuple[bool, bool]:
    """The write/rebuild flags a caller may advertise: host ceiling narrowed by the grant.

    A catalog is a promise about what can be called — a run granted ``system=none`` must
    not be shown the write tools it will be refused. It asks ``_cover`` rather than
    ``evaluate_system`` because nothing is being decided here, and a listing of every tool
    would otherwise write an audit line per catalog refresh.
    """
    allow_write = bool(writes_enabled) and _cover("config_write", axis="system", grant=grant).allowed
    rebuild = (
        bool(allow_rebuild)
        and allow_write
        and _cover("rebuild", axis="system", grant=grant).allowed
    )
    return allow_write, rebuild


def protected_branch(name: str | None, *, extra: Iterable[str] = ()) -> bool:
    """True for branches that need a human decision (defaults + host additions)."""
    if not name:
        return False
    branch = name.strip()
    names = set(PROTECTED_BRANCHES) | {str(e).strip() for e in extra if str(e).strip()}
    return branch in names


def is_agent_branch(name: str | None) -> bool:
    """Agent work belongs on ``ncc/…`` branches, never on the trunk."""
    return bool(name) and str(name).strip().startswith(AGENT_BRANCH_PREFIX)


_PORCELAIN_STATUS_RE = re.compile(r"^\s*[MADRCU?!?]{1,2}\s+")


def porcelain_path(entry: str) -> str:
    """The path a ``git status --porcelain`` line names, or an empty string.

    A rename is reported as ``old -> new``, and the destination is the path staging
    has to cover — the source arrives as its own deletion line when the rename is
    still unstaged, which is the only case where both sides matter.
    """
    candidate = _PORCELAIN_STATUS_RE.sub("", str(entry).strip()).strip().strip('"')
    return candidate.rsplit(" -> ", 1)[-1].strip().strip('"')


def secret_paths(paths: Iterable[str]) -> list[str]:
    """Paths that must never be staged, whatever the grant says.

    Accepts plain paths as well as ``git status --porcelain`` lines.
    """
    out: list[str] = []
    for raw in paths:
        candidate = porcelain_path(raw)
        if candidate and _SECRET_PATH_RE.search(candidate):
            out.append(candidate)
    return out


#: ``.ncc/`` is where a repository lowers the ladder, so everything under it belongs to the
#: owner: a run allowed to stage or delete the file is a run allowed to widen itself back out.
_CEILING_PATH_RE = re.compile(r"(^|/)\.ncc(/|$)", re.IGNORECASE)


def repo_ceiling_paths(paths: Iterable[str]) -> list[str]:
    """Paths that would commit over this repository's own ceiling (L13).

    The whole ``.ncc/`` directory, not just the one file: ``git add -- .ncc`` stages the
    ceiling exactly as precisely as naming it, and a deny list that misses the directory form
    is a deny list an ordinary command walks past.
    """
    out: list[str] = []
    for raw in paths:
        candidate = porcelain_path(raw)
        if candidate and _CEILING_PATH_RE.search(candidate):
            out.append(candidate)
    return out


def _denied(code: str, reason: str, hint: str) -> Decision:
    return Decision(False, code, reason, hint)


#: Global git options that consume the following token (``git -c k=v push``).
_GLOBAL_VALUE_FLAGS = frozenset(
    {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix"}
)

#: A pathset that names the whole tree stages whatever happens to be present, including a file
#: this module would refuse by name — so it is refused where it is typed, not honoured.
BLANKET_PATHS = frozenset({".", "./", "*", "./*", "**"})

#: The verbs that move work into the index, and the flags that mean "everything there is".
_STAGING_SUBCOMMANDS = frozenset({"add", "stage"})
#: Verbs that move work *out* of the index. They get the ceiling screen only: untracking a
#: secret is the cleanup this project wants, untracking the ceiling file is the run removing
#: its own bound — the deletion lands in HEAD the moment anyone commits the index.
_UNTRACKING_SUBCOMMANDS = frozenset({"rm", "remove", "mv"})
_STAGING_ALL_FLAGS = frozenset({"-A", "--all", "-u", "--update"})
_COMMIT_ALL_FLAGS = frozenset({"-a", "--all"})
#: Commit options whose value is free text: a message names no file, and refusing
#: ``commit -m "note the .env change"`` would refuse ordinary work.
_COMMIT_VALUE_FLAGS = frozenset(
    {"-m", "--message", "-F", "--file", "-c", "-C", "--reuse-message", "--reedit-message",
     "--fixup", "--revert", "--author", "--date", "--cleanup", "--trailer", "-t", "--template"}
)

#: What the shell tool must not do with git: write history, the index, or a remote. A shell
#: string carries no grant check, no branch floor and no ``git_action`` audit line, so the
#: capability is removed there rather than run unguarded — see ``check_shell_command``.
_SHELL_FORBIDDEN_GIT_ACTIONS = frozenset(
    {"add", "am", "apply", "cherry-pick", "commit", "merge", "mv", "push", "rebase", "remove",
     "reset", "restore", "revert", "rm", "stage", "tag"}
)


def _split_git_argv(args: Sequence[str]) -> tuple[str, Sequence[str]]:
    subcommand, index = "", 0
    while index < len(args):
        arg = args[index]
        if arg.startswith("-"):
            index += 2 if arg.split("=", 1)[0] in _GLOBAL_VALUE_FLAGS and "=" not in arg else 1
            continue
        return arg, args[index + 1 :]
    return "", ()


def _git_subcommand(args: Sequence[str]) -> str:
    """The subcommand a git argv runs, skipping global options (``-C``, ``-c``, …)."""
    return _split_git_argv(args)[0]


def git_subcommand(argv: Sequence[str]) -> str:
    """The subcommand of a git argv (``push`` in ``git -c x=y push``) — for audit labels."""
    return _git_subcommand([str(a) for a in argv if str(a).strip()])


def _pathspec_path(token: str) -> str:
    """The path a pathspec names, with any ``:(magic)`` prefix and stray quotes removed."""
    text = str(token)
    if text.startswith(":("):
        _, _, text = text.partition(")")
    return text.strip().strip("'\"")


def _staging_argv(args: Sequence[str], *, for_commit: bool) -> tuple[str, list[str]]:
    """``(stage_everything_flag, pathspecs)`` of an ``add``/``commit`` argument list.

    Flags and their values are skipped, so a commit message is never read as a pathspec:
    ``commit -m "note the .env change"`` names no file and must stay allowed.
    """
    all_flags = _COMMIT_ALL_FLAGS if for_commit else _STAGING_ALL_FLAGS
    value_flags = _COMMIT_VALUE_FLAGS if for_commit else frozenset()
    blanket_letter = "a" if for_commit else "A"
    blanket = ""
    paths: list[str] = []
    index = 0
    positional = False
    while index < len(args):
        token = str(args[index])
        index += 1
        if positional:
            paths.append(token)
            continue
        if token == "--":
            positional = True
            continue
        if token.startswith("-"):
            name = token.split("=", 1)[0]
            if name in all_flags or (not token.startswith("--") and blanket_letter in token[1:]):
                blanket = token
            if "=" not in token and (
                name in value_flags
                or (not token.startswith("--") and bool(set(token[1:]) & {"m", "F"}))
            ):
                index += 1
            continue
        paths.append(token)
    return blanket, paths


def _check_staging(subcommand: str, args: Sequence[str], *, for_commit: bool) -> Decision | None:
    """Blanket staging and secret-shaped pathspecs, refused inside the argv itself.

    ``commit_all`` already swaps a blanket pathset for an explicit one; enforcing it here as
    well puts the rule under a hand-built argv and a shell string, not only under the tool.
    """
    blanket, paths = _staging_argv(args, for_commit=for_commit)
    named = [_pathspec_path(path) for path in paths]
    verb = f"git {subcommand}"
    if blanket:
        return _denied(
            "denied_blanket_path",
            f"{verb} {blanket} stages whatever is present, so a path refused by name gets in unexamined",
            "Name the paths to stage (git add -- <path> …).",
        )
    everywhere = sorted({path for path in named if path in BLANKET_PATHS})
    if everywhere:
        return _denied(
            "denied_blanket_path",
            f"{verb} {', '.join(everywhere)} names every file in the repository, not the changed ones",
            "Name the paths to stage (git add -- <path> …).",
        )
    secrets = secret_paths(named)
    if secrets:
        return _denied(
            "denied_secret_path",
            f"{verb} would stage secret-shaped path(s): {', '.join(secrets[:5])}",
            "Keep secrets out of git; stage the rest by name.",
        )
    ceiling = repo_ceiling_paths(named)
    if ceiling:
        return _denied(
            "denied_repo_ceiling_path",
            f"{verb} would stage the path this repository lowers its own ladder from: "
            f"{', '.join(ceiling[:5])}",
            f"{REPO_CEILING_PATH} belongs to the repo owner; a run may only be bounded by it.",
        )
    return None


def _check_untracking(subcommand: str, args: Sequence[str]) -> Decision | None:
    """The ceiling screen for ``rm``/``mv``: untracking the file is the other way to widen.

    Only this file's own screen runs here. ``git rm -- .env`` is the cleanup this project asks
    for, so the secret screen must not follow a removal; the ceiling file is refused because a
    staged deletion of it lifts the repo back to its host ceiling the moment the index is
    committed — by whoever happens to be committing. A removal that names everything cannot be
    screened either, and ``git rm -r .`` takes the ceiling file with it.
    """
    _flag, paths = _staging_argv(args, for_commit=False)
    named = [_pathspec_path(path) for path in paths]
    verb = f"git {subcommand}"
    everywhere = sorted({path for path in named if path in BLANKET_PATHS})
    if everywhere:
        return _denied(
            "denied_blanket_path",
            f"{verb} {', '.join(everywhere)} removes every tracked file, so a path this module "
            "screens by name goes unexamined",
            "Name the paths to remove (git rm -- <path> …).",
        )
    ceiling = repo_ceiling_paths(named)
    if not ceiling:
        return None
    return _denied(
        "denied_repo_ceiling_path",
        f"{verb} would untrack the path this repository lowers its own ladder from: "
        f"{', '.join(ceiling[:5])}",
        f"{REPO_CEILING_PATH} belongs to the repo owner; a run may only be bounded by it.",
    )


def check_git_argv(argv: Sequence[str]) -> Decision:
    """Floor for git invocations: force-push, hook bypass, blanket staging, secret paths."""
    args = [str(a) for a in argv if str(a).strip()]
    subcommand, rest = _split_git_argv(args)

    if subcommand == "push":
        for offset, arg in enumerate(args[1:], start=1):
            if arg.startswith("--force") or arg == "-f":
                return _denied(
                    "denied_force_push",
                    "force-push is refused by code, not by configuration",
                    "Push a new commit, or a human runs the force-push themselves.",
                )
            # ``git push origin +main`` / ``+refs/heads/main:…`` is a force push too.
            if arg.startswith("+") and len(arg) > 1:
                return _denied(
                    "denied_force_push",
                    f"refspec {arg!r} rewrites remote history",
                    "Push a new commit instead of overwriting the remote.",
                )
            if arg in ("-o", "--push-option") and offset + 1 < len(args) and "force" in args[offset + 1]:
                return _denied(
                    "denied_force_push",
                    "push option forces the update",
                    "Push a new commit instead of overwriting the remote.",
                )

    if subcommand in ("commit", "amend", "merge", "rebase", "push"):
        for index, arg in enumerate(args):
            if arg in _HOOK_BYPASS_FLAGS:
                return _denied(
                    "denied_hook_bypass",
                    f"{arg} skips the repository's own gates",
                    "Fix what the hook reports; the host's pre-commit gates are the contract.",
                )
            if arg == "-c" and index + 1 < len(args) and args[index + 1].startswith("commit.gpgsign"):
                return _denied(
                    "denied_hook_bypass",
                    "disabling commit signing is refused",
                    "Sign the commit or let a human handle it.",
                )

    # Staging after the history rules: ``commit --no-verify -a`` is worth the hook answer, and
    # inside staging a blanket flag goes first — a pathset that names nothing cannot be screened.
    if subcommand in _STAGING_SUBCOMMANDS:
        staging = _check_staging(subcommand, rest, for_commit=False)
    elif subcommand == "commit":
        staging = _check_staging(subcommand, rest, for_commit=True)
    else:
        staging = None
    if staging is not None:
        return staging

    # Untracking last: it carries no hook or history meaning, only "this file leaves the index".
    if subcommand in _UNTRACKING_SUBCOMMANDS:
        removal = _check_untracking(subcommand, rest)
        if removal is not None:
            return removal

    return Decision(True, "", "")


def check_branch(name: str | None, *, action: str = "commit") -> Decision:
    """Floor: the two writing git steps happen on ``ncc/…`` only, never on someone's trunk.

    ``ensure_branch`` already refuses to *create* anything outside ``ncc/workflow-…``; this is
    the same rule on ``commit``/``push`` themselves, because HEAD can land on trunk without
    going through that door. The prefix is the precondition (``ncc/``), not the full creation
    pattern — a branch a human renamed by hand is still agent work, not a trunk write.
    """
    branch = str(name or "").strip()
    if is_agent_branch(branch):
        return Decision(True, "", "")
    if branch in ("", "HEAD"):
        return _denied(
            "denied_non_agent_branch",
            "detached HEAD — there is no ncc/… branch for this to land on",
            "Check out a ncc/workflow-… branch (ncc workflow branch) first.",
        )
    return _denied(
        "denied_non_agent_branch",
        f"{action} is refused on {branch!r}: agent work stays on ncc/…",
        "Move the work onto a ncc/workflow-… branch, or do it by hand with git.",
    )


#: Chain and redirect characters. Split as punctuation so ``git status;git commit -m x`` is
#: seen as two git invocations — with ``shlex.split`` the ``;`` hides inside ``--porcelain;``
#: and everything after it goes unexamined. Quoted text is unaffected.
_SHELL_SEPARATORS = ";&|<>"


def _shell_tokens(command: str) -> list[str]:
    lexer = shlex.shlex(str(command), posix=True, punctuation_chars=_SHELL_SEPARATORS)
    lexer.whitespace_split = True
    return list(lexer)


def _is_separator(token: str) -> bool:
    return bool(token) and not token.strip(_SHELL_SEPARATORS)


def check_shell_command(command: str) -> Decision:
    """Same floor for shell strings, plus no git writes at all through that path.

    A shell string has no repository context to check: no root to read HEAD from, no grant step,
    no ``git_action`` audit line. Rather than guess, the capability goes — only the read-only
    subcommands survive, so an allowlisted ``git commit`` cannot land a write on trunk.
    """
    try:
        tokens = _shell_tokens(command)
    except ValueError:
        return Decision(True, "", "")
    invocations: list[list[str]] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if _is_separator(token):
            index += 1
            continue
        if token.rsplit("/", 1)[-1] == "git":
            rest: list[str] = []
            for follow in tokens[index + 1 :]:
                if _is_separator(follow):
                    break
                rest.append(follow)
            invocations.append(rest)
            index += 1 + len(rest)
            continue
        index += 1

    # The specific rules across the whole chain first: in ``git add -- notes.md || git commit
    # --no-verify -m x`` the escalation is the hook bypass, and that is the code to grep for.
    for argv in invocations:
        verdict = check_git_argv(argv)
        if not verdict.allowed:
            return verdict
    for argv in invocations:
        subcommand, _ = _split_git_argv(argv)
        if subcommand in _SHELL_FORBIDDEN_GIT_ACTIONS:
            return _denied(
                "denied_shell_git_write",
                f"git {subcommand} writes history through a shell string, which carries no grant,"
                " no branch floor and no audit line",
                "Use the workflow verb (ncc ai workflow commit / push / …) — that is where the"
                " ladder, the ncc/ floor and the git_action audit live.",
            )
    return Decision(True, "", "")

