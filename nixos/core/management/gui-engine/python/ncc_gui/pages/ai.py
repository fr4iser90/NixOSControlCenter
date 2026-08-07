"""AI domain page — embeds ncc_assistant when available."""

from __future__ import annotations

import subprocess
import traceback

from PySide6.QtWidgets import QLabel, QPushButton, QVBoxLayout, QWidget


def create_page(parent: QWidget | None = None) -> QWidget:
    try:
        from ncc_assistant.gui import create_assistant_panel

        return create_assistant_panel(parent=parent, skip_session_picker=True)
    except Exception as exc:  # noqa: BLE001
        class _Fallback(QWidget):
            def __init__(self, p: QWidget | None = None) -> None:
                super().__init__(p)
                lay = QVBoxLayout(self)
                lay.addWidget(
                    QLabel(
                        "AI Assistant could not be embedded.\n\n"
                        f"{type(exc).__name__}: {exc}\n\n"
                        "Usually the LLM endpoint is unreachable "
                        "(start Ollama / fix api.endpoint), or auth is missing.\n"
                        "You can still open the standalone window:"
                    )
                )
                btn = QPushButton("Open NCC AI window")
                btn.clicked.connect(lambda: subprocess.Popen(["ncc", "ai", "gui"]))
                lay.addWidget(btn)
                detail = QLabel(traceback.format_exc())
                detail.setWordWrap(True)
                detail.setStyleSheet("color: #888; font-size: 11px;")
                lay.addWidget(detail)
                lay.addStretch(1)

        return _Fallback(parent)
