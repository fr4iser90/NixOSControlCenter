"""Workspace workflow: audit gaps + plan Daily tasks (one workspace at a time)."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from .preferences import get_active_workspace_id
from .workspaces import get_workspace, list_workspaces

# Gap id → (title for tasks, priority, related template id)
GAP_META: dict[str, dict[str, str]] = {
    "agents-md": {
        "title": "Add or refresh AGENTS.md",
        "priority": "p0",
        "template": "agents-md-creator",
        "horizon": "now",
    },
    "skills": {
        "title": "Scaffold .agents/skills for this project",
        "priority": "p0",
        "template": "skill-pack-creator",
        "horizon": "now",
    },
    "impressum": {
        "title": "Add DE Impressum stub",
        "priority": "p1",
        "template": "impressum-creator",
        "horizon": "now",
    },
    "privacy": {
        "title": "Add privacy-policy stub (DE/EU)",
        "priority": "p1",
        "template": "privacy-policy-creator",
        "horizon": "now",
    },
    "roadmap-doc": {
        "title": "Add doc/roadmap.md (or refresh from Daily roadmap)",
        "priority": "p1",
        "template": "roadmap-creator",
        "horizon": "next",
    },
    "license": {
        "title": "Add LICENSE (SPDX chooser)",
        "priority": "p2",
        "template": "license-chooser",
        "horizon": "later",
    },
    "precommit": {
        "title": "Add .pre-commit-config.yaml",
        "priority": "p2",
        "template": "precommit-creator",
        "horizon": "next",
    },
    "githooks": {
        "title": "Wire .githooks / install-git-hooks",
        "priority": "p2",
        "template": "githooks-creator",
        "horizon": "next",
    },
    "readme": {
        "title": "Add README.md project overview",
        "priority": "p2",
        "template": "design-concept-creator",
        "horizon": "later",
    },
    "changelog": {
        "title": "Add CHANGELOG.md",
        "priority": "p2",
        "template": "changelog-creator",
        "horizon": "later",
    },
    "contributing": {
        "title": "Add CONTRIBUTING.md",
        "priority": "p2",
        "template": "contributing-creator",
        "horizon": "later",
    },
    "security-md": {
        "title": "Add SECURITY.md",
        "priority": "p2",
        "template": "security-md-creator",
        "horizon": "later",
    },
    "gitignore": {
        "title": "Add .gitignore",
        "priority": "p2",
        "template": "gitignore-creator",
        "horizon": "now",
    },
    "github-actions": {
        "title": "Add GitHub Actions CI stub",
        "priority": "p2",
        "template": "github-actions-creator",
        "horizon": "next",
    },
    "codeowners": {
        "title": "Add CODEOWNERS",
        "priority": "p2",
        "template": "codeowners-creator",
        "horizon": "later",
    },
}

_PRIO_RANK = {"p0": 0, "p1": 1, "p2": 2}

_IMPRESSUM_NAMES = (
    "impressum.md",
    "IMPRESSUM.md",
    "doc/impressum.md",
    "site/impressum.md",
    "frontend/impressum.md",
)
_PRIVACY_NAMES = (
    "privacy.md",
    "PRIVACY.md",
    "datenschutz.md",
    "DATENSCHUTZ.md",
    "doc/privacy.md",
    "doc/datenschutz.md",
    "site/privacy.md",
    "site/datenschutz.md",
)
_ROADMAP_NAMES = (
    "doc/roadmap.md",
    "ROADMAP.md",
    "roadmap.md",
    "docs/roadmap.md",
)


def gap_link(gap_id: str) -> str:
    return f"gap:{gap_id}"


def template_link(template_id: str) -> str:
    return f"template:{template_id}"


def task_gap_id(task: dict[str, Any]) -> str | None:
    for link in task.get("links") or []:
        s = str(link)
        if s.startswith("gap:"):
            return s[4:].strip() or None
    return None


@dataclass
class Gap:
    id: str
    present: bool
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class AuditReport:
    workspace_id: str
    path: str
    label: str
    github: str | None
    is_git: bool
    gaps: list[Gap] = field(default_factory=list)
    hints: list[str] = field(default_factory=list)

    @property
    def missing(self) -> list[Gap]:
        return [g for g in self.gaps if not g.present]

    def to_dict(self) -> dict[str, Any]:
        return {
            "workspace_id": self.workspace_id,
            "path": self.path,
            "label": self.label,
            "github": self.github,
            "is_git": self.is_git,
            "gaps": [g.to_dict() for g in self.gaps],
            "missing": [g.id for g in self.missing],
            "missing_count": len(self.missing),
            "hints": list(self.hints),
            "next_templates": [
                GAP_META[g.id]["template"]
                for g in self.missing
                if g.id in GAP_META
            ],
        }


def _exists_any(root: Path, names: tuple[str, ...]) -> tuple[bool, str]:
    for name in names:
        p = root / name
        if p.is_file():
            return True, str(p.relative_to(root))
    return False, ""


def _has_skills(root: Path) -> tuple[bool, str]:
    skills = root / ".agents" / "skills"
    if not skills.is_dir():
        return False, "no .agents/skills/"
    try:
        kids = [p for p in skills.iterdir() if p.is_dir() and (p / "SKILL.md").is_file()]
    except OSError:
        return False, "unreadable .agents/skills/"
    if not kids:
        return False, ".agents/skills/ empty (no SKILL.md packs)"
    return True, f"{len(kids)} skill pack(s)"


def resolve_workspace_id(workspace_id: str | None = None) -> str:
    wid = (workspace_id or "").strip() or (get_active_workspace_id() or "")
    if not wid:
        raise ValueError(
            "No workspace id. Register one in Settings → Workspaces "
            "(or Companion session picker), then set it active — "
            "or pass --workspace <id>."
        )
    ws = get_workspace(wid)
    if ws is None:
        known = ", ".join(w.id for w in list_workspaces()) or "(none)"
        raise ValueError(f"Unknown workspace {wid!r}. Known: {known}")
    return wid


def audit_workspace(workspace_id: str | None = None) -> AuditReport:
    """Probe repo layout for common ops gaps (deterministic, no LLM)."""
    wid = resolve_workspace_id(workspace_id)
    ws = get_workspace(wid)
    assert ws is not None
    root = Path(ws.path).expanduser()
    report = AuditReport(
        workspace_id=ws.id,
        path=str(root),
        label=ws.label,
        github=ws.github,
        is_git=(root / ".git").exists(),
    )
    if not root.is_dir():
        report.hints.append(f"Path missing or not a directory: {root}")
        return report
    if not report.is_git:
        report.hints.append("Not a git repo (.git missing) — register a git root.")

    checks: list[tuple[str, bool, str]] = []
    ok, detail = (root / "AGENTS.md").is_file(), (
        "AGENTS.md" if (root / "AGENTS.md").is_file() else "missing"
    )
    checks.append(("agents-md", ok, detail))

    ok, detail = _has_skills(root)
    checks.append(("skills", ok, detail))

    ok, detail = _exists_any(root, _IMPRESSUM_NAMES)
    checks.append(("impressum", ok, detail or "missing"))

    ok, detail = _exists_any(root, _PRIVACY_NAMES)
    checks.append(("privacy", ok, detail or "missing"))

    ok, detail = _exists_any(root, _ROADMAP_NAMES)
    checks.append(("roadmap-doc", ok, detail or "missing"))

    lic_ok = any(
        (root / n).is_file()
        for n in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING")
    )
    checks.append(("license", lic_ok, "LICENSE*" if lic_ok else "missing"))

    pre = (root / ".pre-commit-config.yaml").is_file()
    checks.append(
        ("precommit", pre, ".pre-commit-config.yaml" if pre else "missing")
    )

    hooks = (root / ".githooks").is_dir()
    checks.append(("githooks", hooks, ".githooks/" if hooks else "missing"))

    readme = (root / "README.md").is_file() or (root / "README").is_file()
    checks.append(("readme", readme, "README.md" if readme else "missing"))

    cl = (root / "CHANGELOG.md").is_file() or (root / "CHANGELOG").is_file()
    checks.append(("changelog", cl, "CHANGELOG.md" if cl else "missing"))

    contrib = (root / "CONTRIBUTING.md").is_file()
    checks.append(("contributing", contrib, "CONTRIBUTING.md" if contrib else "missing"))

    sec = (root / "SECURITY.md").is_file() or (root / "docs" / "SECURITY.md").is_file()
    checks.append(("security-md", sec, "SECURITY.md" if sec else "missing"))

    gi = (root / ".gitignore").is_file()
    checks.append(("gitignore", gi, ".gitignore" if gi else "missing"))

    wf_dir = root / ".github" / "workflows"
    gha = False
    if wf_dir.is_dir():
        gha = any(wf_dir.glob("*.yml")) or any(wf_dir.glob("*.yaml"))
    checks.append(
        ("github-actions", gha, ".github/workflows" if gha else "missing")
    )

    co = (
        (root / "CODEOWNERS").is_file()
        or (root / ".github" / "CODEOWNERS").is_file()
        or (root / "docs" / "CODEOWNERS").is_file()
    )
    checks.append(("codeowners", co, "CODEOWNERS" if co else "missing"))

    for gid, present, detail in checks:
        report.gaps.append(Gap(id=gid, present=present, detail=detail))

    if report.missing:
        report.hints.append(
            "Run: ncc ai workflow plan --workspace "
            f"{ws.id}  → creates Daily tasks; then task-start / task-finish per gap."
        )
    else:
        report.hints.append("No structural gaps detected for workflow v1 checks.")
    return report


def _tasks_for_workspace(wid: str) -> list[dict[str, Any]]:
    from .workflows import list_tasks

    return [
        t
        for t in list_tasks()
        if str(t.get("workspaceId") or "") in ("", wid)
    ]


def find_task_for_gap(
    wid: str, gap_id: str, *, include_done: bool = True
) -> dict[str, Any] | None:
    link = gap_link(gap_id)
    for t in _tasks_for_workspace(wid):
        links = [str(x) for x in (t.get("links") or [])]
        if link not in links:
            continue
        if not include_done and str(t.get("status") or "") == "done":
            continue
        return t
    return None


def open_tasks_ordered(
    workspace_id: str | None = None,
    *,
    priorities: tuple[str, ...] = ("p0", "p1"),
) -> list[dict[str, Any]]:
    """Open todo/doing tasks for workspace, sorted by priority then doing-first."""
    wid = resolve_workspace_id(workspace_id)
    open_ = [
        t
        for t in _tasks_for_workspace(wid)
        if str(t.get("status") or "") in ("todo", "doing")
        and str(t.get("priority") or "p1") in priorities
    ]

    def _key(t: dict[str, Any]) -> tuple[int, str, str]:
        pr = str(t.get("priority") or "p1")
        return (
            _PRIO_RANK.get(pr, 9),
            "0" if str(t.get("status")) == "doing" else "1",
            str(t.get("createdAt") or ""),
        )

    return sorted(open_, key=_key)


def next_open_task(
    workspace_id: str | None = None,
    *,
    priorities: tuple[str, ...] = ("p0", "p1"),
) -> dict[str, Any] | None:
    """Prefer in-progress (doing), else next todo by priority."""
    ordered = open_tasks_ordered(workspace_id, priorities=priorities)
    return ordered[0] if ordered else None


def plan_from_audit(
    workspace_id: str | None = None,
    *,
    create_roadmap: bool = True,
) -> dict[str, Any]:
    """
    Create Daily tasks for missing gaps.
    Idempotent via stable link ``gap:<id>`` (not title string).
    """
    from .workflows import add_roadmap_item, add_task, list_roadmap

    report = audit_workspace(workspace_id)
    wid = report.workspace_id
    created_tasks: list[dict[str, Any]] = []
    skipped: list[str] = []
    for gap in report.missing:
        meta = GAP_META.get(gap.id) or {}
        existing = find_task_for_gap(wid, gap.id, include_done=True)
        if existing is not None:
            skipped.append(gap.id)
            continue
        title = str(meta.get("title") or f"Fix gap: {gap.id}")
        links = [gap_link(gap.id)]
        if meta.get("template"):
            links.append(template_link(str(meta["template"])))
        task = add_task(
            title,
            body=(
                f"Workflow gap `{gap.id}` for workspace `{wid}`.\n"
                f"Detail: {gap.detail}\n"
                f"Suggested template: {meta.get('template') or '—'}\n"
                f"Stable link: {gap_link(gap.id)}"
            ),
            status="todo",
            priority=str(meta.get("priority") or "p1"),
            workspace_id=wid,
            links=links,
        )
        created_tasks.append(task)

    created_roadmap: list[dict[str, Any]] = []
    if create_roadmap and report.missing:
        rm_title = f"Workflow gaps · {wid}"
        already = any(
            str(r.get("title") or "").strip().lower() == rm_title.lower()
            and str(r.get("horizon") or "") == "now"
            for r in list_roadmap()
        )
        if not already:
            created_roadmap.append(
                add_roadmap_item(
                    rm_title,
                    horizon="now",
                    task_ids=[t["id"] for t in created_tasks],
                )
            )

    return {
        "ok": True,
        "workspace_id": wid,
        "audit": report.to_dict(),
        "created_tasks": created_tasks,
        "skipped_gaps": skipped,
        "created_roadmap": created_roadmap,
    }


def workflow_status(workspace_id: str | None = None) -> dict[str, Any]:
    """Compact status for Companion / CLI."""
    report = audit_workspace(workspace_id)
    wid = report.workspace_id
    open_tasks = open_tasks_ordered(wid, priorities=("p0", "p1", "p2"))
    nxt = next_open_task(wid)
    return {
        "workspace_id": wid,
        "path": report.path,
        "label": report.label,
        "missing_count": len(report.missing),
        "missing": [g.id for g in report.missing],
        "open_tasks": len(open_tasks),
        "tasks": [
            {
                "id": t.get("id"),
                "title": t.get("title"),
                "status": t.get("status"),
                "priority": t.get("priority"),
                "gap": task_gap_id(t),
                "links": list(t.get("links") or []),
            }
            for t in open_tasks[:20]
        ],
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
        "next_templates": report.to_dict().get("next_templates") or [],
        "hints": report.hints,
    }


def audit_summary_lines(workspace_id: str | None = None) -> list[str]:
    st = workflow_status(workspace_id)
    lines = [
        f"Workflow · {st['workspace_id']} · gaps {st['missing_count']} · "
        f"open tasks {st['open_tasks']}"
    ]
    if st["missing"]:
        lines.append("  missing: " + ", ".join(st["missing"]))
    nxt = st.get("next")
    if nxt:
        lines.append(
            f"  next: [{nxt.get('priority')}] {nxt.get('status')} "
            f"{nxt.get('gap') or '—'}  {nxt.get('title')}"
        )
    for t in st.get("tasks") or []:
        lines.append(
            f"  [{t.get('priority')}] {t.get('status')}  "
            f"{t.get('gap') or '—'}  {t.get('title')}"
        )
    return lines


def format_audit_text(report: AuditReport) -> str:
    lines = [
        f"Workspace: {report.workspace_id} ({report.label})",
        f"Path: {report.path}",
        f"GitHub: {report.github or '(none)'}",
        f"Git repo: {'yes' if report.is_git else 'no'}",
        "",
        "Gaps:",
    ]
    for g in report.gaps:
        mark = "ok" if g.present else "MISSING"
        lines.append(f"  [{mark}] {g.id} — {g.detail}")
    if report.hints:
        lines.append("")
        lines.append("Hints:")
        for h in report.hints:
            lines.append(f"  · {h}")
    return "\n".join(lines)


def dump_audit_json(report: AuditReport) -> str:
    return json.dumps(report.to_dict(), indent=2, ensure_ascii=False)
