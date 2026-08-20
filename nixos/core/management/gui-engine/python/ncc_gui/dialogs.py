"""Standard dialogs for NCC domain GUIs."""

from __future__ import annotations

import re

from PySide6.QtGui import QGuiApplication
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


def error(
    parent: QWidget | None,
    title: str,
    text: str,
    *,
    details: str | None = None,
    copy_text: str | None = None,
) -> None:
    """Show an error dialog with OK + Copy (clipboard gets full diagnostic)."""
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Icon.Critical)
    box.setWindowTitle(title)
    box.setText(text)
    detail = (details or "").strip()
    if detail:
        # Keep detailedText for expand; also used as copy payload fallback.
        box.setDetailedText(detail)
    payload = (copy_text or detail or text).strip()
    copy_btn = box.addButton("Copy", QMessageBox.ButtonRole.ActionRole)
    box.addButton(QMessageBox.StandardButton.Ok)
    box.setDefaultButton(QMessageBox.StandardButton.Ok)
    box.exec()
    if box.clickedButton() is copy_btn and payload:
        clip = QGuiApplication.clipboard()
        if clip is not None:
            clip.setText(payload)


def confirm_rebuild(parent: QWidget | None, summary: str) -> bool:
    return confirm(
        parent,
        "Rebuild system?",
        f"{summary}\n\nRun nixos-rebuild switch now?",
    )


_COPYABLE_RE = re.compile(
    r"======== COPYABLE ERROR \(start\) ========\s*(.*?)\s*"
    r"======== COPYABLE ERROR \(end\) ========",
    re.DOTALL,
)


def summarize_command_failure(log: str, *, exit_code: int, label: str = "") -> tuple[str, str]:
    """Return (short_dialog_text, full_copyable) from Activity output."""
    text = log or ""
    copyable_blocks = _COPYABLE_RE.findall(text)
    if copyable_blocks:
        full = copyable_blocks[-1].strip()
    else:
        # Tail of the log — enough context without dumping megabytes.
        lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
        full = "\n".join(lines[-80:]) if lines else f"exit code {exit_code}"

    # Prefer the most useful single-line cause.
    cause = ""
    for pattern in (
        r">\s*(cp: .+)",
        r"error: Cannot build '([^']+)'\.\s*\n\s*Reason: ([^\n]+)",
        r"error: (.+)",
        r"\[ERROR\]\s*(.+)",
        r"Auto-build FAILED[^\n]*",
    ):
        matches = list(re.finditer(pattern, full, re.MULTILINE))
        if matches:
            m = matches[-1]
            cause = " ".join(g for g in m.groups() if g).strip() or m.group(0).strip()
            break
    if not cause:
        # Last non-empty line that looks like an error.
        for ln in reversed(full.splitlines()):
            s = ln.strip()
            if re.search(r"error|failed|permission denied|denied", s, re.I):
                cause = s
                break
        if not cause:
            cause = f"Command failed with exit code {exit_code}."

    who = (label or "Command").strip() or "Command"
    short = (
        f"{who} failed (exit {exit_code}).\n\n"
        f"{cause}\n\n"
        "Use Copy for the full error, or check Activity."
    )
    header = f"{who} — exit {exit_code}\n\n"
    return short, header + full
