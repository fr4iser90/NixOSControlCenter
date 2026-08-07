"""User domain — list configured users / roles (this machine only)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.remote import run_ncc
from ncc_gui.theme import APP_STYLE


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


class UserPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("Users")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel(
            "Users on this machine (systemConfig). "
            "Add or change users in systemConfig/users/ — GUI editing later."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        row = QHBoxLayout()
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.reload)
        row.addWidget(refresh)
        row.addStretch(1)
        root.addLayout(row)

        self.list = QListWidget()
        self.list.currentItemChanged.connect(self._on_select)
        root.addWidget(self.list, stretch=1)

        self.detail = QTextEdit()
        self.detail.setObjectName("nccActivityLog")
        self.detail.setReadOnly(True)
        self.detail.setMaximumHeight(120)
        root.addWidget(self.detail)
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


def create_page() -> QWidget:
    return UserPage()


Page = UserPage
