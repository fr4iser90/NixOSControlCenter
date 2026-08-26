"""SSH password dialog for Target Connect (key save is offered only after success)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLabel,
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


@dataclass(frozen=True)
class SshKeySaveChoice:
    """Result of the post-connect key-save prompt."""

    save: bool
    dont_ask_again: bool = False


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


class TargetSudoDialog(QDialog):
    """Target administrator password for one remote deploy (not stored)."""

    def __init__(self, host: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Target administrator password")
        self.setModal(True)
        self.setMinimumWidth(440)
        self._password = ""

        layout = QVBoxLayout(self)
        layout.setSpacing(12)
        intro = FormValueLabel(
            f"Install on {host} needs administrator rights on the Target.\n"
            "Enter your login password once for this deploy.\n"
            "It is not saved (use SSH keys for login; NOPASSWD sudo avoids this step)."
        )
        layout.addWidget(intro)

        form = QFormLayout()
        self._edit = QLineEdit()
        self._edit.setEchoMode(QLineEdit.EchoMode.Password)
        self._edit.returnPressed.connect(self._accept)
        form.addRow("Password", self._edit)
        layout.addLayout(form)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self._edit.setFocus()

    def _accept(self) -> None:
        pw = self._edit.text()
        if not pw:
            self._edit.setFocus()
            return
        self._password = pw
        self.accept()

    def password(self) -> str:
        return self._password


class SshKeySaveDialog(QDialog):
    """After password Connect: optional key install, with don't-ask-again."""

    def __init__(self, host: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Save SSH key?")
        self.setModal(True)
        self.setMinimumWidth(440)
        self._choice = SshKeySaveChoice(save=False, dont_ask_again=False)

        layout = QVBoxLayout(self)
        layout.setSpacing(12)
        body = FormValueLabel(
            f"Connected to {host}.\n\n"
            "Install your public key on that host so the next Connect "
            "does not need a password?"
        )
        layout.addWidget(body)

        self.dont_ask = QCheckBox("Don't ask again for this host")
        self.dont_ask.setToolTip(
            "If you choose No with this checked, NCC will keep using "
            "password Connect for this host and will not offer key save again."
        )
        layout.addWidget(self.dont_ask)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Yes | QDialogButtonBox.StandardButton.No
        )
        buttons.accepted.connect(self._yes)
        buttons.rejected.connect(self._no)
        layout.addWidget(buttons)

    def _yes(self) -> None:
        self._choice = SshKeySaveChoice(
            save=True, dont_ask_again=self.dont_ask.isChecked()
        )
        self.accept()

    def _no(self) -> None:
        self._choice = SshKeySaveChoice(
            save=False, dont_ask_again=self.dont_ask.isChecked()
        )
        self.accept()  # accept so we can read dont_ask; reject would lose it

    def choice(self) -> SshKeySaveChoice:
        return self._choice


def prompt_ssh_auth(
    parent: QWidget | None, host: str, *, detail: str = ""
) -> SshAuthChoice:
    dlg = SshAuthDialog(host, parent, detail=detail)
    if dlg.exec() != QDialog.DialogCode.Accepted:
        return SshAuthChoice(action="cancel")
    return dlg.choice()


def prompt_save_ssh_key(parent: QWidget | None, host: str) -> SshKeySaveChoice:
    """Ask after a successful password Connect whether to install the local key."""
    from ncc_gui.chrome_prefs import should_offer_ssh_key_save

    if not should_offer_ssh_key_save(host):
        return SshKeySaveChoice(save=False, dont_ask_again=False)

    dlg = SshKeySaveDialog(host, parent)
    if dlg.exec() != QDialog.DialogCode.Accepted:
        return SshKeySaveChoice(save=False, dont_ask_again=False)
    return dlg.choice()
