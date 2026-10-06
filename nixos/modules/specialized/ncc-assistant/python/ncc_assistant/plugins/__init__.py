"""Feature plugins — desktop extras only (e.g. doomscroll).

Not workflow templates, not Cron, not briefing (use template workspace-brief).
"""

from __future__ import annotations

from typing import Any, Protocol, runtime_checkable


@runtime_checkable
class FeaturePlugin(Protocol):
    """Builtin feature plugin contract (Phase 36)."""

    id: str
    title: str
    description: str

    def is_enabled(self) -> bool: ...

    def set_enabled(self, enabled: bool) -> None: ...

    def on_tick(self, *, host: str) -> dict[str, Any] | None:
        """Periodic probe. host is ``companion`` or ``tray``."""
        ...

    def build_settings_widget(self, parent: Any = None) -> Any:
        """Return a Qt QWidget for the Plugins configure panel."""
        ...


def list_plugins() -> list[FeaturePlugin]:
    """Builtin feature plugins (workspace-brief is a template, not a plugin)."""
    from .doomscroll import DoomscrollPlugin

    return [DoomscrollPlugin()]


def get_plugin(plugin_id: str) -> FeaturePlugin | None:
    pid = (plugin_id or "").strip().lower()
    for p in list_plugins():
        if p.id == pid:
            return p
    return None


def tick_all(*, host: str) -> list[dict[str, Any]]:
    """Run on_tick for every enabled plugin. Returns event payloads."""
    out: list[dict[str, Any]] = []
    for p in list_plugins():
        try:
            if not p.is_enabled():
                continue
            result = p.on_tick(host=host)
            if isinstance(result, dict) and result:
                out.append({"plugin": p.id, **result})
        except Exception:
            continue
    return out
