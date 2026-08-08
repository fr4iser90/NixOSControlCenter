"""Hosts — DomainPage kit (fleet targets from SSH client list)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QLineEdit, QListWidgetItem

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bar import TargetBar
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_state import get_active_target, list_host_pairs, set_active_target


class HostsPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Hosts",
            "Fleet targets reuse the SSH client list (`~/.creds` / `ncc ssh client`). "
            "Activate a host to set the global Target bar.",
            parent=parent,
        )
        self.active = QLabel()
        self.active.setObjectName("nccPageSubtitle")
        self.add_content_widget(self.active)

        _, self.list = self.add_list_block("Saved hosts")
        self.list.itemDoubleClicked.connect(lambda _i: self._use())

        form = self.add_form_block("Add host")
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("hostname or IP")
        self.user_edit = QLineEdit()
        self.user_edit.setPlaceholderText("user")
        form.addRow("Host", self.host_edit)
        form.addRow("User", self.user_edit)

        self.add_action("Use as target", self._use, primary=True)
        self.add_action("This machine", self._use_local)
        self.add_action("Add (ssh client)", self._add)
        self.add_action("Remove", self._remove)
        self.add_action("Refresh", self.reload)

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
        proc = self.run_ncc("ssh", "client", "add", host, user)
        if proc.returncode != 0:
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
        proc = self.run_ncc("ssh", "client", "delete", host)
        if proc.returncode != 0:
            return
        if get_active_target() == target:
            self._use_local()
        else:
            self.reload()
            win = self.window()
            bar = win.findChild(TargetBar) if win is not None else None
            if isinstance(bar, TargetBar):
                bar.reload_hosts()


def create_page() -> HostsPage:
    return HostsPage()


Page = HostsPage
