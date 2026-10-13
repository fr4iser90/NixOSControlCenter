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
from functools import lru_cache
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


def resolve_grant(
    *,
    requested: Mapping[str, str] | None = None,
    repo_ceiling: str = "observe",
    system_ceiling_step: str = "none",
    actor: str = "cli",
    env: Mapping[str, str] | None = None,
) -> tuple[Grant, list[str]]:
    """Narrow the host ceiling to one step per axis.

    ``requested`` (CLI flags) wins over the environment, and both may only *lower*
    the ceiling — a step above it is returned in ``violations`` so the caller can
    refuse loudly instead of silently running with less.
    """
    environ = os.environ if env is None else env
    violations: list[str] = []

    def one(axis: str, steps: tuple[str, ...], ceiling: str, env_var: str) -> str:
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
            )
            return ceiling
        return want

    repo = one("repo", REPO_STEPS, normalise_step("repo", repo_ceiling) or "observe", ENV_REPO)
    system = one(
        "system",
        SYSTEM_STEPS,
        normalise_step("system", system_ceiling_step) or "none",
        ENV_SYSTEM,
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


def evaluate(action: str, *, axis: str, grant: Grant | None = None) -> Decision:
    """May ``action`` run under the active (or given) grant?

    No grant context at all means "not an agent run" — the ladder stays out of the
    way and the caller's own ceiling (profile / allowWrite / confirm) decides.
    """
    active = grant if grant is not None else current_grant()
    if active is None:
        return Decision(True, "", "")
    steps = REPO_STEPS if axis == "repo" else SYSTEM_STEPS
    table = REPO_ACTIONS if axis == "repo" else SYSTEM_ACTIONS
    need = table.get(action)
    if need is None:
        return Decision(False, "unknown_action", f"no {axis} step defined for {action!r}")
    have = active.repo if axis == "repo" else active.system
    if _rank(steps, have) >= _rank(steps, need):
        return Decision(True, "", "")
    return Decision(
        False,
        "grant_insufficient",
        f"grant {axis}={have} does not cover {action} (needs {need})",
        hint=f"Run with --grant {axis}={need} (bounded by the host ceiling).",
    )


def evaluate_repo(action: str, *, grant: Grant | None = None) -> Decision:
    return evaluate(action, axis="repo", grant=grant)


def evaluate_system(action: str, *, grant: Grant | None = None) -> Decision:
    return evaluate(action, axis="system", grant=grant)


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


def _denied(code: str, reason: str, hint: str) -> Decision:
    return Decision(False, code, reason, hint)


#: Global git options that consume the following token (``git -c k=v push``).
_GLOBAL_VALUE_FLAGS = frozenset(
    {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix"}
)


def _git_subcommand(args: Sequence[str]) -> str:
    index = 0
    while index < len(args):
        arg = args[index]
        if arg in _GLOBAL_VALUE_FLAGS:
            index += 2
            continue
        if arg.startswith("-"):
            index += 1
            continue
        return arg
    return ""


def git_subcommand(argv: Sequence[str]) -> str:
    """The subcommand of a git argv (``push`` in ``git -c x=y push``) — for audit labels."""
    return _git_subcommand([str(a) for a in argv if str(a).strip()])


def check_git_argv(argv: Sequence[str]) -> Decision:
    """Floor for git invocations: force-push and hook bypass are never allowed."""
    args = [str(a) for a in argv if str(a).strip()]
    subcommand = _git_subcommand(args)

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

    return Decision(True, "", "")


def check_shell_command(command: str) -> Decision:
    """Same floor for shell strings — an allowlisted ``git push`` is not a force-push."""
    try:
        tokens = shlex.split(str(command))
    except ValueError:
        return Decision(True, "", "")
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token in ("&&", ";", "||", "|"):
            index += 1
            continue
        if token.rsplit("/", 1)[-1] == "git":
            rest: list[str] = []
            for follow in tokens[index + 1 :]:
                if follow in ("&&", ";", "||", "|"):
                    break
                rest.append(follow)
            verdict = check_git_argv(rest)
            if not verdict.allowed:
                return verdict
            index += 1 + len(rest)
            continue
        index += 1
    return Decision(True, "", "")

