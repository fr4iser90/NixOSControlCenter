"""Workspace workflow execute: per-task branch → validate → PR + progress checkpoint."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence

from .audit import append_audit
from . import budgets
from .paths import workflow_progress_file
from .permissions import (
    ENV_ACTOR,
    check_git_argv,
    current_grant,
    evaluate_repo,
    git_subcommand,
    porcelain_path,
    protected_branch,
    secret_paths,
)
from .workspace_workflow import (
    next_open_task,
    resolve_workspace_id,
    task_gap_id,
)
from .workspaces import get_workspace

CONFIRM_TOKEN = "CONFIRM"
_SAFE_BRANCH = re.compile(r"^ncc/workflow-[a-z0-9][a-z0-9._/-]{0,60}$")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _repo_root(workspace_id: str | None) -> tuple[str, Path]:
    wid = resolve_workspace_id(workspace_id)
    ws = get_workspace(wid)
    assert ws is not None
    root = Path(ws.path).expanduser().resolve()
    if not root.is_dir():
        raise ValueError(f"Workspace path missing: {root}")
    if not (root / ".git").exists():
        raise ValueError(f"Not a git repo: {root}")
    return wid, root


def _run(
    cmd: list[str],
    *,
    cwd: Path,
    timeout: float = 120.0,
    check: bool = False,
) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {
            "ok": False,
            "cmd": cmd,
            "error": str(exc),
            "stdout": "",
            "stderr": "",
            "returncode": -1,
        }
    out = {
        "ok": proc.returncode == 0,
        "cmd": cmd,
        "returncode": proc.returncode,
        "stdout": (proc.stdout or "").strip(),
        "stderr": (proc.stderr or "").strip(),
    }
    if check and not out["ok"]:
        raise RuntimeError(
            f"Command failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"{out['stderr'] or out['stdout']}"
        )
    return out


#: git subcommands that change the repository (or the remote). Reads stay out of the audit.
_GIT_ACTIONS = frozenset({"commit", "push", "merge", "tag", "rebase", "reset"})


def _actor() -> str:
    """Whose line this is in ``audit.jsonl`` — a schedule id, ``companion``, or ``cli``."""
    grant = current_grant()
    if grant is not None:
        return grant.actor
    return (os.environ.get(ENV_ACTOR) or "").strip() or "cli"


def _audit_git(action: str, *, ok: bool, detail: str = "") -> None:
    if action not in _GIT_ACTIONS:
        return
    append_audit(
        "git_action",
        actor=_actor(),
        tool=f"git {action}",
        result="ok" if ok else "error",
        detail=detail[:240],
    )


def _audit_floor(code: str, reason: str, *, tool: str) -> None:
    """The floor is code, not config — so a refusal is worth finding in the log later."""
    append_audit(
        "floor_denied",
        actor=_actor(),
        tool=tool,
        result="denied",
        detail=f"{code}: {reason}"[:240],
    )


def _audit_publish(kind: str, *, ok: bool, detail: str = "") -> None:
    """``gh pr create`` / ``gh pr merge`` move the repo's history too — audited as one stream."""
    append_audit(
        "git_action",
        actor=_actor(),
        tool=f"gh pr {kind}",
        result="ok" if ok else "error",
        detail=detail[:240],
    )


def _git(root: Path, *args: str, timeout: float = 60.0) -> dict[str, Any]:
    verdict = check_git_argv(args)
    if not verdict.allowed:
        # Refuse before spawning git: the floor is not something git can be argued out of.
        _audit_floor(verdict.code, verdict.reason, tool=f"git {git_subcommand(args)}")
        return {
            "ok": False,
            "cmd": ["git", *args],
            "returncode": 126,
            "stdout": "",
            "stderr": f"{verdict.reason} {verdict.hint}".strip(),
            **verdict.as_dict(),
        }
    result = _run(["git", *args], cwd=root, timeout=timeout)
    _audit_git(
        git_subcommand(args),
        ok=bool(result.get("ok")),
        detail=result.get("stderr") or result.get("stdout") or "",
    )
    return result


def _repo_grant(action: str) -> dict[str, Any] | None:
    """Denial payload when this run's grant does not cover ``action``.

    Returns None outside a grant context (human at the CLI) — those keep the rights the
    tool always had; the floor above still applies to everyone.
    """
    verdict = evaluate_repo(action)
    return None if verdict.allowed else verdict.as_dict()


