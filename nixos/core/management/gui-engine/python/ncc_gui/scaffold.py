"""NCC GUI page kit — Header → Content → Activity → Footer (Actions).

Use ``DomainPage`` for every domain ``ui/gui/page.py``. See doc/GUI-DESIGN.md.
"""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Callable, Sequence

from PySide6.QtCore import QProcess, QProcessEnvironment
from PySide6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.commit_bar import CommitController
from ncc_gui.dialogs import confirm, error
from ncc_gui.theme import APP_STYLE


class DomainPage(QWidget):
    """
    Complete page scaffold from gui-engine.

    Order is fixed (app-like footer):
      1. Header (title + subtitle)
      2. Content blocks (stretch)
      3. Activity log (optional)
      4. Footer Actions — domain buttons left, CommitBar right (pinned bottom)

    Config writes go through ``self.commit`` (stage → Save/Undo → Apply).
    """

    def __init__(
        self,
        title: str,
        subtitle: str = "",
        *,
        activity: bool = True,
        activity_max_height: int | None = 180,
        commit_bar: bool = True,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        self._proc: QProcess | None = None
        self._on_proc_done: Callable[[int], None] | None = None
        self._root = QVBoxLayout(self)
        self._root.setContentsMargins(20, 16, 20, 16)
        self._root.setSpacing(8)
        root = self._root

        # 1. Header
        heading = QLabel(title)
        heading.setObjectName("nccPageTitle")
        root.addWidget(heading)
        self._subtitle = QLabel(subtitle)
        self._subtitle.setObjectName("nccPageSubtitle")
        self._subtitle.setWordWrap(True)
        self._subtitle.setVisible(bool(subtitle))
        root.addWidget(self._subtitle)

        # 2. Content (fills remaining space above footer)
        self._content = QVBoxLayout()
        self._content.setSpacing(8)
        root.addLayout(self._content, stretch=1)

        # 3. Activity (above footer — not below the commit buttons)
        self._activity_box: QGroupBox | None = None
        self.log: QTextEdit | None = None
        if activity:
            self._activity_box = QGroupBox("Activity")
            log_l = QVBoxLayout(self._activity_box)
            self.log = QTextEdit()
            self.log.setObjectName("nccActivityLog")
            self.log.setReadOnly(True)
            self.log.setPlaceholderText("Command output appears here after an action…")
            if activity_max_height is None:
                self.log.setMinimumHeight(160)
            else:
                self.log.setMaximumHeight(activity_max_height)
            log_l.addWidget(self.log)
            root.addWidget(self._activity_box, stretch=0)

        # 4. Footer — domain buttons left, CommitBar (Undo/Save/Apply) bottom-right
        self._actions_box = QGroupBox("Actions")
        self._actions_box.setObjectName("nccPageFooter")
        self._actions_col = QVBoxLayout(self._actions_box)
        self._button_row = QHBoxLayout()
        self._actions_col.addLayout(self._button_row)
        self._button_row.addStretch(1)
        self._has_action_button = False
        self.commit: CommitController | None = None
        if commit_bar:
            self.commit = CommitController(self)
            self._button_row.addWidget(self.commit.bar)
            self._actions_box.setVisible(True)
        else:
            self._actions_box.setVisible(False)
        root.addWidget(self._actions_box, stretch=0)

    # ----- header -----

    def set_subtitle(self, text: str) -> None:
        self._subtitle.setText(text)
        self._subtitle.setVisible(bool(text.strip()))

    # ----- content -----

    def add_block(self, title: str) -> QGroupBox:
        """Framed content block (Settings, Status, Stacks, …)."""
        box = QGroupBox(title)
        self._content.addWidget(box)
        return box

    def add_form_block(self, title: str) -> QFormLayout:
        box = self.add_block(title)
        form = QFormLayout(box)
        return form

    def add_list_block(self, title: str) -> tuple[QGroupBox, QListWidget]:
        """Content block with a list (hosts, stacks, users, …)."""
        box = self.add_block(title)
        col = QVBoxLayout(box)
        lst = QListWidget()
        col.addWidget(lst)
        return box, lst

    def add_content_widget(self, widget: QWidget, *, stretch: int = 0) -> None:
        """Add a pre-built widget into the content zone (e.g. splitter)."""
        self._content.addWidget(widget, stretch=stretch)

    def add_content_layout(self, layout) -> None:
        self._content.addLayout(layout)

    def set_busy(self) -> bool:
        """True if a root process is already running (shows error)."""
        if self._proc is not None and self._proc.state() != QProcess.ProcessState.NotRunning:
            error(self, "Busy", "A command is already running.")
            return True
        return False

    # ----- actions -----

    def _ensure_actions_visible(self) -> None:
        self._actions_box.setVisible(True)

    def add_actions_hint(self, text: str) -> QLabel:
        self._ensure_actions_visible()
        tip = QLabel(text)
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        # Insert above button row
        self._actions_col.insertWidget(self._actions_col.count() - 1, tip)
        return tip

    def add_actions_widget(self, widget: QWidget) -> None:
        """Checkbox / extra control inside Actions (above buttons)."""
        self._ensure_actions_visible()
        self._actions_col.insertWidget(self._actions_col.count() - 1, widget)

    def add_action(
        self,
        label: str,
        slot: Callable[[], None],
        *,
        primary: bool = False,
    ) -> QPushButton:
        self._ensure_actions_visible()
        btn = QPushButton(label)
        btn.clicked.connect(lambda _=False: slot())
        # Primary first among buttons
        if primary and not self._has_action_button:
            self._button_row.insertWidget(0, btn)
        else:
            idx = self._button_row.count() - 1  # before stretch
            self._button_row.insertWidget(max(idx, 0), btn)
        self._has_action_button = True
        return btn

    # ----- activity -----

    def log_clear(self) -> None:
        if self.log is not None:
            self.log.clear()

    def log_append(self, text: str) -> None:
        if self.log is None:
            return
        self.log.append(strip_ansi(text))

    def log_write(self, text: str) -> None:
        """Append without extra bullet formatting; strips ANSI."""
        if self.log is None:
            return
        plain = strip_ansi(text)
        self.log.moveCursor(self.log.textCursor().MoveOperation.End)
        self.log.insertPlainText(plain)
        self.log.moveCursor(self.log.textCursor().MoveOperation.End)

    # ----- run ncc -----

    def run_ncc(
        self,
        *args: str,
        need_confirm: str | None = None,
        timeout: float | None = 180,
        follow_target: bool = False,
        target: str | None = None,
        log: bool = True,
        show_error: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        """Sync ``ncc``. With ``follow_target=True``, uses global Target / env."""
        if need_confirm and not confirm(self, need_confirm, f"Run “{need_confirm}” now?"):
            return subprocess.CompletedProcess(args=["ncc", *args], returncode=0, stdout="", stderr="cancelled")
        from ncc_gui.remote import run_ncc as _run
        from ncc_gui.remote import target_from_env

        host = target
        if follow_target and host is None:
            host = target_from_env()
        proc = _run(*args, target=host, timeout=timeout)
        out = strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
        label = " ".join(args[:2]) if args else "ncc"
        pretty = out or ("Done." if proc.returncode == 0 else "Failed.")
        if log:
            where = f" @ {host}" if host else ""
            self.log_append(f"• {label}{where}\n{pretty}\n")
        if show_error and proc.returncode != 0:
            error(self, label, pretty)
        return proc

    def run_ncc_root(
        self,
        args: Sequence[str],
        *,
        label: str = "Apply",
        on_done: Callable[[int], None] | None = None,
    ) -> None:
        """Async elevated ``ncc …``. Prefer passwordless sudo, then pkexec.

        Order (NOPASSWD admin must not see a password dialog):
          1. already root → ``ncc`` directly
          2. ``sudo -n`` works → ``sudo -n ncc …``
          3. pkexec
          4. interactive sudo
        """
        import os
        import subprocess

        ncc = shutil.which("ncc") or "ncc"
        argv_tail = list(args)

        if os.geteuid() == 0:
            program, argv = ncc, argv_tail
        elif shutil.which("sudo") and subprocess.run(
            ["sudo", "-n", "true"],
            check=False,
            capture_output=True,
        ).returncode == 0:
            program, argv = "sudo", ["-n", ncc, *argv_tail]
        elif shutil.which("pkexec"):
            program, argv = "pkexec", [ncc, *argv_tail]
        elif shutil.which("sudo"):
            program, argv = "sudo", [ncc, *argv_tail]
        else:
            error(self, label, "Need sudo or pkexec for this action.")
            return
        self._start_ncc_process(program, argv, label=label, on_done=on_done)

    def run_ncc_async(
        self,
        args: Sequence[str],
        *,
        label: str = "Run",
        on_done: Callable[[int], None] | None = None,
        env: dict[str, str] | None = None,
    ) -> None:
        """Async ``ncc …`` as the current user (script may self-elevate via ncc-priv)."""
        ncc = shutil.which("ncc") or "ncc"
        self._start_ncc_process(ncc, list(args), label=label, on_done=on_done, env=env)

    def _start_ncc_process(
        self,
        program: str,
        argv: Sequence[str],
        *,
        label: str,
        on_done: Callable[[int], None] | None,
        env: dict[str, str] | None = None,
    ) -> None:
        if self.set_busy():
            return
        self.log_append(f"• {label}\n")
        self._on_proc_done = on_done
        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._on_root_out)
        self._proc.finished.connect(lambda code, _s: self._finish_root(code, label))
        pe = QProcessEnvironment.systemEnvironment()
        if env:
            for key, val in env.items():
                pe.insert(key, val)
        self._proc.setProcessEnvironment(pe)
        self._proc.start(program, list(argv))
        if not self._proc.waitForStarted(5000):
            error(self, label, "Failed to start.")
            self._proc = None
            self._on_proc_done = None

    def _on_root_out(self) -> None:
        if self._proc is None:
            return
        data = bytes(self._proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        if data:
            self.log_write(data)

    def _finish_root(self, code: int, label: str) -> None:
        self.log_append(f"\n[{label}] exit {code}\n")
        cb = self._on_proc_done
        self._proc = None
        self._on_proc_done = None
        if code != 0:
            error(self, label, f"Finished with exit code {code}. See Activity.")
        if cb is not None:
            cb(code)


# Back-compat alias
PageScaffold = DomainPage
