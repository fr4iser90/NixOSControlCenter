"""Users — DomainPage kit (list + create/edit modals, role-gated)."""

from __future__ import annotations

import json
from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLabel,
    QLineEdit,
    QListWidgetItem,
    QVBoxLayout,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage

ROLES = (
    ("guest", "Guest"),
    ("virtualization", "Virtualization"),
    ("restricted-admin", "Restricted admin"),
    ("admin", "Admin"),
)
SHELLS = ("bash", "zsh", "fish")


@dataclass(frozen=True)
class UserRow:
    name: str
    role: str
    shell: str
    auto_login: bool


class UserAccountDialog(QDialog):
    """Shared create / edit modal (GUI-DESIGN § CRUD)."""

    def __init__(
        self,
        parent=None,
        *,
        mode: str = "create",
        allow_admin: bool = True,
        initial: UserRow | None = None,
    ) -> None:
        super().__init__(parent)
        self._mode = mode
        self.setWindowTitle("Create user" if mode == "create" else "Edit user")
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name = QLineEdit()
        self.name.setPlaceholderText("alice")
        if mode == "edit" and initial is not None:
            self.name.setText(initial.name)
            self.name.setReadOnly(True)

        self.role = QComboBox()
        for v, lab in ROLES:
            if v == "admin" and not allow_admin:
                continue
            self.role.addItem(lab, v)

        self.shell = QComboBox()
        for s in SHELLS:
            self.shell.addItem(s, s)

        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        self.password2 = QLineEdit()
        self.password2.setEchoMode(QLineEdit.EchoMode.Password)
        if mode == "edit":
            self.password.setPlaceholderText("leave empty to keep")
            self.password2.setPlaceholderText("leave empty to keep")

        self.auto = QCheckBox("Auto-login")

        if initial is not None:
            self._set_combo(self.role, initial.role)
            self._set_combo(self.shell, initial.shell)
            self.auto.setChecked(initial.auto_login)

        form.addRow("Username", self.name)
        form.addRow("Password", self.password)
        form.addRow("Confirm", self.password2)
        form.addRow("Role", self.role)
        form.addRow("Shell", self.shell)
        form.addRow("", self.auto)
        layout.addLayout(form)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    @staticmethod
    def _set_combo(combo: QComboBox, value: str) -> None:
        for i in range(combo.count()):
            if combo.itemData(i) == value:
                combo.setCurrentIndex(i)
                return

    def values(self) -> tuple[str, str, str, bool, str] | None:
        name = self.name.text().strip().lower()
        if not name:
            return None
        pw = self.password.text()
        pw2 = self.password2.text()
        if pw != pw2:
            return None
        if self._mode == "create" and not name:
            return None
        return (
            name,
            str(self.role.currentData()),
            str(self.shell.currentData()),
            self.auto.isChecked(),
            pw,
        )


def _whoami() -> tuple[str, str, bool]:
    proc = run_ncc("user", "whoami", "--json")
    if proc.returncode == 0 and (proc.stdout or "").strip():
        try:
            data = json.loads(proc.stdout)
            return (
                str(data.get("user") or ""),
                str(data.get("role") or "guest"),
                bool(data.get("canManage")),
            )
        except json.JSONDecodeError:
            pass
    return ("", "guest", False)


def _load_users() -> tuple[list[UserRow], str]:
    proc = run_ncc("user", "list", "--json")
    err = ((proc.stderr or "") + (proc.stdout or "")).strip()
    if proc.returncode != 0:
        return [], err or "ncc user list failed"
    try:
        data = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        return [], "Invalid JSON from ncc user list"
    if not isinstance(data, list):
        return [], "Unexpected list payload"
    rows: list[UserRow] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "")
        if not name:
            continue
        rows.append(
            UserRow(
                name=name,
                role=str(item.get("role") or "guest"),
                shell=str(item.get("shell") or "bash"),
                auto_login=bool(item.get("autoLogin")),
            )
        )
    return rows, ""


class UserPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Users",
            "Create and edit accounts in a dialog. Guests only see themselves.",
            parent=parent,
        )
        self._me = ""
        self._role = "guest"
        self._can_manage = False
        self._selected: UserRow | None = None

        _, self.list = self.add_list_block("Accounts")
        self.list.currentItemChanged.connect(self._on_select)

        self.you_are = QLabel("")
        self.you_are.setObjectName("nccPageSubtitle")
        self.add_content_widget(self.you_are)

        self.do_rebuild = QCheckBox("Rebuild & switch after changes")
        self.do_rebuild.setChecked(True)
        self.add_actions_widget(self.do_rebuild)

        self.btn_create = self.add_action("Create…", self._create, primary=True)
        self.btn_edit = self.add_action("Edit…", self._edit)
        self.btn_delete = self.add_action("Delete…", self._delete)
        self.add_action("Refresh", self.reload)

        self.reload()

    def _set_manage_ui(self) -> None:
        self.btn_create.setVisible(self._can_manage)
        self.btn_edit.setVisible(self._can_manage)
        self.btn_delete.setVisible(self._can_manage)
        self.you_are.setText(f"Signed in as {self._me} · role {self._role}")

    def reload(self) -> None:
        self._me, self._role, self._can_manage = _whoami()
        self._set_manage_ui()
        self.list.clear()
        users, err = _load_users()
        if err:
            self.log_append(f"• List error\n{err}\n")
        for u in users:
            item = QListWidgetItem(f"{u.name}  ·  {u.role}")
            item.setData(Qt.ItemDataRole.UserRole, u)
            self.list.addItem(item)
        if self.list.count():
            self.list.setCurrentRow(0)
        else:
            self._selected = None

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            self._selected = None
            return
        u = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(u, UserRow):
            return
        self._selected = u
        if self._role == "restricted-admin" and u.role == "admin":
            self.btn_delete.setEnabled(False)
            self.btn_edit.setEnabled(self._can_manage)
        else:
            self.btn_delete.setEnabled(self._can_manage)
            self.btn_edit.setEnabled(self._can_manage)

    def _rebuild_flag(self) -> list[str]:
        return ["--rebuild"] if self.do_rebuild.isChecked() else []

    def _create(self) -> None:
        if not self._can_manage:
            return
        dlg = UserAccountDialog(
            self, mode="create", allow_admin=(self._role == "admin")
        )
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        vals = dlg.values()
        if vals is None:
            error(self, "Users", "Username required; passwords must match.")
            return
        name, role_val, shell, auto, password = vals
        if not confirm(self, "Create user?", f"Create {name} as {role_val}?"):
            return
        args = [
            "user",
            "create",
            name,
            "--role",
            role_val,
            "--shell",
            shell,
            "--auto-login",
            "true" if auto else "false",
            *self._rebuild_flag(),
        ]
        env = {"NCC_NEW_USER_PASSWORD": password} if password else None

        def _done(code: int) -> None:
            if code == 0:
                info(self, "Users", f"Created {name}.")
                self.reload()

        self.run_ncc_async(args, label=f"create {name}", on_done=_done, env=env)

    def _edit(self) -> None:
        if not self._can_manage or self._selected is None:
            return
        u = self._selected
        dlg = UserAccountDialog(
            self,
            mode="edit",
            allow_admin=(self._role == "admin"),
            initial=u,
        )
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        vals = dlg.values()
        if vals is None:
            error(self, "Users", "Passwords must match.")
            return
        name, role_val, shell, auto, password = vals
        if self._role == "restricted-admin" and role_val == "admin":
            error(self, "Users", "Restricted admin cannot assign the admin role.")
            return
        if not confirm(
            self,
            "Save user?",
            f"Update {name}: role={role_val}, shell={shell}, auto-login={auto}",
        ):
            return
        args = [
            "user",
            "set",
            name,
            "--role",
            role_val,
            "--shell",
            shell,
            "--auto-login",
            "true" if auto else "false",
            *self._rebuild_flag(),
        ]
        env = {"NCC_NEW_USER_PASSWORD": password} if password else None

        def _done(code: int) -> None:
            if code == 0:
                info(self, "Users", f"Updated {name}.")
                self.reload()

        self.run_ncc_async(args, label=f"set {name}", on_done=_done, env=env)

    def _delete(self) -> None:
        if not self._can_manage or self._selected is None:
            return
        name = self._selected.name
        if not confirm(
            self,
            "Delete user?",
            f"Remove account {name} from NCC config?\n"
            "Home directory is not deleted.",
        ):
            return
        args = ["user", "delete", name, *self._rebuild_flag()]

        def _done(code: int) -> None:
            if code == 0:
                info(self, "Users", f"Deleted {name}.")
                self.reload()

        self.run_ncc_async(args, label=f"delete {name}", on_done=_done)


def create_page() -> UserPage:
    return UserPage()


Page = UserPage
