"""NCC AI Assistant — shared tool runtime, MCP server, and chat CLI."""

__version__ = "1.0.0"

from .config import Settings
from .runtime import ToolRuntime, TOOL_DEFINITIONS
from .session import ChatSession
from .registry import ToolRegistry, get_registry
from .agent import AgentRunner, AgentSettings, run_agent
from .jobs import JobStore, JobMeta, get_job_store
from .presence import get_presence, set_presence, is_paused, pause, resume
from .paths import config_home, jobs_dir, playbooks_dir
from .memory import list_notes, add_note, forget_note
from .playbooks import list_playbooks, get_playbook
from .health import config_health_report, HealthReport
from .audit import append_audit, read_audit
from .profiles import get_profile, list_profiles, resolve_profile

__all__ = [
    "Settings",
    "ToolRuntime",
    "TOOL_DEFINITIONS",
    "ChatSession",
    "ToolRegistry",
    "get_registry",
    "AgentRunner",
    "AgentSettings",
    "run_agent",
    "JobStore",
    "JobMeta",
    "get_job_store",
    "get_presence",
    "set_presence",
    "is_paused",
    "pause",
    "resume",
    "config_home",
    "jobs_dir",
    "playbooks_dir",
    "list_notes",
    "add_note",
    "forget_note",
    "list_playbooks",
    "get_playbook",
    "config_health_report",
    "HealthReport",
    "append_audit",
    "read_audit",
    "get_profile",
    "list_profiles",
    "resolve_profile",
]
