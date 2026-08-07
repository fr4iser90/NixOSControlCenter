"""Security profiles for agent tool access control."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Profile:
    """A security profile defining tool access rules."""
    name: str
    description: str = ""
    allow_write: bool = False
    allow_rebuild: bool = False
    allow_shell: bool = False
    allowlist: list[str] = field(default_factory=list)  # Empty = all allowed (minus denylist)
    denylist: list[str] = field(default_factory=list)
    max_steps: int = 50
    require_confirm: str = "writes"  # "writes" | "always" | "never"


BUILTIN_PROFILES: dict[str, Profile] = {
    "read-only": Profile(
        name="read-only",
        description="Read-only access to configuration and knowledge",
        allow_write=False,
        allow_rebuild=False,
        allow_shell=False,
        denylist=[
            "apply_module_config",
            "apply_system",
            "agent_finish",
        ],
        max_steps=20,
        require_confirm="always",
    ),
    "config-writer": Profile(
        name="config-writer",
        description="Can read and write module configurations",
        allow_write=True,
        allow_rebuild=False,
        allow_shell=False,
        denylist=[
            "apply_system",
        ],
        max_steps=30,
        require_confirm="writes",
    ),
    "ops": Profile(
        name="ops",
        description="Full operational access including system rebuild",
        allow_write=True,
        allow_rebuild=True,
        allow_shell=True,
        denylist=[],
        max_steps=100,
        require_confirm="writes",
    ),
}

# Friendly aliases used by GUI / Nix options
PROFILE_ALIASES: dict[str, str] = {
    "cautious": "config-writer",
    "autonomous": "ops",
}


def _canonical_profile_name(name: str | None) -> str:
    """Resolve profile aliases to builtin names."""
    if not name:
        return "read-only"
    return PROFILE_ALIASES.get(name, name)


def get_profile(name: str) -> Profile | None:
    """Get a profile by name (supports cautious/autonomous aliases)."""
    return BUILTIN_PROFILES.get(_canonical_profile_name(name))


def list_profiles() -> list[Profile]:
    """List all available profiles."""
    return list(BUILTIN_PROFILES.values())


def resolve_profile(
    profile_name: str | None,
    *,
    allow_write_override: bool | None = None,
    allow_rebuild_override: bool | None = None,
    allow_shell_override: bool | None = None,
) -> Profile:
    """
    Resolve a profile by name with optional overrides.
    Supports aliases: cautious → config-writer, autonomous → ops.
    Defaults to read-only if profile not found.
    """
    canonical = _canonical_profile_name(profile_name)
    profile = BUILTIN_PROFILES.get(canonical)
    if profile is None:
        profile = BUILTIN_PROFILES["read-only"]

    return Profile(
        name=profile.name,
        description=profile.description,
        allow_write=allow_write_override if allow_write_override is not None else profile.allow_write,
        allow_rebuild=allow_rebuild_override if allow_rebuild_override is not None else profile.allow_rebuild,
        allow_shell=allow_shell_override if allow_shell_override is not None else profile.allow_shell,
        allowlist=list(profile.allowlist),
        denylist=list(profile.denylist),
        max_steps=profile.max_steps,
        require_confirm=profile.require_confirm,
    )


def filter_tools(
    tool_names: list[str],
    profile: Profile,
) -> list[str]:
    """Filter tool names based on profile allowlist/denylist."""
    if profile.allowlist:
        filtered = [t for t in tool_names if t in profile.allowlist]
    else:
        filtered = list(tool_names)

    filtered = [t for t in filtered if t not in profile.denylist]
    return filtered


def is_tool_allowed(
    tool_name: str,
    profile: Profile,
) -> bool:
    """Check if a specific tool is allowed by the profile."""
    if tool_name in profile.denylist:
        return False
    if profile.allowlist and tool_name not in profile.allowlist:
        return False
    return True


def is_mutating_tool(tool_name: str) -> bool:
    """Check if a tool is considered mutating (writes or rebuilds)."""
    mutating = {
        "apply_module_config",
        "apply_system",
        "restore_config_backup",
    }
    return tool_name in mutating


def requires_confirmation(tool_name: str, profile: Profile) -> bool:
    """Check if a tool requires confirmation under the given profile."""
    if profile.require_confirm == "never":
        return False
    if profile.require_confirm == "always":
        return True
    if profile.require_confirm == "writes":
        return is_mutating_tool(tool_name)
    return False


class ProfileContext:
    """Runtime context for profile-based access control."""

    def __init__(self, profile: Profile) -> None:
        self.profile = profile
        self._tool_call_counts: dict[str, int] = {}

    def check_tool(self, tool_name: str) -> tuple[bool, str]:
        """
        Check if a tool call is allowed.
        Returns (allowed, reason).
        """
        if not is_tool_allowed(tool_name, self.profile):
            return False, f"Tool '{tool_name}' denied by profile '{self.profile.name}'"

        if tool_name == "apply_module_config" and not self.profile.allow_write:
            return False, "Writes not allowed by profile"

        if tool_name == "apply_system" and not self.profile.allow_rebuild:
            return False, "Rebuild not allowed by profile"

        if tool_name.startswith("shell.") and not self.profile.allow_shell:
            return False, "Shell tools not allowed by profile"

        return True, ""

    def record_call(self, tool_name: str) -> int:
        """Record a tool call and return current count."""
        count = self._tool_call_counts.get(tool_name, 0) + 1
        self._tool_call_counts[tool_name] = count
        return count

    def get_call_count(self, tool_name: str) -> int:
        """Get current call count for a tool."""
        return self._tool_call_counts.get(tool_name, 0)

    def to_dict(self) -> dict[str, Any]:
        """Export context state."""
        return {
            "profile": self.profile.name,
            "allow_write": self.profile.allow_write,
            "allow_rebuild": self.profile.allow_rebuild,
            "allow_shell": self.profile.allow_shell,
            "tool_call_counts": dict(self._tool_call_counts),
        }
