"""System — status overview; sync prefs + target in Settings modal."""

from __future__ import annotations

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

from ncc_gui.ansi import strip_ansi
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.system_fs_status import (
    STATUS_SCRIPT,
    build_fs_status_argv,
    fetch_latest_stable_pin,
    parse_fs_status_stdout,
    release_from_fs,
)
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


def _release_badge(status: str) -> str:
    if status == "update-available":
        return "update available"
    if status == "current":
        return "up to date"
    if status == "pin from flake":
        return "from flake"
    return status or "—"


def _dash(value: object) -> str:
    s = str(value or "").strip()
    return s if s else "—"


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
            "Sync the NCC tree, migrate config, or rebuild. "
            "Gear (top right) opens sync preferences.",
            activity_max_height=180,
            parent=parent,
        )
        self._settings = QSettings(_SETTINGS_ORG, _SETTINGS_APP)
        self._local_path = str(self._settings.value(_KEY_LOCAL, _default_local_nixos()))
        self._branch = str(self._settings.value(_KEY_BRANCH, "main"))
        self._auto_build = bool(self._settings.value(_KEY_AUTO_BUILD, True, type=bool))
        self._with_channels = bool(
            self._settings.value(_KEY_WITH_CHANNELS, False, type=bool)
        )

        self.add_header_action(self._open_settings, tooltip="Sync preferences")

        status = self.add_form_block("Status")
        self.lbl_host = self.add_form_value(status, "Hostname")
        self.lbl_nixos = self.add_form_value(status, "NixOS pin")
        self.lbl_latest = self.add_form_value(status, "Latest stable")
        self.lbl_channel = self.add_form_value(status, "Channel")
        self.lbl_release = self.add_form_value(status, "Release status")
        self.lbl_running = self.add_form_value(status, "Running")
        self.lbl_config_ver = self.add_form_value(status, "Config version")
        self.lbl_system_type = self.add_form_value(status, "System type")
        self.lbl_layout = self.add_form_value(status, "Config layout")
        self.lbl_checks = self.add_form_value(status, "Preflight checks")

        self.add_actions_hint(
            "Sync / rebuild need administrator rights on the Target. "
            "Remote sync uses ssh + sudo -n on that host. "
            "Check versions & validate write to Activity only."
        )
        self.add_action("Refresh status", self.reload)
        self.add_action("From local repo", lambda: self._start_sync("local"), primary=True)
        self.add_action("From GitHub", lambda: self._start_sync("remote"))
        self.add_action("Channels only", lambda: self._start_sync("channels"))
        self.add_action(
            "Migrate config",
            lambda: self._run_quick(("migrate-config",), "Migrate config", True),
        )
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

        self._status_proc: QProcess | None = None
        self._reload_timer = QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.setInterval(150)
        self._reload_timer.timeout.connect(self._reload_now)

        target_bus().changed.connect(lambda _t: self._schedule_reload())
        QTimer.singleShot(0, self._schedule_reload)

    def _open_settings(self) -> None:
        dlg = SystemSettingsDialog(self)
        dlg.exec()
        vals = dlg.sync_values()
        self._local_path = vals["local_path"]
        self._branch = vals["branch"]
        self._auto_build = vals["auto_build"]
        self._with_channels = vals["with_channels"]

    def _schedule_reload(self) -> None:
        self._reload_timer.start()

    def reload(self) -> None:
        self._schedule_reload()

    def _set_status_loading(self) -> None:
        self.lbl_host.setText("…")
        self.lbl_nixos.setText("…")
        self.lbl_latest.setText("…")
        self.lbl_channel.setText("…")
        self.lbl_release.setText("reading…")
        self.lbl_running.setText("…")
        self.lbl_config_ver.setText("…")
        self.lbl_system_type.setText("…")
        self.lbl_layout.setText("…")
        self.lbl_checks.setText("…")

    def _apply_fs_status(self, raw: str, *, code: int) -> None:
        """Fill Status from Target /etc/nixos (real config + flake values)."""
        fs = parse_fs_status_stdout(raw)
        if fs.error or (code != 0 and not (raw or "").strip()):
            reason = fs.error or f"read failed (exit {code})"
            self.lbl_host.setText(f"error: {reason}"[:80])
            for lbl in (
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
                lbl.setText("—")
            return

        host = (fs.hostname or "").strip()
        self.lbl_host.setText(_dash(host) if host else "error: hostname unknown")
        self.lbl_config_ver.setText(_dash(fs.config_version))
        self.lbl_system_type.setText(_dash(fs.system_type))
        self.lbl_layout.setText(_dash(fs.layout))
        if fs.enable_checks is True:
            self.lbl_checks.setText("on")
        elif fs.enable_checks is False:
            self.lbl_checks.setText("off")
        else:
            self.lbl_checks.setText("—")
        self.lbl_channel.setText(_dash(fs.channel))

        latest = ""
        try:
            latest = fetch_latest_stable_pin(timeout=4) or ""
        except Exception:
            latest = ""
        rel = release_from_fs(fs, latest=latest)
        pin = rel["current"]
        lat = rel["latest"]
        self.lbl_nixos.setText(f"nixos-{pin}" if pin not in ("", "—") else "—")
        self.lbl_latest.setText(f"nixos-{lat}" if lat not in ("", "—") else "—")
        self.lbl_running.setText(_dash(rel["running"]))
        self.lbl_release.setText(_release_badge(rel["status"]))

    def _reload_now(self) -> None:
        t = target_from_env()
        self.set_subtitle(
            f"Actions run on {t} (header Target). "
            "Sync the NCC tree, migrate config, or rebuild — gear = preferences."
            if t
            else "Sync the NCC tree, migrate config, or rebuild. "
            "Gear (top right) opens sync preferences."
        )
        self._set_status_loading()
        self._start_fs_status_probe()

    def _start_fs_status_probe(self) -> None:
        if self._status_proc is not None:
            if self._status_proc.state() != QProcess.ProcessState.NotRunning:
                self._status_proc.kill()
            self._status_proc = None

        argv = build_fs_status_argv(target_from_env())
        proc = QProcess(self)
        self._status_proc = proc
        proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        proc.finished.connect(self._on_fs_status_finished)
        prog, *args = argv
        proc.start(prog, args)
        if not proc.waitForStarted(3000):
            self.lbl_host.setText("error: status probe failed to start")
            self._status_proc = None
            return
        proc.write(STATUS_SCRIPT.encode("utf-8"))
        proc.closeWriteChannel()

    def _on_fs_status_finished(self, code: int, _status) -> None:
        proc = self._status_proc
        self._status_proc = None
        if proc is None:
            return
        raw = strip_ansi(
            bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        )
        self._apply_fs_status(raw, code=code)

    def _start_sync(self, mode: str) -> None:
        if self.set_busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if mode == "local":
            path = self._local_path
            if not t and (not path or not Path(path).is_dir()):
                error(
                    self,
                    "Local update",
                    f"Directory not found:\n{path}\n\nSet the path in Settings.",
                )
                return
            if t:
                summary = (
                    f"On {where}: sync from a path available there "
                    f"(configured local path is for this PC):\n{path}"
                )
            else:
                summary = f"Copy from local tree:\n{path}"
        elif mode == "remote":
            summary = f"On {where}: clone GitHub NixOSControlCenter @ {self._branch}"
        else:
            summary = f"On {where}: update flake channels / inputs only"

        build = self._auto_build
        extra = "Then build & switch." if build else "No rebuild (copy/channels only)."
        if not confirm(
            self,
            "System update",
            f"{summary}\n\n{extra}\n\nThis changes /etc/nixos on {where}. Continue?",
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
                from ncc_gui.target_session import session_controller

                session_controller().refresh()
                self.reload()

        self.run_ncc_root(
            args,
            label=f"system update ({mode})",
            on_done=_done,
            follow_target=True,
        )

    def _run_quick(self, args: tuple[str, ...], label: str, need_confirm: bool) -> None:
        if self.set_busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if need_confirm and not confirm(self, label, f"Run “{label}” on {where}?"):
            return

        elevated = args[:1] in (("build",), ("allow-unfree",), ("migrate-config",))
        if elevated:

            def _done(code: int) -> None:
                if code == 0:
                    from ncc_gui.target_session import session_controller

                    session_controller().refresh()
                    self.reload()

            self.run_ncc_root(
                ["system", *args],
                label=label,
                follow_target=True,
                on_done=_done,
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
