"""Enforce GitHub Agent write policy before any repo mutate.

Callers: ``core.workflows.github_agent_act`` (``apply_item``, ``arm_campaign``,
``tick_campaign``). No other module enforces ``githubAgent.*`` prefs on writes
today — ToolRuntime uses host grants only. Reads preferences + git dirtiness;
writes nothing.

User: "sollte den als im ui ux auch dann rechte geben oder? ob der was an repos
changen darf … welche repos untouched … best practise … autonmm mehre tage"
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

from core.store.preferences import (
    get_github_agent_allow_write,
    get_github_agent_allowlist,
    get_github_agent_confirm,
    get_github_agent_denylist,
    get_github_agent_dirty_policy,
    get_github_agent_write_classes,
)

GAP_WRITE_CLASS: dict[str, str] = {
    "agents-md": "docs",
    "impressum": "docs",
    "privacy": "docs",
    "skills": "docs",
}

DOCS_GAPS = frozenset(GAP_WRITE_CLASS)


def write_class_for_gap(gap_id: str) -> str | None:
    return GAP_WRITE_CLASS.get(str(gap_id or "").strip())


def is_worktree_dirty(root: Path) -> bool:
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return True
    return bool((proc.stdout or "").strip())


def evaluate_write(
    *,
    workspace_id: str,
    gap_id: str,
    root: Path | None,
    state: str | None = None,
    unattended: bool = True,
) -> dict[str, Any]:
    """Return ``{ok, reason, writeClass}``. ``ok=False`` means do not write."""
    wid = str(workspace_id or "").strip()
    gid = str(gap_id or "").strip()
    wclass = write_class_for_gap(gid)
    if not wclass:
        return {"ok": False, "reason": "unsupported_gap", "writeClass": None}
    if state and str(state).startswith("archive"):
        return {"ok": False, "reason": "archive", "writeClass": wclass}
    if not get_github_agent_allow_write():
        return {"ok": False, "reason": "allowWrite_false", "writeClass": wclass}
    confirm = get_github_agent_confirm()
    if unattended and confirm == "always":
        return {"ok": False, "reason": "confirm_always", "writeClass": wclass}
    allowed_classes = set(get_github_agent_write_classes())
    if wclass not in allowed_classes:
        return {"ok": False, "reason": "write_class_blocked", "writeClass": wclass}
    deny = set(get_github_agent_denylist())
    if wid in deny:
        return {"ok": False, "reason": "denylist", "writeClass": wclass}
    allow = get_github_agent_allowlist()
    if allow and wid not in set(allow):
        return {"ok": False, "reason": "not_in_allowlist", "writeClass": wclass}
    if root is None or not root.is_dir():
        return {"ok": False, "reason": "path_missing", "writeClass": wclass}
    dirty = is_worktree_dirty(root)
    if dirty:
        policy = get_github_agent_dirty_policy()
        if policy == "abort":
            return {"ok": False, "reason": "dirty_abort", "writeClass": wclass}
        return {"ok": False, "reason": "dirty_skip", "writeClass": wclass}
    return {"ok": True, "reason": "ok", "writeClass": wclass}