def _human_decision(action: str, confirm: str, hint: str) -> dict[str, Any] | None:
    """Denial payload for actions that normally need the ``CONFIRM`` token.

    Inside a grant context the token is typed by the model, not by a person, so the
    ladder alone decides there. Outside one (a human at the CLI) the token keeps
    working exactly as it did before.
    """
    if current_grant() is not None:
        return _repo_grant(action)
    if (confirm or "").strip() != CONFIRM_TOKEN:
        return {"error": "confirm_required", "hint": f"Pass confirm=\"{CONFIRM_TOKEN}\" {hint}"}
    return None


def _is_dirty(root: Path) -> bool:
    return bool(_git(root, "status", "--porcelain").get("stdout"))


def _repo_key(root: Path) -> str:
    """Stable id for per-repo budget counters — ``org/repo``, or the directory when local."""
    url = (_git(root, "remote", "get-url", "origin").get("stdout") or "").strip()
    if not url:
        return f"local:{root.name}"
    path = re.sub(r"^(git@|https?://)", "", url)
    if ":" in path.split("/", 1)[0]:
        path = path.split(":", 1)[1]
    path = re.sub(r"\.git$", "", path)
    parts = [p for p in path.strip("/").split("/") if p]
    return "/".join(parts[-2:]) if len(parts) >= 2 else (parts[-1] if parts else root.name)


def _pr_budget_hold(root: Path) -> dict[str, Any] | None:
    """PRs/day and open agent PRs — a breach holds the PR, never the branch or the commit.

    Returning the push result alongside the denial is what makes this recoverable: the work
    is on the remote and ``ncc ai workflow pr`` can open it tomorrow.
    """
    if not budgets.applies():
        return None
    key = _repo_key(root)
    for verdict in (budgets.check_prs(key), budgets.check_open_agent_prs(key)):
        if not verdict.allowed:
            return {**verdict.as_dict(), "prHeld": True}
    return None


def detect_default_branch(root: Path) -> str:
    sym = _git(root, "symbolic-ref", "refs/remotes/origin/HEAD")
    if sym.get("ok") and sym.get("stdout"):
        # refs/remotes/origin/main
        ref = sym["stdout"].strip()
        if "/" in ref:
            return ref.rsplit("/", 1)[-1]
    for name in ("main", "master"):
        probe = _git(root, "rev-parse", "--verify", name)
        if probe.get("ok"):
            return name
    cur = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    return (cur.get("stdout") or "main").strip() or "main"


def load_progress(workspace_id: str | None = None) -> dict[str, Any]:
    wid = resolve_workspace_id(workspace_id)
    path = workflow_progress_file(wid)
    if not path.is_file():
        return {
            "version": 1,
            "workspace_id": wid,
            "updatedAt": None,
            "current_task_id": None,
            "current_branch": None,
            "completed": [],
            "history": [],
        }
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = {}
    if not isinstance(data, dict):
        data = {}
    return {
        "version": 1,
        "workspace_id": wid,
        "updatedAt": data.get("updatedAt"),
        "current_task_id": data.get("current_task_id"),
        "current_branch": data.get("current_branch"),
        "completed": list(data.get("completed") or []),
        "history": list(data.get("history") or [])[-40:],
    }


