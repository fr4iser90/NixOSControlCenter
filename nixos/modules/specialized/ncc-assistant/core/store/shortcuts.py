"""User-local desktop shortcuts for agent pause / resume / approvals.

In-app QShortcut helpers (GUI):
  Call ``install_user_shortcuts()`` once from the GUI settings/startup path
  to seed ``~/.local/share/applications/ncc-assistant-actions.desktop``.
  Plasma global bindings are configured separately via System Settings →
  Shortcuts (see ``shortcut_help()``). Optional in-window QShortcuts can
  mirror the same actions (presence pause/resume, approve list) if the GUI
  wants local key bindings; this module only documents that expectation.
"""

from __future__ import annotations

from pathlib import Path


DESKTOP_FILENAME = "ncc-assistant-actions.desktop"

DESKTOP_CONTENT = """\
[Desktop Entry]
Type=Application
Name=NCC Assistant Actions
Comment=Quick actions for NCC AI agent presence and approvals
Exec=ncc-assistant gui
Icon=help-about
Terminal=false
Categories=System;Utility;
Actions=PauseAgent;ResumeAgent;ShowApprovals;

[Desktop Action PauseAgent]
Name=Pause Agent
Exec=ncc-assistant presence pause
Icon=media-playback-pause

[Desktop Action ResumeAgent]
Name=Resume Agent
Exec=ncc-assistant presence resume
Icon=media-playback-start

[Desktop Action ShowApprovals]
Name=Show Approvals
Exec=ncc-assistant approve list
Icon=dialog-information
"""


def _applications_dir() -> Path:
    return Path.home() / ".local" / "share" / "applications"


def install_user_shortcuts() -> Path:
    """
    Write the user-local desktop file with Pause/Resume/ShowApprovals actions.

    Returns the path written.
    """
    directory = _applications_dir()
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / DESKTOP_FILENAME
    path.write_text(DESKTOP_CONTENT, encoding="utf-8")
    return path


def shortcut_help() -> str:
    """Return human-readable instructions for binding Plasma global shortcuts."""
    return (
        "Plasma global shortcuts\n"
        "-----------------------\n"
        "1. Open System Settings → Shortcuts (or Search → 'Shortcuts').\n"
        "2. Choose 'Custom Shortcuts' or 'Plasma' → 'Add Application…'.\n"
        "3. After running install_user_shortcuts() / ncc-assistant shortcuts,\n"
        f"   the desktop file ~/.local/share/applications/{DESKTOP_FILENAME}\n"
        "   exposes actions: Pause Agent, Resume Agent, Show Approvals.\n"
        "4. Suggested defaults:\n"
        "   • Meta+Shift+P — Pause Agent (ncc-assistant presence pause)\n"
        "   • Meta+Shift+R — Resume Agent (ncc-assistant presence resume)\n"
        "   • Meta+Shift+A — Show Approvals (ncc-assistant approve list)\n"
        "5. Alternatively bind each Exec line directly as a Custom Command.\n"
    )
