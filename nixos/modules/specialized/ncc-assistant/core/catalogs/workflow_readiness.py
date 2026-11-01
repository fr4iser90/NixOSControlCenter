"""Run-readiness for catalog workflows: assess gaps, remediate what we can.

Callers: ``companion.window._run_template`` (preflight before Configure),
``widgets.readiness.WorkflowReadinessDialog``, unit tests under
``tests/ncc-assistant/test_workflow_readiness_v1.py``.

No existing module covers this — ``template_badges`` only labels cards;
``install_template`` / ``import_from_parent`` / ``set_secret`` are the
primitives this orchestrates. Qt-free.

Data touched (user config, never production logs):
- read: ``data/agents/<id>.json``, workspaces registry, secrets.json meta,
  mcp-servers.json, PATH
- write via remediations: workspaces registry, secrets.json (0600),
  mcp-servers.json (0600)

User: "ja bbitte" (build Start → check requirements → fetch/add missing).
"""

from __future__ import annotations

import shutil
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Literal

from core.catalogs.agent_templates import AgentTemplate, get_agent_template

Severity = Literal["ok", "warn", "block"]
FixKind = Literal[
    "none",
    "scan_workspaces",
    "add_workspace",
    "set_secret",
    "install_mcp",
    "host_package",
]


@dataclass
class ReadinessItem:
    """One row in the preflight checklist."""

    id: str
    title: str
    detail: str = ""
    severity: Severity = "ok"
    fix: FixKind = "none"
    secret_name: str | None = None
    mcp_name: str | None = None
    host_bin: str | None = None
    hint: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {k: v for k, v in asdict(self).items() if v is not None}


@dataclass
class ReadinessReport:
    template_id: str
    title: str
    items: list[ReadinessItem] = field(default_factory=list)

    @property
    def ready(self) -> bool:
        return not any(i.severity == "block" for i in self.items)

    @property
    def blocking(self) -> list[ReadinessItem]:
        return [i for i in self.items if i.severity == "block"]

    @property
    def actionable(self) -> list[ReadinessItem]:
        return [i for i in self.items if i.severity != "ok" and i.fix != "none"]

    def to_dict(self) -> dict[str, Any]:
        return {
            "template_id": self.template_id,
            "title": self.title,
            "ready": self.ready,
            "items": [i.to_dict() for i in self.items],
        }


def _needs_workspaces(tmpl: AgentTemplate) -> bool:
    return any(
        p.type in ("workspaceList", "workspace") and p.required for p in tmpl.params
    )


def _required_secrets(tmpl: AgentTemplate) -> list[str]:
    names: list[str] = []
    for s in tmpl.requires_secrets:
        if s and s not in names:
            names.append(s)
    for p in tmpl.params:
        if p.type == "secretRef" and p.required:
            kind = (p.secret_kind or p.default or p.id or "").strip()
            if kind and kind not in names:
                names.append(kind)
    return names


def _mcp_launcher_bins(mcp_names: list[str]) -> list[tuple[str, str]]:
    """Return (bin, hint) pairs required to launch the named MCP templates."""
    from core.catalogs.marketplace import get_template

    needed: dict[str, str] = {}
    for name in mcp_names:
        tmpl = get_template(name)
        if tmpl is None or not tmpl.command:
            continue
        cmd = tmpl.command
        if cmd == "uvx":
            if shutil.which("uvx") or shutil.which("uv"):
                continue
            needed["uvx"] = (
                "Install `uv` (provides `uvx`) so MCP servers can start. "
                "ncc-assistant's wrapper usually puts uv on PATH after system-update."
            )
        elif shutil.which(cmd) is None:
            needed[cmd] = (
                f"Install `{cmd}` on this host — MCP '{name}' launches through it."
            )
    return list(needed.items())


