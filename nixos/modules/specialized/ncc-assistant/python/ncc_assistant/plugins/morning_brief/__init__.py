"""Morning Brief — FeaturePlugin (daily digest nudge; not MCP/templates)."""

from __future__ import annotations

from typing import Any


class MorningBriefPlugin:
    id = "morning-brief"
    title = "Morning Brief"
    description = (
        "Daily Companion brief: PRs, issues, tasks, roadmap. Opt-in schedule "
        "(not MCP, not agent templates, not watchdogs). Workflows tab still "
        "edits tasks/roadmap data."
    )

    def is_enabled(self) -> bool:
        from ...preferences import get_daily_digest_enable

        return get_daily_digest_enable()

    def set_enabled(self, enabled: bool) -> None:
        from ...preferences import set_daily_digest_enable

        set_daily_digest_enable(bool(enabled))

    def on_tick(self, *, host: str) -> dict[str, Any] | None:
        from .logic import maybe_fire_brief

        return maybe_fire_brief(host=host)

    def build_settings_widget(self, parent: Any = None) -> Any:
        from .settings_ui import MorningBriefSettingsWidget

        return MorningBriefSettingsWidget(parent)
