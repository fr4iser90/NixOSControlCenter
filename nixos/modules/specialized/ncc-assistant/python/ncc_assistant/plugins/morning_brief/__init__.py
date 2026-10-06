"""Deprecated shim — briefing is workflow template ``workspace-brief`` + Cron.

Not a FeaturePlugin. Prefer ``ncc_assistant.morning_brief`` helpers and the
``workspace-brief`` agent template.
"""

from __future__ import annotations

from typing import Any


class MorningBriefPlugin:
    """Removed from list_plugins(); kept for import compatibility only."""

    id = "morning-brief"
    title = "Workspace brief (use template)"
    description = (
        "Use Workflows → workspace-brief (once or Cron). Not a plugin."
    )

    def is_enabled(self) -> bool:
        return False

    def set_enabled(self, enabled: bool) -> None:
        return None

    def on_tick(self, *, host: str) -> dict[str, Any] | None:
        return None

    def build_settings_widget(self, parent: Any = None) -> Any:
        from ...morning_brief_settings import MorningBriefSettingsWidget

        return MorningBriefSettingsWidget(parent)


__all__ = ["MorningBriefPlugin"]
