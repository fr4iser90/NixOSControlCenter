"""MCP stdio server exposing the shared ToolRuntime."""

from __future__ import annotations

import json
from typing import Any

from mcp.server.fastmcp import FastMCP

from .config import Settings
from .runtime import ToolRuntime


def build_mcp(settings: Settings | None = None) -> FastMCP:
    settings = settings or Settings.from_env(client_mode="mcp")
    runtime = ToolRuntime(settings)
    mcp = FastMCP("ncc-assistant")

    @mcp.tool()
    def list_modules(query: str | None = None) -> str:
        """List known NCC modules from knowledge registries."""
        return _dump(runtime.list_modules(query))

    @mcp.tool()
    def read_module_config(module_path: str) -> str:
        """Read active systemConfig leaf for a module path."""
        return _dump(runtime.read_module_config(module_path))

    @mcp.tool()
    def search_knowledge(query: str, limit: int = 8) -> str:
        """Search NCC knowledge pack by keyword."""
        return _dump(runtime.search_knowledge(query, limit))

    @mcp.tool()
    def explain_path(module_path: str) -> str:
        """Explain a module path using registries + current config."""
        return _dump(runtime.explain_path(module_path))

    @mcp.tool()
    def propose_config_patch(module_path: str, proposed_nix: str) -> str:
        """Show unified diff for a proposed config change (no write)."""
        return _dump(runtime.propose_config_patch(module_path, proposed_nix))

    @mcp.tool()
    def apply_module_config(
        module_path: str, content_nix: str, confirm: bool = False
    ) -> str:
        """Write module config via facade. Requires confirm=true and mcpAllowWrite."""
        return _dump(
            runtime.apply_module_config(module_path, content_nix, confirm)
        )

    @mcp.tool()
    def validate_config(
        module_path: str | None = None, content_nix: str | None = None
    ) -> str:
        """Validate a Nix attrset fragment or current module leaf."""
        return _dump(runtime.validate_config(module_path, content_nix))

    @mcp.tool()
    def apply_system(confirm: str, hostname: str | None = None) -> str:
        """Run ncc system build switch. confirm must be CONFIRM; allowRebuild required."""
        return _dump(runtime.apply_system(confirm, hostname))

    @mcp.tool()
    def run_preflight() -> str:
        """Run preflight checks before a system rebuild."""
        return _dump(runtime.run_preflight())

    @mcp.tool()
    def config_health_report() -> str:
        """Generate a configuration health report."""
        return _dump(runtime.config_health_report())

    @mcp.tool()
    def memory_list(tag: str | None = None, limit: int = 20) -> str:
        """List persistent memory notes."""
        return _dump(runtime.memory_list(tag, limit))

    @mcp.tool()
    def memory_add(content: str, tags: list[str] | None = None) -> str:
        """Add a note to persistent memory."""
        return _dump(runtime.memory_add(content, tags))

    @mcp.tool()
    def memory_forget(note_id: str) -> str:
        """Forget a memory note by ID."""
        return _dump(runtime.memory_forget(note_id))

    @mcp.tool()
    def list_config_backups(limit: int = 20) -> str:
        """List NixOS configuration backups."""
        return _dump(runtime.list_config_backups(limit))

    return mcp


def run_mcp(settings: Settings | None = None) -> None:
    mcp = build_mcp(settings)
    mcp.run(transport="stdio")


def _dump(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2)
