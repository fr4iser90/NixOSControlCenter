"""Desktop companion: frameless always-on-top avatar + multi-chat overlay."""

from __future__ import annotations

import math
import os
import sys
import traceback
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PySide6.QtCore import (
    QPoint,
    QRectF,
    Qt,
    QThread,
    QTimer,
    Signal,
)
from PySide6.QtGui import (
    QColor,
    QFont,
    QKeySequence,
    QMouseEvent,
    QPainter,
    QPainterPath,
    QPen,
    QShortcut,
)
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSizePolicy,
    QStackedWidget,
    QTextEdit,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

# Avatar moods driven by chat + presence
STATE_IDLE = "idle"
STATE_THINKING = "thinking"
STATE_SPEAKING = "speaking"
STATE_PAUSED = "paused"
STATE_ERROR = "error"

PANEL_NONE = "none"
PANEL_HISTORY = "history"
PANEL_SKILLS = "skills"
PANEL_CRON = "cron"
PANEL_JOBS = "jobs"


def _start_system_move(widget: QWidget) -> bool:
    """Wayland-safe window drag (frameGeometry.move is a no-op on many compositors)."""
    win = widget.window()
    handle = win.windowHandle() if win is not None else None
    if handle is None:
        return False
    try:
        return bool(handle.startSystemMove())
    except Exception:
        return False


