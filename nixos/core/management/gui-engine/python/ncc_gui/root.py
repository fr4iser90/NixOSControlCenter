"""Root NCC Qt shell — domains from registry catalog only."""

from __future__ import annotations

from ncc_gui.app import run_window
from ncc_gui.catalog import load_domains
from ncc_gui.pages.resolve import create_page_for
from ncc_gui.shell import NccShell


def main() -> int:
    domains = load_domains()
    return run_window(
        lambda: NccShell(domains, create_page_for, title="NixOS Control Center")
    )


if __name__ == "__main__":
    raise SystemExit(main())
