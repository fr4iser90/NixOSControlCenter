"""MCP marketplace — curated server templates installable into user config."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any

from .paths import mcp_servers_file

WRITE_RISK_WARNING = (
    "WARNING: This MCP template can write or mutate files/systems. "
    "Review command, args, and paths before enabling. "
    "Do not install untrusted templates."
)


@dataclass
class McpTemplate:
    """A curated MCP server template."""
    name: str
    description: str = ""
    command: str = ""
    args: list[str] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)
    risk: str = "read"  # read | write | network
    install_hint: str | None = None
    source: str = ""

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}

    @classmethod
    def from_dict(cls, data: dict[str, Any], source: str = "") -> "McpTemplate":
        name = data.get("name")
        if not name:
            name = Path(source).stem if source else "unnamed"
        return cls(
            name=str(name),
            description=data.get("description", ""),
            command=data.get("command", ""),
            args=list(data.get("args") or []),
            env=dict(data.get("env") or {}),
            risk=str(data.get("risk", "read")),
            install_hint=data.get("install_hint") or data.get("installHint"),
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

    # Deduplicate while preserving order
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


def install_template(name: str) -> dict[str, Any]:
    """
    Install a template into ~/.config/ncc-assistant/mcp-servers.json
    by merging with any existing servers.
    """
    tmpl = get_template(name)
    if tmpl is None:
        return {"ok": False, "error": f"Unknown MCP template: {name}"}
    if not tmpl.command:
        return {"ok": False, "error": f"Template '{name}' has no command"}

    path = mcp_servers_file()
    existing: dict[str, Any] = {}
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                existing = data
        except (OSError, json.JSONDecodeError):
            existing = {}

    entry: dict[str, Any] = {
        "command": tmpl.command,
        "args": list(tmpl.args),
    }
    if tmpl.env:
        entry["env"] = dict(tmpl.env)

    existing[tmpl.name] = entry
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(existing, indent=2) + "\n", encoding="utf-8")

    result: dict[str, Any] = {
        "ok": True,
        "name": tmpl.name,
        "path": str(path),
        "entry": entry,
        "risk": tmpl.risk,
    }
    warning = tmpl.risk_warning()
    if warning:
        result["warning"] = warning
    return result
