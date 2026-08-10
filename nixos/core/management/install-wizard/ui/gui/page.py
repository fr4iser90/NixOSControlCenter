"""Install — launch wizard / dry-run / shell hint (DomainPage kit)."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from ncc_gui.dialogs import error, info
from ncc_gui.scaffold import DomainPage


def _repo_hint() -> str:
    for key in ("NCC_INSTALL_REPO",):
        v = (os.environ.get(key) or "").strip()
        if v and (Path(v) / "nixos" / "core").is_dir():
            return v
    d = Path.cwd().resolve()
    for p in [d, *d.parents]:
        if (p / "nixos" / "core" / "management").is_dir():
            return str(p)
    return ""


class InstallPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Install",
            "Run the install / migrate wizard, dry-run, or open the full "
            "install nix-shell from a repo checkout.",
            parent=parent,
        )
        self.add_actions_hint(
            "Wizard writes answers for the install shell. "
            "Full deploy still needs: nix-shell <repo>/shell.nix"
        )
        self.add_action("Open wizard", self._wizard)
        self.add_action("Dry-run wizard", self._dry_run)
        self.add_action("Show nix-shell command", self._shell_hint)
        self.add_action("Refresh", self.reload)
        self.reload()

    def reload(self) -> None:
        repo = _repo_hint()
        self.set_subtitle(
            f"Repo: {repo}" if repo else "Repo: (not found — set NCC_INSTALL_REPO)"
        )

    def _wizard(self) -> None:
        self._run_ncc(["install", "wizard"], "Install wizard")

    def _dry_run(self) -> None:
        self._run_ncc(["install", "dry-run"], "Install dry-run")

    def _shell_hint(self) -> None:
        self._run_ncc(["install", "shell"], "Install shell hint")

    def _run_ncc(self, argv: list[str], label: str) -> None:
        ncc = shutil.which("ncc")
        if not ncc:
            error(self, "ncc missing", "ncc is not on PATH.")
            return

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
