"""Embedded PTY terminal — pyte VT emulator + Qt view (shared kit for SSH, …).

Interactive sessions must use this widget (not Activity log). Activity logs use
``ncc_gui.ansi.strip_ansi`` for non-interactive command output only.
"""

from __future__ import annotations

import fcntl
import html
import os
import pty
import signal
import struct
import termios
from typing import Sequence

from PySide6.QtCore import QSocketNotifier, Qt, Signal
from PySide6.QtGui import QFont, QKeyEvent, QTextCursor
from PySide6.QtWidgets import QTextEdit, QVBoxLayout, QWidget

try:
    import pyte
    from pyte.screens import HistoryScreen
except ImportError:  # pragma: no cover - packaging must include pyte
    pyte = None  # type: ignore[assignment]
    HistoryScreen = None  # type: ignore[misc, assignment]


# xterm-ish named + bright colors (pyte uses these names)
_FG = {
    "black": "#1e1e1e",
    "red": "#cd3131",
    "green": "#0dbc79",
    "brown": "#e5e510",
    "yellow": "#e5e510",
    "blue": "#2472c8",
    "magenta": "#bc3fbc",
    "cyan": "#11a8cd",
    "white": "#e5e5e5",
    "default": "#e5e5e5",
    "brightblack": "#666666",
    "brightred": "#f14c4c",
    "brightgreen": "#23d18b",
    "brightyellow": "#f5f543",
    "brightblue": "#3b8eea",
    "brightmagenta": "#d670d6",
    "brightcyan": "#29b8db",
    "brightwhite": "#ffffff",
}


def _css_color(value: str | None, *, fallback: str) -> str:
    if not value or value in ("default",):
        return fallback
    if value.startswith("#") and len(value) in (4, 7):
        return value
    # "38;2;r;g;b" style sometimes appears as rgb
    if value.count(";") >= 2 and value.replace(";", "").isdigit():
        parts = value.split(";")
        if len(parts) >= 3:
            try:
                r, g, b = int(parts[-3]), int(parts[-2]), int(parts[-1])
                return f"#{r:02x}{g:02x}{b:02x}"
            except ValueError:
                pass
    if value.isdigit():
        idx = int(value)
        # rough 256-color cube / grayscale
        if idx < 16:
            names = [
                "black",
                "red",
                "green",
                "yellow",
                "blue",
                "magenta",
                "cyan",
                "white",
                "brightblack",
                "brightred",
                "brightgreen",
                "brightyellow",
                "brightblue",
                "brightmagenta",
                "brightcyan",
                "brightwhite",
            ]
            return _FG.get(names[idx], fallback)
        if 16 <= idx <= 231:
            idx -= 16
            r = idx // 36
            g = (idx % 36) // 6
            b = idx % 6
            def c(n: int) -> int:
                return 0 if n == 0 else 55 + n * 40

            return f"#{c(r):02x}{c(g):02x}{c(b):02x}"
        if 232 <= idx <= 255:
            g = 8 + (idx - 232) * 10
            return f"#{g:02x}{g:02x}{g:02x}"
    return _FG.get(value, fallback)


