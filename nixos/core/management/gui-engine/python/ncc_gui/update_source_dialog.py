"""Modal: choose source for «Update to schema version» (This PC vs GitHub branch)."""

from __future__ import annotations

import getpass
import socket
from pathlib import Path

from PySide6.QtWidgets import (
    QButtonGroup,
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QRadioButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.theme import APP_STYLE


class UpdateSourceDialog(QDialog):
    """Pick Host tree or GitHub branch — not GitHub Releases."""

    def __init__(
        self,
        parent: QWidget | None = None,
        *,
        schema_version: str,
        target: str | None,
        local_path: str,
        branch: str,
        auto_build: bool = True,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle(f"Update to {schema_version}")
        self.setStyleSheet(APP_STYLE)
        self.resize(540, 360)
        self._schema = schema_version
        self._target = (target or "").strip() or None

        root = QVBoxLayout(self)

        where = self._target or "this machine"
        intro = QLabel(
            f"Bring NCC on <b>{where}</b> to config schema "
            f"<b>{schema_version}</b>.<br/>"
            "Choose the source for the new tree, then sync + migrate."
        )
        intro.setObjectName("nccPageSubtitle")
        intro.setWordWrap(True)
        from PySide6.QtCore import Qt

        intro.setTextFormat(Qt.TextFormat.RichText)
        root.addWidget(intro)

        note = QLabel(
            "Schema version lives in the tree — not a GitHub Release. "
            "GitHub uses a git branch (main / develop / …)."
        )
        note.setObjectName("nccPageSubtitle")
        note.setWordWrap(True)
        root.addWidget(note)

        form = QFormLayout()
        self._grp = QButtonGroup(self)

        host_name = socket.gethostname() or "this-pc"
        user = getpass.getuser() or "user"
        self.radio_pc = QRadioButton(f"This PC — {user}@{host_name}")
        self.radio_gh = QRadioButton("GitHub — branch")
        self._grp.addButton(self.radio_pc, 0)
        self._grp.addButton(self.radio_gh, 1)
        self.radio_pc.setChecked(True)

        pc_box = QVBoxLayout()
        pc_box.addWidget(self.radio_pc)
        self.path_edit = QLineEdit(local_path)
        self.path_edit.setPlaceholderText("…/NixOSControlCenter/nixos")
        pc_row = QHBoxLayout()
        pc_row.addWidget(QLabel("Path"))
        pc_row.addWidget(self.path_edit, stretch=1)
        pc_box.addLayout(pc_row)
        pc_w = QWidget()
        pc_w.setLayout(pc_box)
        form.addRow(pc_w)

        gh_box = QVBoxLayout()
        gh_box.addWidget(self.radio_gh)
        self.branch = QComboBox()
        self.branch.setEditable(True)
        for b in ("main", "develop", "experimental"):
            self.branch.addItem(b)
        self.branch.setCurrentText(branch or "main")
        gh_row = QHBoxLayout()
        gh_row.addWidget(QLabel("Branch"))
        gh_row.addWidget(self.branch, stretch=1)
        gh_box.addLayout(gh_row)
        gh_w = QWidget()
        gh_w.setLayout(gh_box)
        form.addRow(gh_w)

        root.addLayout(form)

        self.build_cb = QCheckBox("Build && switch after sync")
        self.build_cb.setChecked(auto_build)
        root.addWidget(self.build_cb)

        if self._target:
            tip = QLabel(
                "This PC: rsync → apply → rebuild → migrate-config on Target.\n"
                "GitHub: update --remote → migrate-config on Target."
            )
        else:
            tip = QLabel(
                "This PC: update --local → migrate-config on this machine.\n"
                "GitHub: update --remote → migrate-config on this machine."
            )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        root.addWidget(tip)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        ok = buttons.button(QDialogButtonBox.StandardButton.Ok)
        if ok is not None:
            ok.setText(f"Update to {schema_version}")
            ok.setObjectName("nccPrimaryButton")
        root.addWidget(buttons)

        self.radio_pc.toggled.connect(self._sync_enabled)
        self._sync_enabled()

    def _sync_enabled(self) -> None:
        pc = self.radio_pc.isChecked()
        self.path_edit.setEnabled(pc)
        self.branch.setEnabled(not pc)

    def choice(self) -> dict:
        if self.radio_pc.isChecked():
            return {
                "source": "local",
                "path": self.path_edit.text().strip(),
                "branch": self.branch.currentText().strip() or "main",
                "auto_build": self.build_cb.isChecked(),
            }
        return {
            "source": "remote",
            "path": self.path_edit.text().strip(),
            "branch": self.branch.currentText().strip() or "main",
            "auto_build": self.build_cb.isChecked(),
        }


def local_path_ok(path: str) -> tuple[bool, str]:
    p = Path(path).expanduser()
    if not p.is_dir():
        return False, f"Directory not found:\n{p}"
    if not (p / "flake.nix").is_file():
        return False, f"No flake.nix in:\n{p}"
    return True, ""
