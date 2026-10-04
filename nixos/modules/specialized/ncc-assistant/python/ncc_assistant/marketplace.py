"""MCP marketplace — curated server templates installable into user config."""

from __future__ import annotations

import json
import os
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from .paths import mcp_servers_file

WRITE_RISK_WARNING = (
    "WARNING: This MCP template can write or mutate files/systems. "
    "Review command, args, and paths before enabling. "
    "Do not install untrusted templates."
)

_PLACEHOLDER_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}")


@dataclass
class McpTemplate:
    """A curated MCP server template."""

    name: str
    description: str = ""
    command: str = ""
    args: list[str] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)
    env_from_secrets: dict[str, str] = field(default_factory=dict)
    risk: str = "read"  # read | write | network
    install_hint: str | None = None
    placeholders: list[str] = field(default_factory=list)
    source: str = ""

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None and v != "" and v != [] and v != {}}

    @classmethod
    def from_dict(cls, data: dict[str, Any], source: str = "") -> McpTemplate:
        name = data.get("name")
        if not name:
            name = Path(source).stem if source else "unnamed"
        env_from = data.get("envFromSecrets") or data.get("env_from_secrets") or {}
        return cls(
            name=str(name),
            description=data.get("description", ""),
            command=data.get("command", ""),
            args=list(data.get("args") or []),
            env=dict(data.get("env") or {}),
            env_from_secrets={str(k): str(v) for k, v in dict(env_from).items()},
            risk=str(data.get("risk", "read")),
            install_hint=data.get("install_hint") or data.get("installHint"),
            placeholders=[str(x) for x in (data.get("placeholders") or [])],
            source=source,
        )

    @property
    def is_write_capable(self) -> bool:
        return self.risk in ("write", "network-write", "read-write")

    def risk_warning(self) -> str | None:
        if self.is_write_capable or self.risk == "network":
            if self.is_write_capable:
                return WRITE_RISK_WARNING
            return (
                "WARNING: This MCP template can access the network. "
                "Review endpoints and credentials before enabling."
            )
        return None


def _template_dirs() -> list[Path]:
    """Candidate directories containing MCP template JSON files."""
    dirs: list[Path] = []
    local = Path(__file__).resolve().parent / "templates" / "mcp"
    dirs.append(local)

    root = os.environ.get("NCC_ASSISTANT_ROOT", "").strip()
    if root:
        dirs.append(Path(root) / "ncc_assistant" / "templates" / "mcp")
        dirs.append(Path(root) / "templates" / "mcp")

    seen: set[str] = set()
    unique: list[Path] = []
    for d in dirs:
        key = str(d)
        if key not in seen:
            seen.add(key)
            unique.append(d)
    return unique


def _load_from_dir(directory: Path) -> list[McpTemplate]:
    templates: list[McpTemplate] = []
    if not directory.is_dir():
        return templates
    for path in sorted(directory.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                continue
            if not data.get("name"):
                data["name"] = path.stem
            templates.append(McpTemplate.from_dict(data, source=str(path)))
        except (OSError, json.JSONDecodeError):
            continue
    return templates


def list_templates() -> list[McpTemplate]:
    """List MCP templates from packaged and local template dirs."""
    by_name: dict[str, McpTemplate] = {}
    for directory in _template_dirs():
        for tmpl in _load_from_dir(directory):
            by_name[tmpl.name] = tmpl
    return list(by_name.values())


def get_template(name: str) -> McpTemplate | None:
    """Get a single template by name."""
    for tmpl in list_templates():
        if tmpl.name == name:
            return tmpl
    return None


def installed_mcp_names() -> set[str]:
    path = mcp_servers_file()
    if not path.is_file():
        return set()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return set()
    if not isinstance(data, dict):
        return set()
    return {str(k) for k in data.keys()}


def expand_placeholders(text: str, ctx: dict[str, str]) -> str:
    """Replace ``{{key}}`` using ctx. Unknown keys raise ValueError."""

    def repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in ctx:
            raise ValueError(f"Missing placeholder value: {{{{{key}}}}}")
        return ctx[key]

    return _PLACEHOLDER_RE.sub(repl, text)


def build_placeholder_context(
    *,
    workspace_id: str | None = None,
    workspace_path: str | None = None,
    extra: dict[str, str] | None = None,
) -> dict[str, str]:
    ctx: dict[str, str] = dict(extra or {})
    if workspace_id:
        from .workspaces import get_workspace

        ws = get_workspace(workspace_id)
        if ws is None:
            raise ValueError(f"Unknown workspace: {workspace_id}")
        ctx.setdefault("workspace.id", ws.id)
        ctx.setdefault("workspace.path", ws.path)
        ctx.setdefault("workspace.label", ws.label)
        if ws.github:
            ctx.setdefault("workspace.github", ws.github)
    if workspace_path:
        ctx.setdefault("workspace.path", str(Path(workspace_path).expanduser()))
    # Default cwd for templates that still use {{workspace.path}} without bind
    ctx.setdefault("workspace.path", str(Path.cwd()))
    ctx.setdefault("workspace.id", "")
    ctx.setdefault("workspace.label", "")
    ctx.setdefault("workspace.github", "")
    return ctx


def install_template(
    name: str,
    *,
    workspace_id: str | None = None,
    workspace_path: str | None = None,
    secret_overrides: dict[str, str] | None = None,
    install_as: str | None = None,
) -> dict[str, Any]:
    """
    Install a template into ~/.config/ncc-assistant/mcp-servers.json.

    Expands ``{{workspace.*}}`` in args/env and resolves ``envFromSecrets``.
    """
    tmpl = get_template(name)
    if tmpl is None:
        return {"ok": False, "error": f"Unknown MCP template: {name}"}
    if not tmpl.command:
        return {"ok": False, "error": f"Template '{name}' has no command"}

    try:
        ctx = build_placeholder_context(
            workspace_id=workspace_id,
            workspace_path=workspace_path,
        )
        args = [expand_placeholders(str(a), ctx) for a in tmpl.args]
        env = {k: expand_placeholders(str(v), ctx) for k, v in tmpl.env.items()}
        secret_map = dict(tmpl.env_from_secrets)
        if secret_overrides:
            for k, secret_name in secret_overrides.items():
                secret_map[k] = f"{{{{secret.{secret_name}}}}}"
        if secret_map:
            from .secrets import resolve_secret_refs

            env.update(resolve_secret_refs(secret_map))
    except ValueError as exc:
        return {"ok": False, "error": str(exc)}

    path = mcp_servers_file()
    existing: dict[str, Any] = {}
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                existing = data
        except (OSError, json.JSONDecodeError):
            existing = {}

    entry_name = (install_as or tmpl.name).strip() or tmpl.name
    entry: dict[str, Any] = {
        "command": tmpl.command,
        "args": args,
    }
    if env:
        entry["env"] = env
    if workspace_id:
        entry["workspaceId"] = workspace_id

    existing[entry_name] = entry
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(existing, indent=2) + "\n", encoding="utf-8")

    result: dict[str, Any] = {
        "ok": True,
        "name": entry_name,
        "path": str(path),
        "entry": {
            "command": entry["command"],
            "args": entry["args"],
            "env_keys": sorted(env.keys()),
            "workspaceId": workspace_id,
        },
        "risk": tmpl.risk,
    }
    warning = tmpl.risk_warning()
    if warning:
        result["warning"] = warning
    return result
