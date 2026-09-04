"""System — status overview; sync prefs + target in Settings modal."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QProcess, QSettings, QTimer
from PySide6.QtGui import QGuiApplication
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
from ncc_gui.push_tree import (
    apply_staged_tree_on_target,
    push_nixos_tree_to_target,
    remote_staging_dir,
)
from ncc_gui.remote import can_elevate, target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.system_fs_status import (
    STATUS_SCRIPT,
    build_fs_status_argv,
    fetch_latest_stable_pin,
    parse_fs_status_stdout,
    release_from_fs,
)
from ncc_gui.settings.safety_tab import load_host_policy
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_probe import EXPECTED_CONFIG_VERSION
from ncc_gui.theme import APP_STYLE
from ncc_gui.update_source_dialog import UpdateSourceDialog, local_path_ok

_SETTINGS_ORG = "NixOSControlCenter"
_SETTINGS_APP = "ncc-gui"
_KEY_LOCAL = "system/localNixosPath"
_KEY_BRANCH = "system/remoteBranch"
_KEY_AUTO_BUILD = "system/autoBuild"
_KEY_WITH_CHANNELS = "system/withChannels"


def _default_local_nixos() -> str:
    configured = (load_host_policy().get("localSourceDir") or "").strip()
    if configured:
        return configured
    live = Path("/etc/nixos")
    if (live / "flake.nix").is_file() and (live / "core" / "management").is_dir():
        return str(live)
    return ""


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
        self.local_path.setPlaceholderText("/path/to/nixos or /etc/nixos")
        form.addRow("Local source path", self.local_path)

        self.branch = QComboBox()
        self.branch.setEditable(True)
        for b in ("main", "develop", "experimental"):
            self.branch.addItem(b)
        self.branch.setCurrentText(str(self._settings.value(_KEY_BRANCH, "main")))
        form.addRow("GitHub branch", self.branch)

        opts = QHBoxLayout()
        self.auto_build = QCheckBox("Build && switch after sync")
        # Prefer last GUI choice; else host policy system-manager.autoBuild
        _host_auto = bool(load_host_policy().get("autoBuild"))
        self.auto_build.setChecked(
            bool(self._settings.value(_KEY_AUTO_BUILD, _host_auto, type=bool))
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
        _host_auto = bool(load_host_policy().get("autoBuild"))
        self._auto_build = bool(
            self._settings.value(_KEY_AUTO_BUILD, _host_auto, type=bool)
        )
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
        # system-manager.enableChecks — preflight before rebuild (not an inventory)
        self.lbl_checks = self.add_form_value(status, "Preflight checks")

        store = self.add_form_block("Nix store")
        self.lbl_store_size = self.add_form_value(store, "Disk (/nix)")
        self.lbl_generations = self.add_form_value(store, "Generations")
        self.lbl_gc_preview = self.add_form_value(store, "GC preview")

        self._elevated_btns: list = []
        self.add_action("Refresh status", self.reload, local=True)
        self.add_action("Copy status", self._copy_status, local=True)
        self._elevated_btns.append(
            self.add_action(
                "From local repo",
                lambda: self._start_sync("local"),
                primary=True,
                ncc=("system", "update"),
            )
        )
        self._elevated_btns.append(
            self.add_action(
                "From GitHub",
                lambda: self._start_sync("remote"),
                ncc=("system", "update"),
            )
        )
        self._elevated_btns.append(
            self.add_action(
                "Channels only",
                lambda: self._start_sync("channels"),
                ncc=("system", "update"),
            )
        )
        self._elevated_btns.append(
            self.add_action(
                "Migrate config",
                lambda: self._run_quick(("migrate-config",), "Migrate config", True),
                ncc=("system", "migrate-config"),
            )
        )
        self.add_action(
            "Check versions",
            lambda: self._run_quick(("check-versions",), "Check versions", False),
            ncc=("system", "check-versions"),
        )
        self.add_action(
            "Validate config",
            lambda: self._run_quick(("validate-config",), "Validate config", False),
            ncc=("system", "validate-config"),
        )
        self.add_action(
            "System report",
            lambda: self._run_quick(("report",), "System report", False),
            ncc=("system", "report"),
        )
        self.add_action(
            "Store status",
            lambda: self._run_quick(("store-status",), "Store status", False),
            ncc=("system", "store-status"),
        )
        self.add_action(
            "GC dry-run",
            lambda: self._run_quick(("gc", "--dry-run"), "GC dry-run", False),
            ncc=("system", "gc"),
        )
        self._elevated_btns.append(
            self.add_action(
                "Run GC",
                lambda: self._run_gc_run(),
                ncc=("system", "gc"),
            )
        )
        self._elevated_btns.append(
            self.add_action(
                "Rebuild only",
                lambda: self._run_quick(("build", "switch"), "Rebuild only", True),
                ncc=("system", "build"),
            )
        )
        self.add_action(
            "Config layout",
            lambda: self._run_quick(("config-layout", "detect"), "Config layout", False),
            ncc=("system", "config-layout"),
        )
        self._elevated_btns.append(
            self.add_action(
                "Allow unfree",
                lambda: self._run_quick(("allow-unfree",), "Allow unfree", True),
                ncc=("system", "allow-unfree"),
            )
        )

        self._status_proc: QProcess | None = None
        self._store_proc: QProcess | None = None
        self._gc_probe_proc: QProcess | None = None
        self._reload_timer = QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.setInterval(150)
        self._reload_timer.timeout.connect(self._reload_now)

        target_bus().changed.connect(lambda _t: self._schedule_reload())
        target_bus().systemAction.connect(self._on_system_action)
        QTimer.singleShot(0, self._schedule_reload)
        QTimer.singleShot(0, self._refresh_elevated_actions)

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

    def _refresh_elevated_actions(self) -> None:
        ok = can_elevate(target=target_from_env())
        tip = (
            ""
            if ok
            else "Needs passwordless sudo on the Target (sudo -n)"
        )
        for btn in self._elevated_btns:
            btn.setEnabled(ok)
            btn.setToolTip(tip)

    def _on_system_action(self, name: object) -> None:
        if not isinstance(name, str) or not name.strip():
            return
        action = name.strip()
        if action in ("update-config", "migrate-config"):
            QTimer.singleShot(0, self._start_update_to_current)

    def _start_update_to_current(self) -> None:
        """Banner «Update to 2.1»: modal → Host rsync or GitHub → Target update."""
        if not can_elevate(target=target_from_env()):
            error(
                self,
                f"Update to {EXPECTED_CONFIG_VERSION}",
                "Passwordless sudo required on the Target "
                "(ssh … sudo -n true).",
            )
            self._refresh_elevated_actions()
            return

        dlg = UpdateSourceDialog(
            self,
            schema_version=EXPECTED_CONFIG_VERSION,
            target=target_from_env(),
            local_path=self._local_path,
            branch=self._branch,
            auto_build=self._auto_build,
        )
        if dlg.exec() != UpdateSourceDialog.DialogCode.Accepted:
            return
        choice = dlg.choice()
        # Persist prefs for next time
        self._local_path = choice["path"] or self._local_path
        self._branch = choice["branch"]
        self._auto_build = bool(choice["auto_build"])
        self._settings.setValue(_KEY_LOCAL, self._local_path)
        self._settings.setValue(_KEY_BRANCH, self._branch)
        self._settings.setValue(_KEY_AUTO_BUILD, self._auto_build)
        self._settings.sync()

        if choice["source"] == "local":
            self._run_update_from_host(
                choice["path"], auto_build=choice["auto_build"]
            )
        else:
            self._run_update_from_github(
                choice["branch"], auto_build=choice["auto_build"]
            )

    def _run_update_from_host(self, path: str, *, auto_build: bool) -> None:
        """This PC → Target/local: sync tree, rebuild, then migrate-config → schema."""
        ok, err = local_path_ok(path)
        if not ok:
            error(self, f"Update to {EXPECTED_CONFIG_VERSION}", err)
            return
        t = target_from_env()
        where = t or "this machine"

        if t:
            # Host→Target: migrate module configs WHILE SSH still works, then rebuild.
            # (Rebuild with ssh-manager.enable=false kills sshd — migrate must be first.)
            summary = (
                f"On {t}:\n"
                f"1) Copy this PC's tree → {remote_staging_dir()}\n"
                f"2) Apply into /etc/nixos (keep your systemConfig)\n"
                f"3) Module migrate (SSH merge / renames — before rebuild)\n"
                f"4) Rebuild & switch\n"
                f"5) Migrate config schema → {EXPECTED_CONFIG_VERSION}"
            )
        else:
            steps = (
                f"1) Update from local tree\n"
                f"2) Rebuild & switch\n"
                f"3) Migrate config → {EXPECTED_CONFIG_VERSION}"
                if auto_build
                else (
                    f"1) Update from local tree (no rebuild)\n"
                    f"2) Migrate config → {EXPECTED_CONFIG_VERSION}"
                )
            )
            summary = f"On this machine:\n{path}\n\n{steps}"

        if not confirm(
            self,
            f"Update to {EXPECTED_CONFIG_VERSION}",
            f"{summary}\n\nContinue on {where}?",
        ):
            return

        if t:
            self._host_push_apply_rebuild_migrate(path, auto_build=auto_build)
            return

        # Local (no Target): update --local, then migrate
        args = [
            "system",
            "update",
            "--yes",
            "--local",
            f"--source-dir={path}",
        ]
        if auto_build:
            args.append("--auto-build")

        def _done(code: int) -> None:
            if code != 0:
                return
            self._run_migrate_after_update()

        if self.set_busy():
            return
        self.run_ncc_root(
            args,
            label=f"update to {EXPECTED_CONFIG_VERSION} (this PC)",
            on_done=_done,
            follow_target=False,
        )

    def _host_push_apply_rebuild_migrate(
        self, path: str, *, auto_build: bool = True
    ) -> None:
        """rsync This-PC tree → Target apply → module migrate → rebuild → schema."""
        from PySide6.QtWidgets import QApplication

        t = target_from_env()
        if not t:
            return
        if self.set_busy():
            return

        self.log_append(f"• rsync {path} → {t}:{remote_staging_dir()}\n")
        QApplication.processEvents()
        pushed, detail = push_nixos_tree_to_target(path, t)
        if not pushed:
            error(
                self,
                f"Update to {EXPECTED_CONFIG_VERSION}",
                f"Failed to copy tree from this PC to Target:\n{detail}",
            )
            return
        self.log_append(f"• staged at {detail}\n")
        self.log_append("• apply staged tree → /etc/nixos (preserve systemConfig)\n")
        QApplication.processEvents()
        applied, apply_out = apply_staged_tree_on_target(t, staging=detail)
        self.log_append(f"{apply_out}\n")
        if not applied:
            error(
                self,
                f"Update to {EXPECTED_CONFIG_VERSION}",
                f"Failed to apply staged tree on Target:\n{apply_out}",
            )
            return

        self._chain_module_migrate_rebuild_schema(auto_build=auto_build)

    def _chain_module_migrate_rebuild_schema(self, *, auto_build: bool) -> None:
        """After Host→Target apply: module migrate → rebuild → schema migrate-config.

        Module migrate MUST run before rebuild: cross-module merges (e.g. ssh-server-manager
        → ssh-manager with enable=true) need to land in systemConfig before Nix eval, or
        openssh stays off and post-rebuild SSH (migrate-config) fails with connection refused.
        """

        def _after_module_migrate(code: int) -> None:
            if code != 0:
                error(
                    self,
                    f"Update to {EXPECTED_CONFIG_VERSION}",
                    "Module migrate failed — rebuild skipped (SSH/config merges "
                    "must succeed first).\n\n"
                    "On Target (console if SSH is down):\n"
                    "  sudo ncc modules migrate --verbose\n"
                    "Then fix enable in systemConfig if needed and rebuild.",
                )
                return
            self._chain_rebuild_then_migrate(auto_build=auto_build)

        if self.set_busy():
            return
        self.log_append("• module migrate (before rebuild — keep SSH merges)\n")
        self.run_ncc_root(
            ["modules", "migrate"],
            label="module migrate (pre-rebuild)",
            on_done=_after_module_migrate,
            follow_target=True,
        )

    def _chain_rebuild_then_migrate(self, *, auto_build: bool) -> None:
        """Rebuild (new ncc on PATH), then schema migrate-config."""

        def _after_rebuild(code: int) -> None:
            if code != 0:
                error(
                    self,
                    f"Update to {EXPECTED_CONFIG_VERSION}",
                    "Rebuild failed — schema migrate skipped. Fix build, then "
                    "run Migrate config (or Update to "
                    f"{EXPECTED_CONFIG_VERSION} again).",
                )
                return
            self._run_migrate_after_update()

        if auto_build:
            if self.set_busy():
                return
            self.run_ncc_root(
                ["system", "build", "switch"],
                label="rebuild after tree sync",
                on_done=_after_rebuild,
                follow_target=True,
            )
        else:
            self._run_migrate_after_update()

    def _run_migrate_after_update(self) -> None:
        """Bump Target systemConfig schema to EXPECTED_CONFIG_VERSION."""

        def _done(code: int) -> None:
            from ncc_gui.target_session import session_controller

            if code == 0:
                info(
                    self,
                    f"Update to {EXPECTED_CONFIG_VERSION}",
                    f"Done. Config schema is {EXPECTED_CONFIG_VERSION}.",
                )
            else:
                error(
                    self,
                    f"Update to {EXPECTED_CONFIG_VERSION}",
                    "Tree synced but migrate-config failed. "
                    "Try Actions → Migrate config.",
                )
            session_controller().refresh()
            self.reload()

        if self.set_busy():
            return
        self.run_ncc_root(
            ["system", "migrate-config"],
            label=f"migrate config → {EXPECTED_CONFIG_VERSION}",
            on_done=_done,
            follow_target=True,
        )

    def _run_update_from_github(self, branch: str, *, auto_build: bool) -> None:
        t = target_from_env()
        where = t or "this machine"
        steps = (
            f"1) Clone GitHub @{branch or 'main'} and sync tree\n"
            f"2) Rebuild & switch\n"
            f"3) Migrate config → {EXPECTED_CONFIG_VERSION}"
            if auto_build
            else (
                f"1) Clone GitHub @{branch or 'main'} and sync tree\n"
                f"2) Migrate config → {EXPECTED_CONFIG_VERSION} (no rebuild)"
            )
        )
        if not confirm(
            self,
            f"Update to {EXPECTED_CONFIG_VERSION}",
            f"On {where}:\n{steps}\n\nContinue?",
        ):
            return

        args = [
            "system",
            "update",
            "--yes",
            "--remote",
            f"--branch={branch or 'main'}",
        ]
        if auto_build:
            args.append("--auto-build")

        def _done(code: int) -> None:
            if code != 0:
                return
            self._run_migrate_after_update()

        if self.set_busy():
            return
        self.run_ncc_root(
            args,
            label=f"update to {EXPECTED_CONFIG_VERSION} (GitHub @{branch})",
            on_done=_done,
            follow_target=True,
        )

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
        self.lbl_store_size.setText("…")
        self.lbl_generations.setText("…")
        self.lbl_gc_preview.setText("…")

    def _apply_store_json(self, raw: str) -> None:
        import json

        text = (raw or "").strip()
        if not text:
            self.lbl_store_size.setText("—")
            self.lbl_generations.setText("—")
            self.lbl_gc_preview.setText("—")
            return
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            self.lbl_store_size.setText("error: invalid JSON")
            self.lbl_generations.setText("—")
            self.lbl_gc_preview.setText("—")
            return
        size = data.get("storeSize")
        self.lbl_store_size.setText(_dash(size))
        gens = data.get("generations")
        cur = data.get("currentGeneration")
        if gens is not None:
            gen_txt = str(gens)
            if cur is not None:
                gen_txt = f"{gens} (current {cur})"
            self.lbl_generations.setText(gen_txt)
        else:
            self.lbl_generations.setText("—")
        dead = data.get("gcDeadPaths")
        freed = data.get("gcFreedEstimate")
        note = (data.get("gcNote") or "").strip()
        if dead is None:
            if note.startswith("skipped"):
                self.lbl_gc_preview.setText("skipped — use GC dry-run (slow)")
            elif note:
                self.lbl_gc_preview.setText(f"n/a ({note})")
            else:
                self.lbl_gc_preview.setText("n/a")
        elif dead == 0:
            self.lbl_gc_preview.setText("0 paths (nothing to free)")
        else:
            preview = f"{dead} paths"
            if freed:
                preview = f"{dead} paths ({freed})"
            self.lbl_gc_preview.setText(preview)

    def _run_gc_run(self) -> None:
        if self.set_busy():
            return
        t = target_from_env()
        where = t or "this machine"
        if not confirm(
            self,
            "Run GC",
            f"Delete unreachable Nix store paths on {where}?\n\n"
            "Boot profiles and active generations are kept.",
        ):
            return
        if not can_elevate(target=target_from_env()):
            error(
                self,
                "Run GC",
                "Passwordless sudo required on the Target "
                "(ssh … sudo -n true).",
            )
            self._refresh_elevated_actions()
            return

        def _done(code: int) -> None:
            if code == 0:
                info(self, "Run GC", "Garbage collection finished.")
                self._start_store_status_probe()
            else:
                error(self, "Run GC", "Garbage collection failed.")

        self.run_ncc_root(
            ["system", "gc", "--run"],
            label="run GC",
            follow_target=True,
            on_done=_done,
        )

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
            self.lbl_checks.setText("enabled")
        elif fs.enable_checks is False:
            self.lbl_checks.setText("disabled")
        else:
            # Option default is true when unset in systemConfig text
            self.lbl_checks.setText("enabled (unset in config)")
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
        self._refresh_elevated_actions()
        self._start_fs_status_probe()
        self._start_store_status_probe()

    def _start_store_status_probe(self) -> None:
        if self._store_proc is not None:
            if self._store_proc.state() != QProcess.ProcessState.NotRunning:
                self._store_proc.kill()
            self._store_proc = None

        from ncc_gui.remote import build_ncc_argv

        # Fast path: disk + generations only (GC scan can take minutes on big stores)
        argv = build_ncc_argv(
            ["system", "store-status", "--json"],
            target=target_from_env(),
        )
        proc = QProcess(self)
        self._store_proc = proc
        proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        proc.finished.connect(self._on_store_status_finished)
        prog, *args = argv
        proc.start(prog, args)
        if not proc.waitForStarted(3000):
            self.lbl_store_size.setText("error: probe failed to start")
            self.lbl_generations.setText("—")
            self.lbl_gc_preview.setText("—")
            self._store_proc = None

    def _start_gc_preview_probe(self) -> None:
        """Background --with-gc scan; may take minutes on multi-TB stores."""
        if self._gc_probe_proc is not None:
            if self._gc_probe_proc.state() != QProcess.ProcessState.NotRunning:
                self._gc_probe_proc.kill()
            self._gc_probe_proc = None

        from ncc_gui.remote import build_ncc_argv

        self.lbl_gc_preview.setText("scanning… (can take minutes)")
        argv = build_ncc_argv(
            ["system", "store-status", "--json", "--with-gc"],
            target=target_from_env(),
        )
        proc = QProcess(self)
        self._gc_probe_proc = proc
        proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        proc.finished.connect(self._on_gc_preview_finished)
        prog, *args = argv
        proc.start(prog, args)
        if not proc.waitForStarted(3000):
            self.lbl_gc_preview.setText("n/a (GC probe failed to start)")
            self._gc_probe_proc = None

    def _on_store_status_finished(self, code: int, _status) -> None:
        proc = self._store_proc
        self._store_proc = None
        if proc is None:
            return
        raw = strip_ansi(
            bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        )
        if code != 0 and not raw.strip():
            err = f"error (exit {code})"
            self.lbl_store_size.setText(err)
            self.lbl_generations.setText("—")
            self.lbl_gc_preview.setText("—")
            return
        self._apply_store_json(raw)
        # Kick off slow GC scan after fast fields are filled
        self._start_gc_preview_probe()

    def _on_gc_preview_finished(self, code: int, _status) -> None:
        proc = self._gc_probe_proc
        self._gc_probe_proc = None
        if proc is None:
            return
        raw = strip_ansi(
            bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        )
        if code != 0 and not raw.strip():
            self.lbl_gc_preview.setText(
                f"n/a (scan exit {code} — try GC dry-run)"
            )
            return
        # Only refresh GC fields; keep disk/gens from fast probe
        import json

        try:
            data = json.loads((raw or "").strip() or "{}")
        except json.JSONDecodeError:
            self.lbl_gc_preview.setText("n/a (invalid GC JSON)")
            return
        dead = data.get("gcDeadPaths")
        freed = data.get("gcFreedEstimate")
        note = (data.get("gcNote") or "").strip()
        if dead is None:
            self.lbl_gc_preview.setText(
                f"n/a ({note})" if note else "n/a (scan failed)"
            )
        elif dead == 0:
            self.lbl_gc_preview.setText("0 paths (nothing to free)")
        else:
            preview = f"{dead} paths"
            if freed:
                preview = f"{dead} paths ({freed})"
            self.lbl_gc_preview.setText(preview)

    def _copy_status(self) -> None:
        """Copy Status + Nix store rows to clipboard (values are also mouse-selectable)."""
        rows = [
            ("Hostname", self.lbl_host),
            ("NixOS pin", self.lbl_nixos),
            ("Latest stable", self.lbl_latest),
            ("Channel", self.lbl_channel),
            ("Release status", self.lbl_release),
            ("Running", self.lbl_running),
            ("Config version", self.lbl_config_ver),
            ("System type", self.lbl_system_type),
            ("Config layout", self.lbl_layout),
            ("Preflight checks", self.lbl_checks),
            ("Disk (/nix)", self.lbl_store_size),
            ("Generations", self.lbl_generations),
            ("GC preview", self.lbl_gc_preview),
        ]
        text = "\n".join(f"{name}: {lbl.text()}" for name, lbl in rows)
        clip = QGuiApplication.clipboard()
        if clip is None:
            error(self, "Copy status", "Clipboard unavailable.")
            return
        clip.setText(text)
        info(self, "Copy status", "Status copied to clipboard.")

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
        if not can_elevate(target=target_from_env()):
            error(
                self,
                "System update",
                "Passwordless sudo required on the Target "
                "(ssh … sudo -n true).",
            )
            self._refresh_elevated_actions()
            return
        t = target_from_env()
        where = t or "this machine"

        # Host→Target + "From local repo": push THIS PC's tree to Target (never
        # run ``ncc system update --local --source-dir=<host-path>`` on Target —
        # that path only exists on this PC).
        if mode == "local" and t:
            path = self._local_path
            ok, err = local_path_ok(path)
            if not ok:
                error(self, "From local repo", err)
                return
            summary = (
                f"This PC → {t}:\n"
                f"1) Copy {path} → {remote_staging_dir()}\n"
                f"2) Apply into /etc/nixos (keep systemConfig)\n"
                f"3) Module migrate (before rebuild)\n"
                f"4) Rebuild & switch\n"
                f"5) Migrate config schema → {EXPECTED_CONFIG_VERSION}"
            )
            build = self._auto_build
            if not build:
                summary = (
                    f"This PC → {t}:\n"
                    f"1) Copy {path} → Target /etc/nixos (keep systemConfig)\n"
                    f"2) Module migrate\n"
                    f"(auto-build off — no rebuild / schema migrate)"
                )
            if not confirm(
                self,
                "From local repo",
                f"{summary}\n\nContinue on {where}?",
            ):
                return
            self._host_push_apply_rebuild_migrate(path, auto_build=build)
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
        if elevated and not can_elevate(target=target_from_env()):
            error(
                self,
                label,
                "Passwordless sudo required on the Target "
                "(ssh … sudo -n true).",
            )
            self._refresh_elevated_actions()
            return
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

        timeout = 3600 if args[:1] == ("build",) or args[:1] == ("gc",) else 180
        proc = self.run_ncc(
            "system",
            *args,
            follow_target=True,
            timeout=timeout,
            need_confirm=None,
        )
        if args == ("store-status",) and proc.returncode == 0:
            self._apply_store_json(proc.stdout or "")
        if args[:1] == ("store-status",) and "--json" in args and proc.returncode == 0:
            self._apply_store_json(proc.stdout or "")
        if args[:2] == ("gc", "--dry-run") and proc.returncode == 0:
            # Prefer parsing "Dead store paths: N" from dry-run output
            dead = None
            for line in (proc.stdout or "").splitlines():
                if "Dead store paths:" in line:
                    try:
                        dead = int(line.rsplit(":", 1)[-1].strip().split()[0])
                    except ValueError:
                        dead = None
                    break
            if dead is not None:
                if dead == 0:
                    self.lbl_gc_preview.setText("0 paths (nothing to free)")
                else:
                    self.lbl_gc_preview.setText(f"{dead} paths")
            else:
                self._start_gc_preview_probe()
        if args == ("config-layout", "detect") and proc.returncode == 0:
            for line in reversed((proc.stdout or "").strip().splitlines()):
                tline = line.strip().strip('"')
                if tline in ("monolith", "split", "none"):
                    self.lbl_layout.setText(tline)
                    break


def create_page(parent=None) -> SystemPage:
    return SystemPage(parent)


Page = SystemPage
