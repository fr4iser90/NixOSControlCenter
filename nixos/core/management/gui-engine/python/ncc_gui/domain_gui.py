"""Standalone domain window launcher used by `ncc <domain>` entries."""

from __future__ import annotations

import sys

from PySide6.QtWidgets import QMainWindow

from ncc_gui.app import ensure_app
from ncc_gui.catalog import DomainInfo, load_domains
from ncc_gui.pages.resolve import create_page_for


def run_page(widget, title: str, argv=None) -> int:
    app = ensure_app(argv)
    win = QMainWindow()
    win.setWindowTitle(title)
    win.resize(960, 640)
    win.setCentralWidget(widget)
    win.show()
    return app.exec()


def _info_for(domain_id: str) -> DomainInfo:
    for d in load_domains():
        if d.id == domain_id:
            return d
    # Standalone domain launch without full catalog (ncc-domain-gui <id>)
    return DomainInfo(
        id=domain_id,
        label=domain_id[:1].upper() + domain_id[1:] if domain_id else domain_id,
        description="",
        enabled=True,
        actions=[],
    )


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: ncc-domain-gui <domain>", file=sys.stderr)
        return 2
    name = sys.argv[1]
    # QApplication MUST exist before any QWidget (SshPage, etc.)
    ensure_app(sys.argv)
    info = _info_for(name)
    return run_page(create_page_for(info), f"ncc {name}")


if __name__ == "__main__":
    raise SystemExit(main())
