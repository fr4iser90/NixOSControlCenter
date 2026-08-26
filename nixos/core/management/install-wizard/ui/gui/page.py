"""Install — preflight gate + wizard / dry-run / backup (DomainPage kit)."""

from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import can_elevate, target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.session_ux import session_mode
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_probe import EXPECTED_CONFIG_VERSION
from ncc_gui.target_session import current_session, session_controller
from ncc_gui.widgets import FormValueLabel

try:
    from .preflight import find_nixos_source, gather_preflight, mode_label
    from .remote_deploy import (
        execute_remote_deploy,
        make_staging_dir,
        run_install_wizard,
        stage_install_config,
    )
except ImportError:  # flat load in unit tests / source tree
    from preflight import find_nixos_source, gather_preflight, mode_label
    from remote_deploy import (
        execute_remote_deploy,
        make_staging_dir,
        run_install_wizard,
        stage_install_config,
    )


class _RemoteDeployBridge(QObject):
    log_line = Signal(str)
    finished = Signal(bool, str)


class _RemoteDeployJob(QRunnable):
    def __init__(
        self,
        bridge: _RemoteDeployBridge,
        *,
        target: str,
        selection: str,
        answers_file: str,
        nixos_source: str,
        sudo_password: str | None = None,
    ) -> None:
        super().__init__()
        self._bridge = bridge
        self._target = target
        self._selection = selection
        self._answers_file = answers_file
        self._nixos_source = nixos_source
        self._sudo_password = sudo_password

    def run(self) -> None:
        try:
            ok, detail = execute_remote_deploy(
                target=self._target,
                selection=self._selection,
                answers_file=self._answers_file,
                nixos_source=self._nixos_source,
                sudo_password=self._sudo_password,
                on_log=self._bridge.log_line.emit,
            )
            self._bridge.finished.emit(ok, detail)
        except Exception as e:
            self._bridge.log_line.emit(f"ERROR: {e}\n")
            self._bridge.finished.emit(False, str(e))


class InstallPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Install",
            "Adopt or install NCC on the header Target. "
            "Remote: same Host→Target chain as System → Update.",
            parent=parent,
        )

        status = self.add_form_block("Preflight")
        self.lbl_host = self.add_form_value(status, "Hostname")
        self.lbl_arch = self.add_form_value(status, "Architecture")
        self.lbl_platform = self.add_form_value(status, "system.platform")
        self.lbl_os = self.add_form_value(status, "OS")
        self.lbl_etc = self.add_form_value(status, "/etc/nixos")
        self.lbl_repo = self.add_form_value(status, "Host tree")
        self.lbl_hw = self.add_form_value(status, "Device targets")
        self.lbl_mode = self.add_form_value(status, "Recommended")
        self.lbl_warn = self.add_form_value(status, "Notes")

        next_box = self.add_form_block("Next step")
        self.lbl_next = FormValueLabel("—")
        next_box.addRow(self.lbl_next)

        self.add_actions_hint(
            "Start wizard: pick blueprint/answers (local window), then deploy. "
            "REMOTE Target: rsync tree → apply → systemConfig → rebuild → migrate "
            "(same as System → Update). LOCAL: apply to this PC's /etc/nixos. "
            "Back up /etc/nixos before migrate."
        )
        self.btn_wizard = self.add_action(
            "Start wizard", self._wizard, primary=True, ncc=("install", "wizard")
        )
        self.btn_wizard.setObjectName("nccPrimaryButton")
        self.add_action("Dry-run wizard", self._dry_run, ncc=("install", "dry-run"))
        self.add_action("Backup /etc/nixos", self._backup, local=True)
        self.add_action(
            "Show nix-shell command", self._shell_hint, ncc=("install", "shell")
        )
        self.add_action("Refresh", self.reload, local=True)

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def _resolve_nixos_source(self) -> str:
        pf = getattr(self, "_pf", None)
        source = (pf.repo if pf else "") or find_nixos_source()
        if source and not os.environ.get("NCC_INSTALL_REPO"):
            os.environ["NCC_INSTALL_REPO"] = source
        return source

    def _remote_target(self) -> str | None:
        sess = current_session()
        if session_mode(sess) != "remote":
            return None
        return target_from_env()

    def reload(self) -> None:
        t = target_from_env() or ""
        sess = current_session()
        pf = gather_preflight(remote_target=t)
        self._pf = pf

        probe = sess.probe if (t and sess.connected == t and sess.probe) else None

        if probe:
            self.lbl_host.setText(probe.hostname or "—")
            self.lbl_arch.setText(probe.arch or "—")
            plat = probe.platform_linux or f"(unknown from {probe.arch})"
            self.lbl_platform.setText(plat)
            nix = "NixOS" if probe.is_nixos else "not NixOS"
            self.lbl_os.setText(f"{probe.os_pretty} ({nix})")
            kind = {
                "missing": "missing",
                "plain": "present (plain / non-NCC)",
                "ncc": "present (looks like NCC)",
            }.get(probe.etc_nixos_kind, probe.etc_nixos_kind)
            self.lbl_etc.setText(kind)
            if sess.state == "needs_install":
                mode = "migrate" if probe.etc_nixos_kind == "plain" else "fresh"
            elif sess.state == "needs_update":
                mode = "reconfigure"
            elif sess.state == "blocked":
                mode = "blocked"
            elif sess.state == "ready":
                mode = "reconfigure"
            else:
                mode = pf.recommended_mode
            self.lbl_mode.setText(mode_label(mode))
            notes = [sess.message] if sess.message else []
            if pf.warnings:
                notes.extend(pf.warnings)
            self.lbl_warn.setText(" · ".join(notes) if notes else "—")
        else:
            self.lbl_host.setText(pf.hostname)
            self.lbl_arch.setText(pf.arch)
            arch_l = (pf.arch or "").lower()
            if arch_l in ("aarch64", "arm64"):
                self.lbl_platform.setText("aarch64-linux (from live arch)")
            elif arch_l in ("x86_64", "amd64"):
                self.lbl_platform.setText("x86_64-linux (from live arch)")
            else:
                self.lbl_platform.setText(f"(unknown from {pf.arch})")
            nix = "NixOS" if pf.is_nixos else "not NixOS"
            self.lbl_os.setText(f"{pf.os_pretty} ({nix})")
            kind = {
                "missing": "missing",
                "plain": "present (plain / non-NCC)",
                "ncc": "present (looks like NCC)",
            }.get(pf.etc_nixos_kind, pf.etc_nixos_kind)
            self.lbl_etc.setText(kind)
            self.lbl_mode.setText(mode_label(pf.recommended_mode))
            self.lbl_warn.setText(
                " · ".join(pf.warnings) if pf.warnings else "—"
            )
            mode = pf.recommended_mode

        self.lbl_repo.setText(pf.repo or "(not found — need /etc/nixos or NCC_INSTALL_REPO)")

        if pf.device_matched:
            hw = "matched: " + ", ".join(pf.device_matched)
        elif pf.device_available:
            hw = (
                "none matched (available: "
                + ", ".join(pf.device_available)
                + ")"
            )
        else:
            hw = "none discovered (open install shell / set SCRIPT_ROOT)"
        self.lbl_hw.setText(hw)

        if t and session_mode(sess) == "remote":
            self.lbl_next.setText(
                "1) Backup Target /etc/nixos  →  2) Start wizard  →  "
                "3) Deploy on Target (rsync / apply / rebuild / migrate). "
                "Wizard window runs on this PC; writes go to Target only."
            )
        elif sess.state == "needs_update":
            self.lbl_next.setText(
                "NCC is present but outdated — prefer System → "
                "From GitHub / Migrate config, then Re-probe."
            )
        elif mode == "migrate":
            self.lbl_next.setText(
                "1) Backup /etc/nixos  →  2) Start wizard  →  3) deploy completes "
                "on the Target (remote) or this PC (local)."
            )
        elif mode == "reconfigure":
            self.lbl_next.setText(
                "NCC markers found. Prefer System sync for day-to-day updates; "
                "use the wizard to re-run install choices."
            )
        elif mode == "fresh":
            self.lbl_next.setText(
                "Fresh path: Start wizard, then deploy (remote Target or this PC)."
            )
        elif mode == "blocked":
            self.lbl_next.setText(
                "Target blocked (OS / arch). Disconnect or fix the host."
            )
        else:
            self.lbl_next.setText("Refresh preflight, then Start wizard.")

        if t:
            self.set_subtitle(
                f"Preflight for {t}. Deploy follows System → Update on REMOTE."
            )
        else:
            self.set_subtitle(
                "Preflight for this PC. Connect a host in the Target bar "
                "to adopt remote NixOS."
            )

    def _confirm_migrate(self) -> bool:
        pf = getattr(self, "_pf", None)
        sess = current_session()
        if sess.state == "needs_install" or (
            pf and pf.etc_nixos and pf.recommended_mode == "migrate"
        ):
            where = self._remote_target() or "this machine"
            return confirm(
                self,
                "Migrate / install",
                f"Existing /etc/nixos on {where} may be overwritten. "
                "Prefer Backup first. Continue?",
            )
        return True

    def _wizard(self) -> None:
        if not self._confirm_migrate():
            return
        if self.set_busy():
            return
        self.log_append("• Install wizard (selection window on this PC)\n")
        code, selection, answers, log = run_install_wizard()
        if log:
            self.log_append(log + "\n")
        if code != 0:
            error(self, "Install wizard", log or f"Exit code {code}")
            return
        self.log_append(f"Selection: {selection}\n")
        remote = self._remote_target()
        if remote:
            self._deploy_remote(remote, selection, answers)
        else:
            if not self.confirm_scope_write("Install apply"):
                return
            self._deploy_local(selection, answers)

    def _dry_run(self) -> None:
        if not self._confirm_migrate():
            return
        if self.set_busy():
            return
        self.log_append("• Install dry-run (staging only — no Target writes)\n")
        code, selection, answers, log = run_install_wizard()
        if log:
            self.log_append(log + "\n")
        if code != 0:
            error(self, "Install dry-run", log or f"Exit code {code}")
            return
        nixos_source = self._resolve_nixos_source()
        if not nixos_source:
            error(
                self,
                "Install dry-run",
                "No Host NixOS tree — deploy NCC to /etc/nixos or set NCC_INSTALL_REPO.",
            )
            return
        staging = make_staging_dir()
        ok, detail = stage_install_config(
            selection=selection,
            answers_file=answers,
            nixos_source=nixos_source,
            staging_etc=staging,
            dry_run=True,
        )
        self.log_append(detail + "\n")
        if ok:
            info(
                self,
                "Install dry-run",
                "Preview OK — nothing written to /etc/nixos on any host.",
            )
        else:
            error(self, "Install dry-run", detail)

    def _deploy_local(self, selection: str, answers: str) -> None:
        nixos_source = self._resolve_nixos_source()
        if not nixos_source:
            error(
                self,
                "Install",
                "No Host NixOS tree — deploy NCC to /etc/nixos or set NCC_INSTALL_REPO.",
            )
            return
        env = os.environ.copy()
        env["NCC_INSTALL_SELECTION"] = selection
        if answers:
            env["NCC_GUI_ANSWERS_FILE"] = answers

        def done(code: int) -> None:
            if code != 0:
                error(self, "Install", f"Exit code {code}")
            else:
                info(
                    self,
                    "Install",
                    "Deploy complete on this PC.\nNext: sudo ncc system-update",
                )
                self.reload()

        if self.set_busy():
            return
        self.run_ncc_root(
            ["install", "apply"],
            label="Install apply (this PC)",
            on_done=done,
            env=env,
        )

    def _deploy_remote(self, target: str, selection: str, answers: str) -> None:
        nixos_source = self._resolve_nixos_source()
        if not nixos_source:
            error(
                self,
                "Install",
                "No Host NixOS tree — deploy NCC to /etc/nixos or set NCC_INSTALL_REPO.",
            )
            return
        if not Path(nixos_source, "flake.nix").is_file():
            error(self, "Install", f"No flake.nix in Host tree:\n{nixos_source}")
            return

        from PySide6.QtCore import Qt
        from PySide6.QtWidgets import QDialog
        from ncc_gui.push_tree import remote_staging_dir

        summary = (
            f"On {target}:\n"
            f"1) Generate systemConfig on this PC (staging — not /etc/nixos here)\n"
            f"2) rsync tree → {remote_staging_dir()}\n"
            f"3) Apply into /etc/nixos (keep hardware-configuration.nix)\n"
            f"4) Copy generated systemConfig\n"
            f"5) nixos-rebuild switch\n"
            f"6) migrate-config → {EXPECTED_CONFIG_VERSION}"
        )
        if not confirm(self, "Install on Target", f"{summary}\n\nContinue?"):
            return

        sudo_password: str | None = None
        if not can_elevate(target=target):
            from ncc_gui.ssh_auth_dialog import TargetSudoDialog

            dlg = TargetSudoDialog(target, self)
            if dlg.exec() != QDialog.DialogCode.Accepted:
                return
            sudo_password = dlg.password()

        self.log_append(f"• Install on Target {target} (background — UI stays responsive)\n")
        bridge = _RemoteDeployBridge()
        bridge.log_line.connect(self.log_append, Qt.ConnectionType.QueuedConnection)
        bridge.finished.connect(
            lambda ok, detail: self._on_remote_deploy_finished(ok, detail, target),
            Qt.ConnectionType.QueuedConnection,
        )
        QThreadPool.globalInstance().start(
            _RemoteDeployJob(
                bridge,
                target=target,
                selection=selection,
                answers_file=answers,
                nixos_source=nixos_source,
                sudo_password=sudo_password,
            )
        )

    def _on_remote_deploy_finished(self, ok: bool, detail: str, target: str) -> None:
        if not ok:
            error(self, "Install on Target", detail)
            return

        def _after_migrate(code: int) -> None:
            if code == 0:
                info(
                    self,
                    "Install on Target",
                    f"Done on {target}.\nRe-probe (Connect) to refresh session.",
                )
            else:
                error(
                    self,
                    "Install on Target",
                    "Rebuild OK but migrate-config failed. "
                    "Try System → Migrate config.",
                )
            session_controller().refresh()
            self.reload()

        if self.set_busy():
            return
        self.run_ncc_root(
            ["system", "migrate-config"],
            label=f"migrate config → {EXPECTED_CONFIG_VERSION}",
            on_done=_after_migrate,
            follow_target=True,
        )

    def _shell_hint(self) -> None:
        ncc = shutil.which("ncc")
        if not ncc:
            error(self, "ncc missing", "ncc is not on PATH.")
            return
        self._resolve_nixos_source()
        proc = self.run_ncc("install", "shell", log=True, show_error=True)
        if proc.returncode == 0:
            hint = ((proc.stdout or "") + (proc.stderr or "")).strip()
            info(self, "Install shell hint", hint or "Done.")

    def _backup(self) -> None:
        t = target_from_env()
        if t:
            error(
                self,
                "Backup",
                f"Connected to {t}. Backup from this GUI copies local "
                "/etc/nixos only. Run backup on the Target (SSH) for now.",
            )
            return
        src = Path("/etc/nixos")
        if not src.is_dir():
            error(self, "Backup", "/etc/nixos not found — nothing to back up.")
            return
        if not confirm(
            self,
            "Backup /etc/nixos",
            "Copy /etc/nixos to ~/ncc-install-backups/etc-nixos-<timestamp>?",
        ):
            return
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        dest_root = Path.home() / "ncc-install-backups"
        dest = dest_root / f"etc-nixos-{stamp}"
        try:
            dest_root.mkdir(parents=True, exist_ok=True)
            shutil.copytree(src, dest, symlinks=True)
        except OSError as e:
            try:
                subprocess.run(
                    ["cp", "-a", str(src), str(dest)],
                    check=True,
                    capture_output=True,
                    text=True,
                )
            except (OSError, subprocess.CalledProcessError) as e2:
                error(self, "Backup failed", f"{e}\n{e2}")
                return
        self.log_append(f"Backup written: {dest}")
        info(self, "Backup", f"Saved to:\n{dest}")


def create_page() -> InstallPage:
    return InstallPage()


Page = InstallPage
