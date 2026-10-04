"""Local git workspace registry for agent templates / MCP."""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .paths import workspaces_file

_ID_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9_-]{0,47}$")
_GITHUB_SSH = re.compile(r"git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$")
_GITHUB_HTTPS = re.compile(r"https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$")


@dataclass
class Workspace:
    id: str
    label: str
    path: str
    github: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "id": self.id,
            "label": self.label,
            "path": self.path,
        }
        if self.github:
            d["github"] = self.github
        return d

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> Workspace | None:
        wid = str(raw.get("id") or "").strip()
        path = str(raw.get("path") or "").strip()
        if not wid or not path:
            return None
        label = str(raw.get("label") or wid).strip() or wid
        gh = str(raw.get("github") or "").strip() or None
        return cls(id=wid, label=label, path=path, github=gh)


def slug_from_path(path: Path) -> str:
    """Derive a valid workspace id from a directory name."""
    raw = re.sub(r"[^a-zA-Z0-9_-]+", "-", path.name).strip("-")
    if not raw:
        raw = "workspace"
    if raw[0].isdigit():
        raw = f"ws-{raw}"
    return raw[:48]


def detect_github_slug(repo_path: Path) -> str | None:
    """Best-effort owner/repo from ``git remote get-url origin``."""
    try:
        proc = subprocess.run(
            ["git", "-C", str(repo_path), "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    url = (proc.stdout or "").strip()
    if not url:
        return None
    for pattern in (_GITHUB_SSH, _GITHUB_HTTPS):
        m = pattern.match(url)
        if m:
            return f"{m.group(1)}/{m.group(2)}"
    return None


def is_git_repo(path: Path) -> bool:
    return (path / ".git").exists()


def discover_git_repos(parent: str | Path, *, max_depth: int = 1) -> list[Path]:
    """
    Find git repositories under ``parent``.

    - depth 0: parent itself if it is a repo
    - depth 1: immediate child dirs that are repos (typical ~/Git layout)
    """
    root = Path(parent).expanduser().resolve()
    if not root.is_dir():
        return []
    found: list[Path] = []
    if is_git_repo(root):
        found.append(root)
    if max_depth < 1:
        return found
    try:
        children = sorted(root.iterdir(), key=lambda p: p.name.lower())
    except OSError:
        return found
    for child in children:
        if child.is_dir() and not child.name.startswith(".") and is_git_repo(child):
            if child not in found:
                found.append(child)
    return found


def validate_workspace_id(workspace_id: str) -> str:
    wid = (workspace_id or "").strip()
    if not _ID_RE.match(wid):
        raise ValueError(
            "Workspace id must start with a letter and use only "
            "letters, digits, '_' or '-' (max 48 chars)."
        )
    return wid


def _load_raw() -> dict[str, Any]:
    path = workspaces_file()
    if not path.is_file():
        return {"workspaces": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"workspaces": []}
    if not isinstance(data, dict):
        return {"workspaces": []}
    items = data.get("workspaces")
    if not isinstance(items, list):
        data["workspaces"] = []
    return data


def _save_raw(data: dict[str, Any]) -> None:
    path = workspaces_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def list_workspaces() -> list[Workspace]:
    out: list[Workspace] = []
    for raw in _load_raw().get("workspaces") or []:
        if isinstance(raw, dict):
            ws = Workspace.from_dict(raw)
            if ws:
                out.append(ws)
    return out


def get_workspace(workspace_id: str) -> Workspace | None:
    for ws in list_workspaces():
        if ws.id == workspace_id:
            return ws
    return None


def upsert_workspace(
    workspace_id: str,
    path: str,
    *,
    label: str | None = None,
    github: str | None = None,
) -> Workspace:
    wid = validate_workspace_id(workspace_id)
    p = Path(path).expanduser().resolve()
    if not p.exists():
        raise ValueError(f"Workspace path does not exist: {p}")
    if not p.is_dir():
        raise ValueError(f"Workspace path is not a directory: {p}")
    gh = (github or "").strip() or None
    if gh and "/" not in gh:
        raise ValueError("github must look like owner/repo")
    ws = Workspace(
        id=wid,
        label=(label or "").strip() or p.name or wid,
        path=str(p),
        github=gh,
    )
    data = _load_raw()
    items = [x for x in (data.get("workspaces") or []) if isinstance(x, dict)]
    replaced = False
    for i, raw in enumerate(items):
        if str(raw.get("id") or "") == wid:
            items[i] = ws.to_dict()
            replaced = True
            break
    if not replaced:
        items.append(ws.to_dict())
    data["workspaces"] = items
    _save_raw(data)
    return ws


def delete_workspace(workspace_id: str) -> bool:
    data = _load_raw()
    items = [x for x in (data.get("workspaces") or []) if isinstance(x, dict)]
    new_items = [x for x in items if str(x.get("id") or "") != workspace_id]
    if len(new_items) == len(items):
        return False
    data["workspaces"] = new_items
    _save_raw(data)
    return True


def resolve_workspace_paths(ids: list[str]) -> list[Workspace]:
    missing: list[str] = []
    out: list[Workspace] = []
    for wid in ids:
        ws = get_workspace(str(wid))
        if ws is None:
            missing.append(str(wid))
        else:
            out.append(ws)
    if missing:
        raise ValueError(f"Unknown workspace id(s): {', '.join(missing)}")
    return out


def import_repos(
    paths: list[str | Path],
    *,
    detect_github: bool = True,
) -> list[Workspace]:
    """Upsert each path as a workspace (id from folder name)."""
    imported: list[Workspace] = []
    for raw in paths:
        p = Path(raw).expanduser().resolve()
        if not p.is_dir():
            continue
        wid = slug_from_path(p)
        # Avoid colliding ids by suffixing if path differs
        existing = get_workspace(wid)
        if existing and Path(existing.path).resolve() != p:
            n = 2
            while get_workspace(f"{wid}-{n}") is not None:
                n += 1
            wid = validate_workspace_id(f"{wid}-{n}")
        gh = detect_github_slug(p) if detect_github else None
        imported.append(
            upsert_workspace(wid, str(p), label=p.name, github=gh)
        )
    return imported


def import_from_parent(parent: str | Path, *, detect_github: bool = True) -> list[Workspace]:
    """Scan a parent folder (e.g. ~/Git) and register each child git repo."""
    repos = discover_git_repos(parent, max_depth=1)
    if not repos:
        raise ValueError(
            f"No git repositories found under {Path(parent).expanduser()}. "
            "Pick a folder that contains project repos (each with a .git directory), "
            "or add a single repo folder instead."
        )
    return import_repos(repos, detect_github=detect_github)
