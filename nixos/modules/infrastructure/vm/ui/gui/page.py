"""VM domain — live libvirt domains + test distros (global Target)."""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import run_ncc, target_from_env
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE


@dataclass(frozen=True)
class DomainRow:
    name: str
    state: str


def load_domains(target: str | None) -> list[DomainRow]:
    proc = run_ncc("vm", "domains", target=target)
    rows: list[DomainRow] = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        name, state = line.split("=", 1)
        name, state = name.strip(), state.strip()
        if name:
            rows.append(DomainRow(name=name, state=state or "?"))
    return rows


class VmPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        self._selected: DomainRow | None = None

        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)
        title = QLabel("Virtual machines")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        sub = QLabel(
            "Libvirt domains. Use the top Target bar to manage VMs on a remote NCC host."
        )
        sub.setObjectName("nccPageSubtitle")
        sub.setWordWrap(True)
        root.addWidget(sub)

        split = QSplitter(Qt.Orientation.Horizontal)
        root.addWidget(split, stretch=1)

        left = QWidget()
        ll = QVBoxLayout(left)
        ll.setContentsMargins(0, 0, 0, 0)
        ll.addWidget(QLabel("Domains"))
        self.list = QListWidget()
        self.list.currentItemChanged.connect(self._on_select)
        ll.addWidget(self.list, stretch=1)
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.reload)
        ll.addWidget(refresh)
        split.addWidget(left)

        right = QGroupBox("Actions")
        rl = QVBoxLayout(right)
        self.detail = QLabel("Select a domain")
        self.detail.setObjectName("nccPageSubtitle")
        rl.addWidget(self.detail)
        row = QHBoxLayout()
        self.start_btn = QPushButton("Start")
        self.start_btn.clicked.connect(lambda: self._dom("start"))
        self.stop_btn = QPushButton("Shutdown")
        self.stop_btn.clicked.connect(lambda: self._dom("stop"))
        self.destroy_btn = QPushButton("Force off")
        self.destroy_btn.clicked.connect(lambda: self._dom("destroy"))
        for b in (self.start_btn, self.stop_btn, self.destroy_btn):
            b.setEnabled(False)
            row.addWidget(b)
        row.addStretch(1)
        rl.addLayout(row)

        rl.addWidget(QLabel("Status / test distros"))
        tools = QHBoxLayout()
        for label, args in (
            ("Full status", ("status",)),
            ("Test distros", ("list",)),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, a=args, lab=label: self._run(a, lab))
            tools.addWidget(btn)
        tools.addStretch(1)
        rl.addLayout(tools)

        self.log = QTextEdit()
        self.log.setObjectName("nccActivityLog")
        self.log.setReadOnly(True)
        rl.addWidget(self.log, stretch=1)
        split.addWidget(right)
        split.setStretchFactor(0, 1)
        split.setStretchFactor(1, 2)

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        current = self._selected.name if self._selected else None
        self.list.clear()
        rows = load_domains(target_from_env())
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
            for b in (self.start_btn, self.stop_btn, self.destroy_btn):
                b.setEnabled(False)
        st = run_ncc("vm", "status", target=target_from_env())
        if not rows:
            self.log.setPlainText(((st.stdout or "") + (st.stderr or "")).strip())

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            self._selected = None
            return
        row = current.data(Qt.ItemDataRole.UserRole)
        if not isinstance(row, DomainRow):
            return
        self._selected = row
        self.detail.setText(f"{row.name}\nState: {row.state}")
        for b in (self.start_btn, self.stop_btn, self.destroy_btn):
            b.setEnabled(True)

    def _dom(self, verb: str) -> None:
        if not self._selected:
            return
        name = self._selected.name
        if verb in ("stop", "destroy") and not confirm(
            self, verb, f"{verb} domain “{name}”?"
        ):
            return
        proc = run_ncc("vm", verb, name, target=target_from_env())
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        self.log.append(f"• {verb} {name}\n{out}\n")
        if proc.returncode != 0:
            error(self, verb, out or "Failed")
        self.reload()

    def _run(self, args: tuple[str, ...], label: str) -> None:
        proc = run_ncc("vm", *args, target=target_from_env())
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        self.log.setPlainText(out or "(empty)")
        if proc.returncode != 0:
            info(self, label, out or "Failed")


def create_page() -> QWidget:
    return VmPage()


Page = VmPage
