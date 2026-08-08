"""SSH — DomainPage kit (clients, PTY, optional server)."""

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
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QSplitter,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.pty_terminal import PtyTerminal
from ncc_gui.scaffold import DomainPage
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


def _run_ssh(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ncc", "ssh", *args],
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
    target = f"{user}@{host}"
    for term in ("konsole", "kitty", "alacritty", "gnome-terminal", "xterm"):
        path = shutil.which(term)
        if not path:
            continue
        if term == "konsole":
            argv = [path, "-e", "ssh", target]
        elif term == "gnome-terminal":
            argv = [path, "--", "ssh", target]
        else:
            argv = [path, "-e", "ssh", target]
        subprocess.Popen(argv, start_new_session=True)
        return
    raise RuntimeError("No terminal emulator found (konsole/kitty/alacritty/…)")


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


class SshPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "SSH",
            "Saved clients, embedded session, and local server controls when enabled.",
            activity_max_height=120,
            parent=parent,
        )
        self.setObjectName("nccShellRoot")
        self._selected: ServerEntry | None = None

        tabs = QTabWidget()
        self.add_content_widget(tabs, stretch=1)

        clients = QWidget()
        c_l = QVBoxLayout(clients)
        split = QSplitter(Qt.Orientation.Horizontal)
        c_l.addWidget(split, stretch=1)

        left = QWidget()
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(0, 0, 0, 0)
        left_l.addWidget(QLabel("Servers"))
        self.list = QListWidget()
        self.list.currentItemChanged.connect(self._on_select)
        left_l.addWidget(self.list, stretch=1)
        split.addWidget(left)

        right = QWidget()
        right_l = QVBoxLayout(right)
        self.detail = QLabel("Select a server")
        self.detail.setObjectName("nccPageSubtitle")
        self.detail.setWordWrap(True)
        right_l.addWidget(self.detail)

        term_box = QGroupBox("Session")
        term_l = QVBoxLayout(term_box)
        self.term = PtyTerminal()
        self.term.setMinimumHeight(220)
        self.term.exited.connect(lambda code: self.log_append(f"• Session ended ({code})"))
        term_l.addWidget(self.term)
        right_l.addWidget(term_box, stretch=1)
        split.addWidget(right)
        split.setStretchFactor(0, 1)
        split.setStretchFactor(1, 3)
        tabs.addTab(clients, "Clients")

        server = QWidget()
        s_l = QVBoxLayout(server)
        self.server_hint = QLabel()
        self.server_hint.setObjectName("nccPageSubtitle")
        self.server_hint.setWordWrap(True)
        s_l.addWidget(self.server_hint)
        self.server_status = QTextEdit()
        self.server_status.setReadOnly(True)
        self.server_status.setObjectName("nccActivityLog")
        s_l.addWidget(self.server_status, stretch=1)
        form = QFormLayout()
        self.server_user = QLineEdit()
        self.server_user.setPlaceholderText("username")
        form.addRow("Username", self.server_user)
        s_l.addLayout(form)
        tabs.addTab(server, "This host (server)")

        self.add_action("Connect (embedded)", self._connect_embedded, primary=True)
        self.add_action("External terminal", self._connect_external)
        self.add_action("Add…", self._add)
        self.add_action("Edit…", self._edit)
        self.add_action("Delete", self._delete)
        self.add_action("Refresh", self.reload)
        self.add_action("Server status", self._refresh_server_status)
        self.add_action(
            "Temp-open (60s)",
            lambda: self._server_action(("temp-open",), True, "Temp-open (60s)"),
        )
        self.add_action(
            "Force-open",
            lambda: self._server_action(("force-open",), True, "Force-open"),
        )
        self.add_action(
            "List requests",
            lambda: self._server_action(("list-requests", "pending"), False, "List requests"),
        )

        self.reload()
        self._refresh_server_status()

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

    def _on_select(self, current: QListWidgetItem | None, _prev: QListWidgetItem | None) -> None:
        if current is None:
            self._selected = None
            self.detail.setText("Select a server")
            return
        entry = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(entry, ServerEntry):
            return
        self._selected = entry
        self.detail.setText(f"Host: {entry.host}\nUser: {entry.user}")

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
        self.log_append(f"• Added {host} ({user})")
        self.reload()

    def _edit(self) -> None:
        if not self._selected:
            info(self, "Edit", "Select a server first.")
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
        self.log_append(f"• Updated {self._selected.host} → {user}")
        self.reload()

    def _delete(self) -> None:
        if not self._selected:
            info(self, "Delete", "Select a server first.")
            return
        host = self._selected.host
        if not confirm(self, "Delete", f"Remove saved server “{host}”?"):
            return
        proc = _run_client("delete", host)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Delete failed", out or "Could not delete server.")
            return
        self.log_append(f"• Deleted {host}")
        self._selected = None
        self.reload()

    def _connect_embedded(self) -> None:
        if not self._selected:
            info(self, "Connect", "Select a server first.")
            return
        entry = self._selected
        target = f"{entry.user}@{entry.host}"
        self.term.start(["ssh", "-tt", target])
        self.log_append(f"• Embedded connect {target}")

    def _connect_external(self) -> None:
        if not self._selected:
            info(self, "Connect", "Select a server first.")
            return
        entry = self._selected
        try:
            _open_external_ssh(entry.host, entry.user)
            self.log_append(f"• External terminal {entry.user}@{entry.host}")
        except RuntimeError as exc:
            error(self, "Connect", str(exc))

    def _refresh_server_status(self) -> None:
        proc = _run_ssh("status")
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0 and ("Unknown" in out or "unknown" in out.lower()):
            self.server_hint.setText(
                "SSH server module is not enabled on this machine. "
                "Enable ssh-server-manager in systemConfig to use temp-open / status here."
            )
            self.server_status.setPlainText(out or "(not available)")
            return
        self.server_hint.setText("Controls for the OpenSSH service on this host.")
        self.server_status.setPlainText(out or "(empty)")
        self.log_append("• Server status refreshed")

    def _server_action(self, args: tuple[str, ...], needs_user: bool, label: str) -> None:
        argv = list(args)
        if needs_user:
            user = self.server_user.text().strip()
            if not user:
                info(self, label, "Enter a username.")
                return
            if not confirm(self, label, f"Run “{label}” for user {user}?"):
                return
            argv.append(user)
        proc = _run_ssh(*argv)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        self.server_status.setPlainText(out or ("Done." if proc.returncode == 0 else "Failed."))
        self.log_append(f"• {label}\n{out or ''}")
        if proc.returncode != 0:
            error(self, label, out or "Command failed.")
        if args[:1] not in (("status",), ("list-requests",)):
            self._refresh_server_status()


def create_page() -> SshPage:
    return SshPage()


Page = SshPage