class PtyTerminal(QWidget):
    """Interactive PTY with VT100 parsing (colors, cursor, prompts)."""

    exited = Signal(int)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        self.view = QTextEdit()
        self.view.setObjectName("nccPtyTerminal")
        self.view.setReadOnly(True)
        self.view.setUndoRedoEnabled(False)
        self.view.setLineWrapMode(QTextEdit.LineWrapMode.NoWrap)
        self.view.setAcceptRichText(True)
        font = QFont("monospace")
        font.setStyleHint(QFont.StyleHint.Monospace)
        font.setPointSize(10)
        self.view.setFont(font)
        self.view.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.view.installEventFilter(self)
        layout.addWidget(self.view)

        self._master_fd: int | None = None
        self._pid: int | None = None
        self._notifier: QSocketNotifier | None = None
        self._cols = 80
        self._rows = 24
        self._screen = None
        self._stream = None
        if pyte is not None and HistoryScreen is not None:
            self._screen = HistoryScreen(self._cols, self._rows, history=5000)
            self._screen.set_mode(pyte.modes.LNM)
            self._stream = pyte.Stream(self._screen)

    @property
    def running(self) -> bool:
        return self._pid is not None

    def start(self, argv: Sequence[str], *, cwd: str | None = None) -> None:
        self.stop()
        self.view.clear()
        self._ensure_screen()
        if self._screen is not None:
            self._screen.reset()
            self._screen.resize(self._rows, self._cols)

        pid, master = pty.fork()
        if pid == 0:
            try:
                if cwd:
                    os.chdir(cwd)
                os.environ.setdefault("TERM", "xterm-256color")
                os.environ.setdefault("COLORTERM", "truecolor")
                # Prefer a simpler prompt if the remote respects it (local ssh often does)
                os.environ.setdefault("TERM_PROGRAM", "ncc-gui")
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
        self.view.setFocus()

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

    def _ensure_screen(self) -> None:
        if self._screen is not None or pyte is None or HistoryScreen is None:
            return
        self._screen = HistoryScreen(self._cols, self._rows, history=5000)
        self._stream = pyte.Stream(self._screen)

    def _on_ready(self, *_args) -> None:
        if self._master_fd is None:
            return
        try:
            chunk = os.read(self._master_fd, 8192)
        except BlockingIOError:
            return
        except OSError:
            chunk = b""
        if not chunk:
            code = 0
            if self._pid is not None:
                try:
                    _pid, status = os.waitpid(self._pid, 0)
                    code = (
                        os.waitstatus_to_exitcode(status)
                        if hasattr(os, "waitstatus_to_exitcode")
                        else 0
                    )
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

        text = chunk.decode("utf-8", errors="replace")
        if self._stream is not None and self._screen is not None:
            self._stream.feed(text)
            self._render_screen()
        else:
            # Fallback without pyte: strip escapes (same as Activity)
            from ncc_gui.ansi import strip_ansi

            self.view.moveCursor(QTextCursor.MoveOperation.End)
            self.view.insertPlainText(strip_ansi(text))
            self.view.moveCursor(QTextCursor.MoveOperation.End)

    def _render_screen(self) -> None:
        assert self._screen is not None
        parts: list[str] = [
            '<pre style="margin:0;font-family:monospace;font-size:10pt;'
            'background:#0d1117;color:#e5e5e5;">'
        ]
        # Scrollback (history.top is oldest→newest deque of line mappings)
        hist = getattr(self._screen, "history", None)
        if hist is not None:
            for line in list(hist.top):
                parts.append(self._format_line_map(line))
                parts.append("\n")
        for y in range(self._screen.lines):
            parts.append(self._format_buffer_row(y))
            if y < self._screen.lines - 1:
                parts.append("\n")
        parts.append("</pre>")
        # Preserve scroll position near bottom if already there
        bar = self.view.verticalScrollBar()
        at_bottom = bar.value() >= bar.maximum() - 4
        self.view.setHtml("".join(parts))
        if at_bottom:
            bar.setValue(bar.maximum())

    def _format_buffer_row(self, y: int) -> str:
        assert self._screen is not None
        buf = self._screen.buffer
        cells = []
        for x in range(self._screen.columns):
            ch = buf[y][x]
            cells.append(ch)
        return self._format_chars(cells)

    def _format_line_map(self, line) -> str:
        # history lines are mappings column→Char
        if not line:
            return ""
        max_x = max(line.keys()) if hasattr(line, "keys") else len(line) - 1
        chars = []
        for x in range(max_x + 1):
            chars.append(line[x])
        return self._format_chars(chars)

    def _format_chars(self, chars) -> str:
        out: list[str] = []
        for ch in chars:
            data = getattr(ch, "data", " ") or " "
            if data == "\x00":
                data = " "
            fg = _css_color(getattr(ch, "fg", None), fallback="#e5e5e5")
            bg = getattr(ch, "bg", None)
            styles = [f"color:{fg}"]
            if bg and bg not in ("default", None):
                styles.append(f"background-color:{_css_color(bg, fallback='#0d1117')}")
            if getattr(ch, "bold", False):
                styles.append("font-weight:700")
            if getattr(ch, "italics", False) or getattr(ch, "italic", False):
                styles.append("font-style:italic")
            if getattr(ch, "underscore", False) or getattr(ch, "underline", False):
                styles.append("text-decoration:underline")
            if getattr(ch, "reverse", False):
                styles = [f"color:#0d1117", f"background-color:{fg}"]
            out.append(
                f'<span style="{";".join(styles)}">{html.escape(data)}</span>'
            )
        return "".join(out).rstrip() or " "

    def eventFilter(self, obj, event):  # noqa: N802
        if obj is self.view and event.type() == event.Type.KeyPress and isinstance(
            event, QKeyEvent
        ):
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
        fm = self.view.fontMetrics()
        cols = max(40, self.view.viewport().width() // max(1, fm.horizontalAdvance("M")))
        rows = max(8, self.view.viewport().height() // max(1, fm.height()))
        self._cols, self._rows = cols, rows
        if self._screen is not None:
            try:
                self._screen.resize(rows, cols)
            except Exception:  # noqa: BLE001
                pass
        if self._master_fd is None:
            return
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
    if key == Qt.Key.Key_Home:
        return b"\x1b[H"
    if key == Qt.Key.Key_End:
        return b"\x1b[F"
    if key == Qt.Key.Key_Delete:
        return b"\x1b[3~"
    if key == Qt.Key.Key_C and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x03"
    if key == Qt.Key.Key_D and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x04"
    if key == Qt.Key.Key_L and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x0c"
    if key == Qt.Key.Key_Z and mods & Qt.KeyboardModifier.ControlModifier:
        return b"\x1a"
    text = event.text()
    if text:
        return text.encode("utf-8", errors="replace")
    return None
