"""SSH — DomainPage kit (clients draft CRUD, PTY, optional server)."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass

from PySide6.QtCore import Qt, QTimer
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

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.pty_terminal import PtyTerminal
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE

_OP = "ssh-client"


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
        # Prefer top-level window so the dialog is not buried under the shell.
        win = parent.window() if parent is not None else None
        super().__init__(win if win is not None else parent)
        self.setWindowTitle(title)
        self.setModal(True)
        self.setMinimumWidth(380)
        self.setStyleSheet(APP_STYLE)
        layout = QVBoxLayout(self)
        form = QFormLayout()
        self.host = QLineEdit(host)
        self.host.setEnabled(host_editable)
        self.user = QLineEdit(user)
        form.addRow("Host", self.host)
        form.addRow("Username", self.user)
        layout.addLayout(form)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self.user.setFocus()

    def values(self) -> tuple[str, str]:
        return self.host.text().strip(), self.user.text().strip()

    def exec(self) -> int:  # noqa: A003
        self.show()
        self.raise_()
        self.activateWindow()
        return super().exec()


class SshPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "SSH",
            "Saved clients (draft Add/Edit/Delete → Apply), embedded session, "
            "and local server controls when enabled. Connect runs immediately.",
            activity_max_height=120,
            parent=parent,
        )
        self.setObjectName("nccShellRoot")
        self._selected: ServerEntry | None = None
        self._live: list[ServerEntry] = []

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

        self.add_actions_hint(
            "Add/Edit/Delete stage drafts (Apply writes the SSH client list). "
            "Connect and server controls run immediately."
        )
        self.add_action("Connect (embedded)", self._connect_embedded, local=True)
        self.add_action("External terminal", self._connect_external, local=True)
        self.add_action("Add…", self._add, ncc=("ssh", "client"))
        self.add_action("Edit…", self._edit, ncc=("ssh", "client"))
        self.add_action("Delete", self._delete, ncc=("ssh", "client"))
        self.add_action("Refresh", self.reload, local=True)
        self.add_action("Server status", self._refresh_server_status, ncc=("ssh", "status"))
        self.add_action(
            "Temp-open (60s)",
            lambda: self._server_action(("temp-open",), True, "Temp-open (60s)"),
            ncc=("ssh", "temp-open"),
        )
        self.add_action(
            "Force-open",
            lambda: self._server_action(("force-open",), True, "Force-open"),
            ncc=("ssh", "force-open"),
        )
        self.add_action(
            "List requests",
            lambda: self._server_action(
                ("list-requests", "pending"), False, "List requests"
            ),
            ncc=("ssh", "list-requests"),
        )

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._render_list)

        target_bus().sshClientEdit.connect(self._on_bus_edit_request)
        self.reload()
        self._refresh_server_status()

    def _on_bus_edit_request(self, target: object) -> None:
        """Header Edit: select host (user@host) and open the edit modal."""
        raw = str(target or "").strip()
        if not raw or "@" not in raw:
            QTimer.singleShot(0, self._edit)
            return
        user, _, host = raw.rpartition("@")
        user, host = user.strip(), host.strip()

        def _open() -> None:
            self._select_host(host, user)
            self._edit()

        QTimer.singleShot(0, _open)

    def _select_host(self, host: str, user: str | None = None) -> None:
        for i in range(self.list.count()):
            item = self.list.item(i)
            if item is None:
                continue
            entry = item.data(Qt.ItemDataRole.UserRole)
            if not isinstance(entry, ServerEntry):
                continue
            if entry.host == host and (user is None or entry.user == user):
                self.list.setCurrentItem(item)
                return
        # Not in list yet — still set selection so Edit can offer a dialog.
        if host and user:
            self._selected = ServerEntry(host=host, user=user)
            self.detail.setText(f"Host: {host}\nUser: {user}")

    def _pending_by_host(self) -> dict[str, PendingChange]:
        assert self.commit is not None
        out: dict[str, PendingChange] = {}
        for ch in self.commit.pending:
            if ch.meta.get("op") != _OP:
                continue
            host = str(ch.meta.get("host") or "")
            if host:
                out[host] = ch
        return out

    def _entry_from_meta(self, ch: PendingChange) -> ServerEntry | None:
        host = str(ch.meta.get("host") or "")
        user = str(ch.meta.get("user") or "")
        if not host or not user:
            return None
        return ServerEntry(host=host, user=user)

    def reload(self) -> None:
        self._live = load_servers()
        self._render_list()

    def _render_list(self) -> None:
        current = self._selected.host if self._selected else None
        self.list.clear()
        pending = self._pending_by_host()
        live_hosts = {e.host for e in self._live}
        pick: QListWidgetItem | None = None

        for entry in self._live:
            ch = pending.get(entry.host)
            if ch is not None and ch.meta.get("action") == "delete":
                text = f"{entry.label}  · pending delete"
                shown = entry
            elif ch is not None and ch.meta.get("action") == "edit":
                draft = self._entry_from_meta(ch) or entry
                text = f"{draft.label}  · pending edit"
                shown = draft
            else:
                text = entry.label
                shown = entry
            item = QListWidgetItem(text)
            item.setData(Qt.ItemDataRole.UserRole, shown)
            item.setData(Qt.ItemDataRole.UserRole + 1, ch.meta.get("action") if ch else "live")
            self.list.addItem(item)
            if current and shown.host == current:
                pick = item

        for host, ch in pending.items():
            if host in live_hosts:
                continue
            if ch.meta.get("action") != "add":
                continue
            draft = self._entry_from_meta(ch)
            if draft is None:
                continue
            item = QListWidgetItem(f"{draft.label}  · pending add")
            item.setData(Qt.ItemDataRole.UserRole, draft)
            item.setData(Qt.ItemDataRole.UserRole + 1, "add")
            self.list.addItem(item)
            if current and draft.host == current:
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
        kind = current.data(Qt.ItemDataRole.UserRole + 1) or "live"
        extra = ""
        if kind in ("add", "edit", "delete"):
            extra = f"\nDraft: pending {kind} — Apply to write; Connect needs a saved entry."
        self.detail.setText(f"Host: {entry.host}\nUser: {entry.user}{extra}")

    @staticmethod
    def _same_host(a: PendingChange, b: PendingChange) -> bool:
        return (
            a.meta.get("op") == b.meta.get("op") == _OP
            and a.meta.get("host") == b.meta.get("host")
        )

    def _stage_replace(self, change: PendingChange) -> None:
        assert self.commit is not None
        self.commit.stage_replace(change, same=self._same_host)

    def _add(self) -> None:
        dlg = _ServerDialog(self, title="Add SSH server")
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        host, user = dlg.values()
        if not host or not user:
            info(self, "Add", "Host and username are required.")
            return
        if any(e.host == host for e in self._live) or host in self._pending_by_host():
            error(self, "Add", f"Host already listed (live or draft): {host}")
            return
        self._stage_replace(
            PendingChange(
                summary=f"ssh client add {host} ({user})",
                argv=["ssh", "client", "add", host, user],
                elevated=False,
                meta={"op": _OP, "action": "add", "host": host, "user": user},
            )
        )

    def _edit(self) -> None:
        if not self._selected:
            info(self, "Edit", "Select a server first.")
            return
        pending = self._pending_by_host().get(self._selected.host)
        if pending is not None and pending.meta.get("action") == "delete":
            error(self, "Edit", "Marked for delete — Undo first.")
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
        host, user = dlg.values()
        if not user:
            info(self, "Edit", "Username is required.")
            return
        action = "add" if pending is not None and pending.meta.get("action") == "add" else "edit"
        argv = (
            ["ssh", "client", "add", host, user]
            if action == "add"
            else ["ssh", "client", "edit", host, user]
        )
        self._stage_replace(
            PendingChange(
                summary=f"ssh client {action} {host} ({user})",
                argv=argv,
                elevated=False,
                meta={"op": _OP, "action": action, "host": host, "user": user},
            )
        )

    def _delete(self) -> None:
        if not self._selected:
            info(self, "Delete", "Select a server first.")
            return
        host = self._selected.host
        user = self._selected.user
        pending = self._pending_by_host().get(host)
        if pending is not None and pending.meta.get("action") == "add":
            if not confirm(
                self,
                "Discard draft?",
                f"Remove pending add for {host}?",
            ):
                return
            assert self.commit is not None
            self.commit.discard_where(
                lambda c: c.meta.get("op") == _OP and c.meta.get("host") == host,
                log=f"• discarded draft add: {host}\n",
            )
            return
        if not confirm(
            self,
            "Delete",
            f"Mark “{host}” for delete (written on Apply)?",
        ):
            return
        self._stage_replace(
            PendingChange(
                summary=f"ssh client delete {host}",
                argv=["ssh", "client", "delete", host],
                elevated=False,
                meta={"op": _OP, "action": "delete", "host": host, "user": user},
            )
        )

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        assert self.commit is not None
        summary = "; ".join(c.summary for c in changes)
        for ch in changes:
            proc = self.run_ncc(*ch.argv, log=True, show_error=True)
            if proc.returncode != 0:
                return
        self.commit.notify_apply_finished(True, summary, offer_rebuild=False)
        self.reload()

    def _connect_embedded(self) -> None:
        if not self._selected:
            info(self, "Connect", "Select a server first.")
            return
        pending = self._pending_by_host().get(self._selected.host)
        if pending is not None and pending.meta.get("action") == "add":
            info(self, "Connect", "Apply the pending add before connecting.")
            return
        if pending is not None and pending.meta.get("action") == "delete":
            info(self, "Connect", "This host is marked for delete.")
            return
        entry = self._selected
        # Prefer live user if only edit is pending (edit not written yet)
        if pending is not None and pending.meta.get("action") == "edit":
            info(
                self,
                "Connect",
                "Pending edit is not written yet — connecting with the draft username. "
                "Apply to save.",
            )
        target = f"{entry.user}@{entry.host}"
        self.term.start(["ssh", "-tt", target])
        self.log_append(f"• Embedded connect {target}")

    def _connect_external(self) -> None:
        if not self._selected:
            info(self, "Connect", "Select a server first.")
            return
        pending = self._pending_by_host().get(self._selected.host)
        if pending is not None and pending.meta.get("action") == "add":
            info(self, "Connect", "Apply the pending add before connecting.")
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
                "Enable ssh-manager (server) in systemConfig to use temp-open / status here."
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
