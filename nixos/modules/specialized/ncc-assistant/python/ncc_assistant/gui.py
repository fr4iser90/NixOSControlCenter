"""Qt6 multi-tab window for NCC AI (Plasma-friendly)."""

from __future__ import annotations

import base64
import json
import mimetypes
import os
import sys
import threading
import traceback
from pathlib import Path
from urllib.parse import urlparse

from PySide6.QtCore import QObject, QSize, Qt, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QFont, QGuiApplication, QIcon, QKeyEvent, QPalette, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QSplitter,
    QStackedWidget,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QTextEdit,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from .auth import apply_api_key, probe_needs_auth, with_cached_credentials
from .config import Settings
from .history import (
    delete_session,
    list_sessions,
    load_session,
    session_plaintext,
)
from .preferences import (
    apply_startup_preferences,
    set_last_model,
    set_last_provider,
)
from .providers import (
    apply_provider_settings,
    ensure_seeded,
    find_provider_by_endpoint,
    get_provider,
)
from .provider_ui import edit_provider_dialog
from .runtime import ToolRuntime
from .session import ChatSession

try:
    from ncc_gui.dialogs import confirm as gui_engine_confirm
except ImportError:  # pragma: no cover
    gui_engine_confirm = None

MAX_IMAGE_BYTES = 8 * 1024 * 1024


class ConfirmBridge(QObject):
    """Ask the GUI thread for write/rebuild confirmation from a worker thread."""

    ask = Signal(dict)

    def __init__(self) -> None:
        super().__init__()
        self._event = threading.Event()
        self._answer = False

    def confirm(self, payload: dict) -> bool:
        self._event.clear()
        self._answer = False
        self.ask.emit(payload)
        self._event.wait(timeout=600)
        return self._answer

    @Slot(bool)
    def resolve(self, ok: bool) -> None:
        self._answer = ok
        self._event.set()