def assess_workflow_readiness(template_id: str) -> ReadinessReport:
    """Build the checklist for one catalog workflow (or empty report if unknown)."""
    tmpl = get_agent_template(template_id)
    if tmpl is None:
        return ReadinessReport(
            template_id=template_id,
            title=template_id,
            items=[
                ReadinessItem(
                    id="unknown",
                    title="Unknown workflow",
                    detail=f"No catalog entry for '{template_id}'",
                    severity="block",
                )
            ],
        )

    items: list[ReadinessItem] = []

    from core.store.workspaces import list_workspaces

    workspaces = list_workspaces()
    if _needs_workspaces(tmpl):
        if not workspaces:
            items.append(
                ReadinessItem(
                    id="workspaces",
                    title="No git workspaces registered",
                    detail="Scan a parent folder (e.g. ~/Git) or add one repo.",
                    severity="block",
                    fix="scan_workspaces",
                    hint="Each workspace is one local git root the agent may use.",
                )
            )
        else:
            items.append(
                ReadinessItem(
                    id="workspaces",
                    title=f"{len(workspaces)} workspace(s) ready",
                    detail=", ".join(w.id for w in workspaces[:8])
                    + ("…" if len(workspaces) > 8 else ""),
                    severity="ok",
                )
            )
    else:
        items.append(
            ReadinessItem(
                id="workspaces",
                title="Workspaces optional",
                detail="This workflow does not require a registered repo.",
                severity="ok",
            )
        )

    from core.store.secrets import has_secret

    for name in _required_secrets(tmpl):
        if has_secret(name):
            items.append(
                ReadinessItem(
                    id=f"secret:{name}",
                    title=f"Secret '{name}' present",
                    severity="ok",
                    secret_name=name,
                )
            )
        else:
            items.append(
                ReadinessItem(
                    id=f"secret:{name}",
                    title=f"Secret '{name}' missing",
                    detail=(
                        "Paste a token once; stored under "
                        "~/.config/ncc-assistant/secrets.json (0600)."
                    ),
                    severity="block",
                    fix="set_secret",
                    secret_name=name,
                    hint="For GitHub: a classic/fine-grained PAT with repo + PR scopes.",
                )
            )

    if tmpl.mcp:
        if shutil.which("git") is None:
            items.append(
                ReadinessItem(
                    id="bin:git",
                    title="`git` not on PATH",
                    detail="Needed for local repo MCP and workspace discovery.",
                    severity="block",
                    fix="host_package",
                    host_bin="git",
                    hint=(
                        "Install git on this host "
                        "(NixOS: programs.git.enable / environment.systemPackages)."
                    ),
                )
            )
        else:
            items.append(
                ReadinessItem(
                    id="bin:git",
                    title="`git` on PATH",
                    severity="ok",
                    host_bin="git",
                )
            )

        needs_gh = "github" in tmpl.mcp or "github" in (tmpl.tags or [])
        if needs_gh:
            if shutil.which("gh"):
                items.append(
                    ReadinessItem(
                        id="bin:gh",
                        title="`gh` on PATH",
                        severity="ok",
                        host_bin="gh",
                    )
                )
            else:
                items.append(
                    ReadinessItem(
                        id="bin:gh",
                        title="`gh` not on PATH (optional)",
                        detail=(
                            "CLI digests / workflow pr helpers use gh; "
                            "MCP github can still run with a token."
                        ),
                        severity="warn",
                        fix="host_package",
                        host_bin="gh",
                        hint="Install GitHub CLI for ncc ai workflows refresh / pr helpers.",
                    )
                )

        for bin_name, hint in _mcp_launcher_bins(list(tmpl.mcp)):
            items.append(
                ReadinessItem(
                    id=f"bin:{bin_name}",
                    title=f"`{bin_name}` not on PATH",
                    detail="MCP servers cannot be installed or started without it.",
                    severity="block",
                    fix="host_package",
                    host_bin=bin_name,
                    hint=hint,
                )
            )

    from core.catalogs.marketplace import get_template, installed_mcp_names

    installed = installed_mcp_names()

    def _mcp_present(name: str) -> bool:
        # install_as may be "git-<workspace>"; treat that as the git template present.
        return name in installed or any(
            k == name or k.startswith(f"{name}-") for k in installed
        )

    for name in tmpl.mcp:
        if _mcp_present(name):
            items.append(
                ReadinessItem(
                    id=f"mcp:{name}",
                    title=f"MCP '{name}' installed",
                    severity="ok",
                    mcp_name=name,
                )
            )
            continue

        launcher_ok = True
        mt = get_template(name)
        if mt and mt.command and shutil.which(mt.command) is None:
            if not (mt.command == "uvx" and shutil.which("uv")):
                launcher_ok = False
        secret_ok = True
        if name == "github" and not has_secret("github_token"):
            secret_ok = False
        fix: FixKind = "install_mcp" if launcher_ok and secret_ok else "none"
        detail = "Will install into ~/.config/ncc-assistant/mcp-servers.json."
        if not launcher_ok:
            detail = "Fix the launcher binary first, then install this MCP."
        elif not secret_ok:
            detail = "Set secret github_token first, then install MCP github."
        items.append(
            ReadinessItem(
                id=f"mcp:{name}",
                title=f"MCP '{name}' not installed",
                detail=detail,
                severity="block",
                fix=fix,
                mcp_name=name,
            )
        )

    if not items:
        items.append(
            ReadinessItem(
                id="noop",
                title="Nothing to prepare",
                severity="ok",
            )
        )

    return ReadinessReport(template_id=tmpl.id, title=tmpl.title, items=items)


