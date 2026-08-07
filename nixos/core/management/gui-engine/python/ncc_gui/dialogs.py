"""Standard dialogs for NCC domain GUIs."""

from __future__ import annotations

from PySide6.QtWidgets import QMessageBox, QWidget


def confirm(parent: QWidget | None, title: str, text: str) -> bool:
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Icon.Question)
    box.setWindowTitle(title)
    box.setText(text)
    box.setStandardButtons(
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
    )
    box.setDefaultButton(QMessageBox.StandardButton.No)
    return box.exec() == QMessageBox.StandardButton.Yes


def info(parent: QWidget | None, title: str, text: str) -> None:
    QMessageBox.information(parent, title, text)


def error(parent: QWidget | None, title: str, text: str) -> None:
    QMessageBox.critical(parent, title, text)


def confirm_rebuild(parent: QWidget | None, summary: str) -> bool:
    return confirm(
        parent,
        "Rebuild system?",
        f"{summary}\n\nRun nixos-rebuild switch now?",
    )
