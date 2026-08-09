#!/usr/bin/env python3
"""Single-question GUI dialogs for install prompts (mid-flow fallback).

PySide6 + NCC APP_STYLE — same look as the install wizard / Control Center.

Usage:
  gui_ask.py text TITLE PROMPT [DEFAULT]
  gui_ask.py yesno TITLE PROMPT [y|n]
  gui_ask.py choice TITLE PROMPT OPT1|OPT2|... [DEFAULT]
  gui_ask.py password TITLE PROMPT [HINT]
"""

from __future__ import annotations

import os
import sys
from collections.abc import Callable
from pathlib import Path
from typing import List, Optional

_GUI_ENGINE = (
    Path(__file__).resolve().parents[4]
    / "nixos"
    / "core"
    / "management"
    / "gui-engine"
    / "python"
)
if _GUI_ENGINE.is_dir():
    sys.path.insert(0, str(_GUI_ENGINE))

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QRadioButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

try:
    from ncc_gui.theme import APP_STYLE
except ImportError:  # pragma: no cover
    APP_STYLE = ""

try:
    from ncc_gui.branding import app_icon
except ImportError:  # pragma: no cover

    def app_icon():  # type: ignore[misc]
        from PySide6.QtGui import QIcon

        return QIcon()


def _ensure_app() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication(sys.argv)
    if APP_STYLE:
        app.setStyleSheet(APP_STYLE)
    icon = app_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)
    return app  # type: ignore[return-value]


class AskDialog(QDialog):
    def __init__(self, title: str, prompt: str, *, min_h: int = 220) -> None:
        super().__init__()
        self.setWindowTitle(title)
        self.setMinimumSize(480, min_h)
        self.resize(540, max(280, min_h))
        self._result: Optional[str] = None
        self._ok_handler: Callable[[], None] = self.accept

        root = QWidget(self)
        root.setObjectName("nccShellRoot")
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.addWidget(root)

        lay = QVBoxLayout(root)
        lay.setContentsMargins(20, 16, 20, 16)
        lay.setSpacing(10)

        brand = QLabel("NCC")
        brand.setObjectName("nccPageTitle")
        lay.addWidget(brand)

        h = QLabel(title)
        h.setObjectName("nccPageTitle")
        lay.addWidget(h)

        sub = QLabel(prompt)
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        lay.addWidget(sub)

        self.body = QVBoxLayout()
        self.body.setAlignment(Qt.AlignmentFlag.AlignTop)
        lay.addLayout(self.body, stretch=1)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        ok = buttons.button(QDialogButtonBox.StandardButton.Ok)
        if ok is not None:
            ok.setObjectName("nccPrimaryButton")
            ok.setText("OK")
        buttons.accepted.connect(lambda: self._ok_handler())
        buttons.rejected.connect(self.reject)
        lay.addWidget(buttons)

    def result_value(self) -> Optional[str]:
        if self.exec() != QDialog.DialogCode.Accepted:
            return None
        return self._result


def ask_text(title: str, prompt: str, default: str = "") -> Optional[str]:
    _ensure_app()
    dlg = AskDialog(title, prompt)
    edit = QLineEdit(default)
    dlg.body.addWidget(edit)
    edit.setFocus()

    def _ok() -> None:
        val = edit.text().strip() or default
        if not val:
            QMessageBox.information(dlg, "Required", "Please enter a value.")
            return
        dlg._result = val
        dlg.accept()

    dlg._ok_handler = _ok
    return dlg.result_value()


def ask_yesno(title: str, prompt: str, default: str = "y") -> Optional[str]:
    _ensure_app()
    dlg = AskDialog(title, prompt)
    default_norm = "y" if default.lower() in ("y", "yes", "true") else "n"
    group = QButtonGroup(dlg)
    for label, value in (("Yes", "y"), ("No", "n")):
        rb = QRadioButton(label)
        rb.setChecked(value == default_norm)
        rb.setProperty("nccValue", value)
        group.addButton(rb)
        dlg.body.addWidget(rb)

    def _ok() -> None:
        for b in group.buttons():
            if b.isChecked():
                dlg._result = str(b.property("nccValue"))
                break
        dlg.accept()

    dlg._ok_handler = _ok
    return dlg.result_value()


