"""System domain — config sync (local/remote/channels), rebuild, health."""

from __future__ import annotations

import shutil
from pathlib import Path

from PySide6.QtCore import QProcess, QProcessEnvironment
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import run_ncc, target_from_env
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE


def _default_local_nixos() -> str:
    home = Path.home()
    candidate = home / "Documents" / "Git" / "NixOSControlCenter" / "nixos"
    if candidate.is_dir():
        return str(candidate)
    return str(candidate)


def _ncc_bin() -> str:
    return shutil.which("ncc") or "ncc"


class SystemPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        self._proc: QProcess | None = None

        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)

        title = QLabel("System")
        title.setObjectName("nccPageTitle")
        root.addWidget(title)
        self.sub = QLabel()
        self.sub.setObjectName("nccPageSubtitle")
        self.sub.setWordWrap(True)
        root.addWidget(self.sub)

        # --- Config update (the real system-update flow) ---
        sync = QGroupBox("Update configuration")
        sl = QVBoxLayout(sync)
        tip = QLabel(
            "Same as `sudo ncc system update`: copy modules into /etc/nixos "
            "(preserves systemConfig + hardware-configuration), optional rebuild."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        sl.addWidget(tip)

        form = QFormLayout()
        self.local_path = QLineEdit(_default_local_nixos())
        self.local_path.setPlaceholderText("…/NixOSControlCenter/nixos")
        form.addRow("Local source", self.local_path)
        self.branch = QComboBox()
        self.branch.setEditable(True)
        for b in ("main", "develop", "experimental"):
            self.branch.addItem(b)
        form.addRow("Remote branch", self.branch)
        sl.addLayout(form)

        opts = QHBoxLayout()
        self.auto_build = QCheckBox("Build & switch after update")
        self.auto_build.setChecked(True)
        self.with_channels = QCheckBox("Also bump channels when newer")
        opts.addWidget(self.auto_build)
        opts.addWidget(self.with_channels)
        opts.addStretch(1)
        sl.addLayout(opts)

        row = QHBoxLayout()
        for label, mode in (
            ("From local repo", "local"),
            ("From GitHub", "remote"),
            ("Channels only", "channels"),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, m=mode: self._start_sync(m))
            row.addWidget(btn)
        row.addStretch(1)
        sl.addLayout(row)
        root.addWidget(sync)

        # --- Status / helpers ---
        status_box = QGroupBox("Status & checks")
        st = QHBoxLayout(status_box)
        for label, args in (
            ("System report", ("report",)),
            ("Check versions", ("check-versions",)),
            ("Validate config", ("validate-config",)),
            ("Rebuild only", ("build", "switch")),
        ):
            need = label == "Rebuild only"
            btn = QPushButton(label)
            btn.clicked.connect(
                lambda _=False, a=args, lab=label, c=need: self._run_quick(a, lab, c)
            )
            st.addWidget(btn)
        st.addStretch(1)
        root.addWidget(status_box)

        extra = QGroupBox("Config helpers")
        el = QHBoxLayout(extra)
        for label, args, need in (
            ("Config layout", ("config-layout", "detect"), False),
            ("Allow unfree", ("allow-unfree",), True),
        ):
            btn = QPushButton(label)
            btn.clicked.connect(
                lambda _=False, a=args, lab=label, c=need: self._run_quick(a, lab, c)
            )
            el.addWidget(btn)
        el.addStretch(1)
        root.addWidget(extra)

        self.log = QTextEdit()
        self.log.setObjectName("nccActivityLog")
        self.log.setReadOnly(True)
        root.addWidget(self.log, stretch=1)

        target_bus().changed.connect(lambda _t: self._refresh_subtitle())
        self._refresh_subtitle()

    def _refresh_subtitle(self) -> None:
        t = target_from_env()
        note = (
            f"Status actions follow Target ({t}). "
            if t
            else ""
        )
        self.sub.setText(
            f"{note}Config sync (local/remote/channels) always runs on this machine "
            "and needs root (pkexec/sudo)."
        )

    def _busy(self) -> bool:
        if self._proc is not None and self._proc.state() != QProcess.ProcessState.NotRunning:
            error(self, "Busy", "An update is already running.")
            return True
        return False

    def _start_sync(self, mode: str) -> None:
        if self._busy():
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

        build = self.auto_build.isChecked() and mode != "channels"
        # channels path has its own flow; still allow --auto-build if checked
        if mode == "channels":
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

        self._launch_root(args, f"system update ({mode})")

    def _launch_root(self, ncc_args: list[str], label: str) -> None:
        ncc = _ncc_bin()
        # Prefer pkexec (GUI auth); fall back to sudo -n
        if shutil.which("pkexec"):
            program = "pkexec"
            argv = [ncc, *ncc_args]
        elif shutil.which("sudo"):
            program = "sudo"
            argv = ["-n", ncc, *ncc_args]
        else:
            error(self, label, "Need pkexec or sudo to run system update as root.")
            return

        self.log.append(f"• {label}\n$ {program} {' '.join(argv)}\n")
        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._on_proc_out)
        self._proc.finished.connect(
            lambda code, _status, lab=label: self._on_proc_done(code, lab)
        )
        self._proc.setProcessEnvironment(QProcessEnvironment.systemEnvironment())
        self._proc.start(program, argv)
        if not self._proc.waitForStarted(5000):
            error(self, label, "Failed to start update process.")
            self._proc = None

    def _on_proc_out(self) -> None:
        if self._proc is None:
            return
        data = bytes(self._proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        if data:
            # QTextEdit is not a terminal — strip CLI-formatter ANSI codes
            plain = strip_ansi(data)
            self.log.moveCursor(self.log.textCursor().MoveOperation.End)
            self.log.insertPlainText(plain)
            self.log.moveCursor(self.log.textCursor().MoveOperation.End)

    def _on_proc_done(self, code: int, label: str) -> None:
        self.log.append(f"\n[{label}] exit {code}\n")
        if code != 0:
            error(self, label, f"Finished with exit code {code}. See activity log.")
        else:
            info(self, label, "Finished successfully.")
        self._proc = None

    def _run_quick(self, args: tuple[str, ...], label: str, need_confirm: bool) -> None:
        if self._busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if need_confirm and not confirm(self, label, f"Run “{label}” on {where}?"):
            return

        # Rebuild needs root on this machine
        if args[:1] == ("build",) and not t:
            build_args = ["system", *args]
            if not confirm(
                self,
                label,
                "Run nixos-rebuild (via ncc system build) as root?",
            ):
                return
            self._launch_root(build_args, label)
            return

        timeout = 3600 if args[:1] == ("build",) else 180
        try:
            proc = run_ncc("system", *args, target=t, timeout=timeout)
        except Exception as exc:  # noqa: BLE001
            error(self, label, str(exc))
            self.log.append(f"• {label}\n{exc}\n")
            return
        out = strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
        pretty = out or ("Done." if proc.returncode == 0 else "Failed.")
        self.log.append(f"• {label} ({where})\n{pretty}\n")
        if proc.returncode != 0:
            error(self, label, pretty)


def create_page(parent=None) -> QWidget:
    return SystemPage(parent)


Page = SystemPage
