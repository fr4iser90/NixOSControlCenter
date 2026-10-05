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
    QCursor,
    QFont,
    QIcon,
    QKeySequence,
    QMouseEvent,
    QPainter,
    QPainterPath,
    QPalette,
    QPen,
    QShortcut,
)
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMenu,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSizeGrip,
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
PANEL_TEMPLATES = "templates"
PANEL_DAILY = "daily"
PANEL_PLUGINS = "plugins"
PANEL_TOOLS = "tools"
PANEL_MCP = "mcp"
PANEL_WORKSPACES = "workspaces"
PANEL_CRON = "cron"
PANEL_JOBS = "jobs"


def _icon_button(
    *,
    tip: str,
    theme: str,
    fallback: str,
    checkable: bool = False,
) -> QToolButton:
    btn = QToolButton()
    btn.setAutoRaise(True)
    btn.setToolTip(tip)
    btn.setCheckable(checkable)
    icon = QIcon.fromTheme(theme)
    if not icon.isNull():
        btn.setIcon(icon)
        btn.setText("")
    else:
        btn.setText(fallback)
    return btn


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


class ResizeCorner(QSizeGrip):
    """Visible bottom-right resize affordance (plain QSizeGrip is invisible on glass)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("nccResizeGrip")
        self.setFixedSize(22, 22)
        self.setToolTip("Drag corner to resize")
        self.setCursor(QCursor(Qt.CursorShape.SizeFDiagCursor))

    def paintEvent(self, event) -> None:  # noqa: N802
        del event
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        accent = self.palette().color(QPalette.ColorRole.Highlight)
        muted = self.palette().color(QPalette.ColorRole.Mid)
        bg = QColor(accent)
        bg.setAlpha(40)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(bg)
        p.drawRoundedRect(self.rect().adjusted(1, 1, -1, -1), 5, 5)
        p.setPen(QPen(accent if accent.isValid() else muted, 2.0))
        w, h = self.width(), self.height()
        for offset in (5, 10, 15):
            p.drawLine(w - 4, h - offset, w - offset, h - 4)
        p.end()


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
        history: list | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self.slot_id = slot_id
        self._session = session
        self._text = text
        self._harness_name = harness_name
        self._cwd = cwd
        self._history = list(history or [])

    def run(self) -> None:
        try:
            from .harness import get_harness

            backend = get_harness(self._harness_name)
            for ev in backend.send(
                self._text,
                cwd=self._cwd,
                session=self._session if self._harness_name == "native" else None,
                history=self._history,
            ):
                self.event.emit(self.slot_id, ev)
        except Exception as exc:  # noqa: BLE001
            self.failed.emit(self.slot_id, f"{exc}\n{traceback.format_exc()}")


class _CompanionTemplateWorker(QThread):
    """Run an agent template goal into a companion slot (same event contract)."""

    event = Signal(str, object)
    failed = Signal(str, str)

    def __init__(
        self,
        slot_id: str,
        template_id: str,
        params: dict[str, Any],
        *,
        harness_force: str | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self.slot_id = slot_id
        self._template_id = template_id
        self._params = params
        self._harness_force = harness_force

    def run(self) -> None:
        try:
            from .agent import run_agent
            from .agent_templates import get_agent_template, render_goal
            from .auth import with_cached_credentials
            from .capacity import capacity_slot
            from .config import Settings
            from .harness import get_harness, resolve_harness_name
            from .workspaces import get_workspace

            tmpl = get_agent_template(self._template_id)
            if tmpl is None:
                raise ValueError(f"Unknown template: {self._template_id}")
            goal = render_goal(tmpl, self._params)
            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
            hname = resolve_harness_name(
                template_harness=tmpl.harness,
                tags=tmpl.tags,
                force=self._harness_force,
            )
            self.event.emit(
                self.slot_id,
                {"kind": "status", "text": f"Template {tmpl.title} · {hname}"},
            )
            cwd = None
            repos = self._params.get("repositories") or self._params.get("workspace")
            if isinstance(repos, list) and repos:
                ws = get_workspace(str(repos[0]))
                if ws:
                    cwd = str(ws.path)
            elif isinstance(repos, str) and repos:
                ws = get_workspace(repos)
                if ws:
                    cwd = str(ws.path)
            with capacity_slot(f"template:{self._template_id}"):
                if hname != "native":
                    for ev in get_harness(hname).send(goal, cwd=cwd):
                        self.event.emit(self.slot_id, ev)
                else:
                    for ev in run_agent(
                        goal,
                        settings,
                        max_steps=tmpl.max_steps or 24,
                        dry_run=tmpl.dry_run,
                        profile=tmpl.profile,
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
    worker: Any | None = None
    reply_buf: str = ""
    thinking_buf: str = ""
    user_prompt: str = ""
    tool_traces: list | None = None  # [{name, args, result}]
    busy: bool = False
    avatar_state: str = STATE_IDLE
    last_error: str = ""
    harness_mode: str = "auto"  # user chip: auto|native|qwen|dsh
    harness: str = "native"  # last resolved
    activity: str = ""
    parent_id: str | None = None
    workspace_id: str | None = None
    title_locked: bool = False  # True after user rename
    history: list | None = None  # [{role, content}] multi-turn for harnesses

    def __post_init__(self) -> None:
        if self.tool_traces is None:
            self.tool_traces = []
        if self.history is None:
            self.history = []

    @staticmethod
    def new(
        title: str = "Chat",
        *,
        parent_id: str | None = None,
        workspace_id: str | None = None,
    ) -> "ChatSlot":
        return ChatSlot(
            id=uuid.uuid4().hex[:8],
            title=title,
            parent_id=parent_id,
            workspace_id=workspace_id,
        )

    @staticmethod
    def from_record(rec: dict[str, Any]) -> "ChatSlot":
        slot = ChatSlot(
            id=str(rec.get("id") or uuid.uuid4().hex[:8]),
            title=str(rec.get("title") or "Chat")[:48],
            title_locked=bool(rec.get("title_locked")),
            workspace_id=rec.get("workspace_id") or None,
            harness_mode=str(rec.get("harness_mode") or "auto"),
            harness=str(rec.get("harness") or "native"),
            parent_id=rec.get("parent_id") or None,
            user_prompt=str(rec.get("user_prompt") or ""),
            reply_buf=str(rec.get("reply_buf") or ""),
            thinking_buf=str(rec.get("thinking_buf") or ""),
            history=list(rec.get("history") or []),
            tool_traces=list(rec.get("tool_traces") or []),
        )
        return slot


def _looks_like_subagent_spawn(event: dict[str, Any]) -> bool:
    """Interim heuristic until adapters emit run_spawn reliably."""
    kind = event.get("kind")
    if kind == "run_spawn":
        return True
    if kind == "tool":
        name = str(event.get("name") or "").lower()
        return any(x in name for x in ("subagent", "task", "delegate", "spawn"))
    if kind == "status":
        text = str(event.get("text") or event.get("phase") or "").lower()
        return "subagent" in text or "spawn" in text
    return False


class AvatarCanvas(QWidget):
    """Painted character with simple idle / blink / talk animation — or skin frames."""

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
        self._skin: dict[str, Any] | None = None
        self._frame_idx = 0
        self._pixmaps: dict[str, list] = {}

        self._timer = QTimer(self)
        self._timer.setInterval(40)
        self._timer.timeout.connect(self._tick)
        self._timer.start()

    def apply_skin(self, skin: dict[str, Any] | None) -> None:
        self._skin = skin
        self._pixmaps.clear()
        self._frame_idx = 0
        if not skin or skin.get("kind") == "painted":
            self.update()
            return
        try:
            from .avatar_skins import frame_paths
            from PySide6.QtGui import QPixmap

            for st in (
                STATE_IDLE,
                STATE_THINKING,
                STATE_SPEAKING,
                STATE_PAUSED,
                STATE_ERROR,
            ):
                paths = frame_paths(skin, st)
                if not paths and st != STATE_IDLE:
                    paths = frame_paths(skin, STATE_IDLE)
                self._pixmaps[st] = [QPixmap(str(p)) for p in paths if p.is_file()]
        except Exception:
            self._pixmaps.clear()
        self.update()

    def set_state(self, state: str) -> None:
        if state != self._state:
            self._state = state
            self._frame_idx = 0
            self.update()

    def state(self) -> str:
        return self._state

    def _tick(self) -> None:
        self._phase += 0.08
        frames = self._pixmaps.get(self._state) or []
        if frames:
            # Animate frame sequence (~8 fps)
            if int(self._phase * 10) % 5 == 0:
                self._frame_idx = (self._frame_idx + 1) % len(frames)
            self.update()
            return
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
        frames = self._pixmaps.get(self._state) or []
        if frames:
            pm = frames[self._frame_idx % len(frames)]
            if not pm.isNull():
                scaled = pm.scaled(
                    w,
                    h,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
                x = (w - scaled.width()) // 2
                y = (h - scaled.height()) // 2
                p.drawPixmap(x, y, scaled)
                return
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
        self.setMinimumSize(280, 420)
        self.resize(340, 560)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        from .companion_store import load_companion_chats
        from .preferences import get_active_workspace_id, get_default_harness_mode

        self._active_workspace_id: str | None = get_active_workspace_id()
        self._slots: list[ChatSlot] = []
        loaded = load_companion_chats()
        if loaded:
            self._slots = [ChatSlot.from_record(r) for r in loaded]
            # Drop orphan nested without parent
            ids = {s.id for s in self._slots}
            self._slots = [
                s for s in self._slots if not s.parent_id or s.parent_id in ids
            ]
        if not self._slots:
            first = ChatSlot.new("Chat 1", workspace_id=self._active_workspace_id)
            first.harness_mode = get_default_harness_mode()
            self._slots = [first]
        self._active_id: str = self._slots[0].id
        self._panel = PANEL_NONE
        self._settings: Any | None = None
        self._drag_origin: QPoint | None = None
        self._win_origin: QPoint | None = None
        self._tool_btns: dict[str, QToolButton] = {}
        self._persist_timer = QTimer(self)
        self._persist_timer.setInterval(2000)
        self._persist_timer.setSingleShot(True)
        self._persist_timer.timeout.connect(self._persist_chats)

        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(6)

        # Transparent drag zone + avatar (painted or skin frames)
        self.avatar = AvatarCanvas()
        try:
            from .avatar_skins import get_active_skin_id, resolve_skin

            self.avatar.apply_skin(resolve_skin(get_active_skin_id()))
        except Exception:
            pass
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
        self.presence_lbl = QLabel("")
        self.presence_lbl.setObjectName("nccMuted")
        header.addWidget(self.presence_lbl)
        header.addStretch()
        self.workspace_combo = QComboBox()
        self.workspace_combo.setToolTip("Active workspace (scopes new chats + templates)")
        self.workspace_combo.setMaximumWidth(120)
        self.workspace_combo.currentIndexChanged.connect(self._on_workspace_chip_changed)
        header.addWidget(self.workspace_combo)
        self.harness_combo = QComboBox()
        self.harness_combo.setToolTip(
            "Harness for this chat (auto resolves coding goals → qwen/dsh)"
        )
        for key, label in (
            ("auto", "auto"),
            ("native", "native"),
            ("qwen", "qwen"),
            ("dsh", "dsh"),
        ):
            self.harness_combo.addItem(label, key)
        self.harness_combo.setMaximumWidth(90)
        self.harness_combo.currentIndexChanged.connect(self._on_harness_chip_changed)
        header.addWidget(self.harness_combo)
        self.harness_resolved_lbl = QLabel("")
        self.harness_resolved_lbl.setObjectName("nccMuted")
        self.harness_resolved_lbl.setToolTip("Resolved harness for last / next send")
        header.addWidget(self.harness_resolved_lbl)
        glass.addLayout(header)

        # Breadcrumb for nested subagent chats
        crumb = QHBoxLayout()
        self.parent_btn = QToolButton()
        self.parent_btn.setText("↑ parent")
        self.parent_btn.setToolTip("Back to parent chat")
        self.parent_btn.clicked.connect(self._go_parent)
        self.parent_btn.hide()
        crumb.addWidget(self.parent_btn)
        self.breadcrumb_lbl = QLabel("")
        self.breadcrumb_lbl.setObjectName("nccMuted")
        crumb.addWidget(self.breadcrumb_lbl, stretch=1)
        glass.addLayout(crumb)

        # Active session chip (replaces tab strip)
        sess_row = QHBoxLayout()
        self.session_btn = QToolButton()
        self.session_btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.session_btn.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self.session_btn.setToolTip("Sessions — switch, new, rename")
        sess_icon = QIcon.fromTheme("document-open-recent")
        if not sess_icon.isNull():
            self.session_btn.setIcon(sess_icon)
        self.session_btn.setText("Chat 1 ▾")
        self._session_menu = QMenu(self)
        self.session_btn.setMenu(self._session_menu)
        self._session_menu.aboutToShow.connect(self._rebuild_session_menu)
        sess_row.addWidget(self.session_btn, stretch=1)
        rename_btn = _icon_button(
            tip="Rename session", theme="document-edit", fallback="✎"
        )
        rename_btn.clicked.connect(self._rename_session)
        sess_row.addWidget(rename_btn)
        glass.addLayout(sess_row)

        # Icon toolbar — primary surfaces + overflow
        tools = QHBoxLayout()
        tools.setSpacing(2)
        primary = (
            (PANEL_TEMPLATES, "folder-templates", "▶", "Workflow templates"),
            (PANEL_DAILY, "view-calendar-day", "📅", "Daily workflows"),
            (PANEL_PLUGINS, "application-x-addon", "🧩", "Feature plugins"),
            (PANEL_TOOLS, "applications-system", "🔧", "Tools registry"),
            (PANEL_MCP, "network-server", "🔌", "MCP servers"),
            (PANEL_WORKSPACES, "folder", "📁", "Workspaces"),
            (PANEL_HISTORY, "document-open-recent", "⏱", "Saved session history"),
        )
        for key, theme, fallback, tip in primary:
            btn = _icon_button(tip=tip, theme=theme, fallback=fallback, checkable=True)
            btn.clicked.connect(lambda checked=False, k=key: self._toggle_panel(k))
            tools.addWidget(btn)
            self._tool_btns[key] = btn

        more_btn = _icon_button(tip="More…", theme="application-menu", fallback="⋯")
        more_menu = QMenu(self)
        more_menu.addAction("Schedules / cron", lambda: self._toggle_panel(PANEL_CRON))
        more_menu.addAction("Agent jobs", lambda: self._toggle_panel(PANEL_JOBS))
        more_menu.addSeparator()
        more_menu.addAction("Pause presence", self._pause)
        more_menu.addAction("Resume presence", self._resume)
        more_menu.addSeparator()
        theme_menu = more_menu.addMenu("Theme")
        from .companion_themes import list_themes

        for tid, label in list_themes():
            theme_menu.addAction(label, lambda t=tid: self._set_theme(t))
        more_menu.addAction("Avatar skin…", self._pick_avatar_skin)
        more_menu.addAction("Inject NCC MCP into qwen/dsh", self._inject_mcp_now)
        more_btn.setMenu(more_menu)
        more_btn.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        tools.addWidget(more_btn)

        tools.addStretch()
        new_btn = _icon_button(tip="New chat", theme="list-add", fallback="+")
        new_btn.clicked.connect(self._new_chat)
        tools.addWidget(new_btn)
        open_btn = _icon_button(tip="Open full AI UI", theme="window-new", fallback="UI")
        open_btn.clicked.connect(self._open_full)
        tools.addWidget(open_btn)
        quit_btn = _icon_button(tip="Quit companion", theme="window-close", fallback="×")
        quit_btn.clicked.connect(QApplication.instance().quit)
        tools.addWidget(quit_btn)
        glass.addLayout(tools)

        self.stack = QStackedWidget()
        self.chat_page = QWidget()
        chat_l = QVBoxLayout(self.chat_page)
        chat_l.setContentsMargins(0, 0, 0, 0)
        chat_l.setSpacing(4)

        self.activity_lbl = QLabel("")
        self.activity_lbl.setObjectName("nccMuted")
        self.activity_lbl.setMinimumHeight(14)
        chat_l.addWidget(self.activity_lbl)

        from .gui_pages import ThinkingBlock
        from .preferences import get_expand_thinking_while_streaming

        self.think_block = ThinkingBlock(
            compact=True,
            expand_while_streaming=get_expand_thinking_while_streaming(),
        )
        chat_l.addWidget(self.think_block)

        self.tools_scroll = QScrollArea()
        self.tools_scroll.setWidgetResizable(True)
        self.tools_scroll.setMaximumHeight(100)
        self.tools_scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.tools_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.tools_host = QWidget()
        self.tools_layout = QVBoxLayout(self.tools_host)
        self.tools_layout.setContentsMargins(0, 0, 0, 0)
        self.tools_layout.setSpacing(3)
        self.tools_layout.addStretch()
        self.tools_scroll.setWidget(self.tools_host)
        self.tools_scroll.hide()
        chat_l.addWidget(self.tools_scroll)
        self._tool_widgets: list[Any] = []

        self.bubble = QTextEdit()
        self.bubble.setReadOnly(True)
        self.bubble.setPlaceholderText("Ask me something…")
        self.bubble.setMaximumHeight(120)
        self.bubble.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        self.bubble.setFocusPolicy(Qt.FocusPolicy.ClickFocus)
        chat_l.addWidget(self.bubble)

        row = QHBoxLayout()
        self.input = QLineEdit()
        self.input.setPlaceholderText("Message…")
        self.input.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.input.returnPressed.connect(self._send)
        row.addWidget(self.input, stretch=1)
        self.retry_btn = QPushButton("Retry")
        self.retry_btn.setToolTip("Resend the last message after an error")
        self.retry_btn.clicked.connect(self._retry)
        self.retry_btn.hide()
        row.addWidget(self.retry_btn)
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

        tip_row = QHBoxLayout()
        tip = QLabel("Drag avatar · Esc · ↘ corner resize")
        tip.setObjectName("nccMuted")
        tip_row.addWidget(tip, stretch=1)
        self.resize_grip = ResizeCorner(self.panel)
        tip_row.addWidget(self.resize_grip, alignment=Qt.AlignmentFlag.AlignRight)
        glass.addLayout(tip_row)

        root.addWidget(self.panel, stretch=1)

        self._theme_id = self._load_theme_id()
        self._apply_theme(self._theme_id)

        QShortcut(QKeySequence("Escape"), self, activated=self._on_escape)
        QShortcut(QKeySequence("Ctrl+N"), self, activated=self._new_chat)
        QShortcut(QKeySequence("Ctrl+Tab"), self, activated=self._next_chat)
        QShortcut(QKeySequence("F2"), self, activated=self._rename_session)

        self._presence_timer = QTimer(self)
        self._presence_timer.setInterval(2000)
        self._presence_timer.timeout.connect(self._sync_presence)
        self._presence_timer.start()
        self._idle_timer = QTimer(self)
        self._idle_timer.setInterval(60_000)
        self._idle_timer.timeout.connect(self._idle_tick)
        self._idle_timer.start()
        self._idle_armed = False
        self._focus_timer = QTimer(self)
        self._focus_timer.setInterval(15_000)
        self._focus_timer.timeout.connect(self._focus_tick)
        self._focus_timer.start()
        self._reload_workspace_chip()
        self._sync_presence()
        self._apply_slot_ui()
        self._restore_geometry()
        QTimer.singleShot(800, self._focus_tick)

    def showEvent(self, event) -> None:  # noqa: N802
        super().showEvent(event)
        self.raise_()
        self.activateWindow()
        QTimer.singleShot(0, self._focus_input)

    def _focus_input(self) -> None:
        if self._panel == PANEL_NONE:
            self.input.setFocus(Qt.FocusReason.ActiveWindowFocusReason)

    def closeEvent(self, event) -> None:  # noqa: N802
        self._persist_chats()
        self._save_geometry()
        super().closeEvent(event)

    def _schedule_persist(self) -> None:
        if hasattr(self, "_persist_timer"):
            self._persist_timer.start()

    def _persist_chats(self) -> None:
        from .companion_store import save_companion_chats, slot_to_record

        try:
            save_companion_chats([slot_to_record(s) for s in self._slots])
        except Exception:
            pass

    def _settings_store(self):
        from PySide6.QtCore import QSettings

        return QSettings("NixOSControlCenter", "ncc-assistant-companion")

    def _load_theme_id(self) -> str:
        from .companion_themes import DEFAULT_THEME, normalize_theme_id

        raw = self._settings_store().value("theme", DEFAULT_THEME)
        return normalize_theme_id(str(raw) if raw is not None else DEFAULT_THEME)

    def _set_theme(self, theme_id: str) -> None:
        self._apply_theme(theme_id)
        self._settings_store().setValue("theme", self._theme_id)

    def _apply_theme(self, theme_id: str) -> None:
        from .companion_themes import (
            apply_palette,
            get_theme,
            normalize_theme_id,
            stylesheet_for,
        )

        self._theme_id = normalize_theme_id(theme_id)
        theme = get_theme(self._theme_id)
        apply_palette(self, theme)
        app = QApplication.instance()
        if app is not None:
            apply_palette(app, theme)
        self.setStyleSheet(stylesheet_for(theme))

    def _restore_geometry(self) -> None:
        s = self._settings_store()
        geo = s.value("geometry")
        if geo is not None:
            try:
                self.restoreGeometry(geo)
                return
            except Exception:
                pass
        pos = s.value("pos")
        size = s.value("size")
        if pos is not None:
            self.move(pos)
        if size is not None:
            try:
                self.resize(size)
            except Exception:
                pass

    def _save_geometry(self) -> None:
        s = self._settings_store()
        s.setValue("geometry", self.saveGeometry())
        s.setValue("pos", self.pos())
        s.setValue("size", self.size())

    def mousePressEvent(self, event: QMouseEvent) -> None:  # noqa: N802
        # Drag from empty glass margins / header area (not line edit / buttons).
        if event.button() == Qt.MouseButton.LeftButton:
            child = self.childAt(event.position().toPoint())
            interactive = isinstance(
                child,
                (
                    QLineEdit,
                    QTextEdit,
                    QPushButton,
                    QToolButton,
                    QListWidget,
                    QComboBox,
                    QScrollArea,
                ),
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

    def _sync_session_chip(self) -> None:
        slot = self._slot()
        mark = " ✦" if slot.busy else ""
        nest = "▸ " if slot.parent_id else ""
        self.session_btn.setText(f"{nest}{slot.title}{mark} ▾"[:28])

    def _rebuild_session_menu(self) -> None:
        self._session_menu.clear()
        self._session_menu.addAction("New chat", self._new_chat)
        self._session_menu.addAction("Rename…", self._rename_session)
        self._session_menu.addSeparator()

        # Group by workspace
        groups: dict[str, list[ChatSlot]] = {}
        for slot in self._slots:
            if slot.parent_id:
                continue  # children listed under parent when active lineage
            key = slot.workspace_id or ""
            groups.setdefault(key, []).append(slot)

        def _ws_label(wid: str) -> str:
            if not wid:
                return "No workspace"
            try:
                from .workspaces import get_workspace

                ws = get_workspace(wid)
                return ws.label if ws else wid
            except Exception:
                return wid

        for wid in sorted(groups.keys(), key=lambda k: (k == "", k)):
            self._session_menu.addSection(_ws_label(wid))
            for slot in groups[wid]:
                mark = " ✦" if slot.busy else ""
                act = self._session_menu.addAction(f"{slot.title}{mark}")
                act.setCheckable(True)
                act.setChecked(slot.id == self._active_id)
                act.triggered.connect(
                    lambda checked=False, sid=slot.id: self._switch_chat(sid)
                )
                # Nested children of this slot
                kids = [s for s in self._slots if s.parent_id == slot.id]
                for child in kids:
                    cmark = " ✦" if child.busy else ""
                    cact = self._session_menu.addAction(f"  ▸ {child.title}{cmark}")
                    cact.setCheckable(True)
                    cact.setChecked(child.id == self._active_id)
                    cact.triggered.connect(
                        lambda checked=False, sid=child.id: self._switch_chat(sid)
                    )

        self._session_menu.addSeparator()
        # Move current session to a workspace
        move_menu = self._session_menu.addMenu("Move to workspace")
        move_menu.addAction(
            "(no workspace)",
            lambda: self._assign_workspace(None),
        )
        try:
            from .workspaces import list_workspaces

            for ws in list_workspaces():
                move_menu.addAction(
                    ws.label,
                    lambda checked=False, wid=ws.id: self._assign_workspace(wid),
                )
        except Exception:
            pass
        self._session_menu.addSeparator()
        del_act = self._session_menu.addAction("Close session")
        del_act.triggered.connect(self._close_session)

    def _assign_workspace(self, workspace_id: str | None) -> None:
        slot = self._slot()
        slot.workspace_id = workspace_id
        from .preferences import set_active_workspace_id

        self._active_workspace_id = workspace_id
        set_active_workspace_id(workspace_id)
        self._reload_workspace_chip()
        self._sync_session_chip()
        self._schedule_persist()

    def _rename_session(self) -> None:
        slot = self._slot()
        text, ok = QInputDialog.getText(
            self, "Rename session", "Title:", text=slot.title
        )
        if not ok:
            return
        title = text.strip()
        if not title:
            return
        slot.title = title[:48]
        slot.title_locked = True
        self._sync_session_chip()
        self._update_breadcrumb(slot)
        self._schedule_persist()

    def _close_session(self) -> None:
        if len(self._slots) <= 1:
            return
        slot = self._slot()
        if slot.busy:
            QMessageBox.information(self, "Sessions", "Stop the busy chat first.")
            return
        # Drop children too
        drop = {slot.id} | {s.id for s in self._slots if s.parent_id == slot.id}
        self._slots = [s for s in self._slots if s.id not in drop]
        self._active_id = self._slots[0].id
        self._apply_slot_ui()
        self._schedule_persist()

    def _clear_tool_widgets(self) -> None:
        for w in self._tool_widgets:
            self.tools_layout.removeWidget(w)
            w.deleteLater()
        self._tool_widgets.clear()
        self.tools_scroll.hide()

    def _rebuild_tool_widgets(self, slot: ChatSlot) -> None:
        from .gui_pages import ToolTraceWidget

        self._clear_tool_widgets()
        traces = slot.tool_traces or []
        if not traces:
            return
        self.tools_scroll.show()
        stretch = self.tools_layout.takeAt(self.tools_layout.count() - 1)
        for tr in traces:
            w = ToolTraceWidget(
                str(tr.get("name") or "tool"),
                tr.get("args") or {},
                compact=True,
            )
            result = tr.get("result")
            if result:
                w.set_result(str(result))
            self.tools_layout.addWidget(w)
            self._tool_widgets.append(w)
        if stretch is not None:
            self.tools_layout.addStretch()
        else:
            self.tools_layout.addStretch()

    def _set_activity(self, slot: ChatSlot, text: str) -> None:
        slot.activity = text
        if slot.id == self._active_id:
            self.activity_lbl.setText(text)

    def _sync_harness_chip(self, slot: ChatSlot) -> None:
        mode = slot.harness_mode or "auto"
        idx = self.harness_combo.findData(mode)
        self.harness_combo.blockSignals(True)
        if idx >= 0:
            self.harness_combo.setCurrentIndex(idx)
        self.harness_combo.blockSignals(False)
        if mode == "auto":
            self.harness_resolved_lbl.setText(f"→ {slot.harness}" if slot.harness else "")
        else:
            self.harness_resolved_lbl.setText("")

    def _on_harness_chip_changed(self, _index: int = 0) -> None:
        slot = self._slot()
        mode = str(self.harness_combo.currentData() or "auto")
        slot.harness_mode = mode
        from .preferences import set_default_harness_mode

        set_default_harness_mode(mode)
        # Preview resolve for display (next send uses same logic)
        if mode != "auto":
            slot.harness = mode
        self._sync_harness_chip(slot)

    def _reload_workspace_chip(self) -> None:
        self.workspace_combo.blockSignals(True)
        self.workspace_combo.clear()
        self.workspace_combo.addItem("(no ws)", "")
        try:
            from .workspaces import list_workspaces

            for ws in list_workspaces():
                self.workspace_combo.addItem(ws.label, ws.id)
        except Exception:
            pass
        idx = self.workspace_combo.findData(self._active_workspace_id or "")
        self.workspace_combo.setCurrentIndex(max(0, idx))
        self.workspace_combo.blockSignals(False)

    def _on_workspace_chip_changed(self, _index: int = 0) -> None:
        from .preferences import set_active_workspace_id

        wid = str(self.workspace_combo.currentData() or "").strip() or None
        self._active_workspace_id = wid
        set_active_workspace_id(wid)
        slot = self._slot()
        if not slot.busy:
            slot.workspace_id = wid

    def _go_parent(self) -> None:
        slot = self._slot()
        if slot.parent_id:
            self._switch_chat(slot.parent_id)

    def _update_breadcrumb(self, slot: ChatSlot) -> None:
        if not slot.parent_id:
            self.parent_btn.hide()
            self.breadcrumb_lbl.setText("")
            return
        parent = next((s for s in self._slots if s.id == slot.parent_id), None)
        self.parent_btn.show()
        pname = parent.title if parent else slot.parent_id
        self.breadcrumb_lbl.setText(f"{pname} › {slot.title}")

    def _apply_slot_ui(self) -> None:
        slot = self._slot()
        parts: list[str] = []
        if slot.user_prompt:
            parts.append(f"You: {slot.user_prompt}")
        if slot.reply_buf.strip():
            parts.append(slot.reply_buf.strip()[-2000:])
        elif slot.last_error:
            parts.append(f"Error: {slot.last_error}")
        self.bubble.setPlainText("\n\n".join(parts))
        sb = self.bubble.verticalScrollBar()
        sb.setValue(sb.maximum())
        self.think_block.clear()
        if slot.thinking_buf.strip():
            self.think_block.append_text(slot.thinking_buf)
            self.think_block.finish()
            self.think_block.collapse()
        self._rebuild_tool_widgets(slot)
        self.activity_lbl.setText(slot.activity)
        self.avatar.set_state(slot.avatar_state)
        self.send_btn.setEnabled(not slot.busy)
        can_retry = (
            not slot.busy
            and bool(slot.last_error)
            and bool((slot.user_prompt or "").strip())
        )
        self.retry_btn.setVisible(can_retry)
        self.retry_btn.setEnabled(can_retry)
        self.input.setEnabled(True)  # always allow typing / queue feel
        self._sync_harness_chip(slot)
        self._update_breadcrumb(slot)
        self._sync_session_chip()
        # Sync workspace combo to slot without clobbering global active on view-only
        self.workspace_combo.blockSignals(True)
        widx = self.workspace_combo.findData(slot.workspace_id or "")
        if widx >= 0:
            self.workspace_combo.setCurrentIndex(widx)
        self.workspace_combo.blockSignals(False)

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
        n = len([s for s in self._slots if not s.parent_id]) + 1
        slot = ChatSlot.new(
            f"Chat {n}", workspace_id=self._active_workspace_id
        )
        slot.harness_mode = self._slot().harness_mode
        self._slots.append(slot)
        self._active_id = slot.id
        self._toggle_panel(PANEL_NONE)
        self._apply_slot_ui()
        self._schedule_persist()
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
        slot.reply_buf = last or f"(loaded {title})"
        slot.workspace_id = self._active_workspace_id
        slot.title_locked = True
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
        idle_mark = ""
        try:
            from .idle import is_idle_eligible
            from .preferences import get_idle_mode

            self._idle_armed = get_idle_mode() != "off" and is_idle_eligible()
            if get_idle_mode() != "off":
                idle_mark = " · idle✓" if self._idle_armed else " · idle…"
        except Exception:
            self._idle_armed = False
        extra = f" · {busy_n} busy" if busy_n else ""
        self.presence_lbl.setText(f"{st}{extra}{idle_mark}")
        if hasattr(self, "avatar"):
            tip = self.avatar.toolTip() or ""
            base = tip.split(" · idle")[0] if " · idle" in tip else tip
            if self._idle_armed:
                self.avatar.setToolTip((base + " · idle sweep armed").strip(" ·"))
            elif base:
                self.avatar.setToolTip(base)
        slot = self._slot()
        if slot.busy:
            return
        if st == "paused":
            slot.avatar_state = STATE_PAUSED
            self.avatar.set_state(STATE_PAUSED)
        elif slot.avatar_state not in (STATE_ERROR, STATE_SPEAKING, STATE_THINKING):
            slot.avatar_state = STATE_IDLE
            self.avatar.set_state(STATE_IDLE)

    def _idle_tick(self) -> None:
        """Periodic idle sweep (schedules / idle-ok) when armed."""
        try:
            from .idle import is_idle_eligible, maybe_sweep
            from .preferences import get_idle_mode

            if get_idle_mode() == "off" or not is_idle_eligible():
                return
            # Run in-thread briefly; jobs are short dry-runs / schedule goals.
            maybe_sweep(start=True)
        except Exception:
            pass

    def _focus_tick(self) -> None:
        """Feature-plugin ticks (doomscroll, morning-brief, …) via registry."""
        try:
            from .plugins import tick_all

            for ev in tick_all(host="companion"):
                nudge = ev.get("companion_nudge")
                if nudge:
                    self._show_doomscroll_nudge(nudge)
                brief = ev.get("companion_brief")
                if brief:
                    self._show_morning_brief(brief)
        except Exception:
            pass

    def _show_morning_brief(self, brief: dict) -> None:
        lines = brief.get("lines") if isinstance(brief, dict) else None
        title = str((brief or {}).get("title") or "Morning Brief")
        text = "\n".join(str(x) for x in (lines or [])) or "(empty brief)"
        try:
            QMessageBox.information(self, title, text)
        except Exception:
            pass
        # Open Daily panel so the user can dig in
        try:
            self._toggle_panel(PANEL_DAILY)
        except Exception:
            pass

    def _show_doomscroll_nudge(self, nudge: dict) -> None:
        try:
            from .focus import clear_pending_nudge

            clear_pending_nudge()
        except Exception:
            pass
        msg = str(nudge.get("message") or "Time to leave the feed.")
        nb = nudge.get("net_block") if isinstance(nudge.get("net_block"), dict) else None
        if nb is not None and not nb.get("ok"):
            err = nb.get("error") or nb.get("stderr") or "apply failed"
            msg = f"{msg}\n\n(Net-block not active: {err})"

        # Optional chat injection (off by default — interrupt is a dialog/overlay).
        try:
            from .preferences import get_doomscroll_inject_chat

            if get_doomscroll_inject_chat():
                self.raise_()
                self.activateWindow()
                slot = self._slot()
                if not slot.busy:
                    slot.reply_buf = msg
                    slot.avatar_state = STATE_SPEAKING
                    slot.activity = "Doomscroll interrupt"
                    self._apply_slot_ui()
                try:
                    self.avatar.set_state(STATE_SPEAKING)
                except Exception:
                    pass
        except Exception:
            pass

        try:
            from .focus_actions import present_interrupt_dialog

            choice = present_interrupt_dialog(msg, parent=self)
        except Exception:
            # Fallback if Qt overlay fails
            QMessageBox.information(self, "Doomscroll interrupt", msg)
            choice = "dismiss"

        try:
            from .idle import touch_activity

            touch_activity("doomscroll-nudge")
        except Exception:
            pass

        if choice == "snooze":
            try:
                from .focus import snooze as focus_snooze

                focus_snooze(30)
            except Exception:
                pass

    def _pick_harness(self, slot: ChatSlot, text: str) -> str:
        import os

        from .harness import looks_like_coding_goal, resolve_harness_name

        env_force = (os.environ.get("NCC_ASSISTANT_COMPANION_HARNESS") or "").strip()
        mode = (slot.harness_mode or "auto").strip().lower()
        if env_force:
            force = env_force
        elif mode in ("native", "qwen", "dsh"):
            force = mode
        else:
            force = None
        tags = ["coding"] if looks_like_coding_goal(text) else []
        return resolve_harness_name(tags=tags, force=force)

    def _spawn_child_slot(self, parent: ChatSlot, event: dict[str, Any]) -> ChatSlot:
        title = str(event.get("title") or event.get("name") or "Subagent")[:20]
        child = ChatSlot.new(
            title, parent_id=parent.id, workspace_id=parent.workspace_id
        )
        child.harness_mode = parent.harness_mode
        child.harness = parent.harness
        child.user_prompt = str(event.get("goal") or event.get("text") or title)
        child.busy = True
        child.avatar_state = STATE_THINKING
        child.activity = "Subagent…"
        self._slots.append(child)
        return child

    def _retry(self) -> None:
        """Resend last user prompt after an error (does not re-append failed turn)."""
        slot = self._slot()
        if slot.busy:
            return
        text = (slot.user_prompt or "").strip()
        if not text or not slot.last_error:
            return
        self.input.setText(text)
        self._send()

    def _send(self) -> None:
        text = self.input.text().strip()
        if not text:
            return
        slot = self._slot()
        if slot.busy:
            return
        try:
            from .idle import touch_activity

            touch_activity("companion-send")
        except Exception:
            pass
        hname = self._pick_harness(slot, text)
        slot.harness = hname
        if hname == "native":
            self._ensure_session(slot)
        self.input.clear()
        slot.reply_buf = ""
        slot.thinking_buf = ""
        slot.tool_traces = []
        slot.last_error = ""
        slot.user_prompt = text
        slot.busy = True
        slot.avatar_state = STATE_THINKING
        slot.activity = f"Streaming ({hname})"
        if (
            not slot.title_locked
            and (slot.title.startswith("Chat ") or slot.title.startswith("Sub"))
            and len(text) > 2
        ):
            slot.title = text[:16] + ("…" if len(text) > 16 else "")
        cwd = None
        if slot.workspace_id:
            try:
                from .workspaces import get_workspace

                ws = get_workspace(slot.workspace_id)
                if ws:
                    cwd = str(ws.path)
            except Exception:
                pass
        self._apply_slot_ui()
        hist = list(slot.history or [])
        worker = _CompanionChatWorker(
            slot.id,
            text,
            harness_name=hname,
            session=slot.session,
            cwd=cwd,
            history=hist,
            parent=self,
        )
        slot.worker = worker
        worker.event.connect(self._on_event)
        worker.failed.connect(self._on_fail)
        worker.finished.connect(lambda sid=slot.id: self._on_worker_done(sid))
        worker.start()
        self._schedule_persist()

    def _on_worker_done(self, slot_id: str) -> None:
        slot = self._slot(slot_id)
        slot.busy = False
        slot.worker = None
        slot.activity = ""
        # Failed turns stay out of history so Retry can resend cleanly.
        if not slot.last_error:
            if slot.user_prompt:
                slot.history = list(slot.history or [])
                slot.history.append({"role": "user", "content": slot.user_prompt})
            if slot.reply_buf.strip():
                slot.history = list(slot.history or [])
                slot.history.append(
                    {"role": "assistant", "content": slot.reply_buf.strip()[-4000:]}
                )
            slot.history = (slot.history or [])[-40:]
        if slot.thinking_buf.strip() and slot_id == self._active_id:
            self.think_block.finish()
            self.think_block.collapse()
        self._schedule_persist()
        if slot_id == self._active_id:
            self._apply_slot_ui()
            self._sync_presence()
        else:
            self._sync_session_chip()

    def _on_event(self, slot_id: str, event: object) -> None:
        if not isinstance(event, dict):
            return
        slot = self._slot(slot_id)
        kind = event.get("kind")

        if _looks_like_subagent_spawn(event) and kind == "run_spawn":
            child = self._spawn_child_slot(slot, event)
            self._sync_session_chip()
            # Stay on parent unless event asks to focus child
            if event.get("focus"):
                self._switch_chat(child.id)
            return
        if kind == "tool" and _looks_like_subagent_spawn(event):
            # Interim: open nested tab (do not steal focus)
            child = self._spawn_child_slot(slot, event)
            self._sync_session_chip()

        if kind == "thinking_delta":
            slot.avatar_state = STATE_THINKING
            piece = str(event.get("text") or "")
            slot.thinking_buf += piece
            self._set_activity(slot, "Thinking…")
            if slot_id == self._active_id and piece:
                self.think_block.append_text(piece)
        elif kind in ("assistant_delta", "delta"):
            slot.avatar_state = STATE_SPEAKING
            slot.reply_buf += str(event.get("text") or "")
            self._set_activity(slot, f"Streaming ({slot.harness})")
            if slot_id == self._active_id:
                self.think_block.collapse()
        elif kind == "assistant":
            slot.reply_buf = str(event.get("text") or slot.reply_buf)
            if slot_id == self._active_id:
                self.think_block.finish()
                self.think_block.collapse()
        elif kind == "tool":
            name = str(event.get("name") or "tool")
            args = event.get("args") or {}
            slot.tool_traces = list(slot.tool_traces or [])
            slot.tool_traces.append({"name": name, "args": args, "result": ""})
            slot.avatar_state = STATE_THINKING
            self._set_activity(slot, f"Running {name}")
            if slot_id == self._active_id:
                from .gui_pages import ToolTraceWidget

                if not self.tools_scroll.isVisible():
                    self.tools_scroll.show()
                stretch = self.tools_layout.takeAt(self.tools_layout.count() - 1)
                w = ToolTraceWidget(name, args, compact=True)
                self.tools_layout.addWidget(w)
                self._tool_widgets.append(w)
                if stretch is not None:
                    self.tools_layout.addItem(stretch)
                else:
                    self.tools_layout.addStretch()
        elif kind == "tool_result":
            body = str(event.get("text") or "")
            traces = slot.tool_traces or []
            if traces:
                traces[-1]["result"] = body[:4000]
            if slot_id == self._active_id and self._tool_widgets:
                self._tool_widgets[-1].set_result(body)
        elif kind == "status":
            phase = str(event.get("phase") or "")
            text = str(event.get("text") or "")
            if phase == "tool" or text:
                slot.avatar_state = STATE_THINKING
                self._set_activity(slot, text or "Working…")
            # never append status into answer bubble
        elif kind == "error":
            slot.avatar_state = STATE_ERROR
            slot.last_error = str(event.get("text") or "error")
            slot.reply_buf = ""
            self._set_activity(slot, "")
        elif kind == "done":
            self._set_activity(slot, "")
            if slot.avatar_state != STATE_PAUSED:
                slot.avatar_state = STATE_IDLE
            if slot_id == self._active_id:
                self.think_block.finish()
                self.think_block.collapse()

        if slot_id == self._active_id:
            parts: list[str] = []
            if slot.user_prompt:
                parts.append(f"You: {slot.user_prompt}")
            if slot.last_error:
                parts.append(f"Error: {slot.last_error}")
            elif slot.reply_buf.strip():
                parts.append(slot.reply_buf.strip()[-2000:])
            self.bubble.setPlainText("\n\n".join(parts))
            sb = self.bubble.verticalScrollBar()
            sb.setValue(sb.maximum())
            self.avatar.set_state(slot.avatar_state)
            self._sync_harness_chip(slot)
            if kind in ("assistant_delta", "delta", "thinking_delta", "tool", "done", "run_spawn"):
                self._sync_session_chip()

    def _on_fail(self, slot_id: str, message: str) -> None:
        slot = self._slot(slot_id)
        slot.avatar_state = STATE_ERROR
        short = message.splitlines()[0][:400]
        slot.last_error = short
        slot.reply_buf = ""
        slot.busy = False
        slot.activity = ""
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
        elif key == PANEL_TEMPLATES:
            self.panel_title.setText("Workflow templates — tap to run")
            try:
                from .agent_templates import list_agent_templates

                tmpls = list_agent_templates()
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not tmpls:
                self.panel_list.addItem("(no templates)")
                return
            for t in tmpls[:50]:
                row = QListWidgetItem(f"{t.title}  ·  {t.category}")
                row.setToolTip(t.description or t.id)
                row.setData(Qt.ItemDataRole.UserRole, ("template", t.id))
                self.panel_list.addItem(row)
        elif key == PANEL_DAILY:
            self.panel_title.setText("Daily — PRs · issues · tasks (tap Refresh)")
            refresh = QListWidgetItem("↻ Refresh GitHub digest")
            refresh.setData(Qt.ItemDataRole.UserRole, ("daily_refresh", ""))
            self.panel_list.addItem(refresh)
            try:
                from .workflows import daily_summary_lines

                lines = daily_summary_lines()
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            for line in lines:
                row = QListWidgetItem(line)
                row.setData(Qt.ItemDataRole.UserRole, ("daily_line", line))
                self.panel_list.addItem(row)
        elif key == PANEL_PLUGINS:
            self.panel_title.setText("Plugins — tap name = on/off")
            try:
                from .plugins import list_plugins
                from .preferences import get_doomscroll_netblock_granted

                plugins = list_plugins()
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not plugins:
                self.panel_list.addItem("(no plugins)")
                return
            for p in plugins:
                mark = "✓" if p.is_enabled() else "·"
                extra = ""
                if p.id == "doomscroll":
                    try:
                        extra = (
                            " · net✓"
                            if get_doomscroll_netblock_granted()
                            else " · net✗"
                        )
                    except Exception:
                        extra = ""
                row = QListWidgetItem(f"{mark} {p.title}{extra}")
                row.setToolTip((p.description or p.id) + "\nTap = enable/disable.")
                row.setData(Qt.ItemDataRole.UserRole, ("plugin_toggle", p.id))
                self.panel_list.addItem(row)
                cfg = QListWidgetItem(f"    ⚙ Configure {p.title}")
                cfg.setData(Qt.ItemDataRole.UserRole, ("plugin_configure", p.id))
                self.panel_list.addItem(cfg)
            grant = QListWidgetItem("🔑 Grant doomscroll net-block privilege…")
            grant.setData(Qt.ItemDataRole.UserRole, ("plugin_grant_netblock", ""))
            self.panel_list.addItem(grant)
            open_gui = QListWidgetItem("↗ Open full AI → Plugins tab")
            open_gui.setData(Qt.ItemDataRole.UserRole, ("plugin_open_gui", ""))
            self.panel_list.addItem(open_gui)
        elif key == PANEL_TOOLS:
            self.panel_title.setText("Tools — tap to toggle enable")
            try:
                from .registry import get_registry

                tools = sorted(get_registry().list_all(), key=lambda t: t.name)
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not tools:
                self.panel_list.addItem("(no tools)")
                return
            for t in tools[:80]:
                mark = "✓" if t.enabled else "·"
                row = QListWidgetItem(f"{mark} {t.name}  [{t.kind}]")
                row.setToolTip(t.description or "")
                row.setData(Qt.ItemDataRole.UserRole, ("tool_toggle", t.name))
                self.panel_list.addItem(row)
        elif key == PANEL_MCP:
            self.panel_title.setText(
                "MCP — NCC inject · client servers · install catalog"
            )
            try:
                from .marketplace import (
                    installed_mcp_names,
                    list_installed_mcp,
                    list_templates,
                )

                installed = list_installed_mcp()
                have = installed_mcp_names()
                catalog = list_templates()
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            # Layer A: expose NCC tools INTO external harnesses
            self.panel_list.addItem(QListWidgetItem("— Harness (qwen/dsh) —"))
            inj = QListWidgetItem("⚡ Inject NCC MCP into qwen/dsh")
            inj.setToolTip(
                "Writes ncc-assistant-mcp into ~/.qwen/settings.json / dsh MCP "
                "config so coding harnesses can call NCC tools. "
                "This is NOT the marketplace catalog below."
            )
            inj.setData(Qt.ItemDataRole.UserRole, ("mcp_inject", ""))
            self.panel_list.addItem(inj)
            # Layer B: MCP servers NCC itself connects to as a client
            self.panel_list.addItem(
                QListWidgetItem("— Installed (NCC client) —")
            )
            if not installed:
                self.panel_list.addItem("(none — install from Catalog)")
            for entry in installed:
                on = bool(entry.get("enabled", True))
                en = "ON" if on else "OFF"
                row = QListWidgetItem(f"● {entry['name']}  ·  {en} · tap toggle")
                row.setToolTip(
                    f"{'Enabled' if on else 'Disabled'} in "
                    f"~/.config/ncc-assistant/mcp-servers.json\n"
                    f"{entry.get('command') or ''}\n"
                    "Tap to enable/disable. Separate row removes the entry."
                )
                row.setData(
                    Qt.ItemDataRole.UserRole, ("mcp_toggle", entry["name"])
                )
                self.panel_list.addItem(row)
                rm = QListWidgetItem(f"    🗑 Remove {entry['name']}")
                rm.setToolTip("Delete this server from mcp-servers.json")
                rm.setData(
                    Qt.ItemDataRole.UserRole, ("mcp_remove", entry["name"])
                )
                self.panel_list.addItem(rm)
            self.panel_list.addItem(
                QListWidgetItem("— Catalog (templates/mcp) —")
            )
            for tmpl in catalog:
                mark = "✓ installed" if tmpl.name in have else "+ install"
                row = QListWidgetItem(
                    f"{mark}  {tmpl.name}  ·  {tmpl.risk or 'read'}"
                )
                tip = getattr(tmpl, "description", "") or tmpl.name
                if getattr(tmpl, "install_hint", None):
                    tip = f"{tip}\n{tmpl.install_hint}"
                row.setToolTip(tip)
                if tmpl.name in have:
                    row.setData(Qt.ItemDataRole.UserRole, ("mcp_toggle", tmpl.name))
                else:
                    row.setData(Qt.ItemDataRole.UserRole, ("mcp_install", tmpl.name))
                self.panel_list.addItem(row)
        elif key == PANEL_WORKSPACES:
            self.panel_title.setText("Workspaces — tap set active · + add")
            add = QListWidgetItem("+ Add workspace folder…")
            add.setData(Qt.ItemDataRole.UserRole, ("ws_add", ""))
            self.panel_list.addItem(add)
            try:
                from .workspaces import list_workspaces

                items = list_workspaces()
            except Exception as exc:  # noqa: BLE001
                self.panel_list.addItem(f"(error: {exc})")
                return
            if not items:
                self.panel_list.addItem("(none yet)")
                return
            for ws in items:
                mark = "★" if ws.id == self._active_workspace_id else "·"
                row = QListWidgetItem(f"{mark} {ws.label}")
                row.setToolTip(ws.path)
                row.setData(Qt.ItemDataRole.UserRole, ("ws_select", ws.id))
                self.panel_list.addItem(row)
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

    def _on_panel_item(self, item: QListWidgetItem) -> None:
        data = item.data(Qt.ItemDataRole.UserRole)
        if not data or not isinstance(data, tuple) or len(data) != 2:
            return
        kind, ref = data
        if kind == "history" and ref:
            self._load_session_into_slot(str(ref))
            return
        if kind == "template" and ref:
            self._run_template(str(ref))
            return
        if kind == "daily_refresh":
            try:
                from .idle import touch_activity
                from .workflows import refresh_github_digest

                touch_activity("companion-daily")
                refresh_github_digest()
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "Daily", str(exc))
            self._fill_panel(PANEL_DAILY)
            return
        if kind == "plugin_toggle" and ref:
            try:
                from .plugins import get_plugin

                plugin = get_plugin(str(ref))
                if plugin is None:
                    return
                turning_on = not plugin.is_enabled()
                plugin.set_enabled(turning_on)
                if turning_on and str(ref) == "doomscroll":
                    from .plugins.doomscroll.privilege_ui import offer_netblock_grant

                    offer_netblock_grant(self)
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "Plugins", str(exc))
            self._fill_panel(PANEL_PLUGINS)
            return
        if kind == "plugin_configure":
            self._configure_plugin(str(ref) if ref else None)
            return
        if kind == "plugin_grant_netblock":
            try:
                from .plugins.doomscroll.privilege_ui import offer_netblock_grant

                offer_netblock_grant(self, force=True)
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "Plugins", str(exc))
            self._fill_panel(PANEL_PLUGINS)
            return
        if kind == "plugin_open_gui":
            self._open_full()
            return
        if kind == "tool_toggle" and ref:
            try:
                from .registry import get_registry

                reg = get_registry()
                entry = reg.get(str(ref))
                if entry:
                    reg.set_enabled(str(ref), not entry.enabled)
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "Tools", str(exc))
            self._fill_panel(PANEL_TOOLS)
            return
        if kind == "mcp_toggle" and ref:
            try:
                from .marketplace import list_installed_mcp, set_mcp_enabled
                from .registry import reload_registry

                cur = next(
                    (x for x in list_installed_mcp() if x["name"] == ref), None
                )
                if cur:
                    set_mcp_enabled(str(ref), not cur.get("enabled", True))
                    reload_registry()
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "MCP", str(exc))
            self._fill_panel(PANEL_MCP)
            return
        if kind == "mcp_remove" and ref:
            try:
                from .marketplace import remove_mcp_server
                from .registry import reload_registry

                if remove_mcp_server(str(ref)):
                    reload_registry()
            except Exception as exc:  # noqa: BLE001
                QMessageBox.warning(self, "MCP", str(exc))
            self._fill_panel(PANEL_MCP)
            return
        if kind == "mcp_install" and ref:
            self._mcp_install_named(str(ref))
            return
        if kind == "mcp_inject":
            self._inject_mcp_now()
            return
        if kind == "mcp_catalog":
            self._mcp_install_picker()
            return
        if kind == "ws_add":
            self._add_workspace_dialog()
            return
        if kind == "ws_select" and ref:
            from .preferences import set_active_workspace_id

            self._active_workspace_id = str(ref)
            set_active_workspace_id(str(ref))
            self._reload_workspace_chip()
            slot = self._slot()
            if not slot.busy:
                slot.workspace_id = str(ref)
            self._toggle_panel(PANEL_NONE)
            return
        if kind in ("cron", "job"):
            self._open_full()

    def _template_params(self, template_id: str) -> dict[str, Any] | None:
        from .agent_templates import get_agent_template

        tmpl = get_agent_template(template_id)
        if tmpl is None:
            QMessageBox.warning(self, "Templates", f"Unknown: {template_id}")
            return None
        params: dict[str, Any] = {
            p.id: p.default for p in tmpl.params if p.default is not None
        }
        ws = self._active_workspace_id or self._slot().workspace_id
        for p in tmpl.params:
            if p.type in ("workspaceList", "workspace") and ws:
                if p.type == "workspaceList":
                    params[p.id] = [ws]
                else:
                    params[p.id] = ws

        if tmpl.params:
            filled = self._template_param_dialog(tmpl, params)
            if filled is None:
                return None
            return filled
        if any(
            p.type in ("workspaceList", "workspace") and p.required for p in tmpl.params
        ) and not ws:
            QMessageBox.information(
                self,
                "Templates",
                "Select or add a workspace first (📁), then retry.",
            )
            return None
        return params

    def _template_param_dialog(
        self, tmpl: Any, seed: dict[str, Any]
    ) -> dict[str, Any] | None:
        dlg = QDialog(self)
        dlg.setWindowTitle(f"Template · {tmpl.title}")
        form = QFormLayout(dlg)
        widgets: dict[str, QWidget] = {}
        ws_ids: list[str] = []
        try:
            from .workspaces import list_workspaces

            ws_ids = [w.id for w in list_workspaces()]
        except Exception:
            pass
        from .templates_ui import FrequencyPicker, TimezonePicker

        for p in tmpl.params:
            if p.type in ("workspaceList", "workspace"):
                combo = QComboBox()
                combo.addItem("(none)", "")
                for wid in ws_ids:
                    combo.addItem(wid, wid)
                cur = seed.get(p.id)
                if isinstance(cur, list) and cur:
                    cur = cur[0]
                idx = combo.findData(str(cur or self._active_workspace_id or ""))
                if idx >= 0:
                    combo.setCurrentIndex(idx)
                form.addRow(p.label + (" *" if p.required else ""), combo)
                widgets[p.id] = combo
            elif p.type == "enum" and p.options:
                combo = QComboBox()
                for opt in p.options:
                    combo.addItem(str(opt), str(opt))
                if seed.get(p.id) is not None:
                    i = combo.findData(str(seed[p.id]))
                    if i >= 0:
                        combo.setCurrentIndex(i)
                form.addRow(p.label + (" *" if p.required else ""), combo)
                widgets[p.id] = combo
            elif p.type == "cronOrInterval":
                picker = FrequencyPicker(
                    default=str(seed.get(p.id) or p.default or "daily")
                )
                form.addRow(p.label + (" *" if p.required else ""), picker)
                widgets[p.id] = picker
            elif p.type == "timezone":
                tz = TimezonePicker(
                    default=str(seed.get(p.id) or p.default or "Europe/Berlin")
                )
                form.addRow(p.label + (" *" if p.required else ""), tz)
                widgets[p.id] = tz
            else:
                edit = QLineEdit(str(seed.get(p.id) or p.default or ""))
                form.addRow(p.label + (" *" if p.required else ""), edit)
                widgets[p.id] = edit
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(dlg.accept)
        buttons.rejected.connect(dlg.reject)
        form.addRow(buttons)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return None
        out: dict[str, Any] = dict(seed)
        for p in tmpl.params:
            w = widgets.get(p.id)
            if isinstance(w, FrequencyPicker):
                out[p.id] = w.on_calendar()
            elif isinstance(w, TimezonePicker):
                out[p.id] = w.currentText().strip()
            elif isinstance(w, QComboBox):
                val = w.currentData()
                if p.type == "workspaceList":
                    out[p.id] = [val] if val else []
                else:
                    out[p.id] = val
            elif isinstance(w, QLineEdit):
                out[p.id] = w.text().strip()
            if p.required and out.get(p.id) in (None, "", []):
                QMessageBox.warning(self, "Templates", f"Required: {p.label}")
                return None
        return out

    def _run_template(self, template_id: str) -> None:
        slot = self._slot()
        if slot.busy:
            QMessageBox.information(self, "Templates", "Current chat is busy.")
            return
        params = self._template_params(template_id)
        if params is None:
            return
        try:
            from .idle import touch_activity

            touch_activity("companion-template")
        except Exception:
            pass
        from .agent_templates import get_agent_template

        tmpl = get_agent_template(template_id)
        title = (tmpl.title if tmpl else template_id)[:24]
        force = None
        mode = (slot.harness_mode or "auto").strip().lower()
        if mode in ("native", "qwen", "dsh"):
            force = mode
        self._toggle_panel(PANEL_NONE)
        slot.reply_buf = ""
        slot.thinking_buf = ""
        slot.tool_traces = []
        slot.last_error = ""
        slot.user_prompt = f"[template] {title}"
        slot.busy = True
        slot.avatar_state = STATE_THINKING
        slot.activity = f"Template ({title})"
        if not slot.title_locked:
            slot.title = title
            slot.title_locked = True
        self._apply_slot_ui()
        worker = _CompanionTemplateWorker(
            slot.id,
            template_id,
            params,
            harness_force=force,
            parent=self,
        )
        slot.worker = worker
        worker.event.connect(self._on_event)
        worker.failed.connect(self._on_fail)
        worker.finished.connect(lambda sid=slot.id: self._on_worker_done(sid))
        worker.start()

    def _add_workspace_dialog(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Add workspace (git repo)")
        if not path:
            return
        try:
            from .workspaces import detect_github_slug, slug_from_path, upsert_workspace

            p = Path(path)
            wid = slug_from_path(p)
            gh = detect_github_slug(p)
            upsert_workspace(wid, str(p), label=p.name, github=gh)
            from .preferences import set_active_workspace_id

            self._active_workspace_id = wid
            set_active_workspace_id(wid)
            self._reload_workspace_chip()
            self._fill_panel(PANEL_WORKSPACES)
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "Workspaces", str(exc))

    def _mcp_install_picker(self) -> None:
        try:
            from .marketplace import installed_mcp_names, list_templates

            installed = installed_mcp_names()
            choices = [t.name for t in list_templates() if t.name not in installed]
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "MCP", str(exc))
            return
        if not choices:
            QMessageBox.information(self, "MCP", "All catalog templates already installed.")
            return
        name, ok = QInputDialog.getItem(
            self, "Install MCP", "Template:", choices, 0, False
        )
        if not ok or not name:
            return
        self._mcp_install_named(name)

    def _mcp_install_named(self, name: str) -> None:
        try:
            from .marketplace import install_template
            from .registry import reload_registry

            result = install_template(
                name, workspace_id=self._active_workspace_id
            )
            if not result.get("ok"):
                QMessageBox.warning(self, "MCP", str(result.get("error") or "failed"))
                return
            reload_registry()
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "MCP", str(exc))
            return
        self._fill_panel(PANEL_MCP)

    def _inject_mcp_now(self) -> None:
        try:
            from .harness.mcp_inject import ensure_dsh_ncc_mcp, ensure_qwen_ncc_mcp

            q = ensure_qwen_ncc_mcp(force=True)
            d = ensure_dsh_ncc_mcp(force=True)
            QMessageBox.information(
                self,
                "MCP inject",
                f"Qwen: {q.get('detail')}\nDSH: {d.get('detail')}",
            )
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "MCP inject", str(exc))

    def _pick_avatar_skin(self) -> None:
        try:
            from .avatar_skins import list_skins, resolve_skin, set_active_skin_id

            skins = list_skins()
            labels = [f"{s['label']} ({s['kind']})" for s in skins]
            choice, ok = QInputDialog.getItem(
                self, "Avatar skin", "Skin:", labels, 0, False
            )
            if not ok:
                return
            idx = labels.index(choice)
            sid = skins[idx]["id"]
            set_active_skin_id(sid)
            self.avatar.apply_skin(resolve_skin(sid))
            tip = (
                "Painted default."
                if sid == "painted"
                else f"Using {sid}. Put PNG frames in ~/.config/ncc-assistant/avatar-skins/{sid}/ "
                "(idle.png / thinking.png / speaking.png or a frames/ folder). "
                "Live2D: export PNG sequence into that folder (Cubism runtime not bundled)."
            )
            QMessageBox.information(self, "Avatar skin", tip)
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "Avatar skin", str(exc))

    def _configure_plugin(self, plugin_id: str | None) -> None:
        try:
            from .plugins import get_plugin, list_plugins

            pid = (plugin_id or "").strip()
            if not pid:
                plugins = list_plugins()
                pid = plugins[0].id if plugins else ""
            plugin = get_plugin(pid)
            if plugin is None:
                QMessageBox.information(self, "Plugins", "Unknown plugin.")
                return
            dlg = QDialog(self)
            dlg.setWindowTitle(f"Configure · {plugin.title}")
            dlg.resize(520, 640)
            lay = QVBoxLayout(dlg)
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setFrameShape(QFrame.Shape.NoFrame)
            body = plugin.build_settings_widget(dlg)
            scroll.setWidget(body)
            lay.addWidget(scroll, 1)
            buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
            buttons.rejected.connect(dlg.reject)
            buttons.accepted.connect(dlg.accept)
            lay.addWidget(buttons)
            dlg.exec()
            self._fill_panel(PANEL_PLUGINS)
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "Plugins", str(exc))

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
