"""Playbook loading and management for predefined agent tasks."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from importlib import resources
from pathlib import Path
from typing import Any

from .paths import playbooks_dir


@dataclass
class Playbook:
    """A playbook definition."""
    name: str
    description: str = ""
    goal: str = ""
    profile: str | None = None
    dry_run: bool = False
    max_steps: int | None = None
    tags: list[str] = field(default_factory=list)
    source: str = ""  # builtin | user
    path: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "goal": self.goal,
            "profile": self.profile,
            "dry_run": self.dry_run,
            "max_steps": self.max_steps,
            "tags": self.tags,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any], source: str = "user", path: str | None = None) -> "Playbook":
        return cls(
            name=data.get("name", ""),
            description=data.get("description", ""),
            goal=data.get("goal", ""),
            profile=data.get("profile"),
            dry_run=data.get("dry_run", data.get("dryRun", False)),
            max_steps=data.get("max_steps", data.get("maxSteps")),
            tags=data.get("tags", []),
            source=source,
            path=path,
        )


def _load_builtin_playbooks() -> list[Playbook]:
    """Load builtin playbooks from package data."""
    playbooks: list[Playbook] = []

    try:
        pkg_files = resources.files("ncc_assistant") / "playbooks"
        if pkg_files.is_dir():
            for item in pkg_files.iterdir():
                if item.name.endswith(".json"):
                    try:
                        content = item.read_text(encoding="utf-8")
                        data = json.loads(content)
                        playbooks.append(Playbook.from_dict(
                            data,
                            source="builtin",
                            path=str(item),
                        ))
                    except (OSError, json.JSONDecodeError):
                        continue
    except (TypeError, AttributeError):
        pass

    return playbooks


def _load_user_playbooks() -> list[Playbook]:
    """Load user playbooks from ~/.config/ncc-assistant/playbooks/."""
    playbooks: list[Playbook] = []
    user_dir = playbooks_dir()

    if not user_dir.is_dir():
        return playbooks

    for path in user_dir.glob("*.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not data.get("name"):
                data["name"] = path.stem
            playbooks.append(Playbook.from_dict(
                data,
                source="user",
                path=str(path),
            ))
        except (OSError, json.JSONDecodeError):
            continue

    return playbooks


def list_playbooks() -> list[Playbook]:
    """List all available playbooks (builtin + user)."""
    playbooks: dict[str, Playbook] = {}

    for pb in _load_builtin_playbooks():
        playbooks[pb.name] = pb

    for pb in _load_user_playbooks():
        playbooks[pb.name] = pb

    return sorted(playbooks.values(), key=lambda p: (p.source != "builtin", p.name))


def get_playbook(name: str) -> Playbook | None:
    """Get a playbook by name."""
    for pb in list_playbooks():
        if pb.name == name:
            return pb
    return None


def save_user_playbook(playbook: Playbook) -> Path:
    """Save a playbook to user directory."""
    user_dir = playbooks_dir()
    user_dir.mkdir(parents=True, exist_ok=True)

    safe_name = "".join(c if c.isalnum() or c in "-_" else "-" for c in playbook.name)
    path = user_dir / f"{safe_name}.json"
    path.write_text(json.dumps(playbook.to_dict(), indent=2) + "\n", encoding="utf-8")
    return path


def delete_user_playbook(name: str) -> bool:
    """Delete a user playbook by name."""
    pb = get_playbook(name)
    if not pb or pb.source != "user" or not pb.path:
        return False

    path = Path(pb.path)
    if path.is_file():
        path.unlink()
        return True
    return False


def get_playbook_metadata(playbook: Playbook) -> dict[str, Any]:
    """Get metadata for running a playbook."""
    return {
        "name": playbook.name,
        "goal": playbook.goal,
        "profile": playbook.profile,
        "dry_run": playbook.dry_run,
        "max_steps": playbook.max_steps,
        "source": playbook.source,
    }
