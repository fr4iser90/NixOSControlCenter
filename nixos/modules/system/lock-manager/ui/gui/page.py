"""Lock domain page with discover / fetch / restore file picker."""

from __future__ import annotations

import subprocess

from PySide6.QtWidgets import (
    QCheckBox,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLineEdit,
    QPushButton,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.pages.base import DomainActionsPage
from ncc_gui.theme import APP_STYLE


class LockPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        layout = self.layout() if self.layout() else None
        from PySide6.QtWidgets import QVBoxLayout

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        actions = DomainActionsPage(
            "lock",
            "Lock",
            [
                ("Create snapshot", ("discover",)),
                ("List cloud snapshots", ("fetch", "--list")),
            ],
            subtitle="Back up desktop settings and restore them later.",
            confirm_labels=("Create snapshot",),
        )
        outer.addWidget(actions)

        box = QGroupBox("Restore from a file")
        form = QFormLayout(box)
        path_row = QHBoxLayout()
        self.path = QLineEdit()
        self.path.setPlaceholderText("Choose a snapshot file…")
        browse = QPushButton("Browse…")
        browse.clicked.connect(self._browse)
        path_row.addWidget(self.path, stretch=1)
        path_row.addWidget(browse)
        form.addRow("Snapshot", path_row)

        self.opt_all = QCheckBox("Everything")
        self.opt_all.setChecked(True)
        self.opt_browsers = QCheckBox("Browsers")
        self.opt_ides = QCheckBox("IDEs")
        self.opt_desktop = QCheckBox("Desktop")
        self.opt_dry = QCheckBox("Preview only (dry-run)")
        opts = QHBoxLayout()
        for w in (self.opt_all, self.opt_browsers, self.opt_ides, self.opt_desktop, self.opt_dry):
            opts.addWidget(w)
        form.addRow("Include", opts)

        restore_btn = QPushButton("Restore")
        restore_btn.clicked.connect(self._restore)
        form.addRow(restore_btn)
        actions.layout().insertWidget(actions.layout().count() - 1, box)

    def _browse(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self,
            "Select snapshot",
            "",
            "Snapshots (*.json *.encrypted *.json.encrypted);;All (*)",
        )
        if path:
            self.path.setText(path)

    def _restore(self) -> None:
        snap = self.path.text().strip()
        if not snap:
            info(self, "Restore", "Choose a snapshot file first.")
            return
        args = ["restore", "--snapshot", snap]
        if self.opt_dry.isChecked():
            args.append("--dry-run")
        if self.opt_all.isChecked():
            args.append("--all")
        else:
            if self.opt_browsers.isChecked():
                args.append("--browsers")
            if self.opt_ides.isChecked():
                args.append("--ides")
            if self.opt_desktop.isChecked():
                args.append("--desktop")
        if not confirm(self, "Restore", "Restore settings from this snapshot?"):
            return
        proc = subprocess.run(["ncc", "lock", *args], capture_output=True, text=True)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Restore failed", out or "Could not restore.")
        else:
            info(self, "Restore", out or "Done.")


def create_page(parent=None):
    return LockPage(parent)
