"""Presence management for agent availability state."""

from __future__ import annotations

import json
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Literal

from .paths import presence_file


PresenceState = Literal["available", "paused", "autonomous"]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class Presence:
    """Agent presence state."""
    state: PresenceState = "available"
    until: str | None = None  # ISO timestamp when presence expires
    reason: str | None = None
    updated_at: str | None = None

    def to_dict(self) -> dict[str, str | None]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, str | None]) -> "Presence":
        state = data.get("state", "available")
        if state not in ("available", "paused", "autonomous"):
            state = "available"
        return cls(
            state=state,  # type: ignore
            until=data.get("until"),
            reason=data.get("reason"),
            updated_at=data.get("updated_at"),
        )


def get_presence() -> Presence:
    """Get current presence state."""
    path = presence_file()
    if not path.is_file():
        return Presence()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        presence = Presence.from_dict(data)
        if presence.until:
            try:
                until_dt = datetime.fromisoformat(presence.until.replace("Z", "+00:00"))
                if until_dt < datetime.now(timezone.utc):
                    presence.state = "available"
                    presence.until = None
                    set_presence(presence.state, reason="Expired")
            except ValueError:
                pass
        return presence
    except (OSError, json.JSONDecodeError):
        return Presence()


def set_presence(
    state: PresenceState,
    *,
    until: str | None = None,
    reason: str | None = None,
) -> Presence:
    """Set presence state and persist."""
    presence = Presence(
        state=state,
        until=until,
        reason=reason,
        updated_at=_now_iso(),
    )
    path = presence_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(presence.to_dict(), indent=2) + "\n", encoding="utf-8")
    return presence


def is_paused() -> bool:
    """Check if agent is currently paused."""
    presence = get_presence()
    return presence.state == "paused"


def is_available() -> bool:
    """Check if agent is available for work."""
    presence = get_presence()
    return presence.state in ("available", "autonomous")


def is_autonomous() -> bool:
    """Check if agent is in autonomous mode."""
    presence = get_presence()
    return presence.state == "autonomous"


def pause(until: str | None = None, reason: str | None = None) -> Presence:
    """Pause the agent."""
    return set_presence("paused", until=until, reason=reason)


def resume(reason: str | None = None) -> Presence:
    """Resume the agent to available state."""
    return set_presence("available", reason=reason)


def set_autonomous(until: str | None = None, reason: str | None = None) -> Presence:
    """Set agent to autonomous mode."""
    return set_presence("autonomous", until=until, reason=reason)
