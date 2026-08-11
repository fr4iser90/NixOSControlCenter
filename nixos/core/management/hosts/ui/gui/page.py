"""Hosts — DomainPage kit (fleet targets; SSH client list drafts → Apply)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QLineEdit, QListWidgetItem

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bar import TargetBar
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_state import get_active_target, list_host_pairs, set_active_target

_OP = "ssh-client"


class HostsPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Hosts",
            "Fleet targets reuse the SSH client list. "
            "Use as target Connects and probes that host. "
            "Add/Remove stage drafts — Apply writes.",
            parent=parent,
        )
        self._live: list[tuple[str, str]] = []
        self._selected_host: str | None = None

        self.active = QLabel()
        self.active.setObjectName("nccPageSubtitle")
        self.add_content_widget(self.active)

        _, self.list = self.add_list_block("Saved hosts")
        self.list.itemDoubleClicked.connect(lambda _i: self._use())
        self.list.currentItemChanged.connect(self._on_select)

        form = self.add_form_block("Add host")
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("hostname or IP")
        self.user_edit = QLineEdit()
        self.user_edit.setPlaceholderText("user")
        form.addRow("Host", self.host_edit)
        form.addRow("User", self.user_edit)

        self.add_actions_hint(
            "Add/Remove stage the SSH client list (Apply writes). "
            "Target activation is immediate and does not need Apply."
        )
        self.add_action("Use as target", self._use)
        self.add_action("This machine", self._use_local)
        self.add_action("Add (ssh client)", self._add)
        self.add_action("Remove", self._remove)
        self.add_action("Refresh", self.reload)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._render_list)

        target_bus().changed.connect(lambda _t: self._refresh_active())
        self.reload()

    def _refresh_active(self) -> None:
        from ncc_gui.target_session import current_session

        s = current_session()
        if s.connected:
            self.active.setText(f"Connected: {s.connected}")
        elif s.candidate:
            self.active.setText(f"Selected (not connected): {s.candidate}")
        else:
            self.active.setText("Active target: This machine")

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

    def reload(self) -> None:
        self._live = list(list_host_pairs())
        self._render_list()
        self._refresh_active()

    def _render_list(self) -> None:
        current = self._selected_host
        self.list.clear()
        pending = self._pending_by_host()
        live_hosts = {h for h, _u in self._live}
        active = get_active_target()
        pick: QListWidgetItem | None = None

        for host, user in self._live:
            ch = pending.get(host)
            target = f"{user}@{host}"
            if ch is not None and ch.meta.get("action") == "delete":
                label = f"{target}  · pending delete"
                data_user = user
            elif ch is not None and ch.meta.get("action") in ("add", "edit"):
                data_user = str(ch.meta.get("user") or user)
                target = f"{data_user}@{host}"
                label = f"{target}  · pending {ch.meta.get('action')}"
            else:
                data_user = user
                label = target
            if active == f"{data_user}@{host}":
                label += "  ← active"
            item = QListWidgetItem(label)
            item.setData(
                Qt.ItemDataRole.UserRole,
                (host, data_user, f"{data_user}@{host}"),
            )
            self.list.addItem(item)
            if current and host == current:
                pick = item

        for host, ch in pending.items():
            if host in live_hosts:
                continue
            if ch.meta.get("action") != "add":
                continue
            user = str(ch.meta.get("user") or "")
            target = f"{user}@{host}"
            item = QListWidgetItem(f"{target}  · pending add")
            item.setData(Qt.ItemDataRole.UserRole, (host, user, target))
            self.list.addItem(item)
            if current and host == current:
                pick = item

        if self.list.count() == 0:
            self.list.addItem(
                QListWidgetItem("(no hosts — add below or via ncc ssh client)")
            )
            self._selected_host = None
        elif pick is not None:
            self.list.setCurrentItem(pick)
        else:
            self.list.setCurrentRow(0)
        self._refresh_active()

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            self._selected_host = None
            return
        data = current.data(Qt.ItemDataRole.UserRole)
        if isinstance(data, tuple) and len(data) == 3:
            self._selected_host = str(data[0])

    def _selected(self) -> tuple[str, str, str] | None:
        item = self.list.currentItem()
        if item is None:
            return None
        data = item.data(Qt.ItemDataRole.UserRole)
        if not isinstance(data, tuple) or len(data) != 3:
            return None
        return data  # type: ignore[return-value]

    def _sync_bar(self, target: str | None, *, connect: bool = False) -> None:
        from ncc_gui.target_session import session_controller

        win = self.window()
        bar = win.findChild(TargetBar) if win is not None else None
        if isinstance(bar, TargetBar):
            bar.reload_hosts()
            bar.set_target(target, emit=False)
        if connect and target:
            s = session_controller().connect_target(target)
            target_bus().changed.emit(s.connected)
            if isinstance(bar, TargetBar):
                bar.reload_hosts()
        elif target is None:
            session_controller().disconnect_target()
            target_bus().changed.emit(None)
        else:
            session_controller().set_candidate(target)
            set_active_target(None)
            target_bus().changed.emit(None)

    def _use(self) -> None:
        sel = self._selected()
        if not sel:
            error(self, "Use", "Select a host first.")
            return
        host, _user, target = sel
        pending = self._pending_by_host().get(host)
        if pending is not None and pending.meta.get("action") == "add":
            info(self, "Target", "Apply the pending add before using as target.")
            return
        if pending is not None and pending.meta.get("action") == "delete":
            info(self, "Target", "This host is marked for delete.")
            return
        self._sync_bar(target, connect=True)
        self._render_list()
        info(
            self,
            "Target",
            f"Connecting to {target}…\nWatch the Target bar status (not linked until probe finishes).",
        )

    def _use_local(self) -> None:
        self._sync_bar(None, connect=False)
        self._render_list()

    @staticmethod
    def _same_host(a: PendingChange, b: PendingChange) -> bool:
        return (
            a.meta.get("op") == b.meta.get("op") == _OP
            and a.meta.get("host") == b.meta.get("host")
        )

    def _add(self) -> None:
        host = self.host_edit.text().strip()
        user = self.user_edit.text().strip()
        if not host or not user:
            error(self, "Add", "Host and user required.")
            return
        if any(h == host for h, _u in self._live) or host in self._pending_by_host():
            error(self, "Add", f"Host already listed (live or draft): {host}")
            return
        assert self.commit is not None
        self.commit.stage_replace(
            PendingChange(
                summary=f"ssh client add {host} ({user})",
                argv=["ssh", "client", "add", host, user],
                elevated=False,
                meta={"op": _OP, "action": "add", "host": host, "user": user},
            ),
            same=self._same_host,
        )
        self.host_edit.clear()
        self.user_edit.clear()
        self._selected_host = host

    def _remove(self) -> None:
        sel = self._selected()
        if not sel:
            error(self, "Remove", "Select a host first.")
            return
        host, user, target = sel
        pending = self._pending_by_host().get(host)
        if pending is not None and pending.meta.get("action") == "add":
            if not confirm(self, "Discard draft?", f"Remove pending add for {target}?"):
                return
            assert self.commit is not None
            self.commit.discard_where(
                lambda c: c.meta.get("op") == _OP and c.meta.get("host") == host,
                log=f"• discarded draft add: {host}\n",
            )
            return
        if not confirm(
            self,
            "Remove",
            f"Mark {target} for remove (written on Apply)?",
        ):
            return
        assert self.commit is not None
        self.commit.stage_replace(
            PendingChange(
                summary=f"ssh client delete {host}",
                argv=["ssh", "client", "delete", host],
                elevated=False,
                meta={"op": _OP, "action": "delete", "host": host, "user": user},
            ),
            same=self._same_host,
        )

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        assert self.commit is not None
        summary = "; ".join(c.summary for c in changes)
        cleared_active = False
        active = get_active_target()
        for ch in changes:
            proc = self.run_ncc(*ch.argv, log=True, show_error=True)
            if proc.returncode != 0:
                return
            if ch.meta.get("action") == "delete":
                host = str(ch.meta.get("host") or "")
                user = str(ch.meta.get("user") or "")
                if active == f"{user}@{host}":
                    cleared_active = True
        self.commit.notify_apply_finished(True, summary, offer_rebuild=False)
        if cleared_active:
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