def ask_choice(
    title: str, prompt: str, options: List[str], default: str = ""
) -> Optional[str]:
    _ensure_app()
    dlg = AskDialog(title, prompt, min_h=320)
    current = default if default in options else (options[0] if options else "")
    group = QButtonGroup(dlg)

    scroll = QScrollArea()
    scroll.setWidgetResizable(True)
    scroll.setFrameShape(QScrollArea.Shape.NoFrame)
    host = QWidget()
    host_lay = QVBoxLayout(host)
    host_lay.setAlignment(Qt.AlignmentFlag.AlignTop)
    for opt in options:
        rb = QRadioButton(opt)
        rb.setChecked(opt == current)
        rb.setProperty("nccValue", opt)
        group.addButton(rb)
        host_lay.addWidget(rb)
    scroll.setWidget(host)
    dlg.body.addWidget(scroll)

    def _ok() -> None:
        for b in group.buttons():
            if b.isChecked():
                dlg._result = str(b.property("nccValue"))
                break
        dlg.accept()

    dlg._ok_handler = _ok
    return dlg.result_value()


def ask_password(title: str, prompt: str, hint: str = "") -> Optional[str]:
    _ensure_app()
    full = prompt + (("\n" + hint) if hint else "")
    dlg = AskDialog(title, full, min_h=300)
    form = QFormLayout()
    p1 = QLineEdit()
    p1.setEchoMode(QLineEdit.EchoMode.Password)
    p2 = QLineEdit()
    p2.setEchoMode(QLineEdit.EchoMode.Password)
    form.addRow("Password", p1)
    form.addRow("Confirm", p2)
    wrap = QWidget()
    wrap.setLayout(form)
    dlg.body.addWidget(wrap)
    if hint:
        note = QLabel("Leave empty to use the suggested/random password.")
        note.setObjectName("nccMuted")
        note.setWordWrap(True)
        dlg.body.addWidget(note)
    p1.setFocus()

    def _ok() -> None:
        a, b = p1.text(), p2.text()
        if not a and not b:
            dlg._result = ""
            dlg.accept()
            return
        if len(a) < 8:
            QMessageBox.critical(
                dlg, "Too short", "Password must be at least 8 characters."
            )
            return
        if a != b:
            QMessageBox.critical(dlg, "Mismatch", "Passwords do not match.")
            return
        dlg._result = a
        dlg.accept()

    dlg._ok_handler = _ok
    return dlg.result_value()


def main(argv: List[str]) -> int:
    if len(argv) < 3:
        print("Usage: gui_ask.py TYPE TITLE PROMPT [args...]", file=sys.stderr)
        return 2
    ask_type, title, prompt = argv[0], argv[1], argv[2]
    rest = argv[3:]

    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        print("No graphical display", file=sys.stderr)
        return 2

    try:
        if ask_type == "text":
            default = rest[0] if rest else ""
            result = ask_text(title, prompt, default)
        elif ask_type == "yesno":
            default = rest[0] if rest else "y"
            result = ask_yesno(title, prompt, default)
        elif ask_type == "choice":
            opts = (rest[0] if rest else "").split("|")
            opts = [o for o in opts if o]
            default = rest[1] if len(rest) > 1 else ""
            result = ask_choice(title, prompt, opts, default)
        elif ask_type == "password":
            hint = rest[0] if rest else ""
            result = ask_password(title, prompt, hint)
        else:
            print(f"Unknown ask type: {ask_type}", file=sys.stderr)
            return 2
    except Exception as exc:
        print(f"GUI failed: {exc}", file=sys.stderr)
        return 2

    if result is None:
        return 1
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
