"""User — DomainPage kit (list configured users / roles)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QListWidgetItem, QTextEdit, QVBoxLayout

from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage


@dataclass(frozen=True)
class UserRow:
    name: str
    role: str
    shell: str
    auto_login: str


def load_users() -> list[UserRow]:
    proc = run_ncc("user", "list")
    rows: list[UserRow] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("=")
        if len(parts) < 2:
            continue
        name = parts[0]
        role = parts[1] if len(parts) > 1 else "?"
        shell = parts[2] if len(parts) > 2 else "?"
        auto = parts[3] if len(parts) > 3 else "?"
        rows.append(UserRow(name=name, role=role, shell=shell, auto_login=auto))
    return rows


class UserPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Users",
            "Users on this machine (systemConfig). "
            "Add or change users in systemConfig/users/ — GUI editing later.",
            activity=False,
            parent=parent,
        )
        _, self.list = self.add_list_block("Configured users")
        self.list.currentItemChanged.connect(self._on_select)

        detail_box = self.add_block("Details")
        dl = QVBoxLayout(detail_box)
        self.detail = QTextEdit()
        self.detail.setObjectName("nccActivityLog")
        self.detail.setReadOnly(True)
        self.detail.setMaximumHeight(120)
        self.detail.setPlaceholderText("Select a user…")
        dl.addWidget(self.detail)

        self.add_action("Refresh", self.reload, primary=True)
        self.reload()

    def reload(self) -> None:
        self.list.clear()
        for u in load_users():
            item = QListWidgetItem(f"{u.name}  ·  {u.role}")
            item.setData(Qt.ItemDataRole.UserRole, u)
            self.list.addItem(item)
        if self.list.count():
            self.list.setCurrentRow(0)
        else:
            self.detail.setPlainText("No users found (check systemConfig.users).")

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            return
        u = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(u, UserRow):
            return
        self.detail.setPlainText(
            f"User: {u.name}\nRole: {u.role}\nShell: {u.shell}\nAuto-login: {u.auto_login}"
        )


def create_page() -> UserPage:
    return UserPage()


Page = UserPage
