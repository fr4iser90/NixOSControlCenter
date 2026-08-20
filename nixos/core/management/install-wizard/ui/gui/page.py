"""Install — preflight gate + wizard / dry-run / backup (DomainPage kit)."""

from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_session import current_session
from ncc_gui.widgets import FormValueLabel

try:
    from .preflight import gather_preflight, mode_label
except ImportError:  # flat load in unit tests / source tree
    from preflight import gather_preflight, mode_label


class InstallPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Install",
            "Adopt or install NCC on the header Target. "
            "Wizard opens in its own window.",
            parent=parent,
        )

        status = self.add_form_block("Preflight")
        self.lbl_host = self.add_form_value(status, "Hostname")
        self.lbl_arch = self.add_form_value(status, "Architecture")
        self.lbl_platform = self.add_form_value(status, "system.platform")
        self.lbl_os = self.add_form_value(status, "OS")
        self.lbl_etc = self.add_form_value(status, "/etc/nixos")
        self.lbl_repo = self.add_form_value(status, "NCC repo")
        self.lbl_hw = self.add_form_value(status, "Device targets")
        self.lbl_mode = self.add_form_value(status, "Recommended")
        self.lbl_warn = self.add_form_value(status, "Notes")

        next_box = self.add_form_block("Next step")
        self.lbl_next = FormValueLabel("—")
        next_box.addRow(self.lbl_next)

        self.add_actions_hint(
            "Wizard is a separate window (answers → install shell). "
            "Back up /etc/nixos before migrate. Full deploy: "
            "nix-shell <repo>/shell.nix. "
            "Remote Target: Connect first; use wizard / shell on that host."
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

        self.lbl_repo.setText(pf.repo or "(not found — set NCC_INSTALL_REPO)")

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

        if sess.state == "needs_install" and t:
            self.lbl_next.setText(
                "1) On the Target: backup /etc/nixos  →  2) Start wizard / "
                "nix-shell deploy  →  3) Re-probe (Connect). "
                "Platform stays ARM/x86 from the Target CPU."
            )
        elif sess.state == "needs_update":
            self.lbl_next.setText(
                "NCC is present but outdated — prefer System → "
                "From GitHub / Migrate config, then Re-probe."
            )
        elif mode == "migrate":
            self.lbl_next.setText(
                "1) Backup /etc/nixos  →  2) Start wizard  →  3) finish in "
                "nix-shell. Device starters appear only if hardware matches."
            )
        elif mode == "reconfigure":
            self.lbl_next.setText(
                "NCC markers found. Prefer System sync for day-to-day updates; "
                "use the wizard to re-run install choices."
            )
        elif mode == "fresh":
            self.lbl_next.setText(
                "Fresh path: Start wizard (or dry-run), then deploy from the "
                "install nix-shell on a NixOS system / ISO."
            )
        elif mode == "blocked":
            self.lbl_next.setText(
                "Target blocked (OS / arch). Disconnect or fix the host."
            )
        else:
            self.lbl_next.setText("Refresh preflight, then Start wizard.")

        if t:
            self.set_subtitle(
                f"Preflight for {t}. Use the wizard to adopt or reconfigure."
            )
        else:
            self.set_subtitle(
                "Preflight for this PC. Connect a host in the Target bar "
                "to adopt remote NixOS."
            )

    def _wizard(self) -> None:
        pf = getattr(self, "_pf", None)
        sess = current_session()
        if sess.state == "needs_install" or (
            pf and pf.etc_nixos and pf.recommended_mode == "migrate"
        ):
            if not confirm(
                self,
                "Migrate / install",
                "Existing /etc/nixos may be overwritten. Prefer Backup first. Continue?",
            ):
                return
        self._run_ncc(["install", "wizard"], "Install wizard")

    def _dry_run(self) -> None:
        self._run_ncc(["install", "dry-run"], "Install dry-run")

    def _shell_hint(self) -> None:
        # Sync: show the printed nix-shell line (not a generic "Finished").
        ncc = shutil.which("ncc")
        if not ncc:
            error(self, "ncc missing", "ncc is not on PATH.")
            return
        repo = getattr(self, "_pf", None)
        repo_path = repo.repo if repo else ""
        if repo_path and not os.environ.get("NCC_INSTALL_REPO"):
            os.environ["NCC_INSTALL_REPO"] = repo_path
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

    def _run_ncc(self, argv: list[str], label: str) -> None:
        ncc = shutil.which("ncc")
        if not ncc:
            error(self, "ncc missing", "ncc is not on PATH.")
            return

        repo = getattr(self, "_pf", None)
        repo_path = repo.repo if repo else ""
        if repo_path and not os.environ.get("NCC_INSTALL_REPO"):
            os.environ["NCC_INSTALL_REPO"] = repo_path

        def done(code: int) -> None:
            if code != 0:
                error(self, label, f"Exit code {code}")
            else:
                info(self, label, "Finished.")
                self.reload()

        self.run_ncc_async(argv, label=label, on_done=done)


def create_page() -> InstallPage:
    return InstallPage()


Page = InstallPage
