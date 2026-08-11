"""SSH password dialog for Target Connect (key save is offered only after success)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLineEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.widgets import FormValueLabel


@dataclass(frozen=True)
class SshAuthChoice:
    """User choice from the password modal."""

    action: str  # "connect" | "cancel"
    password: str = ""


class SshAuthDialog(QDialog):
    """Password only — Connect or Cancel. No key install here."""

    def __init__(self, host: str, parent: QWidget | None = None, *, detail: str = "") -> None:
        super().__init__(parent)
        self.setWindowTitle("SSH authentication")
        self.setModal(True)
        self.setMinimumWidth(440)
        self._choice = SshAuthChoice(action="cancel")

        layout = QVBoxLayout(self)
        layout.setSpacing(12)

        intro = FormValueLabel(
            f"{host} needs a password (no SSH key yet).\n"
            "Enter the password to connect."
        )
        layout.addWidget(intro)

        if detail.strip():
            # Short technical hint — FormValueLabel avoids clipped wrap
            err = FormValueLabel(detail.strip()[:200])
            layout.addWidget(err)

        form = QFormLayout()
        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        self.password.setPlaceholderText("Password")
        self.password.returnPressed.connect(self._accept_connect)
        form.addRow("Password", self.password)
        layout.addLayout(form)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.button(QDialogButtonBox.StandardButton.Ok).setText("Connect")
        buttons.accepted.connect(self._accept_connect)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self.password.setFocus()

    def _accept_connect(self) -> None:
        pw = self.password.text()
        if not pw:
            self.password.setFocus()
            return
        self._choice = SshAuthChoice(action="connect", password=pw)
        self.accept()

    def choice(self) -> SshAuthChoice:
        return self._choice


def prompt_ssh_auth(
    parent: QWidget | None, host: str, *, detail: str = ""
) -> SshAuthChoice:
    dlg = SshAuthDialog(host, parent, detail=detail)
    if dlg.exec() != QDialog.DialogCode.Accepted:
        return SshAuthChoice(action="cancel")
    return dlg.choice()


def prompt_save_ssh_key(parent: QWidget | None, host: str) -> bool:
    """Ask after a successful password Connect whether to install the local key."""
    from ncc_gui.dialogs import confirm

    return confirm(
        parent,
        "Save SSH key?",
        f"Connected to {host}.\n\n"
        "Install your public key on that host so the next Connect "
        "does not need a password?",
    )