class AuthDialog(QDialog):
    def __init__(self, endpoint: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        host = urlparse(endpoint).netloc or endpoint
        self.setWindowTitle("NCC AI - API key")
        self.setModal(True)
        self.resize(440, 200)
        layout = QVBoxLayout(self)
        layout.addWidget(
            QLabel(
                f"Authentication required for <b>{host}</b>.<br/>"
                "Stored in ~/.config/ncc-assistant/ - never in systemConfig."
            )
        )
        form = QFormLayout()
        self.key_edit = QLineEdit()
        self.key_edit.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("API key", self.key_edit)
        self.header_combo = QComboBox()
        self.header_combo.addItem("Auto-detect", "auto")
        self.header_combo.addItem("X-API-KEY", "X-API-KEY")
        self.header_combo.addItem("x-api-key", "x-api-key")
        self.header_combo.addItem("x-ai-key", "x-ai-key")
        self.header_combo.addItem("Authorization (Bearer)", "Authorization")
        self.header_combo.addItem("Custom…", "custom")
        self.header_combo.currentIndexChanged.connect(self._on_header_mode)
        form.addRow("Header", self.header_combo)
        self.header_custom = QLineEdit()
        self.header_custom.setPlaceholderText("Custom header name")
        self.header_custom.hide()
        form.addRow("", self.header_custom)
        layout.addLayout(form)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self.key_edit.setFocus()

    def _on_header_mode(self, _index: int = 0) -> None:
        self.header_custom.setVisible(self.header_combo.currentData() == "custom")

    def values(self) -> tuple[str, str | None]:
        key = self.key_edit.text()
        mode = self.header_combo.currentData()
        if mode == "auto":
            return key, None
        if mode == "custom":
            custom = self.header_custom.text().strip()
            return key, custom or None
        return key, str(mode)


def prompt_auth_dialog(
    settings: Settings, parent: QWidget | None = None
) -> Settings:
    dlg = AuthDialog(settings.endpoint, parent)
    if dlg.exec() != QDialog.DialogCode.Accepted:
        raise RuntimeError("Authentication cancelled.")
    key, header = dlg.values()
    if header is None:
        return apply_api_key(settings, key)
    return apply_api_key(settings, key, preferred_header=header)


class SessionPicker(QDialog):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("NCC AI - Sessions")
        self.resize(520, 420)
        self.choice: str | None = None
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Continue a previous chat or start a new one."))
        self.list = QListWidget()
        for s in list_sessions():
            item = QListWidgetItem(
                f"{s['title']}\n{s['updated'][:19]}  |  {s.get('model') or ''}  |  {s['message_count']} msgs"
            )
            item.setData(Qt.ItemDataRole.UserRole, s["id"])
            self.list.addItem(item)
        self.list.itemDoubleClicked.connect(self._continue_item)
        layout.addWidget(self.list)
        row = QHBoxLayout()
        new_btn = QPushButton("New chat")
        new_btn.clicked.connect(self._new)
        cont_btn = QPushButton("Continue")
        cont_btn.clicked.connect(self._continue)
        cancel = QPushButton("Cancel")
        cancel.clicked.connect(self.reject)
        row.addWidget(new_btn)
        row.addWidget(cont_btn)
        row.addWidget(cancel)
        layout.addLayout(row)

    def _new(self) -> None:
        self.choice = "new"
        self.accept()

    def _continue(self) -> None:
        item = self.list.currentItem()
        if not item:
            if self.list.count() == 0:
                self._new()
                return
            QMessageBox.information(self, "NCC AI", "Select a session first.")
            return
        self.choice = item.data(Qt.ItemDataRole.UserRole)
        self.accept()

    def _continue_item(self, item: QListWidgetItem) -> None:
        self.choice = item.data(Qt.ItemDataRole.UserRole)
        self.accept()


class SessionRow(QWidget):
    """Three-line history row: title / model·provider / date·msgs + icon actions."""

    open_clicked = Signal(str)
    delete_clicked = Signal(str)
    copy_clicked = Signal(str)

    def __init__(self, meta: dict, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.session_id = str(meta.get("id") or "")
        lay = QHBoxLayout(self)
        lay.setContentsMargins(6, 6, 4, 6)
        lay.setSpacing(4)

        text_col = QVBoxLayout()
        text_col.setSpacing(1)

        raw_title = str(meta.get("title") or "Untitled").replace("\n", " ").strip()
        title = QLabel(raw_title)
        title.setObjectName("nccSessionTitle")
        title.setStyleSheet(
            "QLabel#nccSessionTitle { font-weight: 700; color: palette(window-text); }"
        )
        title.setWordWrap(False)
        title.setTextInteractionFlags(Qt.TextInteractionFlag.NoTextInteraction)
        title.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
        title.setToolTip(raw_title)
        # Elide long titles (fixed sidebar width)
        title.setText(
            title.fontMetrics().elidedText(raw_title, Qt.TextElideMode.ElideRight, 180)
        )
        title.setCursor(Qt.CursorShape.PointingHandCursor)
        title.mousePressEvent = lambda _e: self.open_clicked.emit(self.session_id)  # type: ignore[method-assign]
        text_col.addWidget(title)

        model = str(meta.get("model") or "—")
        provider = str(meta.get("provider") or "").strip()
        if not provider:
            ep = str(meta.get("endpoint") or "")
            provider = ep.split("//")[-1].split("/")[0] if ep else "—"
        line2_text = f"{model}  ·  {provider}"
        line2 = QLabel(
            title.fontMetrics().elidedText(line2_text, Qt.TextElideMode.ElideRight, 180)
        )
        line2.setObjectName("nccSessionMeta")
        line2.setStyleSheet(
            "QLabel#nccSessionMeta { color: palette(window-text); font-size: 11px; }"
        )
        line2.setWordWrap(False)
        line2.setToolTip(line2_text)
        line2.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
        line2.setCursor(Qt.CursorShape.PointingHandCursor)
        line2.mousePressEvent = lambda _e: self.open_clicked.emit(self.session_id)  # type: ignore[method-assign]
        text_col.addWidget(line2)

        updated = (meta.get("updated") or "")[:16].replace("T", " ")
        count = int(meta.get("message_count") or 0)
        line3 = QLabel(f"{updated}  ·  {count} msgs")
        line3.setObjectName("nccSessionDate")
        line3.setStyleSheet(
            "QLabel#nccSessionDate { color: palette(placeholder-text); font-size: 11px; }"
        )
        line3.setWordWrap(False)
        line3.setCursor(Qt.CursorShape.PointingHandCursor)
        line3.mousePressEvent = lambda _e: self.open_clicked.emit(self.session_id)  # type: ignore[method-assign]
        text_col.addWidget(line3)

        lay.addLayout(text_col, stretch=1)

        actions = QVBoxLayout()
        actions.setSpacing(2)

        def _icon_btn(theme: str, tip: str, fallback: str) -> QToolButton:
            btn = QToolButton()
            btn.setAutoRaise(True)
            btn.setToolTip(tip)
            icon = QIcon.fromTheme(theme)
            if not icon.isNull():
                btn.setIcon(icon)
            else:
                btn.setText(fallback)
            return btn

        copy_btn = _icon_btn("edit-copy", "Copy transcript", "⎘")
        copy_btn.clicked.connect(lambda: self.copy_clicked.emit(self.session_id))
        actions.addWidget(copy_btn)

        del_btn = _icon_btn("edit-delete", "Delete session", "⌫")
        del_btn.clicked.connect(lambda: self.delete_clicked.emit(self.session_id))
        actions.addWidget(del_btn)
        actions.addStretch()
        lay.addLayout(actions)


class SessionSidebar(QWidget):
    """Persistent chat history list (left of the chat feed)."""

    session_selected = Signal(str)
    new_requested = Signal()
    session_deleted = Signal(str)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("nccSessionSidebar")
        self.setFixedWidth(260)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 8, 0)
        lay.setSpacing(6)

        head = QHBoxLayout()
        title = QLabel("History")
        title.setStyleSheet("font-weight: 700; color: palette(window-text);")
        head.addWidget(title)
        head.addStretch()
        new_btn = QPushButton("New")
        new_btn.setToolTip("Start a new chat session")
        new_btn.clicked.connect(self.new_requested.emit)
        head.addWidget(new_btn)
        lay.addLayout(head)

        self.list = QListWidget()
        self.list.setObjectName("nccSessionList")
        self.list.setSpacing(4)
        self.list.setStyleSheet(
            "QListWidget#nccSessionList {"
            "  border: none; background: transparent;"
            "}"
            "QListWidget#nccSessionList::item {"
            "  border: 1px solid palette(mid); border-radius: 8px;"
            "  background: palette(base); margin: 0px;"
            "}"
            "QListWidget#nccSessionList::item:selected {"
            "  background: palette(highlight);"
            "}"
        )
        lay.addWidget(self.list, stretch=1)

        hint = QLabel("Saved under ~/.config/ncc-assistant/sessions")
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text); font-size: 11px;")
        lay.addWidget(hint)

    def refresh(self, current_id: str | None = None) -> None:
        self.list.clear()
        for s in list_sessions():
            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, s["id"])
            item.setSizeHint(QSize(240, 72))
            row = SessionRow(s)
            row.open_clicked.connect(self._on_open)
            row.delete_clicked.connect(self._on_delete)
            row.copy_clicked.connect(self._on_copy)
            self.list.addItem(item)
            self.list.setItemWidget(item, row)
            if current_id and s["id"] == current_id:
                self.list.setCurrentItem(item)

    def _on_open(self, session_id: str) -> None:
        for i in range(self.list.count()):
            item = self.list.item(i)
            if item and item.data(Qt.ItemDataRole.UserRole) == session_id:
                self.list.setCurrentItem(item)
                break
        self.session_selected.emit(session_id)

    def _on_delete(self, session_id: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete session",
            "Delete this chat from history?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        if delete_session(session_id):
            self.session_deleted.emit(session_id)
            self.refresh()

    def _on_copy(self, session_id: str) -> None:
        text = session_plaintext(session_id)
        if not text:
            return
        QGuiApplication.clipboard().setText(text)


class ChatWorker(QThread):
    event = Signal(object)
    failed = Signal(str)

    def __init__(
        self,
        session: ChatSession,
        text: str,
        images: list[dict[str, str]] | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._session = session
        self._text = text
        self._images = images or []

    def run(self) -> None:
        try:
            for ev in self._session.send(
                self._text, images=self._images, prompt_auth=None
            ):
                self.event.emit(ev)
        except Exception as exc:
            self.failed.emit(f"{exc}\n{traceback.format_exc()}")


from .gui_pages import (
    AgentPage,
    DiffReviewDialog,
    JobsPage,
    SchedulesPage,
    SettingsPage,
    ToolTraceWidget,
    ToolsPage,
)


class Bubble(QFrame):
    """Chat bubble with theme-safe contrast and icon copy."""

    def __init__(
        self,
        role: str,
        text: str = "",
        *,
        markdown: bool = False,
        pixmap: QPixmap | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setObjectName("nccBubble")
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum)
        self._markdown = markdown
        self._raw = text
        self._role = role

        role_l = role.lower()
        # Always pair background with WindowText / Text — never mid-on-mid.
        if role_l == "you":
            self.setProperty("nccRole", "you")
            self.setStyleSheet(
                "QFrame#nccBubble[nccRole='you'] {"
                "  background: palette(alternate-base);"
                "  border: 1px solid palette(mid);"
                "  border-radius: 12px;"
                "}"
            )
        elif role_l in ("assistant", "status"):
            self.setProperty("nccRole", "assistant")
            border = (
                "border: 1px solid palette(highlight);"
                if role_l == "status"
                else "border: 1px solid palette(mid);"
            )
            self.setStyleSheet(
                "QFrame#nccBubble[nccRole='assistant'] {"
                f"  background: palette(base); {border} border-radius: 12px;"
                "}"
            )
        elif role_l == "error":
            self.setProperty("nccRole", "error")
            self.setStyleSheet(
                "QFrame#nccBubble[nccRole='error'] {"
                "  background: palette(alternate-base);"
                "  border: 1px solid #c44; border-radius: 10px;"
                "}"
            )
        else:
            self.setProperty("nccRole", "meta")
            self.setStyleSheet(
                "QFrame#nccBubble[nccRole='meta'] {"
                "  background: palette(alternate-base);"
                "  border: 1px solid palette(mid); border-radius: 10px;"
                "}"
            )

        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 10, 14, 10)
        layout.setSpacing(6)

        header = QHBoxLayout()
        header.setSpacing(8)

        who = QLabel(role)
        who.setObjectName("nccBubbleRole")
        who.setStyleSheet(
            "QLabel#nccBubbleRole { font-weight: 700; color: palette(window-text); }"
        )
        header.addWidget(who)
        header.addStretch()

        copy_btn = QToolButton()
        copy_btn.setAutoRaise(True)
        copy_btn.setToolTip("Copy message")
        icon = QIcon.fromTheme("edit-copy")
        if not icon.isNull():
            copy_btn.setIcon(icon)
        else:
            copy_btn.setText("⎘")
        copy_btn.clicked.connect(self.copy_to_clipboard)
        header.addWidget(copy_btn)
        layout.addLayout(header)

        if pixmap is not None and not pixmap.isNull():
            img = QLabel()
            img.setPixmap(
                pixmap.scaled(
                    320,
                    240,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
            )
            layout.addWidget(img)

        if markdown:
            self.body = QTextBrowser()
            self.body.setOpenExternalLinks(True)
            self.body.setFrameShape(QFrame.Shape.NoFrame)
            self.body.setStyleSheet(
                "QTextBrowser { background: transparent; color: palette(text);"
                " padding: 0; border: none; }"
            )
            self.body.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            self.body.setTextInteractionFlags(
                Qt.TextInteractionFlag.TextSelectableByMouse
                | Qt.TextInteractionFlag.TextSelectableByKeyboard
                | Qt.TextInteractionFlag.LinksAccessibleByMouse
            )
            self.set_markdown(text)
            layout.addWidget(self.body)
        else:
            self.body = QLabel(text)
            self.body.setWordWrap(True)
            self.body.setStyleSheet("color: palette(window-text);")
            self.body.setTextInteractionFlags(
                Qt.TextInteractionFlag.TextSelectableByMouse
                | Qt.TextInteractionFlag.TextSelectableByKeyboard
            )
            layout.addWidget(self.body)

    def _markdown_doc_css(self) -> str:
        pal = self.palette()
        fg = pal.color(QPalette.ColorRole.WindowText).name()
        code_bg = pal.color(QPalette.ColorRole.AlternateBase).name()
        return (
            f"body {{ color: {fg}; }}"
            f"code, pre {{ background-color: {code_bg}; color: {fg}; }}"
            f"a {{ color: {pal.color(QPalette.ColorRole.Link).name()}; }}"
        )

    def set_markdown(self, text: str) -> None:
        self._raw = text
        if isinstance(self.body, QTextBrowser):
            self.body.document().setDefaultStyleSheet(self._markdown_doc_css())
            self.body.setMarkdown(text or "")
            doc = self.body.document()
            doc.setTextWidth(self.body.viewport().width() or 700)
            h = int(doc.size().height()) + 8
            self.body.setFixedHeight(max(h, 24))

    def append_markdown(self, piece: str) -> None:
        self.set_markdown((self._raw or "") + piece)

    def plain_text(self) -> str:
        if self._markdown:
            return self._raw or ""
        if isinstance(self.body, QLabel):
            return self.body.text()
        return self._raw or ""

    def copy_to_clipboard(self) -> None:
        QGuiApplication.clipboard().setText(self.plain_text())



class Composer(QTextEdit):
    submit = Signal()

    def keyPressEvent(self, event: QKeyEvent) -> None:
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if event.modifiers() & Qt.KeyboardModifier.ShiftModifier:
                super().keyPressEvent(event)
                return
            self.submit.emit()
            return
        super().keyPressEvent(event)


class ChatPage(QWidget):
    """Chat tab - existing ChatWindow logic as a widget."""

    def __init__(
        self,
        session: ChatSession,
        confirm: ConfirmBridge,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.session = session
        self.confirm = confirm
        self.confirm.ask.connect(self.on_confirm_request)
        self.session.set_confirm_hook(self.confirm.confirm)

        self._worker: ChatWorker | None = None
        self._last_user = ""
        self._busy = False
        self._pending_images: list[dict[str, str]] = []
        self._status_bubble: Bubble | None = None
        self._stream_bubble: Bubble | None = None
        self._pulse = 0
        self._model_guard = False
        self._provider_guard = False

        root = QHBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(0)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setChildrenCollapsible(False)

        self.sidebar = SessionSidebar()
        self.sidebar.new_requested.connect(self.on_new_session)
        self.sidebar.session_selected.connect(self._load_session_id)
        self.sidebar.session_deleted.connect(self._on_session_deleted)
        splitter.addWidget(self.sidebar)

        chat_host = QWidget()
        layout = QVBoxLayout(chat_host)
        layout.setContentsMargins(8, 0, 0, 0)
        layout.setSpacing(8)

        bar = QHBoxLayout()
        bar.addWidget(QLabel("Provider"))
        self.provider_combo = QComboBox()
        self.provider_combo.setMinimumWidth(140)
        self.provider_combo.currentIndexChanged.connect(self.on_provider_changed)
        bar.addWidget(self.provider_combo)

        def _bar_icon(theme: str, tip: str, fallback: str) -> QToolButton:
            btn = QToolButton()
            btn.setAutoRaise(True)
            btn.setToolTip(tip)
            icon = QIcon.fromTheme(theme)
            if not icon.isNull():
                btn.setIcon(icon)
            else:
                btn.setText(fallback)
            return btn

        self.provider_add_btn = _bar_icon("list-add", "Add provider", "+")
        self.provider_add_btn.clicked.connect(self.on_add_provider)
        bar.addWidget(self.provider_add_btn)
        self.provider_edit_btn = _bar_icon("document-edit", "Edit provider", "✎")
        self.provider_edit_btn.clicked.connect(self.on_edit_provider)
        bar.addWidget(self.provider_edit_btn)

        bar.addWidget(QLabel("Model"))
        self.model_combo = QComboBox()
        self.model_combo.setMinimumWidth(200)
        self.model_combo.currentIndexChanged.connect(self.on_model_changed)
        bar.addWidget(self.model_combo)

        new_btn = QPushButton("New")
        new_btn.setToolTip("Start a new chat session")
        new_btn.clicked.connect(self.on_new_session)
        bar.addWidget(new_btn)

        open_btn = QPushButton("Sessions")
        open_btn.setToolTip("Browse all sessions (dialog)")
        open_btn.clicked.connect(self.on_open_session)
        bar.addWidget(open_btn)

        bar.addStretch()
        layout.addLayout(bar)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.feed_host = QWidget()
        self.feed = QVBoxLayout(self.feed_host)
        self.feed.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.feed.setSpacing(10)
        self.scroll.setWidget(self.feed_host)

        # Empty landing (no fake chat bubble / no copy icon)
        self.landing = QLabel()
        self.landing.setObjectName("nccLanding")
        self.landing.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.landing.setWordWrap(True)
        self.landing.setTextFormat(Qt.TextFormat.RichText)
        self.landing.setStyleSheet(
            "QLabel#nccLanding {"
            "  color: palette(window-text);"
            "  padding: 48px 32px;"
            "  font-size: 14px;"
            "}"
        )

        self.chat_stack = QStackedWidget()
        self.chat_stack.addWidget(self.scroll)
        self.chat_stack.addWidget(self.landing)
        layout.addWidget(self.chat_stack, stretch=1)

        self.busy_bar = QProgressBar()
        self.busy_bar.setObjectName("nccBusy")
        self.busy_bar.setRange(0, 0)
        self.busy_bar.setTextVisible(False)
        self.busy_bar.hide()
        layout.addWidget(self.busy_bar)

        self.status = QLabel("")
        self.status.setStyleSheet("font-weight: 700; font-size: 13px;")
        self.status.hide()
        layout.addWidget(self.status)

        self.attach_label = QLabel("")
        self.attach_label.setStyleSheet("color: palette(mid);")
        self.attach_label.hide()
        layout.addWidget(self.attach_label)

        row = QHBoxLayout()
        self.attach_btn = QPushButton("Img")
        self.attach_btn.setToolTip("Attach image (vision models only)")
        self.attach_btn.setFixedSize(48, 90)
        self.attach_btn.clicked.connect(self.on_attach)
        row.addWidget(self.attach_btn)

        self.composer = Composer()
        self.composer.setObjectName("nccComposer")
        self.composer.setPlaceholderText("Message NCC...  Enter send / Shift+Enter newline")
        self.composer.setFixedHeight(90)
        self.composer.submit.connect(self.on_send)
        row.addWidget(self.composer, stretch=1)

        self.stop_btn = QPushButton("Stop")
        self.stop_btn.setFixedSize(90, 90)
        self.stop_btn.setEnabled(False)
        self.stop_btn.clicked.connect(self.on_stop)
        row.addWidget(self.stop_btn)

        self.send_btn = QPushButton("Send")
        self.send_btn.setFixedSize(100, 90)
        self.send_btn.clicked.connect(self.on_send)
        row.addWidget(self.send_btn)
        layout.addLayout(row)

        splitter.addWidget(chat_host)
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([260, 800])
        root.addWidget(splitter)

        self._pulse_timer = QTimer(self)
        self._pulse_timer.setInterval(450)
        self._pulse_timer.timeout.connect(self._pulse_status)

        self._populate_providers()
        self._populate_models()
        self._update_vision_ui()
        self._replay_history_bubbles()
        self.sidebar.refresh(self.session.session_id)
        self._refresh_landing()

    def _landing_text(self) -> str:
        writes = "on" if self.session.settings.writes_enabled else "off"
        rebuild = "on" if self.session.settings.allow_rebuild else "off"
        return (
            "<p style='font-size:22px;font-weight:700;margin:0 0 12px 0'>NCC Assistant</p>"
            "<p style='margin:0 0 8px 0'>Ask about your NixOS Control Center configuration.</p>"
            f"<p style='margin:0;opacity:0.85'>Config writes: <b>{writes}</b> · "
            f"System rebuilds: <b>{rebuild}</b><br/>"
            "Dangerous tools ask for confirmation in this window.</p>"
        )

    def _refresh_landing(self) -> None:
        """Show centered landing when there is no visible chat yet."""
        visible = 0
        for i in range(self.feed.count()):
            w = self.feed.itemAt(i).widget()
            if w is not None:
                visible += 1
        if visible == 0:
            self.landing.setText(self._landing_text())
            self.chat_stack.setCurrentWidget(self.landing)
        else:
            self.chat_stack.setCurrentWidget(self.scroll)

    def _populate_providers(self) -> None:
        self._provider_guard = True
        self.provider_combo.clear()
        providers = ensure_seeded()
        current_ep = self.session.settings.endpoint
        current_id = None
        match = find_provider_by_endpoint(current_ep)
        if match:
            current_id = match.id
        for p in providers:
            self.provider_combo.addItem(p.name, p.id)
        idx = self.provider_combo.findData(current_id) if current_id else -1
        if idx >= 0:
            self.provider_combo.setCurrentIndex(idx)
        elif self.provider_combo.count():
            self.provider_combo.setCurrentIndex(0)
        self._provider_guard = False

    def _populate_models(self) -> None:
        self._model_guard = True
        self.model_combo.clear()
        models = self.session.refresh_models()
        current = self.session.settings.model or self.session.model_label
        if not models and current:
            models = [{"id": current, "vision": self.session.current_model_vision()}]
        for m in models:
            mid = m.get("id") or ""
            label = mid + ("  (vision)" if m.get("vision") else "")
            self.model_combo.addItem(label, mid)
        idx = self.model_combo.findData(current)
        if idx < 0 and current:
            for i in range(self.model_combo.count()):
                if self.model_combo.itemData(i) == current:
                    idx = i
                    break
        if idx >= 0:
            self.model_combo.setCurrentIndex(idx)
        elif self.model_combo.count():
            self.model_combo.setCurrentIndex(0)
            mid = self.model_combo.currentData()
            if mid:
                self.session.set_model(str(mid))
                set_last_model(str(mid))
        self._model_guard = False

    def refresh_providers_ui(self) -> None:
        """Called from Settings after provider list edits."""
        self._populate_providers()

    def _replay_history_bubbles(self) -> None:
        for msg in self.session.messages:
            role = msg.get("role")
            if role == "system":
                continue
            content = msg.get("content")
            text = ""
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                bits = []
                for p in content:
                    if isinstance(p, dict) and p.get("type") == "text":
                        bits.append(p.get("text") or "")
                text = "\n".join(bits) or "[multimodal message]"
            if role == "user":
                self._add_bubble("You", text, markdown=False)
            elif role == "assistant":
                self._add_bubble("Assistant", text or "", markdown=True)
            elif role == "tool":
                self._add_bubble("Result", text[:1400], markdown=False)

    def _update_meta(self) -> None:
        """Kept as no-op for call sites; endpoint/key chrome lives in provider editor."""

    def _update_vision_ui(self) -> None:
        vision = self.session.current_model_vision()
        self.attach_btn.setVisible(vision)
        if not vision:
            self._pending_images.clear()
            self._refresh_attach_label()

    def _scroll_bottom(self) -> None:
        QApplication.processEvents()
        self.scroll.verticalScrollBar().setValue(
            self.scroll.verticalScrollBar().maximum()
        )

    def _add_bubble(
        self,
        role: str,
        text: str,
        *,
        markdown: bool = False,
        pixmap: QPixmap | None = None,
    ) -> Bubble:
        bubble = Bubble(role, text, markdown=markdown, pixmap=pixmap)
        self.feed.addWidget(bubble)
        self._refresh_landing()
        self._scroll_bottom()
        return bubble

    def _discard_empty_stream_bubble(self) -> None:
        """Remove a stream placeholder that never received text (tool-only rounds)."""
        b = self._stream_bubble
        if b is None:
            return
        if (b.plain_text() or "").strip():
            return
        self.feed.removeWidget(b)
        b.deleteLater()
        self._stream_bubble = None
        self._refresh_landing()

    def _set_activity(self, text: str | None) -> None:
        if not text:
            self.busy_bar.hide()
            self.status.hide()
            self.status.setText("")
            self._pulse_timer.stop()
            if self._status_bubble is not None:
                self.feed.removeWidget(self._status_bubble)
                self._status_bubble.deleteLater()
                self._status_bubble = None
            return
        self.busy_bar.show()
        self.status.show()
        self.status.setText(text + "...")
        self._pulse = 0
        if not self._pulse_timer.isActive():
            self._pulse_timer.start()
        # Status stays in the footer bar only — no extra bubble (avoids duplicate chrome).
        if self._status_bubble is not None:
            self.feed.removeWidget(self._status_bubble)
            self._status_bubble.deleteLater()
            self._status_bubble = None
        self._scroll_bottom()

    def _pulse_status(self) -> None:
        if not self.status.isVisible():
            return
        base = self.status.text().rstrip(".")
        self._pulse = (self._pulse + 1) % 4
        shown = base + ("." * self._pulse if self._pulse else "...")
        self.status.setText(shown)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.send_btn.setEnabled(not busy)
        self.attach_btn.setEnabled(not busy and self.attach_btn.isVisible())
        self.composer.setReadOnly(busy)
        self.model_combo.setEnabled(not busy)
        self.provider_combo.setEnabled(not busy)
        self.provider_add_btn.setEnabled(not busy)
        self.provider_edit_btn.setEnabled(not busy)
        self.stop_btn.setEnabled(busy)
        if not busy:
            self._set_activity(None)
            self._stream_bubble = None

    def _refresh_attach_label(self) -> None:
        n = len(self._pending_images)
        if n == 0:
            self.attach_label.hide()
            return
        names = ", ".join(img.get("name") or "image" for img in self._pending_images)
        self.attach_label.setText(f"Attached ({n}): {names}")
        self.attach_label.show()

    @Slot(int)
    def on_model_changed(self, _index: int) -> None:
        if self._model_guard:
            return
        mid = self.model_combo.currentData()
        if mid:
            self.session.set_model(str(mid))
            set_last_model(str(mid))
            self._update_vision_ui()
            self._update_meta()

    @Slot(int)
    def on_provider_changed(self, _index: int) -> None:
        if self._provider_guard:
            return
        pid = self.provider_combo.currentData()
        if not pid:
            return
        prov = get_provider(str(pid))
        if prov is None:
            return
        settings = apply_provider_settings(self.session.settings, prov)
        settings = with_cached_credentials(settings)
        self.session.settings = settings
        self.session.runtime = ToolRuntime(
            settings, confirm_hook=self.confirm.confirm
        )
        set_last_provider(prov.id, prov.endpoint)
        self._populate_models()
        self._update_vision_ui()

    @Slot()
    def on_add_provider(self) -> None:
        if self._busy:
            return
        prov = edit_provider_dialog(self, provider=None)
        if prov is None:
            return
        self.refresh_providers_ui()
        idx = self.provider_combo.findData(prov.id)
        if idx >= 0:
            self.provider_combo.setCurrentIndex(idx)

    @Slot()
    def on_edit_provider(self) -> None:
        if self._busy:
            return
        pid = self.provider_combo.currentData()
        if not pid:
            QMessageBox.information(self, "NCC AI", "Select a provider first.")
            return
        prov = get_provider(str(pid))
        if prov is None:
            return
        updated = edit_provider_dialog(self, provider=prov)
        if updated is None:
            return
        self.refresh_providers_ui()
        idx = self.provider_combo.findData(updated.id)
        if idx >= 0:
            self._provider_guard = True
            self.provider_combo.setCurrentIndex(idx)
            self._provider_guard = False
        # Re-apply in case endpoint/headers/key changed
        settings = apply_provider_settings(self.session.settings, updated)
        settings = with_cached_credentials(settings)
        self.session.settings = settings
        self.session.runtime = ToolRuntime(
            settings, confirm_hook=self.confirm.confirm
        )
        set_last_provider(updated.id, updated.endpoint)
        self._populate_models()
        self._update_vision_ui()

    @Slot(str)
    def _on_session_deleted(self, session_id: str) -> None:
        if session_id == self.session.session_id:
            self.on_new_session()
        else:
            self.sidebar.refresh(self.session.session_id)

    @Slot()
    def on_new_session(self) -> None:
        if self._busy:
            return
        self.session.reset_conversation()
        while self.feed.count():
            item = self.feed.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
        self._refresh_landing()
        self.sidebar.refresh(self.session.session_id)

    @Slot()
    def on_open_session(self) -> None:
        if self._busy:
            return
        picker = SessionPicker(self)
        if picker.exec() != QDialog.DialogCode.Accepted:
            return
        if picker.choice == "new" or not picker.choice:
            self.on_new_session()
            return
        self._load_session_id(picker.choice)

    @Slot(str)
    def _load_session_id(self, session_id: str) -> None:
        if self._busy:
            return
        if session_id == self.session.session_id:
            return
        data = load_session(session_id)
        if not data:
            QMessageBox.warning(self, "NCC AI", "Could not load session.")
            self.sidebar.refresh(self.session.session_id)
            return
        model = data.get("model")
        settings = self.session.settings
        if model:
            from dataclasses import replace
            settings = replace(settings, model=model)
        self.session = ChatSession.create(
            settings,
            interactive_auth=False,
            confirm_hook=self.confirm.confirm,
            messages=data.get("messages") or [],
            session_id=data.get("id"),
            title=data.get("title"),
        )
        while self.feed.count():
            item = self.feed.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
        self._populate_models()
        self._update_vision_ui()
        self._replay_history_bubbles()
        self._refresh_landing()
        self.sidebar.refresh(self.session.session_id)

    @Slot(dict)
    def on_confirm_request(self, payload: dict) -> None:
        detail = payload.get("detail") or ""
        text = f"{payload.get('summary', '')}\n\n{detail}"
        box = QMessageBox(self)
        box.setIcon(
            QMessageBox.Icon.Warning
            if payload.get("level") == "rebuild"
            else QMessageBox.Icon.Question
        )
        box.setWindowTitle(str(payload.get("title") or "Confirm"))
        box.setText(str(payload.get("summary") or "Confirm?"))
        box.setInformativeText(text[:3500])
        box.setStandardButtons(
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        box.setDefaultButton(QMessageBox.StandardButton.No)
        ok = box.exec() == QMessageBox.StandardButton.Yes
        self.confirm.resolve(ok)

    @Slot()
    def on_attach(self) -> None:
        if not self.session.current_model_vision():
            QMessageBox.information(
                self,
                "NCC AI",
                "Current model does not advertise vision. Pick a vision model first.",
            )
            return
        paths, _ = QFileDialog.getOpenFileNames(
            self,
            "Attach image",
            str(Path.home()),
            "Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)",
        )
        for path in paths:
            p = Path(path)
            try:
                raw = p.read_bytes()
            except OSError as exc:
                QMessageBox.warning(self, "NCC AI", f"Cannot read {p.name}: {exc}")
                continue
            if len(raw) > MAX_IMAGE_BYTES:
                QMessageBox.warning(self, "NCC AI", f"{p.name} > 8 MiB - skipped.")
                continue
            mime, _ = mimetypes.guess_type(str(p))
            if not mime or not mime.startswith("image/"):
                mime = "image/png"
            self._pending_images.append(
                {
                    "mime": mime,
                    "data_b64": base64.b64encode(raw).decode("ascii"),
                    "name": p.name,
                    "path": str(p),
                }
            )
        self._refresh_attach_label()

    @Slot()
    def on_stop(self) -> None:
        self.session.request_cancel()
        self.status.setText("Cancelling...")

    @Slot()
    def on_send(self) -> None:
        if self._busy:
            return
        text = self.composer.toPlainText().strip()
        images = list(self._pending_images)
        if not text and not images:
            return
        if images and not self.session.current_model_vision():
            QMessageBox.warning(
                self,
                "NCC AI",
                "Images attached but model is not vision-capable. Remove images or switch model.",
            )
            return
        self._last_user = text
        self.composer.clear()
        self._pending_images.clear()
        self._refresh_attach_label()
        self._set_busy(True)
        self._set_activity(f"Waiting for {self.session.model_label}")

        pix = None
        if images:
            try:
                pix = QPixmap(images[0]["path"])
            except Exception:
                pix = None
        preview = text or "(image)"
        if images and text:
            preview = f"{text}\n[{len(images)} image(s)]"
        elif images:
            preview = f"[{len(images)} image(s)]"
        self._add_bubble("You", preview, pixmap=pix)

        self._worker = ChatWorker(self.session, text, images, self)
        self._worker.event.connect(self.on_event)
        self._worker.failed.connect(self.on_fail)
        self._worker.finished.connect(self._on_worker_finished)
        self._worker.start()

    @Slot(object)
    def on_event(self, event: object) -> None:
        if not isinstance(event, dict):
            return
        kind = event.get("kind")
        if kind == "user":
            return
        if kind == "assistant_start":
            self._set_activity(f"Streaming from {self.session.model_label}")
            # Lazy: do not create an empty Assistant bubble (tool-only rounds
            # used to leave a duplicate grey header).
            self._discard_empty_stream_bubble()
            self._stream_bubble = None
        elif kind == "assistant_delta":
            if self._stream_bubble is None:
                self._stream_bubble = self._add_bubble("Assistant", "", markdown=True)
            self._stream_bubble.append_markdown(event.get("text") or "")
            self._scroll_bottom()
        elif kind == "assistant":
            self._set_activity(None)
            text = event.get("text") or ""
            if event.get("streamed") and self._stream_bubble is not None:
                self._stream_bubble.set_markdown(text)
                self._stream_bubble = None
            elif text.strip():
                self._discard_empty_stream_bubble()
                self._add_bubble("Assistant", text, markdown=True)
            else:
                self._discard_empty_stream_bubble()
            self._update_meta()
        elif kind == "tool":
            self._discard_empty_stream_bubble()
            from .gui_pages import ToolTraceWidget

            trace = ToolTraceWidget(str(event.get("name")), event.get("args"))
            self._last_trace = trace
            self.feed.addWidget(trace)
            self._scroll_bottom()
        elif kind == "tool_result":
            body = event.get("text") or ""
            if getattr(self, "_last_trace", None) is not None:
                self._last_trace.set_result(body)
                self._last_trace = None
            else:
                if len(body) > 1400:
                    body = body[:1400] + "..."
                self._add_bubble("Result", f"```\n{body}\n```", markdown=True)
            if event.get("name") == "propose_config_patch" or '"diff"' in body[:400]:
                try:
                    data = json.loads(body) if body.strip().startswith("{") else None
                except json.JSONDecodeError:
                    data = None
                if isinstance(data, dict) and data.get("diff"):
                    from .gui_pages import DiffReviewDialog

                    dlg = DiffReviewDialog([data], self)
                    if dlg.exec() == QDialog.DialogCode.Accepted and dlg.selected_paths:
                        QMessageBox.information(
                            self,
                            "Diff review",
                            "Selected: "
                            + ", ".join(dlg.selected_paths)
                            + "\nAsk the assistant to apply with confirm, or use Rollback assistant.",
                        )
        elif kind == "status":
            self._set_activity(str(event.get("text") or "Working"))
        elif kind == "error":
            self._set_activity(None)
            self._discard_empty_stream_bubble()
            self._stream_bubble = None
            self._add_bubble("Error", event.get("text") or "")
            self._maybe_reauth(str(event.get("text") or ""))
        elif kind == "done":
            self._set_activity(None)
            self._discard_empty_stream_bubble()
            self._update_meta()
            self.session.persist()
            self.sidebar.refresh(self.session.session_id)

    def _maybe_reauth(self, err: str) -> None:
        low = err.lower()
        if "401" not in low and "403" not in low and "unauthorized" not in low:
            return
        try:
            self.session.settings = prompt_auth_dialog(self.session.settings, self)
            self.session.runtime = ToolRuntime(
                self.session.settings, confirm_hook=self.confirm.confirm
            )
            self.session.refresh_models()
            self._populate_models()
            self._update_meta()
            if self._last_user:
                self.composer.setPlainText(self._last_user)
        except RuntimeError:
            pass

    @Slot(str)
    def on_fail(self, message: str) -> None:
        self._set_activity(None)
        self._add_bubble("Error", message)

    @Slot()
    def _on_worker_finished(self) -> None:
        self._set_busy(False)
        self.composer.setFocus()


class AssistantPanel(QWidget):
    """Embeddable AI tabs (Chat / Agent / Tools / Jobs / Schedules / Settings)."""

    def __init__(
        self,
        session: ChatSession,
        confirm: ConfirmBridge,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.session = session
        self.confirm = confirm
        self.setObjectName("nccRoot")
        self.setStyleSheet(
            """
            QWidget#nccRoot { background: palette(window); }
            QScrollArea { border: none; background: transparent; }
            QTextEdit#nccComposer {
              border: 1px solid palette(mid); border-radius: 10px;
              padding: 8px; background: palette(base);
            }
            QPushButton {
              border-radius: 8px; font-weight: 600; padding: 6px 10px;
            }
            QProgressBar#nccBusy {
              border: none; border-radius: 3px; background: palette(alternate-base);
              max-height: 6px;
            }
            QProgressBar#nccBusy::chunk { background: palette(highlight); border-radius: 3px; }
            QTabWidget::pane { border: 1px solid palette(mid); border-radius: 4px; }
            QTabBar::tab { padding: 8px 16px; }
            QTabBar::tab:selected { background: palette(highlight); color: palette(highlighted-text); }
            """
        )
        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)

        header = QHBoxLayout()
        title = QLabel("NCC AI Assistant")
        f = QFont()
        f.setPointSize(16)
        f.setBold(True)
        title.setFont(f)
        header.addWidget(title)
        header.addStretch()
        layout.addLayout(header)

        self.tabs = QTabWidget()
        layout.addWidget(self.tabs, stretch=1)

        self.chat_page = ChatPage(session, confirm)
        self.tabs.addTab(self.chat_page, "Chat")
        self.agent_page = AgentPage(confirm)
        self.tabs.addTab(self.agent_page, "Agent")
        self.tools_page = ToolsPage()
        self.tabs.addTab(self.tools_page, "Tools")
        self.jobs_page = JobsPage()
        self.tabs.addTab(self.jobs_page, "Jobs")
        self.schedules_page = SchedulesPage()
        self.tabs.addTab(self.schedules_page, "Schedules")
        self.settings_page = SettingsPage()
        self.settings_page.providers_changed.connect(self.chat_page.refresh_providers_ui)
        self.tabs.addTab(self.settings_page, "Settings")


class MainWindow(QMainWindow):
    """Main window wrapping AssistantPanel."""

    def __init__(
        self,
        session: ChatSession,
        confirm: ConfirmBridge,
    ) -> None:
        super().__init__()
        self.session = session
        self.confirm = confirm
        self.setWindowTitle("NCC AI Assistant")
        self.resize(1000, 800)
        self.panel = AssistantPanel(session, confirm)
        self.setCentralWidget(self.panel)
        self.chat_page = self.panel.chat_page


def create_assistant_panel(
    settings: Settings | None = None,
    *,
    parent: QWidget | None = None,
    skip_session_picker: bool = True,
) -> QWidget:
    """Embeddable AI panel for the NCC root shell."""
    settings = apply_startup_preferences(
        settings or Settings.from_env(client_mode="chat")
    )
    try:
        if not settings.api_key:
            need = probe_needs_auth(settings)
            if need is True or settings.api == "anthropic":
                settings = prompt_auth_dialog(settings)
    except RuntimeError as exc:
        box = QWidget(parent)
        lay = QVBoxLayout(box)
        lay.addWidget(QLabel(f"AI unavailable: {exc}"))
        return box

    confirm = ConfirmBridge()
    session_kwargs: dict = {
        "interactive_auth": False,
        "confirm_hook": confirm.confirm,
    }
    if not skip_session_picker:
        picker = SessionPicker()
        if picker.exec() != QDialog.DialogCode.Accepted:
            box = QWidget(parent)
            lay = QVBoxLayout(box)
            lay.addWidget(QLabel("Session picker cancelled."))
            return box
        if picker.choice and picker.choice != "new":
            data = load_session(picker.choice)
            if data:
                from dataclasses import replace
                if data.get("model"):
                    settings = replace(settings, model=data["model"])
                session_kwargs.update(
                    messages=data.get("messages") or [],
                    session_id=data.get("id"),
                    title=data.get("title"),
                )
    try:
        session = ChatSession.create(settings, **session_kwargs)
    except Exception as exc:  # noqa: BLE001 — show panel even if LLM is down
        box = QWidget(parent)
        lay = QVBoxLayout(box)
        lay.addWidget(QLabel(f"AI session failed: {exc}"))
        return box
    return AssistantPanel(session, confirm, parent=parent)


def run_gui(settings: Settings | None = None) -> int:
    try:
        from ncc_gui.app import ensure_app

        app = ensure_app(sys.argv)
    except ImportError:
        app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("NCC AI")
    app.setDesktopFileName("ncc-assistant")

    settings = apply_startup_preferences(
        settings or Settings.from_env(client_mode="chat")
    )

    try:
        if not settings.api_key:
            need = probe_needs_auth(settings)
            if need is True or settings.api == "anthropic":
                settings = prompt_auth_dialog(settings)
    except RuntimeError as exc:
        QMessageBox.critical(None, "NCC AI", str(exc))
        return 1

    picker = SessionPicker()
    if picker.exec() != QDialog.DialogCode.Accepted:
        return 0

    confirm = ConfirmBridge()
    session_kwargs: dict = {
        "interactive_auth": False,
        "confirm_hook": confirm.confirm,
    }

    if picker.choice and picker.choice != "new":
        data = load_session(picker.choice)
        if data:
            from dataclasses import replace
            if data.get("model"):
                settings = replace(settings, model=data["model"])
            session_kwargs.update(
                messages=data.get("messages") or [],
                session_id=data.get("id"),
                title=data.get("title"),
            )

    try:
        session = ChatSession.create(settings, **session_kwargs)
    except RuntimeError as exc:
        QMessageBox.critical(None, "NCC AI", str(exc))
        return 1

    try:
        from ncc_gui.reload import generation_bus, resolve_executable, set_relaunch_argv

        set_relaunch_argv([resolve_executable("ncc-assistant"), "gui"])

        def _soft() -> None:
            try:
                from .registry import reload_registry

                reload_registry()
            except Exception:
                pass

        generation_bus().soft_switched.connect(_soft)
    except ImportError:
        pass

    window = MainWindow(session, confirm)
    window.show()
    window.chat_page.composer.setFocus()
    return int(app.exec())
