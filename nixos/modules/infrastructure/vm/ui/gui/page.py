"""VM — DomainPage kit (libvirt domains via Target)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QListWidgetItem, QVBoxLayout

from ncc_gui.dialogs import confirm
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus


@dataclass(frozen=True)
class DomainRow:
    name: str
    state: str


class VmPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Virtual machines",
            "Libvirt domains. Use the top Target bar to manage VMs on a remote NCC host.",
            parent=parent,
        )
        self._selected: DomainRow | None = None

        _, self.list = self.add_list_block("Domains")
        self.list.currentItemChanged.connect(self._on_select)

        detail_box = self.add_block("Selected")
        dl = QVBoxLayout(detail_box)
        self.detail = QLabel("Select a domain")
        self.detail.setObjectName("nccPageSubtitle")
        self.detail.setWordWrap(True)
        dl.addWidget(self.detail)

        self.add_action("Start", lambda: self._dom("start"), primary=True)
        self.add_action("Shutdown", lambda: self._dom("stop"))
        self.add_action("Force off", lambda: self._dom("destroy"))
        self.add_action("Refresh", self.reload)
        self.add_action("Full status", lambda: self._run(("status",), "Full status"))
        self.add_action("Test distros", lambda: self._run(("list",), "Test distros"))

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        current = self._selected.name if self._selected else None
        self.list.clear()
        proc = self.run_ncc("vm", "domains", follow_target=True, log=False, show_error=False)
        rows: list[DomainRow] = []
        for line in (proc.stdout or "").splitlines():
            line = line.strip()
            if not line or "=" not in line:
                continue
            name, state = line.split("=", 1)
            name, state = name.strip(), state.strip()
            if name:
                rows.append(DomainRow(name=name, state=state or "?"))
        pick = None
        for row in rows:
            item = QListWidgetItem(f"{row.name}  [{row.state}]")
            item.setData(Qt.ItemDataRole.UserRole, row)
            self.list.addItem(item)
            if current and row.name == current:
                pick = item
        if pick:
            self.list.setCurrentItem(pick)
        elif self.list.count():
            self.list.setCurrentRow(0)
        else:
            self._selected = None
            self.detail.setText("No domains (is libvirt running?)")

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            self._selected = None
            return
        row = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(row, DomainRow):
            return
        self._selected = row
        self.detail.setText(f"{row.name}\nState: {row.state}")

    def _dom(self, verb: str) -> None:
        if not self._selected:
            return
        name = self._selected.name
        need = verb if verb in ("stop", "destroy") else None
        if need and not confirm(self, verb, f"{verb} domain “{name}”?"):
            return
        self.run_ncc("vm", verb, name, follow_target=True)
        self.reload()

    def _run(self, args: tuple[str, ...], label: str) -> None:
        self.run_ncc("vm", *args, follow_target=True)


def create_page() -> VmPage:
    return VmPage()


Page = VmPage
