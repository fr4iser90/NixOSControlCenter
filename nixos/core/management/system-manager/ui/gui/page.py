"""System — status overview; sync prefs + target in Settings modal."""

from __future__ import annotations

import json
import socket
from pathlib import Path

from PySide6.QtCore import QProcess, QSettings, QTimer
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import build_ncc_argv, run_ncc, target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.theme import APP_STYLE

_SETTINGS_ORG = "NixOSControlCenter"
_SETTINGS_APP = "ncc-gui"
_KEY_LOCAL = "system/localNixosPath"
_KEY_BRANCH = "system/remoteBranch"
_KEY_AUTO_BUILD = "system/autoBuild"
_KEY_WITH_CHANNELS = "system/withChannels"


def _default_local_nixos() -> str:
    home = Path.home()
    candidate = home / "Documents" / "Git" / "NixOSControlCenter" / "nixos"
    return str(candidate)


def _parse_release_json(raw: str) -> dict[str, str]:
    empty = {
        "channel": "—",
        "current": "—",
        "latest": "—",
        "running": "—",
        "status": "unknown",
    }
    if not (raw or "").strip():
        return empty
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return empty
    return {
        "channel": str(data.get("channel") or "—"),
        "current": str(data.get("current") or "—"),
        "latest": str(data.get("latest") or "—"),
        "running": str(data.get("running") or "—") or "—",
        "status": str(data.get("status") or "unknown"),
    }


def _release_badge(status: str) -> str:
    if status == "update-available":
        return "update available"
    if status == "current":
        return "up to date"
    return status or "—"


def _load_system_status() -> dict:
    """``ncc system status --json`` — config facade (monolith or split)."""
    proc = run_ncc(
        "system",
        "status",
        "--json",
        target=target_from_env(),
        timeout=45,
    )
    raw = (proc.stdout or "").strip()
    if proc.returncode != 0 or not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


