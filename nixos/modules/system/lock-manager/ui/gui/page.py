"""Lock — DomainPage kit (snapshot / restore)."""

from __future__ import annotations

from PySide6.QtWidgets import QCheckBox, QFileDialog, QHBoxLayout, QLineEdit, QPushButton, QWidget

from ncc_gui.dialogs import confirm, info
from ncc_gui.scaffold import DomainPage


class LockPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Lock",
            "Back up desktop settings and restore them later.",
            parent=parent,
        )
        form = self.add_form_block("Restore from a file")
        path_row = QHBoxLayout()
        self.path = QLineEdit()
        self.path.setPlaceholderText("Choose a snapshot file…")
        browse = QPushButton("Browse…")
        browse.clicked.connect(self._browse)
        path_row.addWidget(self.path, stretch=1)
        path_row.addWidget(browse)
        path_wrap = QWidget()
        path_wrap.setLayout(path_row)
        form.addRow("Snapshot", path_wrap)

        self.opt_all = QCheckBox("Everything")
        self.opt_all.setChecked(True)
        self.opt_browsers = QCheckBox("Browsers")
        self.opt_ides = QCheckBox("IDEs")
        self.opt_desktop = QCheckBox("Desktop")
        self.opt_dry = QCheckBox("Preview only (dry-run)")
        opts = QHBoxLayout()
        for w in (self.opt_all, self.opt_browsers, self.opt_ides, self.opt_desktop, self.opt_dry):
            opts.addWidget(w)
        opts_wrap = QWidget()
        opts_wrap.setLayout(opts)
        form.addRow("Include", opts_wrap)

        self.add_action("Restore", self._restore, primary=True)
        self.add_action(
            "Create snapshot",
            lambda: self.run_ncc("lock", "discover", need_confirm="Create snapshot"),
        )
        self.add_action(
            "List cloud snapshots",
            lambda: self.run_ncc("lock", "fetch", "--list"),
        )

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
        args: list[str] = ["lock", "restore", "--snapshot", snap]
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
        self.run_ncc(*args)


def create_page(parent=None):
    return LockPage(parent)


Page = LockPage
