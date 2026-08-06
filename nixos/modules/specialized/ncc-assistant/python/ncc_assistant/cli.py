"""CLI entry: ncc-assistant [gui|chat|mcp|tool]."""

from __future__ import annotations

import argparse
import json
import sys

from .auth import with_cached_credentials
from .chat import run_chat
from .config import Settings
from .mcp_server import run_mcp
from .runtime import TOOL_DEFINITIONS, ToolRuntime


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="ncc-assistant",
        description="NCC AI Assistant — GUI chat, CLI, and MCP tools",
    )
    sub = parser.add_subparsers(dest="command", required=False)

    sub.add_parser("gui", help="Graphical chat window (default)")
    sub.add_parser("chat", help="Terminal chat (legacy)")
    sub.add_parser("cli", help="Alias for terminal chat")
    sub.add_parser("mcp", help="Run MCP server on stdio")

    tool_p = sub.add_parser("tool", help="Invoke a single tool (debug/scripting)")
    tool_p.add_argument("name", help="Tool name")
    tool_p.add_argument(
        "--args",
        default="{}",
        help="JSON object of tool arguments",
    )

    list_p = sub.add_parser("tools", help="List tool names")
    list_p.add_argument("--json", action="store_true")

    args = parser.parse_args(argv)
    command = args.command or "gui"

    if command == "tools":
        if getattr(args, "json", False):
            print(json.dumps(TOOL_DEFINITIONS, indent=2))
        else:
            for t in TOOL_DEFINITIONS:
                print(f"{t['name']}\t{t['description']}")
        return 0

    if command == "mcp":
        settings = with_cached_credentials(Settings.from_env(client_mode="mcp"))
        run_mcp(settings)
        return 0

    if command == "tool":
        settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
        runtime = ToolRuntime(settings)
        try:
            payload = json.loads(args.args)
        except json.JSONDecodeError as exc:
            print(f"Invalid --args JSON: {exc}", file=sys.stderr)
            return 2
        result = runtime.call(args.name, payload)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0 if result.get("ok", True) else 1

    if command in ("chat", "cli"):
        settings = Settings.from_env(client_mode="chat")
        return run_chat(settings)

    # Default: GUI
    from .gui import run_gui

    return run_gui(Settings.from_env(client_mode="chat"))


if __name__ == "__main__":
    raise SystemExit(main())
