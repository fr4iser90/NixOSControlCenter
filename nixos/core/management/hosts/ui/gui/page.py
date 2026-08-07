"""Hosts domain — fleet targets from SSH client list (~/.creds)."""

from __future__ import annotations

import subprocess

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.target_bar import TargetBar
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_state import (
    get_active_target,
    list_host_pairs,
    set_active_target,
)
from ncc_gui.theme import APP_STYLE


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["ncc", *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )


class HostsPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("Hosts")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel(
            "Fleet targets reuse the SSH client list (`~/.creds` / `ncc ssh client`). "
            "Activate a host to set the global Target bar."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        self.active = QLabel()
        self.active.setObjectName("nccPageSubtitle")
        root.addWidget(self.active)

        self.list = QListWidget()
        self.list.itemDoubleClicked.connect(lambda _i: self._use())
        root.addWidget(self.list, stretch=1)

        btns = QHBoxLayout()
        use_btn = QPushButton("Use as target")
        use_btn.clicked.connect(self._use)
        local_btn = QPushButton("This machine")
        local_btn.clicked.connect(self._use_local)
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.reload)
        btns.addWidget(use_btn)
        btns.addWidget(local_btn)
        btns.addWidget(refresh)
        btns.addStretch(1)
        root.addLayout(btns)

        form = QFormLayout()
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("hostname or IP")
        self.user_edit = QLineEdit()
        self.user_edit.setPlaceholderText("user")
        form.addRow("Host", self.host_edit)
        form.addRow("User", self.user_edit)
        root.addLayout(form)
        add_row = QHBoxLayout()
        add_btn = QPushButton("Add (ssh client)")
        add_btn.clicked.connect(self._add)
        rem_btn = QPushButton("Remove")
        rem_btn.clicked.connect(self._remove)
        add_row.addWidget(add_btn)
        add_row.addWidget(rem_btn)
        add_row.addStretch(1)
        root.addLayout(add_row)

        target_bus().changed.connect(lambda _t: self._refresh_active())
        self.reload()

    def _refresh_active(self) -> None:
        t = get_active_target()
        self.active.setText(f"Active target: {t or 'This machine'}")

    def reload(self) -> None:
        self.list.clear()
        active = get_active_target()
        for host, user in list_host_pairs():
            target = f"{user}@{host}"
            label = target + ("  ← active" if active == target else "")
            item = QListWidgetItem(label)
            item.setData(Qt.ItemDataRole.UserRole, (host, user, target))
            self.list.addItem(item)
        if self.list.count() == 0:
            self.list.addItem(QListWidgetItem("(no hosts — add below or via ncc ssh client)"))
        self._refresh_active()

    def _selected(self) -> tuple[str, str, str] | None:
        item = self.list.currentItem()
        if item is None:
            return None
        data = item.data(Qt.ItemDataRole.UserRole)
        if not isinstance(data, tuple) or len(data) != 3:
            return None
        return data  # type: ignore[return-value]

    def _sync_bar(self, target: str | None) -> None:
        win = self.window()
        bar = win.findChild(TargetBar) if win is not None else None
        if isinstance(bar, TargetBar):
            bar.reload_hosts()
            bar.set_target(target, emit=True)
        else:
            set_active_target(target)
            target_bus().changed.emit(target)

    def _use(self) -> None:
        sel = self._selected()
        if not sel:
            error(self, "Use", "Select a host first.")
            return
        _host, _user, target = sel
        self._sync_bar(target)
        self.reload()
        info(self, "Target", f"Active target: {target}")

    def _use_local(self) -> None:
        self._sync_bar(None)
        self.reload()

    def _add(self) -> None:
        host = self.host_edit.text().strip()
        user = self.user_edit.text().strip()
        if not host or not user:
            error(self, "Add", "Host and user required.")
            return
        proc = _run("ssh", "client", "add", host, user)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Add", out or "ncc ssh client add failed (is ssh-client enabled?)")
            return
        self.host_edit.clear()
        self.user_edit.clear()
        self.reload()
        win = self.window()
        bar = win.findChild(TargetBar) if win is not None else None
        if isinstance(bar, TargetBar):
            bar.reload_hosts()

    def _remove(self) -> None:
        sel = self._selected()
        if not sel:
            error(self, "Remove", "Select a host first.")
            return
        host, _user, target = sel
        if not confirm(self, "Remove", f"Remove {target} from SSH client list?"):
            return
        proc = _run("ssh", "client", "delete", host)
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if proc.returncode != 0:
            error(self, "Remove", out or "delete failed")
            return
        if get_active_target() == target:
            self._use_local()
        else:
            self.reload()
            win = self.window()
            bar = win.findChild(TargetBar) if win is not None else None
            if isinstance(bar, TargetBar):
                bar.reload_hosts()


def create_page() -> QWidget:
    return HostsPage()


Page = HostsPage
