"""Install — preflight gate + wizard / dry-run / backup (DomainPage kit)."""

from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

from PySide6.QtWidgets import QLabel

from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import target_from_env
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus

try:
    from .preflight import gather_preflight, mode_label
except ImportError:  # flat load in unit tests / source tree
    from preflight import gather_preflight, mode_label


class InstallPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Install",
            "Prepare this machine (or note the GUI target), then start the "
            "install / migrate wizard. Wizard opens in its own window.",
            parent=parent,
        )

        status = self.add_form_block("Preflight")
        self.lbl_target = QLabel("—")
        self.lbl_host = QLabel("—")
        self.lbl_arch = QLabel("—")
        self.lbl_platform = QLabel("—")
        self.lbl_os = QLabel("—")
        self.lbl_etc = QLabel("—")
        self.lbl_repo = QLabel("—")
        self.lbl_hw = QLabel("—")
        self.lbl_mode = QLabel("—")
        self.lbl_warn = QLabel("—")
        for w in (
            self.lbl_target,
            self.lbl_host,
            self.lbl_arch,
            self.lbl_platform,
            self.lbl_os,
            self.lbl_etc,
            self.lbl_repo,
            self.lbl_hw,
            self.lbl_mode,
            self.lbl_warn,
        ):
            w.setWordWrap(True)
            w.setObjectName("nccPageSubtitle")
        status.addRow("Target", self.lbl_target)
        status.addRow("Hostname", self.lbl_host)
        status.addRow("Architecture", self.lbl_arch)
        status.addRow("system.platform", self.lbl_platform)
        status.addRow("OS", self.lbl_os)
        status.addRow("/etc/nixos", self.lbl_etc)
        status.addRow("NCC repo", self.lbl_repo)
        status.addRow("Device targets", self.lbl_hw)
        status.addRow("Recommended", self.lbl_mode)
        status.addRow("Notes", self.lbl_warn)

        next_box = self.add_form_block("Next step")
        self.lbl_next = QLabel("—")
        self.lbl_next.setWordWrap(True)
        self.lbl_next.setObjectName("nccPageSubtitle")
        next_box.addRow(self.lbl_next)

        self.add_actions_hint(
            "Wizard is a separate window (answers → install shell). "
            "Back up /etc/nixos before migrate. Full deploy: "
            "nix-shell <repo>/shell.nix"
        )
        # primary must be first add_action for kit insert-at-0 behavior
        self.btn_wizard = self.add_action(
            "Start wizard", self._wizard, primary=True
        )
        self.btn_wizard.setObjectName("nccPrimaryButton")
        self.add_action("Dry-run wizard", self._dry_run)
        self.add_action("Backup /etc/nixos", self._backup)
        self.add_action("Show nix-shell command", self._shell_hint)
        self.add_action("Refresh", self.reload)

        target_bus().changed.connect(lambda _t: self.reload())
        self.reload()

    def reload(self) -> None:
        t = target_from_env() or ""
        pf = gather_preflight(remote_target=t)
        self._pf = pf

        self.lbl_target.setText(t or "This machine")
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

        self.lbl_mode.setText(mode_label(pf.recommended_mode))
        self.lbl_warn.setText(
            " · ".join(pf.warnings) if pf.warnings else "—"
        )

        if pf.recommended_mode == "migrate":
            self.lbl_next.setText(
                "1) Backup /etc/nixos  →  2) Start wizard  →  3) finish in "
                "nix-shell. Device starters appear only if hardware matches."
            )
        elif pf.recommended_mode == "reconfigure":
            self.lbl_next.setText(
                "NCC markers found under /etc/nixos. Prefer System sync for "
                "day-to-day updates; use the wizard to re-run install choices."
            )
        elif pf.recommended_mode == "fresh":
            self.lbl_next.setText(
                "Fresh path: Start wizard (or dry-run), then deploy from the "
                "install nix-shell on a NixOS system / ISO."
            )
        else:
            self.lbl_next.setText("Refresh preflight, then Start wizard.")

        note = f"Target bar: {t}. " if t else ""
        self.set_subtitle(
            f"{note}Preflight is local. Wizard opens separately — "
            "not embedded in this page."
        )

    def _wizard(self) -> None:
        pf = getattr(self, "_pf", None)
        if pf and pf.etc_nixos and pf.recommended_mode == "migrate":
            if not confirm(
                self,
                "Migrate",
                "/etc/nixos already exists. Prefer Backup first. Continue to wizard?",
            ):
                return
        self._run_ncc(["install", "wizard"], "Install wizard")

    def _dry_run(self) -> None:
        self._run_ncc(["install", "dry-run"], "Install dry-run")

    def _shell_hint(self) -> None:
        self._run_ncc(["install", "shell"], "Install shell hint")

    def _backup(self) -> None:
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
            # Fallback: cp -a (handles some permission edge cases better with sudo later)
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

        # Ensure wizard can discover blueprints when launched from GUI
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
