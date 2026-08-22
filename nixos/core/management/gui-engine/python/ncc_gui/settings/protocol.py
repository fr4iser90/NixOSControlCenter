"""Settings tab contribution protocol (modules + core)."""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field

from PySide6.QtWidgets import QWidget


@dataclass
class SettingsTabSpec:
    """One settings section in the Control Center dialog.

    ``requires_domains`` — only show this tab when *all* listed domain ids are
    present and enabled in ``NCC_GUI_CATALOG`` (discovery, no hardcoding).
    Empty = always available (core chrome).
    """

    id: str
    title: str
    # Build the page widget (parent is the dialog stack host)
    build: Callable[[QWidget | None], QWidget] = field(repr=False)
    # Read values from the built widget into a plain dict (prefs fragment)
    collect: Callable[[QWidget], dict] = field(repr=False)
    # Persist collected dict (write chrome_prefs / module prefs)
    apply: Callable[[dict], None] = field(repr=False)
    order: int = 100
    requires_domains: Sequence[str] = field(default_factory=tuple)
    # Optional short blurb under the title
    subtitle: str = ""
