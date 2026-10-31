"""Read-only inventory of the operator's project portfolio and how it drifts.

The agent cannot build this itself. Its `git` MCP server is bound to one
``{{workspace.path}}``, its `filesystem` server is rooted at ``/tmp/ncc-mcp-fs``, and the
``read-only`` profile sets ``allow_shell=False`` — so "walk every project under one root" has
no tool behind it. This module is that tool: one call, whole portfolio, deterministic.

Everything here reads. The drift it reports is the difference between four things that are each
individually plausible and jointly wrong — the folder name on disk, the name its ``origin``
points at, what ``workspaces.json`` claims, and what its README says the project is for. Only
the second is read from git (`rev-parse`/`remote`/`status`), each call bounded by a timeout,
never a write and never a fetch.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from core.store.workspaces import (
    Workspace,
    detect_github_slug,
    discover_git_repos,
    is_git_repo,
    list_workspaces,
)

#: Readme names we look at, in order, for the one line that says what a project is for.
README_NAMES = ("README.md", "README.rst", "README.txt", "README", "readme.md")

#: Longest "what does this do" line worth carrying into a report row.
PURPOSE_MAX = 180


def _git(root: Path, *args: str) -> str | None:
    """stdout of a read-only git call, or None when git could not answer. Never raises.

    ``--no-optional-locks`` is not decoration: ``git status`` refreshes the index cache by
    default and would rewrite ``.git/index`` in every repository this audit only came to look at.
    """
    try:
        proc = subprocess.run(
            ["git", "--no-optional-locks", "-C", str(root), *args],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return (proc.stdout or "").strip()


def _purpose(root: Path) -> tuple[str | None, str | None]:
    """``(purpose, readme_name)`` — first heading, else first prose line of the README."""
    for name in README_NAMES:
        candidate = root / name
        if not candidate.is_file():
            continue
        try:
            text = candidate.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith(("<!--", "[![", "<img")):
                continue
            if stripped.startswith("#"):
                stripped = stripped.lstrip("#").strip()
            if stripped:
                return stripped[:PURPOSE_MAX], name
            break
        return None, name
    return None, None


@dataclass
class ProjectRow:
    """One project as the portfolio sees it, with every name it answers to."""

    folder: str
    path: str
    is_repo: bool = False
    branch: str | None = None
    dirty_paths: int | None = None
    origin_slug: str | None = None
    registry_id: str | None = None
    registry_github: str | None = None
    purpose: str | None = None
    purpose_from: str | None = None
    drifts: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        out: dict[str, Any] = {"folder": self.folder, "path": self.path, "is_repo": self.is_repo}
        for key, value in (
            ("branch", self.branch),
            ("dirty_paths", self.dirty_paths),
            ("origin_slug", self.origin_slug),
            ("registry_id", self.registry_id),
            ("registry_github", self.registry_github),
            ("purpose", self.purpose),
            ("purpose_from", self.purpose_from),
        ):
            if value is not None:
                out[key] = value
        out["drifts"] = list(self.drifts)
        return out


def _folder_of(path: str) -> str:
    return Path(path).name


def _repo_name(slug: str) -> str:
    return slug.rsplit("/", 1)[-1]


def _read_registry() -> dict[str, Workspace]:
    by_path: dict[str, Workspace] = {}
    for ws in list_workspaces():
        by_path.setdefault(str(Path(ws.path).resolve()), ws)
    return by_path


def _scan_project(root: Path, registry: dict[str, Workspace]) -> ProjectRow:
    row = ProjectRow(folder=root.name, path=str(root))
    resolved = str(root.resolve())

    ws = registry.get(resolved)
    if ws is not None:
        row.registry_id = ws.id
        row.registry_github = ws.github

    purpose, readme = _purpose(root)
    row.purpose = purpose
    row.purpose_from = readme

    if not is_git_repo(root):
        row.drifts.append("not_a_repo")
        return row

    row.is_repo = True
    row.branch = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    status = _git(root, "status", "--porcelain")
    row.dirty_paths = len([ln for ln in (status or "").splitlines() if ln.strip()])
    if row.dirty_paths:
        row.drifts.append("dirty_worktree")

    slug = detect_github_slug(root)
    row.origin_slug = slug
    if slug is None:
        row.drifts.append("no_origin_remote")
        return row

    if _repo_name(slug).lower() != root.name.lower():
        row.drifts.append("folder_vs_origin_name")
    if row.registry_github and row.registry_github.lower() != slug.lower():
        row.drifts.append("registry_vs_origin")
    elif row.registry_github is None:
        row.drifts.append("registry_github_missing")
    if ws is None:
        row.drifts.append("repo_not_registered")
    return row


def portfolio_drift_report(
    root: str | Path | None = None,
) -> dict[str, Any]:
    """Inventory every project under ``root`` and report how its names and state disagree.

    ``root`` defaults to the common parent of the registered workspace paths, so a run started
    without arguments looks at the same folder the operator's registry lives in. Missing paths
    are dropped from that parent before it is computed — one deleted checkout must not move the
    root to ``/home/<user>`` and turn an audit of a portfolio into an audit of a home directory.
    """
    registry = _read_registry()

    portfolio_root = Path(root).expanduser().resolve() if root else None
    if portfolio_root is None:
        existing = [Path(ws.path) for ws in registry.values() if Path(ws.path).is_dir()]
        if not existing:
            return {
                "ok": False,
                "error": "No portfolio root: pass one, or register a workspace whose path exists.",
                "registered": len(registry),
            }
        # One checkout tells us its parent and nothing else; several bound the portfolio between them.
        portfolio_root = existing[0].parent if len(existing) == 1 else _common_parent(existing)

    if not portfolio_root.is_dir():
        return {"ok": False, "error": f"Portfolio root is not a directory: {portfolio_root}"}

    rows: list[ProjectRow] = []
    seen: set[str] = set()

    for repo in discover_git_repos(portfolio_root):
        seen.add(str(repo.resolve()))
        rows.append(_scan_project(repo, registry))

    for child in sorted((p for p in portfolio_root.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
        resolved = str(child.resolve())
        if resolved in seen or child.name.startswith("."):
            continue
        # A registered folder that is still on disk belongs here, repo or not: skipping it would
        # hide "registered and present but not a repository", which is one of the drifts asked for.
        seen.add(resolved)
        rows.append(_scan_project(child, registry))

    missing: list[dict[str, Any]] = []
    for path, ws in sorted(registry.items()):
        if Path(path).is_dir():
            continue
        entry: dict[str, Any] = {"id": ws.id, "path": path, "drifts": ["registered_path_missing"]}
        if ws.github:
            entry["registry_github"] = ws.github
        missing.append(entry)

    rows.sort(key=lambda r: r.folder.lower())

    counts: dict[str, int] = {}
    for row in rows:
        for drift in row.drifts:
            counts[drift] = counts.get(drift, 0) + 1
    for entry in missing:
        for drift in entry["drifts"]:
            counts[drift] = counts.get(drift, 0) + 1

    report: dict[str, Any] = {
        "ok": True,
        "root": str(portfolio_root),
        "projects": [r.to_dict() for r in rows],
        "registered_but_missing": missing,
        "counts": counts,
        "github": _github_state(),
        "summary": f"{len(rows)} projects under {portfolio_root}, {len(missing)} registered but missing",
    }
    return report


def _common_parent(paths: list[Path]) -> Path:
    """Deepest directory that contains every path, at or below their shared ancestor."""
    parts = [p.parts for p in paths]
    shared: list[str] = []
    for group in zip(*parts):
        if len(set(group)) != 1:
            break
        shared.append(group[0])
    return Path(*shared) if shared else Path("/")


def _github_state() -> dict[str, Any]:
    """Why GitHub-side facts were not compared — always stated, never a quiet absence.

    A report that says nothing about GitHub reads as "nothing was wrong there". On a host without
    ``gh`` the honest answer is that the upstream half was not looked at, so each reason is named
    apart: not installed, no credential, or nothing to ask about.
    """
    if shutil.which("gh") is None:
        return {"checked": False, "reason": "gh is not installed on this host"}
    if not (os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")):
        return {"checked": False, "reason": "gh exists but no GH_TOKEN/GITHUB_TOKEN for this run"}
    return {
        "checked": False,
        "reason": "upstream comparison is not implemented; nothing about GitHub was verified",
    }


def drift_findings(report: dict[str, Any]) -> list[str]:
    """Flat ``project — drift`` lines, for a run that only wants to write the list down."""
    lines: list[str] = []
    for row in report.get("projects", []):
        for drift in row.get("drifts", []):
            lines.append(f"{row['folder']} — {drift}")
    for entry in report.get("registered_but_missing", []):
        for drift in entry.get("drifts", []):
            lines.append(f"{entry['id']} — {drift}")
    return lines
