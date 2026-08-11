"""Homelab — DomainPage kit (overview, containers, ports, domains, stacks)."""

from __future__ import annotations

import json

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QListWidgetItem, QVBoxLayout

from ncc_gui.ansi import strip_ansi
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus


class HomelabPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Homelab",
            "Docker overview on the selected Target: status, containers, "
            "published ports, domains, and Swarm stacks.",
            parent=parent,
        )

        ov = self.add_form_block("Overview")
        self.ov_docker = QLabel("—")
        self.ov_swarm = QLabel("—")
        self.ov_role = QLabel("—")
        self.ov_domain = QLabel("—")
        self.ov_email = QLabel("—")
        self.ov_virt = QLabel("—")
        ov.addRow("Docker", self.ov_docker)
        ov.addRow("Swarm", self.ov_swarm)
        ov.addRow("Swarm role", self.ov_role)
        ov.addRow("Domain", self.ov_domain)
        ov.addRow("Email", self.ov_email)
        ov.addRow("Virt user", self.ov_virt)

        _, self.containers = self.add_list_block("Containers")
        _, self.ports = self.add_list_block("Ports")
        _, self.domains = self.add_list_block("Domains")
        _, self.stacks = self.add_list_block("Stacks")

        detail_box = self.add_block("Selected")
        dl = QVBoxLayout(detail_box)
        self.detail = QLabel("Select a row for details")
        self.detail.setObjectName("nccPageSubtitle")
        self.detail.setWordWrap(True)
        dl.addWidget(self.detail)

        self.containers.currentItemChanged.connect(self._on_select)
        self.ports.currentItemChanged.connect(self._on_select)
        self.domains.currentItemChanged.connect(self._on_select)
        self.stacks.currentItemChanged.connect(self._on_select)

        self.add_action("Refresh", self.reload, primary=True)
        self.add_action(
            "Init Swarm",
            lambda: self._run(("init-swarm",), "Init Swarm", confirm=True),
        )

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        self._load_overview()
        self._fill_pipe_list(
            self.containers,
            "list-containers",
            empty="No containers",
            fmt=self._fmt_container,
        )
        self._fill_pipe_list(
            self.ports,
            "list-ports",
            empty="No published ports",
            fmt=self._fmt_port,
        )
        self._fill_pipe_list(
            self.domains,
            "list-domains",
            empty="No domains found",
            fmt=self._fmt_domain,
        )
        self._load_stacks()
        self.detail.setText("Select a row for details")

    def _load_overview(self) -> None:
        st = self.run_ncc(
            "homelab", "status", "--json", follow_target=True, log=False, show_error=False
        )
        raw = (st.stdout or "").strip()
        if st.returncode != 0 or not raw:
            text = strip_ansi(((st.stdout or "") + (st.stderr or "")).strip())
            self.ov_docker.setText(text or "(status unavailable)")
            for w in (self.ov_swarm, self.ov_role, self.ov_domain, self.ov_email, self.ov_virt):
                w.setText("—")
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            self.ov_docker.setText("Invalid status JSON")
            return

        installed = bool(data.get("docker_installed"))
        running = bool(data.get("docker_running"))
        if not installed:
            docker = "Not installed"
        elif running:
            docker = "Running"
        else:
            docker = "Installed, daemon down"
        self.ov_docker.setText(docker)
        self.ov_swarm.setText(str(data.get("swarm_status") or "—"))
        self.ov_role.setText(str(data.get("swarm_role") or "—") or "—")
        self.ov_domain.setText(str(data.get("domain") or "—") or "—")
        self.ov_email.setText(str(data.get("email") or "—") or "—")
        self.ov_virt.setText(str(data.get("virt_user") or "—") or "—")

    def _fill_pipe_list(self, widget, verb: str, *, empty: str, fmt) -> None:
        widget.clear()
        proc = self.run_ncc(
            "homelab", verb, follow_target=True, log=False, show_error=False
        )
        lines = [
            ln.strip()
            for ln in ((proc.stdout or "") + (proc.stderr or "")).splitlines()
            if ln.strip() and "|" in ln.strip()
        ]
        if proc.returncode != 0 and not lines:
            err = strip_ansi((proc.stderr or proc.stdout or empty).strip())
            widget.addItem(QListWidgetItem(err or empty))
            return
        if not lines:
            widget.addItem(QListWidgetItem(empty))
            return
        for line in lines:
            parts = line.split("|")
            label, detail = fmt(parts)
            item = QListWidgetItem(label)
            item.setData(Qt.ItemDataRole.UserRole, detail)
            widget.addItem(item)

    @staticmethod
    def _fmt_container(parts: list[str]) -> tuple[str, str]:
        name = parts[0] if len(parts) > 0 else "?"
        status = parts[1] if len(parts) > 1 else "?"
        image = parts[2] if len(parts) > 2 else ""
        ports = parts[3] if len(parts) > 3 else ""
        label = f"{name}  [{status}]"
        detail = f"Container: {name}\nStatus: {status}\nImage: {image}\nPorts: {ports or '—'}"
        return label, detail

    @staticmethod
    def _fmt_port(parts: list[str]) -> tuple[str, str]:
        # container|proto|host_ip|host_port|container_port
        name = parts[0] if len(parts) > 0 else "?"
        proto = parts[1] if len(parts) > 1 else "?"
        host_ip = parts[2] if len(parts) > 2 else ""
        host_port = parts[3] if len(parts) > 3 else "?"
        cport = parts[4] if len(parts) > 4 else "?"
        bind = f"{host_ip}:{host_port}" if host_ip else host_port
        label = f"{bind} → {name}:{cport}/{proto}"
        detail = (
            f"Container: {name}\n"
            f"Published: {bind}/{proto}\n"
            f"Container port: {cport}"
        )
        return label, detail

    @staticmethod
    def _fmt_domain(parts: list[str]) -> tuple[str, str]:
        source = parts[0] if len(parts) > 0 else "?"
        domain = parts[1] if len(parts) > 1 else "?"
        label = f"{domain}  ({source})"
        detail = f"Domain: {domain}\nSource: {source}"
        return label, detail

    def _load_stacks(self) -> None:
        self.stacks.clear()
        ls = self.run_ncc(
            "homelab", "list-stacks", follow_target=True, log=False, show_error=False
        )
        out = (ls.stdout or "") + (ls.stderr or "")
        for line in out.splitlines():
            line = line.strip()
            if not line or line.lower().startswith("name") or "docker stacks" in line.lower():
                continue
            name = line.split()[0] if line.split() else line
            if name.startswith("[") or name.startswith("==="):
                continue
            item = QListWidgetItem(line)
            item.setData(Qt.ItemDataRole.UserRole, f"Stack: {name}\n{line}")
            self.stacks.addItem(item)
        if ls.returncode != 0 and self.stacks.count() == 0:
            self.stacks.addItem(QListWidgetItem(out.strip() or "Cannot list stacks"))
        elif self.stacks.count() == 0:
            self.stacks.addItem(QListWidgetItem("No stacks (Swarm inactive or empty)"))

    def _on_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            return
        detail = current.data(Qt.ItemDataRole.UserRole)
        if isinstance(detail, str) and detail:
            self.detail.setText(detail)
        else:
            self.detail.setText(current.text())

    def _run(self, args: tuple[str, ...], label: str, *, confirm: bool = False) -> None:
        need = label if confirm else None
        self.run_ncc("homelab", *args, follow_target=True, need_confirm=need)
        self.reload()


def create_page() -> HomelabPage:
    return HomelabPage()


Page = HomelabPage
