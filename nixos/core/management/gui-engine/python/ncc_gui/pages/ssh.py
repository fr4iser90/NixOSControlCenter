"""SSH domain page — saved servers list and client actions."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.theme import APP_STYLE


@dataclass(frozen=True)
class ServerEntry:
    host: str
    user: str

    @property
    def label(self) -> str:
        return f"{self.host} ({self.user})"


def _run_client(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ncc", "ssh", "client", *args],
        check=False,
        capture_output=True,
        text=True,
    )


def load_servers() -> list[ServerEntry]:
    proc = _run_client("list")
    if proc.returncode != 0:
        return []
    out: list[ServerEntry] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        host, user = line.split("=", 1)
        host, user = host.strip(), user.strip()
        if host and user:
            out.append(ServerEntry(host=host, user=user))
    return out


def _open_external_ssh(host: str, user: str) -> None:
    """Temporary: open an external terminal until embedded PTY lands."""
    target = f"{user}@{host}"
    candidates: list[list[str]] = []
    for term in ("konsole", "kitty", "alacritty", "gnome-terminal", "xterm"):
        path = shutil.which(term)
        if not path:
            continue
        if term == "konsole":
            candidates.append([path, "-e", "ssh", target])
        elif term == "gnome-terminal":
            candidates.append([path, "--", "ssh", target])
        else:
            candidates.append([path, "-e", "ssh", target])
    if not candidates:
        # Last resort: background ssh won't work well; raise for caller
        raise RuntimeError("No terminal emulator found (konsole/kitty/alacritty/…)")
    subprocess.Popen(candidates[0], start_new_session=True)


class _ServerDialog(QDialog):
    def __init__(
        self,
        parent: QWidget | None,
        *,
        title: str,
        host: str = "",
        user: str = "",
        host_editable: bool = True,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setStyleSheet(APP_STYLE)
        form = QFormLayout(self)
        self.host = QLineEdit(host)
        self.host.setEnabled(host_editable)
        self.user = QLineEdit(user)
        form.addRow("Host", self.host)
        form.addRow("Username", self.user)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        form.addRow(buttons)

    def values(self) -> tuple[str, str]:
        return self.host.text().strip(), self.user.text().strip()


class SshPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        self.setObjectName("nccShellRoot")

        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("SSH")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel("Saved servers. Connect opens an external terminal for now.")
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        split = QSplitter(Qt.Orientation.Horizontal)
        root.addWidget(split, stretch=1)

        left = QWidget()
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(0, 0, 0, 0)
        left_l.addWidget(QLabel("Servers"))
        self.list = QListWidget()
        self.list.currentItemChanged.connect(self._on_select)
        left_l.addWidget(self.list, stretch=1)

        btn_row = QHBoxLayout()
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.reload)
        add_btn = QPushButton("Add…")
        add_btn.clicked.connect(self._add)
        btn_row.addWidget(refresh)
        btn_row.addWidget(add_btn)
        btn_row.addStretch(1)
        left_l.addLayout(btn_row)
        split.addWidget(left)

        right = QGroupBox("Details")
        right_l = QVBoxLayout(right)
        self.detail = QLabel("Select a server")
        self.detail.setObjectName("nccPageSubtitle")
        self.detail.setWordWrap(True)
        right_l.addWidget(self.detail)

        actions = QHBoxLayout()
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self._connect)
        self.edit_btn = QPushButton("Edit…")
        self.edit_btn.clicked.connect(self._edit)
        self.delete_btn = QPushButton("Delete")
        self.delete_btn.clicked.connect(self._delete)
        for b in (self.connect_btn, self.edit_btn, self.delete_btn):
            b.setEnabled(False)
            actions.addWidget(b)
        actions.addStretch(1)
        right_l.addLayout(actions)

        log_box = QGroupBox("Activity")
        log_l = QVBoxLayout(log_box)
        self.log = QTextEdit()
        self.log.setObjectName("nccActivityLog")
        self.log.setReadOnly(True)
        self.log.setMaximumHeight(160)
        log_l.addWidget(self.log)
        right_l.addWidget(log_box)
        right_l.addStretch(1)
        split.addWidget(right)
        split.setStretchFactor(0, 1)
        split.setStretchFactor(1, 2)

        self._selected: ServerEntry | None = None
        self.reload()

    def _append(self, msg: str) -> None:
        self.log.append(msg)

    def reload(self) -> None:
        current = self._selected.host if self._selected else None
        self.list.clear()
        servers = load_servers()
        pick: QListWidgetItem | None = None
        for entry in servers:
            item = QListWidgetItem(entry.label)
            item.setData(Qt.ItemDataRole.UserRole, entry)
            self.list.addItem(item)
            if current and entry.host == current:
                pick = item
        if pick is not None:
            self.list.setCurrentItem(pick)
        elif self.list.count():
            self.list.setCurrentRow(0)
        else:
            self._selected = None
            self.detail.setText("No servers yet. Click Add…")
            for b in (self.connect_btn, self.edit_btn, self.delete_btn):
                b.setEnabled(False)

    def _on_select(self, current: QListWidgetItem | None, _prev: QListWidgetItem | None) -> None:
        if current is None:
            self._selected = None
            self.detail.setText("Select a server")
            for b in (self.connect_btn, self.edit_btn, self.delete_btn):
                b.setEnabled(False)
            return
        entry = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(entry, ServerEntry):
            return
        self._selected = entry
        self.detail.setText(f"Host: {entry.host}\nUser: {entry.user}")
        for b in (self.connect_btn, self.edit_btn, self.delete_btn):
            b.setEnabled(True)

    def _add(self) -> None:
        dlg = _ServerDialog(self, title="Add SSH server")
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        host, user = dlg.values()
        if not host or not user:
            info(self, "Add", "Host and username are required.")
            return
        proc = _run_client("add", host, user)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Add failed", out or "Could not add server.")
            return
        self._append(f"• Added {host} ({user})")
        self.reload()

    def _edit(self) -> None:
        if not self._selected:
            return
        dlg = _ServerDialog(
            self,
            title="Edit SSH server",
            host=self._selected.host,
            user=self._selected.user,
            host_editable=False,
        )
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        _host, user = dlg.values()
        if not user:
            info(self, "Edit", "Username is required.")
            return
        proc = _run_client("edit", self._selected.host, user)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Edit failed", out or "Could not update server.")
            return
        self._append(f"• Updated {self._selected.host} → {user}")
        self.reload()

    def _delete(self) -> None:
        if not self._selected:
            return
        host = self._selected.host
        if not confirm(self, "Delete", f"Remove saved server “{host}”?"):
            return
        proc = _run_client("delete", host)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Delete failed", out or "Could not delete server.")
            return
        self._append(f"• Deleted {host}")
        self._selected = None
        self.reload()

    def _connect(self) -> None:
        if not self._selected:
            return
        entry = self._selected
        try:
            _open_external_ssh(entry.host, entry.user)
            self._append(f"• Connect {entry.user}@{entry.host} (external terminal)")
        except RuntimeError as exc:
            error(self, "Connect", str(exc))


def create_page() -> QWidget:
    return SshPage()


Page = SshPage
