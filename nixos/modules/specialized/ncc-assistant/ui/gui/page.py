"""AI — embed assistant panel in Control Center shell."""

from __future__ import annotations

import subprocess
import traceback

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QTextEdit

from ncc_gui.scaffold import DomainPage


def create_page(parent=None):
    try:
        from ncc_assistant.gui import create_assistant_panel

        return create_assistant_panel(parent=parent, skip_session_picker=True)
    except Exception as exc:  # noqa: BLE001
        class _Fallback(DomainPage):
            def __init__(self, p=None) -> None:
                super().__init__(
                    "AI Assistant",
                    "Could not open the assistant panel.",
                    activity=False,
                    parent=p,
                )
                detail = (
                    f"{type(exc).__name__}: {exc}\n\n"
                    "Check api.endpoint and network access, then retry.\n\n"
                    f"{traceback.format_exc()}"
                )
                body = QTextEdit()
                body.setReadOnly(True)
                body.setPlainText(detail)
                body.setTextInteractionFlags(
                    Qt.TextInteractionFlag.TextSelectableByMouse
                    | Qt.TextInteractionFlag.TextSelectableByKeyboard
                )
                body.setObjectName("nccMuted")
                self.add_content_widget(body)
                self.add_action(
                    "Open NCC AI window",
                    lambda: subprocess.Popen(["ncc", "ai", "gui"]),
                    primary=True,
                    local=True,
                )

        return _Fallback(parent)
