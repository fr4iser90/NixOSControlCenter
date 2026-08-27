"""Users — DomainPage kit (list + create/edit modals, draft-first CommitBar)."""

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

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import confirm, error
from ncc_gui.domain_fs_status import read_users_fs
from ncc_gui.remote import run_ncc, target_from_env
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


def _row_from_meta(meta: dict) -> UserRow | None:
    raw = meta.get("row")
    if not isinstance(raw, dict):
        return None
    name = str(raw.get("name") or "")
    if not name:
        return None
    return UserRow(
        name=name,
        role=str(raw.get("role") or "guest"),
        shell=str(raw.get("shell") or "bash"),
        auto_login=bool(raw.get("auto_login")),
    )


def _row_to_meta(row: UserRow) -> dict:
    return {
        "name": row.name,
        "role": row.role,
        "shell": row.shell,
        "auto_login": row.auto_login,
    }


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
        fs = read_users_fs(target_from_env())
        if fs.ok and fs.users:
            rows = [
                UserRow(
                    name=u.name,
                    role=u.role,
                    shell=u.shell,
                    auto_login=u.auto_login,
                )
                for u in fs.users
            ]
            return rows, ""
        if fs.ok:
            return [], ""
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
            "Create and edit accounts in a dialog — they appear as drafts in the list. "
            "Save / Undo, then Apply to write config (rebuild is offered after Apply).",
            parent=parent,
        )
        self._me = ""
        self._role = "guest"
        self._can_manage = False
        self._selected: UserRow | None = None
        self._live: list[UserRow] = []
        self._flush_queue: list[PendingChange] = []
        self._flush_summary = ""
        self._reloading = False

        _, self.list = self.add_list_block("Accounts")
        self.list.currentItemChanged.connect(self._on_select)

        self.you_are = QLabel("")
        self.you_are.setObjectName("nccPageSubtitle")
        self.add_content_widget(self.you_are)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._render_list)

        self.btn_create = self.add_action(
            "Create…", self._create, ncc=("user", "create")
        )
        self.btn_edit = self.add_action("Edit…", self._edit, local=True)
        self.btn_delete = self.add_action(
            "Delete…", self._delete, ncc=("user", "delete")
        )
        self.add_action("Refresh", self.reload, local=True)

        self.reload()

    def _set_manage_ui(self) -> None:
        self.btn_create.setVisible(self._can_manage)
        self.btn_edit.setVisible(self._can_manage)
        self.btn_delete.setVisible(self._can_manage)
        self.you_are.setText(f"Signed in as {self._me} · role {self._role}")

    def reload(self) -> None:
        self._me, self._role, self._can_manage = _whoami()
        self._set_manage_ui()
        users, err = _load_users()
        if err:
            self.log_append(f"• List error\n{err}\n")
        self._live = users
        self._render_list()

    def _pending_by_name(self) -> dict[str, PendingChange]:
        assert self.commit is not None
        out: dict[str, PendingChange] = {}
        for ch in self.commit.pending:
            row = _row_from_meta(ch.meta)
            if row is not None:
                out[row.name] = ch
        return out

    def _render_list(self) -> None:
        if self._reloading:
            return
        self._reloading = True
        try:
            prev = self._selected.name if self._selected else None
            self.list.clear()
            pending = self._pending_by_name()
            live_names = {u.name for u in self._live}

            for u in self._live:
                ch = pending.get(u.name)
                if ch is not None and ch.meta.get("op") == "delete":
                    item = QListWidgetItem(f"{u.name}  ·  {u.role}  · pending delete")
                    item.setData(Qt.ItemDataRole.UserRole, u)
                    item.setData(Qt.ItemDataRole.UserRole + 1, "delete")
                    self.list.addItem(item)
                    continue
                if ch is not None and ch.meta.get("op") == "set":
                    draft = _row_from_meta(ch.meta) or u
                    item = QListWidgetItem(
                        f"{draft.name}  ·  {draft.role}  · pending edit"
                    )
                    item.setData(Qt.ItemDataRole.UserRole, draft)
                    item.setData(Qt.ItemDataRole.UserRole + 1, "set")
                    self.list.addItem(item)
                    continue
                item = QListWidgetItem(f"{u.name}  ·  {u.role}")
                item.setData(Qt.ItemDataRole.UserRole, u)
                item.setData(Qt.ItemDataRole.UserRole + 1, "live")
                self.list.addItem(item)

            for name, ch in pending.items():
                if name in live_names:
                    continue
                if ch.meta.get("op") != "create":
                    continue
                draft = _row_from_meta(ch.meta)
                if draft is None:
                    continue
                item = QListWidgetItem(
                    f"{draft.name}  ·  {draft.role}  · pending create"
                )
                item.setData(Qt.ItemDataRole.UserRole, draft)
                item.setData(Qt.ItemDataRole.UserRole + 1, "create")
                self.list.addItem(item)

            if self.list.count() == 0:
                self._selected = None
                return
            if prev:
                for i in range(self.list.count()):
                    u = self.list.item(i).data(Qt.ItemDataRole.UserRole)
                    if isinstance(u, UserRow) and u.name == prev:
                        self.list.setCurrentRow(i)
                        return
            self.list.setCurrentRow(0)
        finally:
            self._reloading = False

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

    @staticmethod
    def _same_user(a: PendingChange, b: PendingChange) -> bool:
        ra = _row_from_meta(a.meta)
        rb = _row_from_meta(b.meta)
        return ra is not None and rb is not None and ra.name == rb.name

    def _stage_replace(self, change: PendingChange) -> None:
        assert self.commit is not None
        self.commit.stage_replace(change, same=self._same_user)

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
        if any(u.name == name for u in self._live) or name in self._pending_by_name():
            error(self, "Users", f"User already listed (live or draft): {name}")
            return
        row = UserRow(name=name, role=role_val, shell=shell, auto_login=auto)
        meta: dict = {"op": "create", "row": _row_to_meta(row)}
        if password:
            meta["env"] = {"NCC_NEW_USER_PASSWORD": password}
        self._stage_replace(
            PendingChange(
                summary=f"create {name} ({role_val})",
                argv=[
                    "user",
                    "create",
                    name,
                    "--role",
                    role_val,
                    "--shell",
                    shell,
                    "--auto-login",
                    "true" if auto else "false",
                ],
                elevated=False,
                meta=meta,
            )
        )

    def _edit(self) -> None:
        if not self._can_manage or self._selected is None:
            return
        u = self._selected
        pending = self._pending_by_name().get(u.name)
        if pending is not None and pending.meta.get("op") == "delete":
            error(self, "Users", f"{u.name} is marked for delete — Undo first.")
            return
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
        row = UserRow(name=name, role=role_val, shell=shell, auto_login=auto)
        # Still a draft create? Keep create argv with updated fields.
        if pending is not None and pending.meta.get("op") == "create":
            meta: dict = {"op": "create", "row": _row_to_meta(row)}
            if password:
                meta["env"] = {"NCC_NEW_USER_PASSWORD": password}
            elif isinstance(pending.meta.get("env"), dict):
                meta["env"] = dict(pending.meta["env"])
            self._stage_replace(
                PendingChange(
                    summary=f"create {name} ({role_val})",
                    argv=[
                        "user",
                        "create",
                        name,
                        "--role",
                        role_val,
                        "--shell",
                        shell,
                        "--auto-login",
                        "true" if auto else "false",
                    ],
                    elevated=False,
                    meta=meta,
                )
            )
            return
        meta = {"op": "set", "row": _row_to_meta(row)}
        if password:
            meta["env"] = {"NCC_NEW_USER_PASSWORD": password}
        self._stage_replace(
            PendingChange(
                summary=f"set {name} ({role_val})",
                argv=[
                    "user",
                    "set",
                    name,
                    "--role",
                    role_val,
                    "--shell",
                    shell,
                    "--auto-login",
                    "true" if auto else "false",
                ],
                elevated=False,
                meta=meta,
            )
        )

    def _delete(self) -> None:
        if not self._can_manage or self._selected is None:
            return
        name = self._selected.name
        pending = self._pending_by_name().get(name)
        # Cancel a draft create instead of staging delete
        if pending is not None and pending.meta.get("op") == "create":
            if not confirm(
                self,
                "Discard draft?",
                f"Remove pending create for {name} from the draft list?",
            ):
                return
            assert self.commit is not None
            self.commit.discard_where(
                lambda c: (_row_from_meta(c.meta) or UserRow("", "", "", False)).name
                == name,
                log=f"• discarded draft create: {name}\n",
            )
            return
        if not confirm(
            self,
            "Delete user?",
            f"Mark {name} for delete (written on Apply).\n"
            "Home directory is not deleted.",
        ):
            return
        row = self._selected
        self._stage_replace(
            PendingChange(
                summary=f"delete {name}",
                argv=["user", "delete", name],
                elevated=False,
                meta={"op": "delete", "row": _row_to_meta(row)},
            )
        )

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        self._flush_queue = list(changes)
        self._flush_summary = "; ".join(c.summary for c in changes)
        self._run_next_flush()

    def _run_next_flush(self) -> None:
        assert self.commit is not None
        if not self._flush_queue:
            self.commit.notify_apply_finished(True, self._flush_summary)
            self.reload()
            return
        ch = self._flush_queue.pop(0)
        env = ch.meta.get("env") if isinstance(ch.meta.get("env"), dict) else None

        def done(code: int) -> None:
            if code != 0:
                self._flush_queue.clear()
                return
            self._run_next_flush()

        self.run_ncc_async(
            ch.argv,
            label=ch.summary,
            on_done=done,
            env=env,
        )


def create_page() -> UserPage:
    return UserPage()


Page = UserPage
