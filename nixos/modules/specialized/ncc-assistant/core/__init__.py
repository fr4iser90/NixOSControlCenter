"""NCC AI Assistant — shared tool runtime, MCP server, and chat CLI."""

__version__ = "1.0.0"

from core.store.config import Settings
from core.runtime.runtime import ToolRuntime, TOOL_DEFINITIONS
from core.runtime.session import ChatSession
from core.runtime.registry import ToolRegistry, get_registry
from core.runtime.agent import AgentRunner, AgentSettings, run_agent
from core.store.jobs import JobStore, JobMeta, get_job_store
from core.store.presence import get_presence, set_presence, is_paused, pause, resume
from core.store.paths import config_home, jobs_dir, playbooks_dir
from core.runtime.memory import list_notes, add_note, forget_note
from core.catalogs.playbooks import list_playbooks, get_playbook
from core.catalogs.health import config_health_report, HealthReport
from core.policy.audit import append_audit, read_audit
from core.policy.profiles import get_profile, list_profiles, resolve_profile

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
