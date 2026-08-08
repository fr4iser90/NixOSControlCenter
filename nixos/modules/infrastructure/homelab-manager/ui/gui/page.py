"""Homelab — DomainPage kit (Swarm / stacks via Target)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QListWidgetItem, QVBoxLayout

from ncc_gui.ansi import strip_ansi
from ncc_gui.remote import target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus


class HomelabPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Homelab",
            "Docker Swarm and stacks. Use the top Target bar to run on your server "
            "(shared modules, different systemConfig).",
            parent=parent,
        )
        status_box = self.add_block("Status")
        sl = QVBoxLayout(status_box)
        self.status = QLabel("—")
        self.status.setObjectName("nccPageSubtitle")
        self.status.setWordWrap(True)
        sl.addWidget(self.status)

        _, self.stacks = self.add_list_block("Stacks")

        self.add_action("Refresh", self.reload, primary=True)
        self.add_action(
            "Init Swarm",
            lambda: self._run(("init-swarm",), "Init Swarm", confirm=True),
        )

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        st = self.run_ncc("homelab", "status", follow_target=True, log=False, show_error=False)
        text = strip_ansi(((st.stdout or "") + (st.stderr or "")).strip())
        self.status.setText(text or "(no status)")
        ls = self.run_ncc(
            "homelab", "list-stacks", follow_target=True, log=False, show_error=False
        )
        self.stacks.clear()
        out = (ls.stdout or "") + (ls.stderr or "")
        for line in out.splitlines():
            line = line.strip()
            if not line or line.lower().startswith("name") or "docker stacks" in line.lower():
                continue
            name = line.split()[0] if line.split() else line
            if name.startswith("[") or name.startswith("==="):
                continue
            item = QListWidgetItem(line)
            item.setData(Qt.ItemDataRole.UserRole, name)
            self.stacks.addItem(item)
        if ls.returncode != 0 and self.stacks.count() == 0:
            self.stacks.addItem(QListWidgetItem(out.strip() or "Cannot list stacks"))

    def _run(self, args: tuple[str, ...], label: str, *, confirm: bool = False) -> None:
        need = label if confirm else None
        self.run_ncc("homelab", *args, follow_target=True, need_confirm=need)
        self.reload()


def create_page() -> HomelabPage:
    return HomelabPage()


Page = HomelabPage
