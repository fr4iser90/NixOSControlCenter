"""Doomscroll / focus — first FeaturePlugin (not Settings core, not MCP)."""

from __future__ import annotations

from typing import Any


class DoomscrollPlugin:
    id = "doomscroll"
    title = "Doomscroll prevention"
    description = (
        "Watch selected browsers/sites (e.g. YouTube Shorts). Interrupt after "
        "time or clip count; optional nft net-block. Not an MCP server or "
        "agent template — a desktop focus plugin."
    )

    def is_enabled(self) -> bool:
        from ...preferences import get_doomscroll_enable

        return get_doomscroll_enable()

    def set_enabled(self, enabled: bool) -> None:
        from ...preferences import set_doomscroll_enable

        set_doomscroll_enable(bool(enabled))

    def on_tick(self, *, host: str) -> dict[str, Any] | None:
        from ...focus import consume_pending_nudge, tick
        from ...preferences import get_doomscroll_style

        result = tick()
        nudge: dict[str, Any] | None = None
        if result.get("intervened"):
            nudge = {
                "message": result.get("message") or "",
                "style": result.get("style") or get_doomscroll_style(),
                "streak_sec": result.get("streak_sec"),
                "window": result.get("window"),
            }
        elif host == "companion":
            pending = consume_pending_nudge()
            if pending and str(pending.get("style") or "") in (
                "companion",
                "agent",
                "nudge",
            ):
                nudge = pending

        out: dict[str, Any] = {"tick": result}
        if host == "companion" and nudge and str(nudge.get("style") or "companion") in (
            "companion",
            "agent",
        ):
            out["companion_nudge"] = nudge
        if host == "tray" and result.get("intervened"):
            out["tray_message"] = {
                "title": "NCC · Doomscroll interrupt",
                "body": str(result.get("message") or "Leave the feed."),
            }
        if host == "tray":
            try:
                from ...focus import peek_pending_nudge

                if peek_pending_nudge():
                    out["tray_badge"] = "doomscroll"
            except Exception:
                pass
        return out

    def build_settings_widget(self, parent: Any = None) -> Any:
        from .settings_ui import DoomscrollSettingsWidget

        return DoomscrollSettingsWidget(parent)
