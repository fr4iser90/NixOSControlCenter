#!/usr/bin/env python3
"""Dialog helpers — Copy must set clipboard on click (Wayland-safe)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

GUI_PY = Path(__file__).resolve().parents[2] / "nixos/core/management/gui-engine/python"
sys.path.insert(0, str(GUI_PY))


class ErrorDialogCopyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if "PySide6" not in sys.modules:
            sys.modules["PySide6"] = MagicMock()
            sys.modules["PySide6.QtCore"] = MagicMock()
            sys.modules["PySide6.QtGui"] = MagicMock()
            sys.modules["PySide6.QtWidgets"] = MagicMock()

    def test_copy_sets_clipboard_on_button_click(self) -> None:
        from PySide6.QtGui import QClipboard

        clip = MagicMock()
        box = MagicMock()
        copy_btn = MagicMock()
        ok_btn = MagicMock()
        box.addButton.side_effect = [copy_btn, ok_btn]
        box.clickedButton.return_value = copy_btn

        with (
            patch("ncc_gui.dialogs.QMessageBox", return_value=box),
            patch("ncc_gui.dialogs.QGuiApplication") as qapp,
        ):
            qapp.clipboard.return_value = clip
            from ncc_gui.dialogs import error

            error(None, "Catalog", "path missing\nline2")

        # clicked.connect registered a callback — invoke it
        self.assertTrue(copy_btn.clicked.connect.called)
        cb = copy_btn.clicked.connect.call_args[0][0]
        cb()
        clip.setText.assert_any_call("path missing\nline2", QClipboard.Mode.Clipboard)


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
