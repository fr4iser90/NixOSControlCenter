"""MCP client pool for connecting to external MCP servers."""

from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass, field
from typing import Any

from .paths import mcp_servers_file


@dataclass
class McpServerConfig:
    """Configuration for an MCP server."""
    name: str
    command: str
    args: list[str] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)


class McpClientError(RuntimeError):
    """Error from MCP client operations."""
    pass


class McpClientPool:
    """
    Pool of MCP client connections using stdio transport.
    Lazily connects to servers on first use.
    """

    def __init__(self) -> None:
        self._servers: dict[str, McpServerConfig] = {}
        self._sessions: dict[str, Any] = {}
        self._tools_cache: dict[str, list[dict[str, Any]]] = {}
        self._load_server_configs()

    def _load_server_configs(self) -> None:
        """Load MCP server configurations from env and user file."""
        env_json = os.environ.get("NCC_ASSISTANT_MCP_SERVERS_JSON")
        if env_json:
            try:
                data = json.loads(env_json)
                if isinstance(data, dict):
                    for name, cfg in data.items():
                        if isinstance(cfg, dict) and cfg.get("command"):
                            self._servers[name] = McpServerConfig(
                                name=name,
                                command=cfg["command"],
                                args=cfg.get("args", []),
                                env=cfg.get("env", {}),
                            )
            except json.JSONDecodeError:
                pass

        user_file = mcp_servers_file()
        if user_file.is_file():
            try:
                data = json.loads(user_file.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    for name, cfg in data.items():
                        if isinstance(cfg, dict) and cfg.get("command"):
                            self._servers[name] = McpServerConfig(
                                name=name,
                                command=cfg["command"],
                                args=cfg.get("args", []),
                                env=cfg.get("env", {}),
                            )
            except (OSError, json.JSONDecodeError):
                pass

    def reload_configs(self) -> None:
        """Reload server configurations."""
        self._servers.clear()
        self._load_server_configs()

    def list_servers(self) -> list[str]:
        """List available server names."""
        return list(self._servers.keys())

    def get_server_config(self, server: str) -> McpServerConfig | None:
        """Get configuration for a server."""
        return self._servers.get(server)

    async def _connect(self, server: str) -> Any:
        """Lazily connect to an MCP server."""
        if server in self._sessions:
            return self._sessions[server]

        config = self._servers.get(server)
        if not config:
            raise McpClientError(f"Unknown MCP server: {server}")

        try:
            from mcp import ClientSession
            from mcp.client.stdio import stdio_client, StdioServerParameters
        except ImportError:
            raise McpClientError("mcp library not available for client connections")

        env = {**os.environ, **config.env}
        params = StdioServerParameters(
            command=config.command,
            args=config.args,
            env=env,
        )

        try:
            read_stream, write_stream = await stdio_client(params).__aenter__()
            session = ClientSession(read_stream, write_stream)
            await session.__aenter__()
            await session.initialize()
            self._sessions[server] = session
            return session
        except Exception as exc:
            raise McpClientError(f"Failed to connect to MCP server {server}: {exc}") from exc

    async def _ensure_connected(self, server: str) -> Any:
        """Ensure connection to server, reconnecting if needed."""
        if server not in self._sessions:
            return await self._connect(server)
        return self._sessions[server]

    async def list_tools_async(self, server: str) -> list[dict[str, Any]]:
        """List tools available from an MCP server."""
        if server in self._tools_cache:
            return self._tools_cache[server]

        try:
            session = await self._ensure_connected(server)
            result = await session.list_tools()
            tools = []
            for tool in result.tools:
                tools.append({
                    "name": tool.name,
                    "description": tool.description or "",
                    "inputSchema": tool.inputSchema or {"type": "object", "properties": {}},
                })
            self._tools_cache[server] = tools
            return tools
        except McpClientError:
            raise
        except Exception as exc:
            raise McpClientError(f"Failed to list tools from {server}: {exc}") from exc

    def list_tools(self, server: str) -> list[dict[str, Any]]:
        """Synchronous wrapper for list_tools_async."""
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None:
            future = asyncio.ensure_future(self.list_tools_async(server))
            return loop.run_until_complete(future)
        return asyncio.run(self.list_tools_async(server))

    async def call_tool_async(
        self,
        server: str,
        tool: str,
        arguments: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Call a tool on an MCP server."""
        try:
            session = await self._ensure_connected(server)
            result = await session.call_tool(tool, arguments or {})

            content_parts = []
            for item in result.content:
                if hasattr(item, "text"):
                    content_parts.append(item.text)
                elif hasattr(item, "data"):
                    content_parts.append(f"[binary data: {len(item.data)} bytes]")
                else:
                    content_parts.append(str(item))

            return {
                "ok": not result.isError,
                "content": "\n".join(content_parts),
                "raw": [str(c) for c in result.content],
            }
        except McpClientError:
            raise
        except Exception as exc:
            return {
                "ok": False,
                "error": f"MCP call failed: {exc}",
            }

    def call_tool(
        self,
        server: str,
        tool: str,
        arguments: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Synchronous wrapper for call_tool_async."""
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None:
            future = asyncio.ensure_future(self.call_tool_async(server, tool, arguments))
            return loop.run_until_complete(future)
        return asyncio.run(self.call_tool_async(server, tool, arguments))

    async def close_async(self) -> None:
        """Close all connections."""
        for server, session in list(self._sessions.items()):
            try:
                await session.__aexit__(None, None, None)
            except Exception:
                pass
        self._sessions.clear()
        self._tools_cache.clear()

    def close(self) -> None:
        """Synchronous wrapper for close_async."""
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None:
            future = asyncio.ensure_future(self.close_async())
            loop.run_until_complete(future)
        else:
            asyncio.run(self.close_async())


_default_pool: McpClientPool | None = None


def get_mcp_pool() -> McpClientPool:
    """Get or create the default MCP client pool."""
    global _default_pool
    if _default_pool is None:
        _default_pool = McpClientPool()
    return _default_pool
