"""Homelab domain — Docker/Swarm status & stacks via global Target."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error
from ncc_gui.remote import run_ncc, target_from_env
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE


class HomelabPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("Homelab")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel(
            "Docker Swarm and stacks. Use the top Target bar to run "
            "`ncc homelab` on your server (shared modules, different systemConfig)."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        row = QHBoxLayout()
        for label, args, need_confirm in (
            ("Status", ("status",), False),
            ("Refresh stacks", ("list-stacks",), False),
            ("Init Swarm", ("init-swarm",), True),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(
                lambda _=False, a=args, c=need_confirm, lab=label: self._run(a, c, lab)
            )
            row.addWidget(btn)
        row.addStretch(1)
        root.addLayout(row)

        self.status = QTextEdit()
        self.status.setObjectName("nccActivityLog")
        self.status.setReadOnly(True)
        self.status.setMaximumHeight(160)
        root.addWidget(self.status)

        box = QGroupBox("Stacks")
        bl = QVBoxLayout(box)
        self.stacks = QListWidget()
        bl.addWidget(self.stacks)
        root.addWidget(box, stretch=1)

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        t = target_from_env()
        st = run_ncc("homelab", "status", target=t)
        self.status.setPlainText(((st.stdout or "") + (st.stderr or "")).strip() or "(no status)")
        ls = run_ncc("homelab", "list-stacks", target=t)
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

    def _run(self, args: tuple[str, ...], need_confirm: bool, label: str) -> None:
        if need_confirm and not confirm(self, label, f"Run “{label}” on target?"):
            return
        proc = run_ncc("homelab", *args, target=target_from_env())
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        self.status.setPlainText(out or ("Done." if proc.returncode == 0 else "Failed."))
        if proc.returncode != 0:
            error(self, label, out or "Command failed.")
        if args[0] in ("status", "list-stacks", "init-swarm"):
            self.reload()


def create_page() -> QWidget:
    return HomelabPage()


Page = HomelabPage
