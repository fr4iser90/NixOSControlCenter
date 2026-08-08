"""System — DomainPage kit (config sync, rebuild, health)."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtWidgets import QCheckBox, QComboBox, QHBoxLayout, QLabel, QLineEdit, QWidget

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus


def _default_local_nixos() -> str:
    home = Path.home()
    candidate = home / "Documents" / "Git" / "NixOSControlCenter" / "nixos"
    return str(candidate)


class SystemPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "System",
            "",
            activity_max_height=None,
            parent=parent,
        )

        tip = QLabel(
            "Same as `ncc system update`: copy modules into /etc/nixos "
            "(preserves systemConfig + hardware-configuration), optional rebuild."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)

        form = self.add_form_block("Update configuration")
        form.addRow(tip)
        self.local_path = QLineEdit(_default_local_nixos())
        self.local_path.setPlaceholderText("…/NixOSControlCenter/nixos")
        form.addRow("Local source", self.local_path)
        self.branch = QComboBox()
        self.branch.setEditable(True)
        for b in ("main", "develop", "experimental"):
            self.branch.addItem(b)
        form.addRow("Remote branch", self.branch)

        opts = QHBoxLayout()
        self.auto_build = QCheckBox("Build & switch after update")
        self.auto_build.setChecked(True)
        self.with_channels = QCheckBox("Also bump channels when newer")
        opts.addWidget(self.auto_build)
        opts.addWidget(self.with_channels)
        opts.addStretch(1)
        opts_w = QWidget()
        opts_w.setLayout(opts)
        form.addRow(opts_w)

        self.add_actions_hint("Config sync always runs on this machine and needs root.")
        self.add_action("From local repo", lambda: self._start_sync("local"), primary=True)
        self.add_action("From GitHub", lambda: self._start_sync("remote"))
        self.add_action("Channels only", lambda: self._start_sync("channels"))
        self.add_action("System report", lambda: self._run_quick(("report",), "System report", False))
        self.add_action(
            "Check versions",
            lambda: self._run_quick(("check-versions",), "Check versions", False),
        )
        self.add_action(
            "Validate config",
            lambda: self._run_quick(("validate-config",), "Validate config", False),
        )
        self.add_action(
            "Rebuild only",
            lambda: self._run_quick(("build", "switch"), "Rebuild only", True),
        )
        self.add_action(
            "Config layout",
            lambda: self._run_quick(("config-layout", "detect"), "Config layout", False),
        )
        self.add_action(
            "Allow unfree",
            lambda: self._run_quick(("allow-unfree",), "Allow unfree", True),
        )

        target_bus().changed.connect(lambda _t: self._refresh_subtitle())
        self._refresh_subtitle()

    def _refresh_subtitle(self) -> None:
        t = target_from_env()
        note = f"Status actions follow Target ({t}). " if t else ""
        self.set_subtitle(
            f"{note}Config sync (local/remote/channels) always runs on this machine "
            "and requires administrator rights."
        )

    def _start_sync(self, mode: str) -> None:
        if self.set_busy():
            return
        if mode == "local":
            path = self.local_path.text().strip()
            if not path or not Path(path).is_dir():
                error(self, "Local update", f"Directory not found:\n{path}")
                return
            summary = f"Copy from local tree:\n{path}"
        elif mode == "remote":
            branch = self.branch.currentText().strip() or "main"
            summary = f"Clone GitHub NixOSControlCenter @ {branch}"
        else:
            summary = "Update flake channels / inputs only"

        build = self.auto_build.isChecked()
        extra = "Then build & switch." if build else "No rebuild (copy/channels only)."
        if not confirm(
            self,
            "System update",
            f"{summary}\n\n{extra}\n\nThis changes /etc/nixos. Continue?",
        ):
            return

        args = ["system", "update", "--yes", f"--{mode}"]
        if mode == "local":
            args += ["--source-dir", self.local_path.text().strip()]
        if mode == "remote":
            args += ["--branch", self.branch.currentText().strip() or "main"]
        if self.with_channels.isChecked() and mode in ("local", "remote"):
            args.append("--with-channels")
        if build:
            args.append("--auto-build")

        def _done(code: int) -> None:
            if code == 0:
                info(self, f"system update ({mode})", "Finished successfully.")

        self.run_ncc_root(args, label=f"system update ({mode})", on_done=_done)

    def _run_quick(self, args: tuple[str, ...], label: str, need_confirm: bool) -> None:
        if self.set_busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if need_confirm and not confirm(self, label, f"Run “{label}” on {where}?"):
            return

        if args[:1] == ("build",) and not t:
            if not confirm(self, label, "Run nixos-rebuild (via ncc system build) as root?"):
                return
            self.run_ncc_root(["system", *args], label=label)
            return

        timeout = 3600 if args[:1] == ("build",) else 180
        self.run_ncc(
            "system",
            *args,
            follow_target=True,
            timeout=timeout,
            need_confirm=None,
        )


def create_page(parent=None) -> SystemPage:
    return SystemPage(parent)


Page = SystemPage
