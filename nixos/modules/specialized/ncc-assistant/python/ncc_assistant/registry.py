"""Unified tool registry for builtins, shell tools, and MCP servers."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .paths import tools_dir, tool_state_file, mcp_servers_file
from .runtime import TOOL_DEFINITIONS


@dataclass
class ToolEntry:
    """A registered tool entry."""
    name: str
    kind: str  # "builtin" | "shell" | "mcp"
    description: str
    enabled: bool = True
    input_schema: dict[str, Any] = field(default_factory=lambda: {"type": "object", "properties": {}})
    source: str = ""
    max_calls_per_job: int | None = None
    command: str | None = None  # For shell tools
    mcp_server: str | None = None  # For MCP tools
    mcp_tool: str | None = None  # Original MCP tool name


class ToolRegistry:
    """
    Unified tool registry that loads:
    - Builtins from TOOL_DEFINITIONS
    - Shell tools from ~/.config/ncc-assistant/tools/*.json
    - MCP tools from env NCC_ASSISTANT_MCP_SERVERS_JSON + mcp-servers.json
    """

    def __init__(self) -> None:
        self._tools: dict[str, ToolEntry] = {}
        self._user_state: dict[str, bool] = {}
        self._load_user_state()
        self._load_builtins()
        self._load_shell_tools()
        self._load_mcp_servers()

    def _load_user_state(self) -> None:
        """Load user enable/disable overrides from tool-state.json."""
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
        """Persist user enable/disable overrides."""
        path = tool_state_file()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self._user_state, indent=2) + "\n", encoding="utf-8")

    def _load_builtins(self) -> None:
        """Load builtin tools from TOOL_DEFINITIONS."""
        for tdef in TOOL_DEFINITIONS:
            name = tdef["name"]
            enabled = self._user_state.get(name, True)
            self._tools[name] = ToolEntry(
                name=name,
                kind="builtin",
                description=tdef.get("description", ""),
                enabled=enabled,
                input_schema=tdef.get("inputSchema", {"type": "object", "properties": {}}),
                source="builtin",
            )

    def _load_shell_tools(self) -> None:
        """Load shell tools from ~/.config/ncc-assistant/tools/*.json."""
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
                input_schema=data.get("inputSchema", {"type": "object", "properties": {}}),
                source=str(path),
                max_calls_per_job=data.get("maxCallsPerJob"),
                command=data.get("command"),
            )

    def _load_mcp_servers(self) -> None:
        """Load MCP server definitions from env and user file."""
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
                enabled = self._user_state.get(namespaced, tool.get("enabled", True))
                self._tools[namespaced] = ToolEntry(
                    name=namespaced,
                    kind="mcp",
                    description=tool.get("description", f"MCP tool: {tool_name}"),
                    enabled=enabled,
                    input_schema=tool.get("inputSchema", {"type": "object", "properties": {}}),
                    source=f"mcp:{server_name}",
                    max_calls_per_job=tool.get("maxCallsPerJob"),
                    mcp_server=server_name,
                    mcp_tool=tool_name,
                )

    def reload(self) -> None:
        """Reload all tools from sources."""
        self._tools.clear()
        self._load_user_state()
        self._load_builtins()
        self._load_shell_tools()
        self._load_mcp_servers()

    def list_all(self) -> list[ToolEntry]:
        """Return all registered tools."""
        return list(self._tools.values())

    def list_enabled(self) -> list[ToolEntry]:
        """Return only enabled tools."""
        return [t for t in self._tools.values() if t.enabled]

    def get(self, name: str) -> ToolEntry | None:
        """Get a tool by name."""
        return self._tools.get(name)

    def set_enabled(self, name: str, enabled: bool) -> bool:
        """Set tool enabled state and persist."""
        if name not in self._tools:
            return False
        self._tools[name].enabled = enabled
        self._user_state[name] = enabled
        self._save_user_state()
        return True

    def openai_tools(self) -> list[dict[str, Any]]:
        """Return OpenAI function-calling format for enabled tools."""
        tools = []
        for t in self.list_enabled():
            tools.append({
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": t.input_schema,
                },
            })
        return tools

    def mcp_tools(self) -> list[dict[str, Any]]:
        """Return MCP tool format for enabled tools."""
        tools = []
        for t in self.list_enabled():
            tools.append({
                "name": t.name,
                "description": t.description,
                "inputSchema": t.input_schema,
            })
        return tools


_default_registry: ToolRegistry | None = None


def get_registry() -> ToolRegistry:
    """Get or create the default tool registry."""
    global _default_registry
    if _default_registry is None:
        _default_registry = ToolRegistry()
    return _default_registry


def reload_registry() -> ToolRegistry:
    """Force reload the default registry."""
    global _default_registry
    _default_registry = ToolRegistry()
    return _default_registry
