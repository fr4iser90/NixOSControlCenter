"""Root NCC Qt shell — domains from registry catalog only."""

from __future__ import annotations

from ncc_gui.app import run_window
from ncc_gui.catalog import load_domains
from ncc_gui.pages.resolve import create_page_for
from ncc_gui.reload import pop_resume_domain, root_relaunch_argv, set_relaunch_argv
from ncc_gui.shell import NccShell


def main() -> int:
    domains = load_domains()

    def factory() -> NccShell:
        shell = NccShell(domains, create_page_for, title="NixOS Control Center")
        resume = pop_resume_domain()
        if resume:
            shell.select_domain(resume)
        # Watcher already installed by ensure_app; only override relaunch target.
        set_relaunch_argv(
            lambda: root_relaunch_argv(domain_id=shell.current_domain_id())
        )
        return shell

    return run_window(factory)


if __name__ == "__main__":
    raise SystemExit(main())