def save_progress(workspace_id: str | None, payload: dict[str, Any]) -> dict[str, Any]:
    wid = resolve_workspace_id(workspace_id)
    path = workflow_progress_file(wid)
    out = dict(payload)
    out["version"] = 1
    out["workspace_id"] = wid
    out["updatedAt"] = _now()
    path.write_text(
        json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return out


def _append_history(prog: dict[str, Any], event: dict[str, Any]) -> None:
    hist = list(prog.get("history") or [])
    hist.append({**event, "at": _now()})
    prog["history"] = hist[-40:]


def default_branch_name(*, prefix: str = "work", task_id: str | None = None) -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    slug = re.sub(r"[^a-z0-9]+", "-", (prefix or "work").lower()).strip("-") or "work"
    tid = re.sub(r"[^a-z0-9]+", "", (task_id or "").lower())[:10]
    if tid:
        return f"ncc/workflow-{slug}-{tid}"
    return f"ncc/workflow-{slug}-{stamp}"


def ensure_branch(
    workspace_id: str | None = None,
    *,
    branch: str | None = None,
    prefix: str = "work",
    task_id: str | None = None,
    from_default: bool = False,
    allow_dirty: bool = False,
) -> dict[str, Any]:
    """Create/switch to an ncc/workflow-* branch."""
    wid, root = _repo_root(workspace_id)
    if not allow_dirty and _is_dirty(root):
        return {
            "ok": False,
            "workspace_id": wid,
            "error": "dirty_tree",
            "hint": "Commit/stash changes first, or pass allow_dirty.",
            "path": str(root),
        }
    name = (branch or "").strip() or default_branch_name(prefix=prefix, task_id=task_id)
    if not _SAFE_BRANCH.match(name):
        raise ValueError(
            f"Branch must match ncc/workflow-… ({name!r}). "
            "Refusing arbitrary branch names."
        )
    status = _git(root, "status", "--porcelain")
    cur = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    current = cur.get("stdout") or ""
    if current == name:
        return {
            "ok": True,
            "workspace_id": wid,
            "branch": name,
            "already": True,
            "dirty": bool(status.get("stdout")),
            "path": str(root),
        }
    if from_default:
        base = detect_default_branch(root)
        co_base = _git(root, "checkout", base)
        if not co_base["ok"]:
            return {
                "ok": False,
                "workspace_id": wid,
                "error": co_base.get("stderr") or f"checkout {base} failed",
                "path": str(root),
            }
    created = _git(root, "checkout", "-b", name)
    if not created["ok"]:
        switched = _git(root, "checkout", name)
        if not switched["ok"]:
            return {
                "ok": False,
                "workspace_id": wid,
                "branch": name,
                "error": switched.get("stderr") or created.get("stderr"),
                "path": str(root),
            }
        return {
            "ok": True,
            "workspace_id": wid,
            "branch": name,
            "already": True,
            "dirty": bool(status.get("stdout")),
            "path": str(root),
        }
    return {
        "ok": True,
        "workspace_id": wid,
        "branch": name,
        "already": False,
        "dirty": bool(status.get("stdout")),
        "path": str(root),
    }


def rebase_onto_default(workspace_id: str | None = None) -> dict[str, Any]:
    """Rebase current branch onto detected default (no force-push)."""
    wid, root = _repo_root(workspace_id)
    if _is_dirty(root):
        return {"ok": False, "error": "dirty_tree", "workspace_id": wid}
    base = detect_default_branch(root)
    # fetch best-effort
    _git(root, "fetch", "origin", base, timeout=120.0)
    onto = f"origin/{base}"
    verify = _git(root, "rev-parse", "--verify", onto)
    target = onto if verify.get("ok") else base
    res = _git(root, "rebase", target, timeout=180.0)
    if not res["ok"]:
        _git(root, "rebase", "--abort")
        return {
            "ok": False,
            "workspace_id": wid,
            "error": "rebase_failed",
            "stderr": res.get("stderr"),
            "onto": target,
        }
    return {"ok": True, "workspace_id": wid, "onto": target}


def detect_validate_commands(root: Path) -> list[list[str]]:
    """Best-effort project validators (ordered, stop on first failure)."""
    cmds: list[list[str]] = []
    if (root / "tests" / "run-gates.sh").is_file():
        cmds.append(["bash", "tests/run-gates.sh"])
        return cmds
    if (root / "flake.nix").is_file() and shutil.which("nix"):
        cmds.append(["nix", "flake", "check"])
    if (root / "package.json").is_file() and shutil.which("npm"):
        try:
            pkg = json.loads((root / "package.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pkg = {}
        scripts = pkg.get("scripts") if isinstance(pkg, dict) else {}
        if isinstance(scripts, dict):
            if "test" in scripts:
                cmds.append(["npm", "test", "--", "--watchAll=false"])
            elif "lint" in scripts:
                cmds.append(["npm", "run", "lint"])
    if (root / "pyproject.toml").is_file() or (root / "pytest.ini").is_file():
        if shutil.which("pytest"):
            cmds.append(["pytest", "-q"])
    if (root / "Cargo.toml").is_file() and shutil.which("cargo"):
        cmds.append(["cargo", "test", "--quiet"])
    if not cmds:
        cmds.append(["git", "status", "--short"])
    return cmds


def validate_workspace(workspace_id: str | None = None) -> dict[str, Any]:
    """Run detected validators; return per-command results."""
    wid, root = _repo_root(workspace_id)
    cmds = detect_validate_commands(root)
    results: list[dict[str, Any]] = []
    ok_all = True
    for cmd in cmds:
        timeout = 900.0 if "run-gates" in cmd or cmd[:1] == ["nix"] else 300.0
        res = _run(cmd, cwd=root, timeout=timeout)
        results.append(res)
        if not res["ok"]:
            ok_all = False
            break
    return {
        "ok": ok_all,
        "workspace_id": wid,
        "path": str(root),
        "commands": results,
    }


#: A pathset that covers everything is ``git add -A`` under another name, so it is refused
#: rather than honoured: the point of naming paths is that a file can be refused by name.
_BLANKET_PATHS = frozenset({".", "./", "*", "./*", "**"})


def _dirty_pathset(status_stdout: str) -> list[str]:
    """Every path ``git status --porcelain --untracked-files=all`` names."""
    out: list[str] = []
    for entry in status_stdout.splitlines():
        path = porcelain_path(entry)
        if path and path not in out:
            out.append(path)
    return out


def _named_pathset(root: Path, requested: Iterable[str]) -> tuple[list[str], list[str], list[str]]:
    """Repo-relative paths to stage, and the two kinds of request that are refused.

    ``outside`` covers a path that walks out of the checkout (``../…``) — it would stage
    work the run was never given a grant for, and git only refuses it by accident.
    """
    keep: list[str] = []
    blanket: list[str] = []
    outside: list[str] = []
    for raw in requested:
        text = str(raw).strip().replace("\\", "/")
        if not text:
            continue
        if text in _BLANKET_PATHS:
            blanket.append(text)
            continue
        relative = os.path.relpath(os.path.abspath(os.path.join(str(root), text)), str(root))
        if relative == os.curdir or relative.startswith(f"{os.pardir}{os.sep}") or relative == os.pardir:
            outside.append(text)
            continue
        if relative not in keep:
            keep.append(relative)
    return keep, blanket, outside


def commit_all(
    workspace_id: str | None = None,
    *,
    message: str,
    paths: Sequence[str] | None = None,
) -> dict[str, Any]:
    """Commit an explicit pathset (no push).

    ``paths`` is what this run actually changed. Left out, the pathset is whatever git
    reports dirty — still staged path by path, never with ``git add -A``: a blanket stage
    takes whatever is in the tree, including a key nobody meant to commit, and there is no
    way to refuse one once it is in the index.
    """
    wid, root = _repo_root(workspace_id)
    msg = (message or "").strip() or "ncc workflow: workspace updates"

    denied = _repo_grant("commit")
    if denied:
        return {"ok": False, "workspace_id": wid, **denied}

    # ``--untracked-files=all`` is not a detail: the default report collapses an untracked
    # directory into ``keys/``, so a secret inside one reads as a folder to the screen
    # below while staging takes the file. ``core.quotepath=false`` keeps a non-ASCII name
    # literal — git would otherwise hand back an escape sequence that is not a pathspec.
    status = _git(
        root, "-c", "core.quotepath=false", "status", "--porcelain", "--untracked-files=all"
    )
    if not status.get("ok"):
        # Never read a failed status as "clean" — that would hide both the failure and
        # the secret screen below.
        return {
            "ok": False,
            "workspace_id": wid,
            "error": "status_failed",
            "reason": status.get("stderr") or "git status failed",
        }

    if paths is None:
        pathset, blanket, outside = _dirty_pathset(status.get("stdout") or ""), [], []
    else:
        pathset, blanket, outside = _named_pathset(root, paths)

    if blanket:
        _audit_floor(
            "denied_blanket_path",
            f"commit pathset names the whole tree: {', '.join(blanket)}",
            tool="git commit",
        )
        return {
            "ok": False,
            "workspace_id": wid,
            "committed": False,
            "error": "denied_blanket_path",
            "denied": "denied_blanket_path",
            "rejectedPaths": blanket,
            "reason": "staging the whole tree is how secrets get committed",
            "hint": "Name the changed paths (--path, repeatable), or leave --path out to "
            "stage what git reports dirty.",
        }
    if outside:
        _audit_floor(
            "denied_path_outside_repo",
            f"commit pathset leaves the checkout: {', '.join(outside)}",
            tool="git commit",
        )
        return {
            "ok": False,
            "workspace_id": wid,
            "committed": False,
            "error": "denied_path_outside_repo",
            "denied": "denied_path_outside_repo",
            "rejectedPaths": outside,
            "reason": "the pathset reaches outside the workspace this run works on",
            "hint": "Pass paths relative to the repository root.",
        }
    # The deny list is unconditional: an explicit --path is not a way past it, and one hit
    # refuses the whole commit rather than quietly dropping a file the caller asked for.
    blocked = secret_paths(pathset)
    if blocked:
        _audit_floor(
            "denied_secret_path",
            f"refused to stage {', '.join(blocked)}",
            tool="git commit",
        )
        return {
            "ok": False,
            "workspace_id": wid,
            "committed": False,
            "error": "denied_secret_path",
            "denied": "denied_secret_path",
            "secretPaths": blocked,
            "reason": "the pathset contains files that look like credentials",
            "hint": "Add them to .gitignore, or stage the real changes yourself with git add <path>.",
        }
    if not pathset:
        return {
            "ok": True,
            "workspace_id": wid,
            "committed": False,
            "reason": "nothing_to_commit",
        }

    added = _git(root, "add", "--", *pathset)
    if not added.get("ok"):
        return {
            "ok": False,
            "workspace_id": wid,
            "committed": False,
            "error": "stage_failed",
            "paths": pathset,
            "reason": added.get("stderr") or "git add failed",
        }
    if not (_git(root, "diff", "--cached", "--name-only").get("stdout") or "").strip():
        # Every named path was already committed. git would fail the commit on an empty
        # index, and "nothing happened" is the honest answer rather than an error.
        return {
            "ok": True,
            "workspace_id": wid,
            "committed": False,
            "paths": pathset,
            "reason": "nothing_to_commit",
        }
    # The diff cap is measured on what is actually staged, then unstaged again: the work
    # stays local and the workspace task stays open.
    if budgets.applies():
        numstat = _git(root, "diff", "--cached", "--numstat")
        lines = budgets.staged_diff_lines(numstat.get("stdout") or "")
        verdict = budgets.check_diff_lines(lines)
        if not verdict.allowed:
            # Scoped to the pathset: a human's staged work is not this run's to unstage.
            _git(root, "reset", "-q", "--", *pathset)
            return {
                "ok": False,
                "workspace_id": wid,
                "committed": False,
                "diffLines": lines,
                **verdict.as_dict(),
            }
    res = _git(root, "commit", "-m", msg)
    return {
        "ok": bool(res["ok"]),
        "workspace_id": wid,
        "committed": bool(res["ok"]),
        "stagedPaths": pathset,
        "stdout": res.get("stdout"),
        "stderr": res.get("stderr"),
    }


def push_branch(workspace_id: str | None = None, *, set_upstream: bool = True) -> dict[str, Any]:
    wid, root = _repo_root(workspace_id)
    cur = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    branch = cur.get("stdout") or ""
    if not branch or branch == "HEAD":
        return {"ok": False, "error": "detached HEAD", "workspace_id": wid}

    denied = _repo_grant("push")
    if denied:
        return {"ok": False, "workspace_id": wid, "branch": branch, **denied}
    if current_grant() is not None and protected_branch(branch):
        _audit_floor("denied_protected_branch", f"{branch} is protected", tool="git push")
        return {
            "ok": False,
            "workspace_id": wid,
            "branch": branch,
            "error": "denied_protected_branch",
            "denied": "denied_protected_branch",
            "reason": f"{branch} is protected",
            "hint": "Push a ncc/… branch and open a PR; getting onto trunk is a human decision.",
        }

    args = ["push"]
    if set_upstream:
        args.extend(["-u", "origin", branch])
    else:
        args.append("origin")
    res = _git(root, *args, timeout=180.0)
    return {
        "ok": bool(res["ok"]),
        "workspace_id": wid,
        "branch": branch,
        "stdout": res.get("stdout"),
        "stderr": res.get("stderr"),
    }


def open_pull_request(
    workspace_id: str | None = None,
    *,
    title: str,
    body: str = "",
    draft: bool = False,
    require_clean_validate: bool = False,
) -> dict[str, Any]:
    """Push current branch and open a PR via gh. Optionally refuse if validate fails."""
    if not shutil.which("gh"):
        raise ValueError("gh CLI not on PATH")
    wid, root = _repo_root(workspace_id)
    denied = _repo_grant("pr")
    if denied:
        return {"ok": False, "workspace_id": wid, **denied}
    if require_clean_validate:
        val = validate_workspace(wid)
        if not val.get("ok"):
            return {
                "ok": False,
                "workspace_id": wid,
                "error": "validate_failed",
                "validate": val,
                "hint": "Fix validators before opening a PR.",
            }
    cur = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    branch = cur.get("stdout") or ""
    push = push_branch(wid)
    held = _pr_budget_hold(root)
    if held:
        return {"ok": False, "workspace_id": wid, "branch": branch, "push": push, **held}
    cmd = [
        "gh",
        "pr",
        "create",
        "--title",
        (title or f"ncc workflow: {branch}")[:200],
        "--body",
        (body or "Opened by NCC workspace workflow.")[:8000],
    ]
    if draft:
        cmd.append("--draft")
    res = _run(cmd, cwd=root, timeout=120.0)
    _audit_publish("create", ok=bool(res["ok"]), detail=res.get("stderr") or res.get("stdout") or "")
    if res["ok"] and budgets.applies():
        budgets.record_pr(_repo_key(root))
    return {
        "ok": bool(res["ok"]),
        "workspace_id": wid,
        "branch": branch,
        "push": push,
        "url": res.get("stdout") if res.get("ok") else "",
        "stderr": res.get("stderr"),
        "stdout": res.get("stdout"),
    }


def merge_pull_request(
    workspace_id: str | None = None,
    *,
    pr: str | None = None,
    confirm: str = "",
    strategy: str = "squash",
) -> dict[str, Any]:
    """Merge PR only on a human decision — a token counts outside grant context only."""
    denied = _human_decision("merge", confirm, "to merge.")
    if denied:
        return {"ok": False, **denied}
    if not shutil.which("gh"):
        raise ValueError("gh CLI not on PATH")
    wid, root = _repo_root(workspace_id)
    strat = strategy if strategy in ("squash", "merge", "rebase") else "squash"
    cmd = ["gh", "pr", "merge"]
    if pr:
        cmd.append(str(pr))
    cmd.extend([f"--{strat}", "--delete-branch"])
    res = _run(cmd, cwd=root, timeout=180.0)
    _audit_publish("merge", ok=bool(res["ok"]), detail=res.get("stderr") or res.get("stdout") or "")
    if res["ok"] and budgets.applies():
        # A PR that lands frees the slot it held in the open-PR budget.
        budgets.record_merge(_repo_key(root))
    return {
        "ok": bool(res["ok"]),
        "workspace_id": wid,
        "pr": pr or "current",
        "strategy": strat,
        "stdout": res.get("stdout"),
        "stderr": res.get("stderr"),
        "confirmed": True,
    }


def bump_version(
    workspace_id: str | None = None,
    *,
    confirm: str = "",
    part: str = "patch",
) -> dict[str, Any]:
    """Bump package.json version only on a human decision (grant ``release`` or token)."""
    denied = _human_decision("release", confirm, "to bump version.")
    if denied:
        return {"ok": False, **denied}
    wid, root = _repo_root(workspace_id)
    part = part if part in ("major", "minor", "patch") else "patch"
    pkg_path = root / "package.json"
    if not pkg_path.is_file():
        return {
            "ok": False,
            "workspace_id": wid,
            "error": "unsupported",
            "hint": "No package.json — bump manually or extend workflow bump later.",
        }
    try:
        data = json.loads(pkg_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"ok": False, "error": str(exc), "workspace_id": wid}
    raw = str(data.get("version") or "0.0.0")
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)", raw)
    if not m:
        return {"ok": False, "error": f"unparsed version {raw!r}", "workspace_id": wid}
    major, minor, patch = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
    if part == "major":
        major, minor, patch = major + 1, 0, 0
    elif part == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    new_v = f"{major}.{minor}.{patch}"
    data["version"] = new_v
    pkg_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    commit = commit_all(
        wid, message=f"chore: bump version to {new_v}", paths=("package.json",)
    )
    return {
        "ok": True,
        "workspace_id": wid,
        "old": raw,
        "version": new_v,
        "part": part,
        "commit": commit,
        "confirmed": True,
    }


def task_start(
    workspace_id: str | None = None,
    *,
    task_id: str | None = None,
    allow_dirty: bool = False,
) -> dict[str, Any]:
    """
    Start one Daily task: mark doing, branch from default, checkpoint.
    One task → one branch. Prefers resume of current doing task.
    """
    from .workflows import get_task, update_task

    wid, root = _repo_root(workspace_id)
    prog = load_progress(wid)
    tid = (task_id or "").strip()
    if not tid:
        # resume in-progress from progress or next_open_task
        if prog.get("current_task_id"):
            tid = str(prog["current_task_id"])
        else:
            nxt = next_open_task(wid)
            if nxt is None:
                return {
                    "ok": False,
                    "workspace_id": wid,
                    "error": "no_open_tasks",
                    "hint": "Run: ncc ai workflow plan",
                }
            tid = str(nxt["id"])
    task = get_task(tid)
    if task is None:
        return {"ok": False, "error": "unknown_task", "task_id": tid, "workspace_id": wid}
    if str(task.get("workspaceId") or "") not in ("", wid):
        return {"ok": False, "error": "task_wrong_workspace", "task_id": tid}
    gap = task_gap_id(task) or "task"
    prefix = re.sub(r"[^a-z0-9]+", "-", gap.lower()).strip("-") or "task"
    branch_res = ensure_branch(
        wid,
        prefix=prefix,
        task_id=tid,
        from_default=True,
        allow_dirty=allow_dirty,
    )
    if not branch_res.get("ok"):
        return {**branch_res, "task_id": tid}
    update_task(tid, status="doing")
    prog["current_task_id"] = tid
    prog["current_branch"] = branch_res.get("branch")
    _append_history(
        prog,
        {
            "event": "task_start",
            "task_id": tid,
            "gap": gap,
            "branch": branch_res.get("branch"),
        },
    )
    save_progress(wid, prog)
    return {
        "ok": True,
        "workspace_id": wid,
        "task_id": tid,
        "title": task.get("title"),
        "gap": gap,
        "priority": task.get("priority"),
        "branch": branch_res.get("branch"),
        "already_branch": branch_res.get("already"),
        "path": str(root),
        "instruction": (
            f"Implement ONLY gap `{gap}` / task `{tid}`. "
            "Then: ncc ai workflow task-finish --task "
            f"{tid} -m '…'"
        ),
    }


def task_finish(
    workspace_id: str | None = None,
    *,
    task_id: str | None = None,
    message: str = "",
    title: str = "",
    body: str = "",
    skip_rebase: bool = False,
    draft: bool = False,
) -> dict[str, Any]:
    """
    Finish one task: validate (hard) → commit → rebase → PR → mark done + checkpoint.
    Refuses PR if validate fails.
    """
    from .workflows import append_task_link, complete_task, get_task, update_task

    wid, _root = _repo_root(workspace_id)
    prog = load_progress(wid)
    tid = (task_id or "").strip() or str(prog.get("current_task_id") or "")
    if not tid:
        return {"ok": False, "error": "no_task_id", "hint": "Pass --task ID"}
    task = get_task(tid)
    if task is None:
        return {"ok": False, "error": "unknown_task", "task_id": tid}
    gap = task_gap_id(task) or "task"
    val = validate_workspace(wid)
    if not val.get("ok"):
        update_task(tid, status="doing")
        _append_history(
            prog,
            {"event": "validate_failed", "task_id": tid, "gap": gap},
        )
        save_progress(wid, prog)
        return {
            "ok": False,
            "workspace_id": wid,
            "task_id": tid,
            "error": "validate_failed",
            "validate": val,
            "hint": "Fix failures; do not open a PR.",
        }
    msg = (message or "").strip() or f"workflow({gap}): {task.get('title')}"
    commit = commit_all(wid, message=msg)
    if not commit.get("ok"):
        return {
            "ok": False,
            "workspace_id": wid,
            "task_id": tid,
            "error": "commit_failed",
            "commit": commit,
        }
    rebase = {"ok": True, "skipped": True}
    if not skip_rebase:
        rebase = rebase_onto_default(wid)
        if not rebase.get("ok"):
            return {
                "ok": False,
                "workspace_id": wid,
                "task_id": tid,
                "error": "rebase_failed",
                "rebase": rebase,
                "commit": commit,
                "hint": "Resolve rebase manually; PR not opened.",
            }
    pr_title = (title or "").strip() or f"workflow: {gap} — {task.get('title')}"
    pr_body = (body or "").strip() or (
        f"Autonomous workflow task `{tid}` (gap `{gap}`).\n\n"
        f"{task.get('body') or ''}"
    )
    pr = open_pull_request(
        wid,
        title=pr_title,
        body=pr_body,
        draft=draft,
        require_clean_validate=False,  # already validated
    )
    if not pr.get("ok"):
        return {
            "ok": False,
            "workspace_id": wid,
            "task_id": tid,
            "error": "pr_failed",
            "pr": pr,
            "commit": commit,
            "rebase": rebase,
        }
    complete_task(tid)
    if pr.get("url"):
        append_task_link(tid, f"pr:{pr['url']}")
    completed = list(prog.get("completed") or [])
    completed.append(
        {
            "task_id": tid,
            "gap": gap,
            "branch": pr.get("branch"),
            "pr_url": pr.get("url"),
            "at": _now(),
        }
    )
    prog["completed"] = completed[-50:]
    prog["current_task_id"] = None
    prog["current_branch"] = None
    _append_history(
        prog,
        {
            "event": "task_finish",
            "task_id": tid,
            "gap": gap,
            "pr_url": pr.get("url"),
        },
    )
    save_progress(wid, prog)
    nxt = next_open_task(wid)
    return {
        "ok": True,
        "workspace_id": wid,
        "task_id": tid,
        "gap": gap,
        "commit": commit,
        "rebase": rebase,
        "pr": pr,
        "next": (
            {
                "id": nxt.get("id"),
                "title": nxt.get("title"),
                "gap": task_gap_id(nxt),
                "priority": nxt.get("priority"),
            }
            if nxt
            else None
        ),
    }


def resume_status(workspace_id: str | None = None) -> dict[str, Any]:
    """What to do next: current doing task or next todo + progress."""
    from .workflows import get_task

    wid = resolve_workspace_id(workspace_id)
    prog = load_progress(wid)
    cur_id = prog.get("current_task_id")
    cur_task = get_task(str(cur_id)) if cur_id else None
    nxt = next_open_task(wid)
    return {
        "ok": True,
        "workspace_id": wid,
        "progress": prog,
        "current_task": (
            {
                "id": cur_task.get("id"),
                "title": cur_task.get("title"),
                "status": cur_task.get("status"),
                "gap": task_gap_id(cur_task),
                "branch": prog.get("current_branch"),
            }
            if cur_task
            else None
        ),
        "next": (
            {
                "id": nxt.get("id"),
                "title": nxt.get("title"),
                "status": nxt.get("status"),
                "priority": nxt.get("priority"),
                "gap": task_gap_id(nxt),
            }
            if nxt
            else None
        ),
        "hint": (
            f"Resume: ncc ai workflow task-start --task {cur_id}"
            if cur_id
            else (
                f"Start: ncc ai workflow task-start --task {nxt.get('id')}"
                if nxt
                else "No open p0/p1 tasks — plan or ship."
            )
        ),
    }


def execute_status(workspace_id: str | None = None) -> dict[str, Any]:
    wid, root = _repo_root(workspace_id)
    branch = _git(root, "rev-parse", "--abbrev-ref", "HEAD").get("stdout") or ""
    dirty = _is_dirty(root)
    pr_url = ""
    if shutil.which("gh"):
        view = _run(
            ["gh", "pr", "view", "--json", "url,number,state,title"],
            cwd=root,
            timeout=30.0,
        )
        if view.get("ok") and view.get("stdout"):
            try:
                pr_url = json.loads(view["stdout"]).get("url") or ""
            except json.JSONDecodeError:
                pr_url = view["stdout"][:200]
    prog = load_progress(wid)
    return {
        "workspace_id": wid,
        "path": str(root),
        "branch": branch,
        "default_branch": detect_default_branch(root),
        "dirty": dirty,
        "pr_url": pr_url,
        "progress": prog,
        "validators": [" ".join(c) for c in detect_validate_commands(root)],
        "confirm_token": CONFIRM_TOKEN,
        "hints": [
            "pro loop: plan → task-start → implement → task-finish (validate hard)",
            "one task = one branch = one PR; resume via workflow resume",
            f'merge/bump require confirm="{CONFIRM_TOKEN}"',
        ],
    }