class SystemSettingsDialog(QDialog):
    """Sync preferences for From local / GitHub / Channels (Target = shell bar)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("System settings")
        self.setStyleSheet(APP_STYLE)
        self.resize(520, 280)
        self._settings = QSettings(_SETTINGS_ORG, _SETTINGS_APP)

        root = QVBoxLayout(self)

        sync_box = QGroupBox("Sync preferences")
        form = QFormLayout(sync_box)
        sync_tip = QLabel(
            "Used by From local repo / From GitHub / Channels only. "
            "Host Target stays in the bar at the top of the window."
        )
        sync_tip.setObjectName("nccPageSubtitle")
        sync_tip.setWordWrap(True)
        form.addRow(sync_tip)

        self.local_path = QLineEdit(
            str(self._settings.value(_KEY_LOCAL, _default_local_nixos()))
        )
        self.local_path.setPlaceholderText("…/NixOSControlCenter/nixos")
        form.addRow("Local repo path", self.local_path)

        self.branch = QComboBox()
        self.branch.setEditable(True)
        for b in ("main", "develop", "experimental"):
            self.branch.addItem(b)
        self.branch.setCurrentText(str(self._settings.value(_KEY_BRANCH, "main")))
        form.addRow("GitHub branch", self.branch)

        opts = QHBoxLayout()
        self.auto_build = QCheckBox("Build && switch after sync")
        self.auto_build.setChecked(
            bool(self._settings.value(_KEY_AUTO_BUILD, True, type=bool))
        )
        self.with_channels = QCheckBox("Also bump channels when newer")
        self.with_channels.setChecked(
            bool(self._settings.value(_KEY_WITH_CHANNELS, False, type=bool))
        )
        opts.addWidget(self.auto_build)
        opts.addWidget(self.with_channels)
        opts.addStretch(1)
        opts_w = QWidget()
        opts_w.setLayout(opts)
        form.addRow(opts_w)
        root.addWidget(sync_box)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        buttons.rejected.connect(self.reject)
        buttons.accepted.connect(self.accept)
        close_btn = buttons.button(QDialogButtonBox.StandardButton.Close)
        if close_btn is not None:
            close_btn.clicked.connect(self.accept)
        root.addWidget(buttons)

    def persist(self) -> None:
        self._settings.setValue(_KEY_LOCAL, self.local_path.text().strip())
        self._settings.setValue(_KEY_BRANCH, self.branch.currentText().strip() or "main")
        self._settings.setValue(_KEY_AUTO_BUILD, self.auto_build.isChecked())
        self._settings.setValue(_KEY_WITH_CHANNELS, self.with_channels.isChecked())
        self._settings.sync()

    def sync_values(self) -> dict:
        self.persist()
        return {
            "local_path": self.local_path.text().strip(),
            "branch": self.branch.currentText().strip() or "main",
            "auto_build": self.auto_build.isChecked(),
            "with_channels": self.with_channels.isChecked(),
        }


class SystemPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "System",
            "Machine overview. Sync preferences are in the header settings.",
            activity_max_height=None,
            parent=parent,
        )
        self._settings = QSettings(_SETTINGS_ORG, _SETTINGS_APP)
        self._release_proc: QProcess | None = None
        # In-memory copy of sync prefs (edited in Settings modal)
        self._local_path = str(self._settings.value(_KEY_LOCAL, _default_local_nixos()))
        self._branch = str(self._settings.value(_KEY_BRANCH, "main"))
        self._auto_build = bool(self._settings.value(_KEY_AUTO_BUILD, True, type=bool))
        self._with_channels = bool(
            self._settings.value(_KEY_WITH_CHANNELS, False, type=bool)
        )

        self.add_header_action(self._open_settings, tooltip="Sync preferences")

        status = self.add_form_block("Status")
        self.lbl_target = QLabel("—")
        self.lbl_host = QLabel("—")
        self.lbl_nixos = QLabel("—")
        self.lbl_latest = QLabel("—")
        self.lbl_channel = QLabel("—")
        self.lbl_release = QLabel("—")
        self.lbl_running = QLabel("—")
        self.lbl_config_ver = QLabel("—")
        self.lbl_system_type = QLabel("—")
        self.lbl_layout = QLabel("—")
        self.lbl_checks = QLabel("—")
        for w in (
            self.lbl_target,
            self.lbl_host,
            self.lbl_nixos,
            self.lbl_latest,
            self.lbl_channel,
            self.lbl_release,
            self.lbl_running,
            self.lbl_config_ver,
            self.lbl_system_type,
            self.lbl_layout,
            self.lbl_checks,
        ):
            w.setWordWrap(True)
            w.setObjectName("nccPageSubtitle")
        status.addRow("Target", self.lbl_target)
        status.addRow("Hostname", self.lbl_host)
        status.addRow("NixOS pin", self.lbl_nixos)
        status.addRow("Latest stable", self.lbl_latest)
        status.addRow("Channel", self.lbl_channel)
        status.addRow("Release status", self.lbl_release)
        status.addRow("Running", self.lbl_running)
        status.addRow("Config version", self.lbl_config_ver)
        status.addRow("System type", self.lbl_system_type)
        status.addRow("Config layout", self.lbl_layout)
        status.addRow("Preflight checks", self.lbl_checks)

        self.add_actions_hint(
            "Sync / rebuild need administrator rights. "
            "Check versions & validate write to Activity only."
        )
        self.add_action("Refresh status", self.reload)
        self.add_action("From local repo", lambda: self._start_sync("local"), primary=True)
        self.add_action("From GitHub", lambda: self._start_sync("remote"))
        self.add_action("Channels only", lambda: self._start_sync("channels"))
        self.add_action(
            "Check versions",
            lambda: self._run_quick(("check-versions",), "Check versions", False),
        )
        self.add_action(
            "Validate config",
            lambda: self._run_quick(("validate-config",), "Validate config", False),
        )
        self.add_action(
            "System report",
            lambda: self._run_quick(("report",), "System report", False),
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

        target_bus().changed.connect(lambda _t: self.reload())
        QTimer.singleShot(0, self.reload)

    def _open_settings(self) -> None:
        dlg = SystemSettingsDialog(self)
        dlg.exec()
        vals = dlg.sync_values()
        self._local_path = vals["local_path"]
        self._branch = vals["branch"]
        self._auto_build = vals["auto_build"]
        self._with_channels = vals["with_channels"]

    def reload(self) -> None:
        t = target_from_env()
        self.lbl_target.setText(t or "This machine")

        meta = _load_system_status()
        if meta:
            host = str(meta.get("hostname") or "").strip()
            self.lbl_host.setText(host or self._local_hostname())
            self.lbl_config_ver.setText(str(meta.get("configVersion") or "—"))
            self.lbl_system_type.setText(str(meta.get("systemType") or "—"))
            self.lbl_layout.setText(str(meta.get("layout") or "—"))
            checks = meta.get("enableChecks")
            if checks is True:
                self.lbl_checks.setText("on")
            elif checks is False:
                self.lbl_checks.setText("off")
            else:
                self.lbl_checks.setText("—")
            ch = str(meta.get("channel") or "").strip()
            if ch and ch != "—":
                self.lbl_channel.setText(ch)
        else:
            self.lbl_host.setText(self._local_hostname())
            self.lbl_config_ver.setText("—")
            self.lbl_system_type.setText("—")
            self.lbl_layout.setText("—")
            self.lbl_checks.setText("—")
            # Until rebuild installs `ncc system status`
            if not t:
                self.lbl_config_ver.setText("(needs rebuild: ncc system status)")

        self.lbl_nixos.setText("…")
        self.lbl_latest.setText("…")
        if not (meta.get("channel") if meta else None):
            self.lbl_channel.setText("…")
        self.lbl_release.setText("checking…")
        self.lbl_running.setText("…")
        self._start_release_probe()

        note = f"Status probes follow Target ({t}). " if t else ""
        self.set_subtitle(
            f"{note}Header settings = sync prefs only. "
            "Sync actions always run on this machine."
        )

    @staticmethod
    def _local_hostname() -> str:
        try:
            return socket.gethostname()
        except OSError:
            return "—"

    def _start_release_probe(self) -> None:
        if self._release_proc is not None:
            if self._release_proc.state() != QProcess.ProcessState.NotRunning:
                self._release_proc.kill()
            self._release_proc = None

        argv = build_ncc_argv(
            ("system", "check-release", "--json", "--quiet"),
            target=target_from_env(),
        )
        proc = QProcess(self)
        self._release_proc = proc
        proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        proc.finished.connect(self._on_release_finished)
        prog, *args = argv
        proc.start(prog, args)
        if not proc.waitForStarted(3000):
            self.lbl_release.setText("probe failed to start")
            self.lbl_nixos.setText("—")
            self.lbl_latest.setText("—")
            self.lbl_running.setText("—")
            self._release_proc = None

    def _on_release_finished(self, code: int, _status) -> None:
        proc = self._release_proc
        self._release_proc = None
        if proc is None:
            return
        raw = bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        if code not in (0, 10) and not (raw or "").strip():
            self.lbl_nixos.setText("—")
            self.lbl_latest.setText("—")
            self.lbl_release.setText("probe failed")
            self.lbl_running.setText("—")
            return
        rel = _parse_release_json(raw)
        pin = rel["current"]
        latest = rel["latest"]
        self.lbl_nixos.setText(f"nixos-{pin}" if pin != "—" else "—")
        self.lbl_latest.setText(f"nixos-{latest}" if latest != "—" else "—")
        if self.lbl_channel.text() in ("…", "—", ""):
            self.lbl_channel.setText(rel["channel"])
        self.lbl_release.setText(_release_badge(rel["status"]))
        running = rel["running"]
        self.lbl_running.setText(running if running and running != "—" else "—")

    def _start_sync(self, mode: str) -> None:
        if self.set_busy():
            return
        if mode == "local":
            path = self._local_path
            if not path or not Path(path).is_dir():
                error(
                    self,
                    "Local update",
                    f"Directory not found:\n{path}\n\nSet the path in Settings.",
                )
                return
            summary = f"Copy from local tree:\n{path}"
        elif mode == "remote":
            summary = f"Clone GitHub NixOSControlCenter @ {self._branch}"
        else:
            summary = "Update flake channels / inputs only"

        build = self._auto_build
        extra = "Then build & switch." if build else "No rebuild (copy/channels only)."
        if not confirm(
            self,
            "System update",
            f"{summary}\n\n{extra}\n\nThis changes /etc/nixos. Continue?",
        ):
            return

        args = ["system", "update", "--yes", f"--{mode}"]
        if mode == "local":
            args += ["--source-dir", self._local_path]
        if mode == "remote":
            args += ["--branch", self._branch]
        if self._with_channels and mode in ("local", "remote"):
            args.append("--with-channels")
        if build:
            args.append("--auto-build")

        def _done(code: int) -> None:
            if code == 0:
                info(self, f"system update ({mode})", "Finished successfully.")
                self.reload()

        self.run_ncc_root(args, label=f"system update ({mode})", on_done=_done)

    def _run_quick(self, args: tuple[str, ...], label: str, need_confirm: bool) -> None:
        if self.set_busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if need_confirm and not confirm(self, label, f"Run “{label}” on {where}?"):
            return

        if args[:1] in (("build",), ("allow-unfree",)) and not t:
            self.run_ncc_root(
                ["system", *args],
                label=label,
                on_done=lambda c: self.reload() if c == 0 else None,
            )
            return

        timeout = 3600 if args[:1] == ("build",) else 180
        proc = self.run_ncc(
            "system",
            *args,
            follow_target=True,
            timeout=timeout,
            need_confirm=None,
        )
        if args == ("config-layout", "detect") and proc.returncode == 0:
            for line in reversed((proc.stdout or "").strip().splitlines()):
                tline = line.strip().strip('"')
                if tline in ("monolith", "split", "none"):
                    self.lbl_layout.setText(tline)
                    break


def create_page(parent=None) -> SystemPage:
    return SystemPage(parent)


Page = SystemPage
