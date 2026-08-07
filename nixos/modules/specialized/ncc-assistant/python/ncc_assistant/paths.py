"""Centralized path management for NCC assistant data directories."""

from __future__ import annotations

import os
from pathlib import Path


def config_home() -> Path:
    """Return XDG_CONFIG_HOME/ncc-assistant, creating if needed."""
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    path = base / "ncc-assistant"
    path.mkdir(parents=True, exist_ok=True)
    return path


def sessions_dir() -> Path:
    """Directory for chat session JSON files."""
    path = config_home() / "sessions"
    path.mkdir(parents=True, exist_ok=True)
    return path


def tools_dir() -> Path:
    """Directory for user-defined shell tool JSON files."""
    path = config_home() / "tools"
    path.mkdir(parents=True, exist_ok=True)
    return path


def jobs_dir() -> Path:
    """Directory for agent job state."""
    path = config_home() / "jobs"
    path.mkdir(parents=True, exist_ok=True)
    return path


def playbooks_dir() -> Path:
    """Directory for user playbook definitions."""
    path = config_home() / "playbooks"
    path.mkdir(parents=True, exist_ok=True)
    return path


def schedules_dir() -> Path:
    """Directory for scheduled task definitions."""
    path = config_home() / "schedules"
    path.mkdir(parents=True, exist_ok=True)
    return path


def approvals_dir() -> Path:
    """Directory for pending decision/approval requests."""
    path = config_home() / "approvals"
    path.mkdir(parents=True, exist_ok=True)
    return path


def knowledge_overlay_dir() -> Path:
    """Directory for user knowledge overlay files."""
    path = config_home() / "knowledge-overlay"
    path.mkdir(parents=True, exist_ok=True)
    return path


def memory_file() -> Path:
    """Path to memory.jsonl for persistent notes."""
    return config_home() / "memory.jsonl"


def presence_file() -> Path:
    """Path to presence.json for agent presence state."""
    return config_home() / "presence.json"


def disable_file() -> Path:
    """Path to DISABLE kill-switch file."""
    return config_home() / "DISABLE"


def agent_lock_file() -> Path:
    """Path to agent.lock for single-agent enforcement."""
    return config_home() / "agent.lock"


def audit_file() -> Path:
    """Path to audit.jsonl for audit logging."""
    return config_home() / "audit.jsonl"


def tool_state_file() -> Path:
    """Path to tool-state.json for user tool enable/disable overrides."""
    return config_home() / "tool-state.json"


def mcp_servers_file() -> Path:
    """Path to mcp-servers.json for user MCP server definitions."""
    return config_home() / "mcp-servers.json"


def credentials_file() -> Path:
    """Path to credentials.json (exists in auth.py, aliased here)."""
    return config_home() / "credentials.json"


def is_disabled() -> bool:
    """Check if the kill-switch DISABLE file exists."""
    return disable_file().exists()


def ensure_all_dirs() -> None:
    """Ensure all standard directories exist."""
    config_home()
    sessions_dir()
    tools_dir()
    jobs_dir()
    playbooks_dir()
    schedules_dir()
    approvals_dir()
    knowledge_overlay_dir()