class _CompanionChatWorker(QThread):
    event = Signal(str, object)  # slot_id, event
    failed = Signal(str, str)  # slot_id, message

    def __init__(
        self,
        slot_id: str,
        text: str,
        *,
        harness_name: str,
        session: Any | None = None,
        cwd: str | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self.slot_id = slot_id
        self._session = session
        self._text = text
        self._harness_name = harness_name
        self._cwd = cwd

    def run(self) -> None:
        try:
            from .harness import get_harness

            backend = get_harness(self._harness_name)
            for ev in backend.send(
                self._text,
                cwd=self._cwd,
                session=self._session if self._harness_name == "native" else None,
            ):
                self.event.emit(self.slot_id, ev)
        except Exception as exc:  # noqa: BLE001
            self.failed.emit(self.slot_id, f"{exc}\n{traceback.format_exc()}")


@dataclass
class ChatSlot:
    """One parallel companion chat (own session + stream buffer)."""

    id: str
    title: str = "Chat"
    session: Any | None = None
    worker: _CompanionChatWorker | None = None
    reply_buf: str = ""
    thinking_buf: str = ""
    transcript: str = ""
    busy: bool = False
    avatar_state: str = STATE_IDLE
    last_error: str = ""
    harness: str = "native"

    @staticmethod
    def new(title: str = "Chat") -> "ChatSlot":
        return ChatSlot(id=uuid.uuid4().hex[:8], title=title)


class AvatarCanvas(QWidget):
    """Painted character with simple idle / blink / talk animation."""

    clicked = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFixedSize(160, 160)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setCursor(Qt.CursorShape.SizeAllCursor)
        self._state = STATE_IDLE
        self._phase = 0.0
        self._blink = 0.0
        self._drag_origin: QPoint | None = None
        self._win_origin: QPoint | None = None

        self._timer = QTimer(self)
        self._timer.setInterval(40)
        self._timer.timeout.connect(self._tick)
        self._timer.start()

    def set_state(self, state: str) -> None:
        if state != self._state:
            self._state = state
            self.update()

    def state(self) -> str:
        return self._state

    def _tick(self) -> None:
        self._phase += 0.08
        if self._state in (STATE_IDLE, STATE_PAUSED):
            self._blink = max(0.0, self._blink - 0.15)
            if int(self._phase * 10) % 100 == 0:
                self._blink = 1.0
        elif self._state == STATE_SPEAKING:
            self._blink = 0.0
        self.update()

    def paintEvent(self, event) -> None:  # noqa: N802
        del event
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        w, h = self.width(), self.height()
        cx, cy = w / 2, h / 2 + 8

        p.setBrush(QColor(0, 0, 0, 40))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(QRectF(cx - 42, h - 22, 84, 14))

        bounce = 0.0
        if self._state == STATE_THINKING:
            bounce = math.sin(self._phase * 2) * 3
        elif self._state == STATE_SPEAKING:
            bounce = math.sin(self._phase * 4) * 2
        elif self._state == STATE_IDLE:
            bounce = math.sin(self._phase) * 1.5

        if self._state == STATE_ERROR:
            body = QColor("#c45c5c")
            accent = QColor("#8a3030")
        elif self._state == STATE_PAUSED:
            body = QColor("#7a8a9a")
            accent = QColor("#4a5560")
        elif self._state == STATE_THINKING:
            body = QColor("#6b8cae")
            accent = QColor("#3d5a80")
        elif self._state == STATE_SPEAKING:
            body = QColor("#5a9e7a")
            accent = QColor("#2d6a4f")
        else:
            body = QColor("#6a8fbf")
            accent = QColor("#3d5a80")

        head = QRectF(cx - 48, cy - 70 + bounce, 96, 96)
        p.setBrush(body)
        p.setPen(QPen(accent, 2.5))
        p.drawEllipse(head)

        p.setBrush(accent)
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(QRectF(cx - 38, cy - 78 + bounce, 16, 16))
        p.drawEllipse(QRectF(cx + 22, cy - 78 + bounce, 16, 16))

        eye_y = cy - 40 + bounce
        eye_open = 10 * (1.0 - min(1.0, self._blink))
        if self._state == STATE_PAUSED:
            p.setPen(QPen(QColor("#1a1a1a"), 3, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            p.drawLine(int(cx - 28), int(eye_y), int(cx - 12), int(eye_y))
            p.drawLine(int(cx + 12), int(eye_y), int(cx + 28), int(eye_y))
        else:
            p.setBrush(QColor("#1a1a1a"))
            p.setPen(Qt.PenStyle.NoPen)
            if eye_open < 2:
                p.setPen(QPen(QColor("#1a1a1a"), 2))
                p.drawLine(int(cx - 26), int(eye_y), int(cx - 14), int(eye_y))
                p.drawLine(int(cx + 14), int(eye_y), int(cx + 26), int(eye_y))
            else:
                p.drawEllipse(QRectF(cx - 28, eye_y - eye_open / 2, 14, eye_open))
                p.drawEllipse(QRectF(cx + 14, eye_y - eye_open / 2, 14, eye_open))
                p.setBrush(QColor(255, 255, 255, 200))
                p.drawEllipse(QRectF(cx - 24, eye_y - eye_open / 2 + 1, 4, 4))
                p.drawEllipse(QRectF(cx + 18, eye_y - eye_open / 2 + 1, 4, 4))

        mouth_y = cy - 8 + bounce
        p.setPen(QPen(QColor("#1a1a1a"), 2.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        if self._state == STATE_SPEAKING:
            open_amt = 4 + abs(math.sin(self._phase * 6)) * 8
            p.setBrush(QColor("#1a1a1a"))
            p.setPen(Qt.PenStyle.NoPen)
            p.drawEllipse(QRectF(cx - 10, mouth_y - open_amt / 2, 20, open_amt))
        elif self._state == STATE_ERROR:
            path = QPainterPath()
            path.moveTo(cx - 14, mouth_y + 4)
            path.quadTo(cx, mouth_y - 6, cx + 14, mouth_y + 4)
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawPath(path)
        elif self._state == STATE_THINKING:
            p.drawArc(int(cx - 12), int(mouth_y - 6), 24, 14, 20 * 16, 140 * 16)
        else:
            path = QPainterPath()
            path.moveTo(cx - 12, mouth_y)
            path.quadTo(cx, mouth_y + 10, cx + 12, mouth_y)
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.drawPath(path)

        if self._state == STATE_THINKING:
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(accent)
            for i in range(3):
                o = (math.sin(self._phase * 3 + i) + 1) / 2
                p.setOpacity(0.4 + 0.6 * o)
                p.drawEllipse(QRectF(cx + 40 + i * 10, cy - 70 + bounce - o * 6, 7, 7))
            p.setOpacity(1.0)

        p.setPen(QColor("#334"))
        font = QFont()
        font.setPointSize(9)
        font.setBold(True)
        p.setFont(font)
        label = {
            STATE_IDLE: "ready",
            STATE_THINKING: "thinking…",
            STATE_SPEAKING: "speaking",
            STATE_PAUSED: "paused",
            STATE_ERROR: "error",
        }.get(self._state, self._state)
        p.drawText(QRectF(0, h - 18, w, 16), Qt.AlignmentFlag.AlignHCenter, label)

    def mousePressEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            if not _start_system_move(self):
                win = self.window()
                self._drag_origin = event.globalPosition().toPoint()
                self._win_origin = win.frameGeometry().topLeft()
            self.clicked.emit()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if (
            self._drag_origin is not None
            and self._win_origin is not None
            and event.buttons() & Qt.MouseButton.LeftButton
        ):
            delta = event.globalPosition().toPoint() - self._drag_origin
            self.window().move(self._win_origin + delta)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        self._drag_origin = None
        self._win_origin = None
        super().mouseReleaseEvent(event)


class CompanionWindow(QWidget):
    """Always-on-top companion: avatar + multi-chat + quick panels."""

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("NCC Companion")
        # Window (not Tool): Tool often steals/blocks keyboard focus on Plasma/Wayland.
        self.setWindowFlags(
            Qt.WindowType.Window
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setMinimumWidth(300)
        self.resize(320, 520)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        self._slots: list[ChatSlot] = [ChatSlot.new("Chat 1")]
        self._active_id: str = self._slots[0].id
        self._panel = PANEL_NONE
        self._settings: Any | None = None
        self._drag_origin: QPoint | None = None
        self._win_origin: QPoint | None = None

        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(6)

        # Transparent drag zone + avatar
        self.avatar = AvatarCanvas()
        root.addWidget(self.avatar, alignment=Qt.AlignmentFlag.AlignHCenter)

        # Solid glass panel for interactive chrome
        self.panel = QFrame()
        self.panel.setObjectName("glass")
        glass = QVBoxLayout(self.panel)
        glass.setContentsMargins(10, 10, 10, 10)
        glass.setSpacing(6)

        header = QHBoxLayout()
        title = QLabel("NCC")
        f = title.font()
        f.setBold(True)
        f.setPointSize(11)
        title.setFont(f)
        header.addWidget(title)
        header.addStretch()
        self.presence_lbl = QLabel("")
        self.presence_lbl.setStyleSheet("color: #667;")
        header.addWidget(self.presence_lbl)
        self.harness_lbl = QLabel("native")
        self.harness_lbl.setStyleSheet("color: #556; font-size: 10px;")
        self.harness_lbl.setToolTip("Active harness (native / qwen / dsh)")
        header.addWidget(self.harness_lbl)
        glass.addLayout(header)

        # Chat tabs
        self.tabs_row = QHBoxLayout()
        self.tabs_row.setSpacing(4)
        glass.addLayout(self.tabs_row)
        self._tab_buttons: dict[str, QToolButton] = {}

        # Icon toolbar
        tools = QHBoxLayout()
        tools.setSpacing(4)
        self._tool_btns: dict[str, QToolButton] = {}
        for key, label, tip in (
            (PANEL_HISTORY, "Hist", "Session history"),
            (PANEL_SKILLS, "Skill", "Skills / templates"),
            (PANEL_CRON, "Cron", "Schedules / cron"),
            (PANEL_JOBS, "Jobs", "Agent jobs"),
        ):
            btn = QToolButton()
            btn.setText(label)
            btn.setToolTip(tip)
            btn.setCheckable(True)
            btn.clicked.connect(lambda checked=False, k=key: self._toggle_panel(k))
            tools.addWidget(btn)
            self._tool_btns[key] = btn
        tools.addStretch()
        new_btn = QToolButton()
        new_btn.setText("+")
        new_btn.setToolTip("New chat")
        new_btn.clicked.connect(self._new_chat)
        tools.addWidget(new_btn)
        open_btn = QToolButton()
        open_btn.setText("UI")
        open_btn.setToolTip("Open full AI UI")
        open_btn.clicked.connect(self._open_full)
        tools.addWidget(open_btn)
        pause_btn = QToolButton()
        pause_btn.setText("❚❚")
        pause_btn.setToolTip("Pause presence")
        pause_btn.clicked.connect(self._pause)
        tools.addWidget(pause_btn)
        resume_btn = QToolButton()
        resume_btn.setText("▶")
        resume_btn.setToolTip("Resume presence")
        resume_btn.clicked.connect(self._resume)
        tools.addWidget(resume_btn)
        quit_btn = QToolButton()
        quit_btn.setText("×")
        quit_btn.setToolTip("Quit companion")
        quit_btn.clicked.connect(QApplication.instance().quit)
        tools.addWidget(quit_btn)
        glass.addLayout(tools)

        self.stack = QStackedWidget()
        self.chat_page = QWidget()
        chat_l = QVBoxLayout(self.chat_page)
        chat_l.setContentsMargins(0, 0, 0, 0)
        chat_l.setSpacing(6)

        self.bubble = QTextEdit()
        self.bubble.setReadOnly(True)
        self.bubble.setPlaceholderText("Ask me something…")
        self.bubble.setMaximumHeight(140)
        self.bubble.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        self.bubble.setFocusPolicy(Qt.FocusPolicy.ClickFocus)
        chat_l.addWidget(self.bubble)

        row = QHBoxLayout()
        self.input = QLineEdit()
        self.input.setPlaceholderText("Message…")
        self.input.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.input.returnPressed.connect(self._send)
        row.addWidget(self.input, stretch=1)
        self.send_btn = QPushButton("Send")
        self.send_btn.setDefault(True)
        self.send_btn.clicked.connect(self._send)
        row.addWidget(self.send_btn)
        chat_l.addLayout(row)

        self.list_page = QWidget()
        list_l = QVBoxLayout(self.list_page)
        list_l.setContentsMargins(0, 0, 0, 0)
        self.panel_title = QLabel("")
        self.panel_title.setStyleSheet("font-weight: 600;")
        list_l.addWidget(self.panel_title)
        self.panel_list = QListWidget()
        self.panel_list.itemActivated.connect(self._on_panel_item)
        self.panel_list.itemClicked.connect(self._on_panel_item)
        list_l.addWidget(self.panel_list)
        back = QPushButton("Back to chat")
        back.clicked.connect(lambda: self._toggle_panel(PANEL_NONE))
        list_l.addWidget(back)

        self.stack.addWidget(self.chat_page)
        self.stack.addWidget(self.list_page)
        glass.addWidget(self.stack)

        tip = QLabel("Drag avatar to move · Esc quits")
        tip.setStyleSheet("color: #889; font-size: 10px;")
        tip.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        glass.addWidget(tip)

        root.addWidget(self.panel)

        self.setStyleSheet(
            """
            QFrame#glass {
              background: rgba(244, 246, 248, 230);
              border: 1px solid rgba(80, 90, 100, 90);
              border-radius: 14px;
            }
            QTextEdit, QLineEdit, QListWidget {
              background: rgba(255, 255, 255, 235);
              border: 1px solid #c5ccd4;
              border-radius: 8px;
              padding: 6px;
              color: #1a1a1a;
            }
            QPushButton, QToolButton {
              border-radius: 6px;
              padding: 4px 8px;
              background: rgba(255,255,255,200);
              border: 1px solid #c5ccd4;
              color: #1a1a1a;
            }
            QToolButton:checked {
              background: #3d5a80;
              color: white;
              border-color: #2d4460;
            }
            QToolButton[activeChat="true"] {
              background: #5a9e7a;
              color: white;
              border-color: #2d6a4f;
            }
            QLabel { color: #1a1a1a; }
            """
        )

        QShortcut(QKeySequence("Escape"), self, activated=self._on_escape)
        QShortcut(QKeySequence("Ctrl+N"), self, activated=self._new_chat)
        QShortcut(QKeySequence("Ctrl+Tab"), self, activated=self._next_chat)

        self._presence_timer = QTimer(self)
        self._presence_timer.setInterval(2000)
        self._presence_timer.timeout.connect(self._sync_presence)
        self._presence_timer.start()
        self._sync_presence()
        self._rebuild_tabs()
        self._apply_slot_ui()

        from PySide6.QtCore import QSettings

        s = QSettings("NixOSControlCenter", "ncc-assistant-companion")
        pos = s.value("pos")
        if pos is not None:
            self.move(pos)

    def showEvent(self, event) -> None:  # noqa: N802
        super().showEvent(event)
        self.raise_()
        self.activateWindow()
        QTimer.singleShot(0, self._focus_input)

    def _focus_input(self) -> None:
        if self._panel == PANEL_NONE:
            self.input.setFocus(Qt.FocusReason.ActiveWindowFocusReason)

    def closeEvent(self, event) -> None:  # noqa: N802
        from PySide6.QtCore import QSettings

        QSettings("NixOSControlCenter", "ncc-assistant-companion").setValue(
            "pos", self.pos()
        )
        super().closeEvent(event)

    def mousePressEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        # Drag from empty glass margins / header area (not line edit / buttons).
        if event.button() == Qt.MouseButton.LeftButton:
            child = self.childAt(event.position().toPoint())
            interactive = isinstance(
                child, (QLineEdit, QTextEdit, QPushButton, QToolButton, QListWidget)
            )
            if not interactive:
                if not _start_system_move(self):
                    self._drag_origin = event.globalPosition().toPoint()
                    self._win_origin = self.frameGeometry().topLeft()
                event.accept()
                return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        if (
            self._drag_origin is not None
            and self._win_origin is not None
            and event.buttons() & Qt.MouseButton.LeftButton
        ):
            self.move(self._win_origin + (event.globalPosition().toPoint() - self._drag_origin))
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        self._drag_origin = None
        self._win_origin = None
        super().mouseReleaseEvent(event)

    def _on_escape(self) -> None:
        if self._panel != PANEL_NONE:
            self._toggle_panel(PANEL_NONE)
            return
        app = QApplication.instance()
        if app is not None:
            app.quit()

    def _slot(self, slot_id: str | None = None) -> ChatSlot:
        sid = slot_id or self._active_id
        for s in self._slots:
            if s.id == sid:
                return s
        return self._slots[0]

    def _rebuild_tabs(self) -> None:
        while self.tabs_row.count():
            item = self.tabs_row.takeAt(0)
            w = item.widget()
            if w is not None:
                w.deleteLater()
        self._tab_buttons.clear()
        for slot in self._slots:
            btn = QToolButton()
            mark = "…" if slot.busy else ""
            btn.setText(f"{slot.title}{mark}"[:18])
            btn.setToolTip(f"{slot.title} ({slot.id})")
            btn.setCheckable(True)
            btn.setChecked(slot.id == self._active_id)
            btn.setProperty("activeChat", "true" if slot.id == self._active_id else "false")
            btn.clicked.connect(lambda checked=False, sid=slot.id: self._switch_chat(sid))
            self.tabs_row.addWidget(btn)
            self._tab_buttons[slot.id] = btn
        self.tabs_row.addStretch()

    def _apply_slot_ui(self) -> None:
        slot = self._slot()
        self.bubble.setPlainText(slot.transcript or slot.reply_buf)
        sb = self.bubble.verticalScrollBar()
        sb.setValue(sb.maximum())
        self.avatar.set_state(slot.avatar_state)
        self.send_btn.setEnabled(not slot.busy)
        self.input.setEnabled(True)  # always allow typing / queue feel
        self._rebuild_tabs()

    def _switch_chat(self, slot_id: str) -> None:
        if slot_id == self._active_id:
            return
        self._active_id = slot_id
        self._toggle_panel(PANEL_NONE)
        self._apply_slot_ui()
        self._focus_input()

    def _next_chat(self) -> None:
        if len(self._slots) < 2:
            return
        ids = [s.id for s in self._slots]
        i = ids.index(self._active_id)
        self._switch_chat(ids[(i + 1) % len(ids)])

    def _new_chat(self) -> None:
        n = len(self._slots) + 1
        slot = ChatSlot.new(f"Chat {n}")
        self._slots.append(slot)
        self._active_id = slot.id
        self._toggle_panel(PANEL_NONE)
        self._apply_slot_ui()
        self._focus_input()

    def _shared_settings(self) -> Any:
        if self._settings is None:
            from .config import Settings
            from .preferences import apply_startup_preferences

            self._settings = apply_startup_preferences(Settings.from_env(client_mode="chat"))
        return self._settings

    def _ensure_session(self, slot: ChatSlot) -> None:
        if slot.session is not None:
            return
        from .session import ChatSession

        slot.session = ChatSession.create(
            self._shared_settings(),
            interactive_auth=False,
            refresh_models=False,
        )

    def _load_session_into_slot(self, session_id: str) -> None:
        from .history import load_session
        from .session import ChatSession

        data = load_session(session_id)
        if not data:
            return
        msgs = data.get("messages") or []
        title = str(data.get("title") or session_id)[:24]
        slot = ChatSlot.new(title)
        slot.session = ChatSession.create(
            self._shared_settings(),
            interactive_auth=False,
            refresh_models=False,
            messages=list(msgs) if isinstance(msgs, list) else None,
            session_id=session_id,
            title=title,
        )
        # Last assistant text for bubble
        last = ""
        for m in reversed(msgs if isinstance(msgs, list) else []):
            if isinstance(m, dict) and m.get("role") == "assistant":
                last = str(m.get("content") or "")[:2000]
                break
        slot.transcript = last or f"(loaded {title})"
        slot.reply_buf = slot.transcript
        self._slots.append(slot)
        self._active_id = slot.id
        self._toggle_panel(PANEL_NONE)
        self._apply_slot_ui()

    def _sync_presence(self) -> None:
        try:
            from .presence import get_presence

            st = get_presence().state
        except Exception:
            st = "available"
        busy_n = sum(1 for s in self._slots if s.busy)
        extra = f" · {busy_n} busy" if busy_n else ""
        self.presence_lbl.setText(f"{st}{extra}")
        slot = self._slot()
        if slot.busy:
            return
        if st == "paused":
            slot.avatar_state = STATE_PAUSED
            self.avatar.set_state(STATE_PAUSED)
        elif slot.avatar_state not in (STATE_ERROR, STATE_SPEAKING, STATE_THINKING):
            slot.avatar_state = STATE_IDLE
            self.avatar.set_state(STATE_IDLE)

    def _pick_harness(self, text: str) -> str:
        import os

        from .harness import looks_like_coding_goal, resolve_harness_name

        force = (os.environ.get("NCC_ASSISTANT_COMPANION_HARNESS") or "").strip() or None
        tags = ["coding"] if looks_like_coding_goal(text) else []
        return resolve_harness_name(tags=tags, force=force)

    def _send(self) -> None:
        text = self.input.text().strip()
        if not text:
            return
        slot = self._slot()
        if slot.busy:
            return
        hname = self._pick_harness(text)
        slot.harness = hname
        if hname == "native":
            self._ensure_session(slot)
        self.input.clear()
        slot.reply_buf = ""
        slot.thinking_buf = ""
        slot.last_error = ""
        slot.transcript = f"You: {text}\n\n[{hname}] …"
        slot.busy = True
        slot.avatar_state = STATE_THINKING
        if slot.title.startswith("Chat ") and len(text) > 2:
            slot.title = text[:16] + ("…" if len(text) > 16 else "")
        self._apply_slot_ui()
        self.harness_lbl.setText(hname)
        worker = _CompanionChatWorker(
            slot.id,
            text,
            harness_name=hname,
            session=slot.session,
            parent=self,
        )
        slot.worker = worker
        worker.event.connect(self._on_event)
        worker.failed.connect(self._on_fail)
        worker.finished.connect(lambda sid=slot.id: self._on_worker_done(sid))
        worker.start()

    def _on_worker_done(self, slot_id: str) -> None:
        slot = self._slot(slot_id)
        slot.busy = False
        slot.worker = None
        if slot_id == self._active_id:
            self._apply_slot_ui()
            self._sync_presence()
        else:
            self._rebuild_tabs()

    def _compose_transcript(self, slot: ChatSlot) -> str:
        parts: list[str] = []
        if slot.thinking_buf.strip():
            parts.append("── thinking ──\n" + slot.thinking_buf.strip()[-1200:])
        if slot.reply_buf.strip():
            if parts:
                parts.append("\n── reply ──\n")
            parts.append(slot.reply_buf.strip()[-2000:])
        return "\n".join(parts) if parts else slot.transcript

    def _on_event(self, slot_id: str, event: object) -> None:
        if not isinstance(event, dict):
            return
        slot = self._slot(slot_id)
        kind = event.get("kind")
        if kind == "thinking_delta":
            slot.avatar_state = STATE_THINKING
            slot.thinking_buf += str(event.get("text") or "")
            slot.transcript = self._compose_transcript(slot)
        elif kind in ("assistant_delta", "delta"):
            slot.avatar_state = STATE_SPEAKING
            slot.reply_buf += str(event.get("text") or "")
            slot.transcript = self._compose_transcript(slot)
        elif kind == "assistant":
            slot.reply_buf = str(event.get("text") or slot.reply_buf)
            slot.transcript = self._compose_transcript(slot)
        elif kind == "tool":
            name = event.get("name") or "tool"
            args = event.get("args") or {}
            arg_s = str(args)
            if len(arg_s) > 120:
                arg_s = arg_s[:120] + "…"
            slot.reply_buf += f"\n[tool] {name}({arg_s})\n"
            slot.transcript = self._compose_transcript(slot)
            slot.avatar_state = STATE_THINKING
        elif kind == "tool_result":
            name = event.get("name") or "tool"
            body = str(event.get("text") or "")[:400]
            slot.reply_buf += f"[result] {name}: {body}\n"
            slot.transcript = self._compose_transcript(slot)
        elif kind == "status":
            phase = event.get("phase") or ""
            if phase == "tool":
                slot.avatar_state = STATE_THINKING
        elif kind == "error":
            slot.avatar_state = STATE_ERROR
            slot.transcript = str(event.get("text") or "error")
        elif kind == "done":
            if slot.avatar_state != STATE_PAUSED:
                slot.avatar_state = STATE_IDLE
        if slot_id == self._active_id:
            self.bubble.setPlainText(slot.transcript)
            sb = self.bubble.verticalScrollBar()
            sb.setValue(sb.maximum())
            self.avatar.set_state(slot.avatar_state)
            self.harness_lbl.setText(slot.harness)
            if kind in ("assistant_delta", "delta", "thinking_delta", "tool", "done"):
                self._rebuild_tabs()

    def _on_fail(self, slot_id: str, message: str) -> None:
        slot = self._slot(slot_id)
        slot.avatar_state = STATE_ERROR
        short = message.splitlines()[0][:400]
        slot.transcript = f"Error: {short}"
        slot.busy = False
        if slot_id == self._active_id:
            self._apply_slot_ui()

    def _toggle_panel(self, key: str) -> None:
        if key == PANEL_NONE or (key == self._panel and key != PANEL_NONE):
            self._panel = PANEL_NONE
            self.stack.setCurrentWidget(self.chat_page)
            for b in self._tool_btns.values():
                b.setChecked(False)
            self._focus_input()
            return
        self._panel = key
        for k, b in self._tool_btns.items():
            b.setChecked(k == key)
        self.stack.setCurrentWidget(self.list_page)
        self._fill_panel(key)

    def _fill_panel(self, key: str) -> None:
        self.panel_list.clear()
        if key == PANEL_HISTORY:
            self.panel_title.setText("Session history")
            try:
                from .history import list_sessions

                items = list_sessions(limit=30)
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not items:
                self.panel_list.addItem("(no saved sessions)")
                return
            for it in items:
                title = str(it.get("title") or "Untitled")
                sid = str(it.get("id") or "")
                n = it.get("message_count") or 0
                row = QListWidgetItem(f"{title}  ·  {n} msgs")
                row.setData(Qt.ItemDataRole.UserRole, ("history", sid))
                self.panel_list.addItem(row)
        elif key == PANEL_SKILLS:
            self.panel_title.setText("Skills & templates")
            for label, kind, ref in self._skill_rows():
                row = QListWidgetItem(label)
                row.setData(Qt.ItemDataRole.UserRole, (kind, ref))
                self.panel_list.addItem(row)
            if self.panel_list.count() == 0:
                self.panel_list.addItem("(none found)")
        elif key == PANEL_CRON:
            self.panel_title.setText("Schedules")
            try:
                from .schedule_templates import list_nix_schedules, list_user_schedules

                rows = [("user", s) for s in list_user_schedules()] + [
                    ("nix", s) for s in list_nix_schedules()
                ]
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not rows:
                self.panel_list.addItem("(no schedules)")
                return
            for src, spec in rows:
                name = getattr(spec, "name", None) or str(spec)
                cal = getattr(spec, "on_calendar", None) or getattr(spec, "onCalendar", "") or ""
                row = QListWidgetItem(f"[{src}] {name}  {cal}")
                row.setData(Qt.ItemDataRole.UserRole, ("cron", name))
                self.panel_list.addItem(row)
        elif key == PANEL_JOBS:
            self.panel_title.setText("Agent jobs")
            try:
                from .jobs import get_job_store

                jobs = get_job_store().list_jobs(limit=30)
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not jobs:
                self.panel_list.addItem("(no jobs)")
                return
            for j in jobs:
                jid = getattr(j, "id", "") or ""
                st = getattr(j, "status", "") or ""
                goal = (getattr(j, "goal", None) or getattr(j, "title", "") or "")[:40]
                row = QListWidgetItem(f"{st} · {goal}")
                row.setData(Qt.ItemDataRole.UserRole, ("job", jid))
                self.panel_list.addItem(row)

    def _skill_rows(self) -> list[tuple[str, str, str]]:
        out: list[tuple[str, str, str]] = []
        roots: list[Path] = []
        env = os.environ.get("NCC_ASSISTANT_PROMPTS") or os.environ.get("NCC_AI_PROMPTS")
        if env:
            roots.append(Path(env) / "skills")
        roots.append(Path(__file__).resolve().parents[2] / "prompts" / "skills")
        seen: set[str] = set()
        for root in roots:
            if not root.is_dir():
                continue
            for path in sorted(root.glob("*.md")):
                if path.stem in seen:
                    continue
                seen.add(path.stem)
                out.append((f"skill · {path.stem}", "skill", path.stem))
        try:
            from .agent_templates import list_agent_templates

            for t in list_agent_templates():
                tid = getattr(t, "id", None) or getattr(t, "name", "")
                title = getattr(t, "title", None) or tid
                out.append((f"tmpl · {title}", "template", str(tid)))
        except Exception:
            pass
        return out[:40]

    def _on_panel_item(self, item: QListWidgetItem) -> None:
        data = item.data(Qt.ItemDataRole.UserRole)
        if not data or not isinstance(data, tuple) or len(data) != 2:
            return
        kind, ref = data
        if kind == "history" and ref:
            self._load_session_into_slot(str(ref))
            return
        if kind == "skill" and ref:
            # Seed active chat with a short ask to use the skill
            self._toggle_panel(PANEL_NONE)
            self.input.setText(f"Use skill `{ref}` for the current task.")
            self._focus_input()
            return
        if kind == "template" and ref:
            self._toggle_panel(PANEL_NONE)
            self.input.setText(f"Run agent template `{ref}`.")
            self._focus_input()
            return
        if kind in ("cron", "job"):
            # Informational for v1 — open full UI for management
            self._open_full()

    def _open_full(self) -> None:
        import shutil

        from PySide6.QtCore import QProcess

        bin_path = shutil.which("ncc-assistant") or shutil.which("ncc")
        if bin_path and bin_path.endswith("ncc"):
            QProcess.startDetached(bin_path, ["ai", "gui"])
        elif bin_path:
            QProcess.startDetached(bin_path, ["gui"])
        else:
            from .gui import run_gui

            os.environ.setdefault("NCC_CLI_NESTED", "1")
            run_gui()

    def _pause(self) -> None:
        from .presence import set_presence

        set_presence("paused", reason="companion")
        self._sync_presence()

    def _resume(self) -> None:
        from .presence import set_presence

        set_presence("available", reason="companion")
        self._sync_presence()


def run_companion() -> int:
    # Prefer xcb only if user already chose it; otherwise let Qt/Wayland work.
    app = QApplication.instance() or QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(True)
    app.setApplicationName("NCC Companion")
    win = CompanionWindow()
    # Place near bottom-right if no saved pos
    from PySide6.QtCore import QSettings

    if QSettings("NixOSControlCenter", "ncc-assistant-companion").value("pos") is None:
        screen = app.primaryScreen()
        if screen is not None:
            geo = screen.availableGeometry()
            win.move(geo.right() - win.width() - 24, geo.bottom() - win.height() - 48)
    win.show()
    win.activateWindow()
    win.input.setFocus()
    return int(app.exec())
