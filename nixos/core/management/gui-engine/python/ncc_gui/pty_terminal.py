"""Minimal embedded PTY terminal (PySide6 + pty). Good enough for interactive ssh."""

from __future__ import annotations

import fcntl
import os
import pty
import signal
import struct
import termios
from typing import Sequence

from PySide6.QtCore import QSocketNotifier, Qt, Signal
from PySide6.QtGui import QFont, QKeyEvent, QTextCursor
from PySide6.QtWidgets import QPlainTextEdit, QVBoxLayout, QWidget


class PtyTerminal(QWidget):
    exited = Signal(int)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.view = QPlainTextEdit()
        self.view.setReadOnly(False)
        self.view.setUndoRedoEnabled(False)
        self.view.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        font = QFont("monospace")
        font.setStyleHint(QFont.StyleHint.Monospace)
        font.setPointSize(10)
        self.view.setFont(font)
        self.view.installEventFilter(self)
        layout.addWidget(self.view)

        self._master_fd: int | None = None
        self._pid: int | None = None
        self._notifier: QSocketNotifier | None = None

    @property
    def running(self) -> bool:
        return self._pid is not None

    def start(self, argv: Sequence[str], *, cwd: str | None = None) -> None:
        self.stop()
        self.view.clear()
        pid, master = pty.fork()
        if pid == 0:
            # Child
            try:
                if cwd:
                    os.chdir(cwd)
                os.execvp(argv[0], list(argv))
            except OSError as exc:
                os.write(2, f"exec failed: {exc}\n".encode())
                os._exit(127)
            return

        self._pid = pid
        self._master_fd = master
        flags = fcntl.fcntl(master, fcntl.F_GETFL)
        fcntl.fcntl(master, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        self._notifier = QSocketNotifier(master, QSocketNotifier.Type.Read, self)
        self._notifier.activated.connect(self._on_ready)
        self._apply_winsize()

    def stop(self) -> None:
        if self._notifier is not None:
            self._notifier.setEnabled(False)
            self._notifier.deleteLater()
            self._notifier = None
        if self._pid is not None:
            try:
                os.kill(self._pid, signal.SIGHUP)
            except ProcessLookupError:
                pass
            try:
                os.waitpid(self._pid, os.WNOHANG)
            except ChildProcessError:
                pass
            self._pid = None
        if self._master_fd is not None:
            try:
                os.close(self._master_fd)
            except OSError:
                pass
            self._master_fd = None

    def write_bytes(self, data: bytes) -> None:
        if self._master_fd is None or not data:
            return
        try:
            os.write(self._master_fd, data)
        except OSError:
            pass

    def _on_ready(self, *_args) -> None:
        if self._master_fd is None:
            return
        try:
            chunk = os.read(self._master_fd, 4096)
        except BlockingIOError:
            return
        except OSError:
            chunk = b""
        if not chunk:
            code = 0
            if self._pid is not None:
                try:
                    _pid, status = os.waitpid(self._pid, 0)
                    code = os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else 0
                except ChildProcessError:
                    pass
                self._pid = None
            if self._master_fd is not None:
                try:
                    os.close(self._master_fd)
                except OSError:
                    pass
                self._master_fd = None
            if self._notifier is not None:
                self._notifier.setEnabled(False)
            self.exited.emit(code)
            return
        # Strip crude CSI for readability; keep basic newlines/tabs.
        text = chunk.decode("utf-8", errors="replace")
        text = _strip_ansi(text)
        self.view.moveCursor(QTextCursor.MoveOperation.End)
        self.view.insertPlainText(text)
        self.view.moveCursor(QTextCursor.MoveOperation.End)

    def eventFilter(self, obj, event):  # noqa: N802
        if obj is self.view and event.type() == event.Type.KeyPress and isinstance(event, QKeyEvent):
            if self._master_fd is None:
                return False
            data = _key_to_bytes(event)
            if data is not None:
                self.write_bytes(data)
                return True
        return super().eventFilter(obj, event)

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        self._apply_winsize()

    def _apply_winsize(self) -> None:
        if self._master_fd is None:
            return
        # Approximate cols/rows from widget size / font metrics
        fm = self.view.fontMetrics()
        cols = max(20, self.view.viewport().width() // max(1, fm.horizontalAdvance("M")))
        rows = max(5, self.view.viewport().height() // max(1, fm.height()))
        winsize = struct.pack("HHHH", rows, cols, 0, 0)
        try:
            fcntl.ioctl(self._master_fd, termios.TIOCSWINSZ, winsize)
        except OSError:
            pass

    def closeEvent(self, event) -> None:  # noqa: N802
        self.stop()
        super().closeEvent(event)


def _key_to_bytes(event: QKeyEvent) -> bytes | None:
    key = event.key()
    mods = event.modifiers()
    if key == Qt.Key.Key_Return or key == Qt.Key.Key_Enter:
        return b"\r"
    if key == Qt.Key.Key_Backspace:
        return b"\x7f"
    if key == Qt.Key.Key_Tab:
        return b"\t"
    if key == Qt.Key.Key_Escape:
        return b"\x1b"
    if key == Qt.Key.Key_Up:
        return b"\x1b[A"
    if key == Qt.Key.Key_Down:
        return b"\x1b[B"
    if key == Qt.Key.Key_Right:
        return b"\x1b[C"
    if key == Qt.Key.Key_Left:
        return b"\x1b[D"
    if key == Qt.Key.Key_C and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x03"
    if key == Qt.Key.Key_D and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x04"
    if key == Qt.Key.Key_L and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x0c"
    text = event.text()
    if text:
        return text.encode("utf-8", errors="replace")
    return None


def _strip_ansi(s: str) -> str:
    import re

    # CSI sequences + OSC
    s = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", s)
    s = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", s)
    s = re.sub(r"\x1b[()][0-9A-Za-z]", "", s)
    return s.replace("\r\n", "\n").replace("\r", "\n")
