"""Unified tool registry: builtins, domain packs, shell tools, MCP."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .paths import tools_dir, tool_state_file, mcp_servers_file
from .permissions import invoker_role, role_has_permission
from .runtime import TOOL_DEFINITIONS


@dataclass
class ToolEntry:
    """A registered tool entry."""

    name: str
    kind: str  # "builtin" | "domain" | "shell" | "mcp"
    description: str
    enabled: bool = True
    input_schema: dict[str, Any] = field(
        default_factory=lambda: {"type": "object", "properties": {}}
    )
    source: str = ""
    max_calls_per_job: int | None = None
    command: str | None = None  # shell tools (string command)
    argv: list[str] | None = None  # domain tools (no shell)
    risk: str = "read"  # read | write | rebuild
    permission: str | None = None  # NCC capability, e.g. user.create
    confirm: bool = False
    domain: str = ""
    mcp_server: str | None = None
    mcp_tool: str | None = None


def _domain_tools_payload() -> dict[str, Any]:
    env_json = os.environ.get("NCC_ASSISTANT_DOMAIN_TOOLS_JSON", "").strip()
    if env_json:
        try:
            data = json.loads(env_json)
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            pass
    path = Path(os.environ.get("NCC_ASSISTANT_DOMAIN_TOOLS_FILE", "") or "")
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return data
        except (OSError, json.JSONDecodeError):
            pass
    return {}


class ToolRegistry:
    """
    Load order:
    1. builtins
    2. domain packs (Nix-discovered ``ai/tools``)
    3. user shell tools (~/.config)
    4. MCP static tools[]
    """

    def __init__(self) -> None:
        self._tools: dict[str, ToolEntry] = {}
        self._user_state: dict[str, bool] = {}
        self._load_user_state()
        self._load_builtins()
        self._load_domain_tools()
        self._load_shell_tools()
        self._load_mcp_servers()

    def _load_user_state(self) -> None:
        path = tool_state_file()
        if not path.is_file():
            return
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                self._user_state = {k: bool(v) for k, v in data.items()}
        except (OSError, json.JSONDecodeError):
            pass

    def _save_user_state(self) -> None:
        path = tool_state_file()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self._user_state, indent=2) + "\n", encoding="utf-8")

    def _load_builtins(self) -> None:
        for tdef in TOOL_DEFINITIONS:
            name = tdef["name"]
            enabled = self._user_state.get(name, True)
            risk = "write" if name in (
                "apply_module_config",
                "restore_config_backup",
            ) else ("rebuild" if name == "apply_system" else "read")
            self._tools[name] = ToolEntry(
                name=name,
                kind="builtin",
                description=tdef.get("description", ""),
                enabled=enabled,
                input_schema=tdef.get(
                    "inputSchema", {"type": "object", "properties": {}}
                ),
                source="builtin",
                risk=risk,
            )

    def _load_domain_tools(self) -> None:
        data = _domain_tools_payload()
        tools = data.get("tools") or []
        if not isinstance(tools, list):
            return
        for raw in tools:
            if not isinstance(raw, dict):
                continue
            name = raw.get("name")
            argv = raw.get("argv")
            if not name or not isinstance(argv, list) or not argv:
                continue
            if name in self._tools:
                continue
            risk = str(raw.get("risk") or "read")
            if risk not in ("read", "write", "rebuild"):
                risk = "read"
            enabled = self._user_state.get(name, raw.get("enabled", True))
            self._tools[name] = ToolEntry(
                name=str(name),
                kind="domain",
                description=str(raw.get("description") or f"Domain tool: {name}"),
                enabled=bool(enabled),
                input_schema=raw.get(
                    "inputSchema", {"type": "object", "properties": {}}
                ),
                source=f"domain:{raw.get('module') or raw.get('domain') or '?'}",
                argv=[str(x) for x in argv],
                risk=risk,
                permission=(
                    str(raw["permission"]) if raw.get("permission") else None
                ),
                confirm=bool(raw.get("confirm", risk != "read")),
                domain=str(raw.get("domain") or ""),
                max_calls_per_job=raw.get("maxCallsPerJob"),
            )

    def _load_shell_tools(self) -> None:
        tdir = tools_dir()
        if not tdir.is_dir():
            return
        for path in tdir.glob("*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(data, dict):
                continue
            name = data.get("name") or path.stem
            if name in self._tools:
                continue
            enabled = self._user_state.get(name, data.get("enabled", True))
            self._tools[name] = ToolEntry(
                name=name,
                kind="shell",
                description=data.get("description", f"Shell tool: {name}"),
                enabled=enabled,
                input_schema=data.get(
                    "inputSchema", {"type": "object", "properties": {}}
                ),
                source=str(path),
                max_calls_per_job=data.get("maxCallsPerJob"),
                command=data.get("command"),
                risk=str(data.get("risk") or "write"),
                permission=data.get("permission"),
            )

    def _load_mcp_servers(self) -> None:
        servers: dict[str, dict[str, Any]] = {}

        env_json = os.environ.get("NCC_ASSISTANT_MCP_SERVERS_JSON")
        if env_json:
            try:
                env_data = json.loads(env_json)
                if isinstance(env_data, dict):
                    servers.update(env_data)
            except json.JSONDecodeError:
                pass

        user_file = mcp_servers_file()
        if user_file.is_file():
            try:
                user_data = json.loads(user_file.read_text(encoding="utf-8"))
                if isinstance(user_data, dict):
                    servers.update(user_data)
            except (OSError, json.JSONDecodeError):
                pass

        for server_name, server_def in servers.items():
            if not isinstance(server_def, dict):
                continue
            tools = server_def.get("tools") or []
            for tool in tools:
                if not isinstance(tool, dict):
                    continue
                tool_name = tool.get("name")
                if not tool_name:
                    continue
                namespaced = f"mcp.{server_name}.{tool_name}"
                if namespaced in self._tools:
                    continue
                enabled = self._user_state.get(
                    namespaced, tool.get("enabled", True)
                )
                self._tools[namespaced] = ToolEntry(
                    name=namespaced,
                    kind="mcp",
                    description=tool.get(
                        "description", f"MCP tool: {tool_name}"
                    ),
                    enabled=enabled,
                    input_schema=tool.get(
                        "inputSchema", {"type": "object", "properties": {}}
                    ),
                    source=f"mcp:{server_name}",
                    max_calls_per_job=tool.get("maxCallsPerJob"),
                    mcp_server=server_name,
                    mcp_tool=tool_name,
                    risk=str(tool.get("risk") or "read"),
                )

    def reload(self) -> None:
        self._tools.clear()
        self._load_user_state()
        self._load_builtins()
        self._load_domain_tools()
        self._load_shell_tools()
        self._load_mcp_servers()

    def list_all(self) -> list[ToolEntry]:
        return list(self._tools.values())

    def list_enabled(self) -> list[ToolEntry]:
        return [t for t in self._tools.values() if t.enabled]

    def get(self, name: str) -> ToolEntry | None:
        return self._tools.get(name)

    def set_enabled(self, name: str, enabled: bool) -> bool:
        if name not in self._tools:
            return False
        self._tools[name].enabled = enabled
        self._user_state[name] = enabled
        self._save_user_state()
        return True

    def list_for_invoker(
        self,
        *,
        role: str | None = None,
        allow_write: bool = True,
        allow_rebuild: bool = False,
        allowlist: list[str] | None = None,
        denylist: list[str] | None = None,
    ) -> list[ToolEntry]:
        """Enabled tools filtered by NCC role + write/rebuild policy."""
        role = role if role is not None else invoker_role()
        deny = set(denylist or [])
        allow = set(allowlist) if allowlist else None
        out: list[ToolEntry] = []
        for t in self.list_enabled():
            if t.name in deny:
                continue
            if allow is not None and t.name not in allow:
                continue
            if t.permission and not role_has_permission(role, t.permission):
                continue
            if t.risk in ("write", "rebuild") and not allow_write:
                continue
            if t.risk == "rebuild" and not allow_rebuild:
                continue
            out.append(t)
        return out

    def openai_tools(
        self,
        *,
        role: str | None = None,
        allow_write: bool = True,
        allow_rebuild: bool = False,
        allowlist: list[str] | None = None,
        denylist: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        tools = []
        for t in self.list_for_invoker(
            role=role,
            allow_write=allow_write,
            allow_rebuild=allow_rebuild,
            allowlist=allowlist,
            denylist=denylist,
        ):
            tools.append(
                {
                    "type": "function",
                    "function": {
                        "name": t.name,
                        "description": t.description,
                        "parameters": t.input_schema,
                    },
                }
            )
        return tools

    def mcp_tools(self) -> list[dict[str, Any]]:
        tools = []
        for t in self.list_enabled():
            tools.append(
                {
                    "name": t.name,
                    "description": t.description,
                    "inputSchema": t.input_schema,
                }
            )
        return tools


_default_registry: ToolRegistry | None = None


def get_registry() -> ToolRegistry:
    global _default_registry
    if _default_registry is None:
        _default_registry = ToolRegistry()
    return _default_registry


def reload_registry() -> ToolRegistry:
    global _default_registry
    _default_registry = ToolRegistry()
    return _default_registry
