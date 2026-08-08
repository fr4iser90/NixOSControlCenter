"""AI — DomainPage kit fallback when assistant panel cannot embed."""

from __future__ import annotations

import subprocess
import traceback

from PySide6.QtWidgets import QLabel

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
                    "Could not embed the assistant panel. "
                    "Usually the LLM endpoint is unreachable or auth is missing.",
                    activity=False,
                    parent=p,
                )
                body = QLabel(
                    f"{type(exc).__name__}: {exc}\n\n"
                    "Start Ollama / fix api.endpoint, then retry.\n\n"
                    f"{traceback.format_exc()}"
                )
                body.setObjectName("nccMuted")
                body.setWordWrap(True)
                self.add_content_widget(body)
                self.add_action(
                    "Open NCC AI window",
                    lambda: subprocess.Popen(["ncc", "ai", "gui"]),
                    primary=True,
                )

        return _Fallback(parent)