def remediate_scan_workspaces(parent: str | Path) -> dict[str, Any]:
    """Register every child git repo under ``parent``."""
    from core.store.workspaces import import_from_parent, list_workspaces

    try:
        imported = import_from_parent(parent)
    except ValueError as exc:
        return {"ok": False, "error": str(exc)}
    except OSError as exc:
        return {"ok": False, "error": str(exc)}
    return {
        "ok": True,
        "imported": [w.id for w in imported],
        "total": len(list_workspaces()),
    }


def remediate_set_secret(
    name: str, value: str, *, label: str | None = None
) -> dict[str, Any]:
    """Store a named secret (never logged)."""
    from core.store.secrets import set_secret

    cleaned = (value or "").strip()
    if not cleaned:
        return {"ok": False, "error": "Empty secret value"}
    if not (name or "").strip():
        return {"ok": False, "error": "Empty secret name"}
    meta = set_secret(name.strip(), cleaned, label=label)
    return {"ok": True, "name": meta.name}


def remediate_install_mcp(
    name: str,
    *,
    workspace_id: str | None = None,
    secret_name: str | None = None,
) -> dict[str, Any]:
    """Install one marketplace MCP template, bound to workspace/secret when relevant."""
    from core.catalogs.marketplace import install_template
    from core.store.workspaces import list_workspaces

    ws_id = workspace_id
    if not ws_id:
        wss = list_workspaces()
        ws_id = wss[0].id if wss else None

    overrides = None
    if name == "github":
        overrides = {"GITHUB_PERSONAL_ACCESS_TOKEN": secret_name or "github_token"}

    install_as = None
    if name == "git" and ws_id:
        install_as = f"git-{ws_id}"

    return install_template(
        name,
        workspace_id=ws_id,
        secret_overrides=overrides,
        install_as=install_as,
    )


def auto_remediate_mcp(report: ReadinessReport) -> list[dict[str, Any]]:
    """Install every MCP row that is ready to fix without UI prompts."""
    results: list[dict[str, Any]] = []
    for item in report.items:
        if item.fix != "install_mcp" or not item.mcp_name:
            continue
        results.append(remediate_install_mcp(item.mcp_name))
    return results


def default_git_parent() -> Path:
    """Best-effort ~/Git (or ~/Documents/Git) for the scan picker default."""
    home = Path.home()
    for candidate in (home / "Git", home / "Documents" / "Git", home / "src"):
        if candidate.is_dir():
            return candidate
    return home / "Git"
