"""Minimal PySide6 control window for Chronicle (replaces GTK default path)."""

from __future__ import annotations

import os
import subprocess
import sys

from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

try:
    from ncc_gui.app import ensure_app
except ImportError:  # pragma: no cover
    from PySide6.QtWidgets import QApplication

    def ensure_app(argv=None):
        return QApplication.instance() or QApplication(argv or sys.argv)


def _bin() -> str:
    return os.environ.get("NCC_CHRONICLE_BIN", "chronicle")


def run_cmd(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [_bin(), *args],
        check=False,
        capture_output=True,
        text=True,
    )


class ChronicleWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("ncc chronicle")
        self.resize(520, 360)
        root = QWidget()
        self.setCentralWidget(root)
        layout = QVBoxLayout(root)
        layout.addWidget(QLabel("Chronicle — record workflows (ncc chronicle …)"))

        row = QHBoxLayout()
        for label, args in [
            ("Start", ("start", "--daemon")),
            ("Stop", ("stop",)),
            ("Capture", ("capture",)),
            ("Status", ("status",)),
            ("List", ("list",)),
        ]:
            btn = QPushButton(label)
            btn.clicked.connect(lambda _=False, a=args: self._run(a))
            row.addWidget(btn)
        layout.addLayout(row)

        self.log = QTextEdit()
        self.log.setReadOnly(True)
        layout.addWidget(self.log, stretch=1)
        self._run(("status",))

    def _run(self, args: tuple[str, ...]) -> None:
        proc = run_cmd(*args)
        out = (proc.stdout or "") + (proc.stderr or "")
        self.log.append(f"$ ncc chronicle {' '.join(args)}\n{out}\n")
        if proc.returncode != 0:
            QMessageBox.warning(self, "Chronicle", out or f"exit {proc.returncode}")


def main(argv: list[str] | None = None) -> int:
    app = ensure_app(argv)
    win = ChronicleWindow()
    win.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
