"""Auto-inject NCC MCP server into external harness configs (qwen / dsh)."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any


NCC_MCP_NAME = "ncc-assistant"


def _ncc_mcp_command() -> tuple[str, list[str]]:
    """Prefer ncc-assistant mcp, else ncc ai mcp."""
    for name in ("ncc-assistant", "ncc"):
        found = shutil.which(name)
        if found and name == "ncc-assistant":
            return found, ["mcp"]
        if found and name == "ncc":
            return found, ["ai", "mcp"]
    # Fallback: python -m
    return "ncc-assistant", ["mcp"]


def ncc_mcp_entry() -> dict[str, Any]:
    cmd, args = _ncc_mcp_command()
    return {
        "command": cmd,
        "args": args,
        "timeout": 60000,
        "trust": False,
    }


def ensure_qwen_ncc_mcp(*, force: bool = False) -> dict[str, Any]:
    """
    Merge ``ncc-assistant`` into ``~/.qwen/settings.json`` mcpServers.
    Returns {ok, path, created|updated|skipped, detail}.
    """
    settings_path = Path.home() / ".qwen" / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, Any] = {}
    if settings_path.is_file():
        try:
            raw = json.loads(settings_path.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                data = raw
        except (OSError, json.JSONDecodeError):
            data = {}

    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        servers = {}
        data["mcpServers"] = servers

    existing = servers.get(NCC_MCP_NAME)
    if existing and not force:
        return {
            "ok": True,
            "path": str(settings_path),
            "status": "skipped",
            "detail": "ncc-assistant already configured in qwen settings",
        }

    servers[NCC_MCP_NAME] = ncc_mcp_entry()
    data["mcpServers"] = servers
    settings_path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(settings_path, 0o600)
    except OSError:
        pass
    return {
        "ok": True,
        "path": str(settings_path),
        "status": "updated" if existing else "created",
        "detail": f"Wrote {NCC_MCP_NAME} → {settings_path}",
    }


def ensure_dsh_ncc_mcp(*, force: bool = False) -> dict[str, Any]:
    """
    Best-effort: write ``~/.dsh/mcp.json`` or merge into ``~/.dsh/config.json``.
    DeepSeek Harness preview layouts vary — we write a dedicated sidecar.
    """
    dsh_home = Path(os.environ.get("DSH_HOME") or (Path.home() / ".dsh"))
    dsh_home.mkdir(parents=True, exist_ok=True)
    path = dsh_home / "ncc-mcp.json"
    if path.is_file() and not force:
        return {
            "ok": True,
            "path": str(path),
            "status": "skipped",
            "detail": "dsh ncc-mcp sidecar already present",
        }
    payload = {"mcpServers": {NCC_MCP_NAME: ncc_mcp_entry()}}
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    # Also try merge into config.json if present
    cfg = dsh_home / "config.json"
    if cfg.is_file():
        try:
            data = json.loads(cfg.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                servers = data.get("mcpServers")
                if not isinstance(servers, dict):
                    servers = {}
                if NCC_MCP_NAME not in servers or force:
                    servers[NCC_MCP_NAME] = ncc_mcp_entry()
                    data["mcpServers"] = servers
                    cfg.write_text(
                        json.dumps(data, indent=2) + "\n", encoding="utf-8"
                    )
        except (OSError, json.JSONDecodeError):
            pass
    return {
        "ok": True,
        "path": str(path),
        "status": "created",
        "detail": f"Wrote dsh MCP sidecar {path}",
    }


def ensure_harness_mcp(harness: str, *, force: bool = False) -> dict[str, Any]:
    name = (harness or "").strip().lower()
    if name == "qwen":
        return ensure_qwen_ncc_mcp(force=force)
    if name == "dsh":
        return ensure_dsh_ncc_mcp(force=force)
    return {"ok": True, "status": "skipped", "detail": "native — no inject"}
