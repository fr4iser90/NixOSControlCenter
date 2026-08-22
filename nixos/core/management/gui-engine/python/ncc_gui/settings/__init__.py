"""GUI Settings — discovery-based tabs for the Control Center ⚙ dialog.

Modules may ship ``ui/gui/settings.py`` next to ``page.py`` (copied into
``ncc_domain_page.<id>``). Core tabs live in this package.

Protocol: export ``get_settings_tab() -> SettingsTabSpec | None``.
"""

from __future__ import annotations

from ncc_gui.settings.dialog import SettingsDialog, open_settings_dialog
from ncc_gui.settings.protocol import SettingsTabSpec

__all__ = [
    "SettingsDialog",
    "SettingsTabSpec",
    "open_settings_dialog",
]
