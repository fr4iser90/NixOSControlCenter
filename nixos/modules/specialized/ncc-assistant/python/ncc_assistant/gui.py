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
    QMenu,
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

from .auth import apply_api_key, with_cached_credentials
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
from .transcript import (
    format_from_index_plaintext,
    format_messages_markdown,
    format_messages_plaintext,
    message_plaintext,
)

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
        self._copy_btn = copy_btn
        copy_btn.clicked.connect(self._on_copy_clicked)
        actions.addWidget(copy_btn)

        del_btn = _icon_btn("edit-delete", "Delete session", "⌫")
        del_btn.clicked.connect(lambda: self.delete_clicked.emit(self.session_id))
        actions.addWidget(del_btn)
        actions.addStretch()
        lay.addLayout(actions)

    def _on_copy_clicked(self) -> None:
        self.copy_clicked.emit(self.session_id)
        btn = self._copy_btn
        prev_tip = btn.toolTip()
        prev_text = btn.text()
        had_icon = not btn.icon().isNull()
        btn.setToolTip("Copied")
        ok = QIcon.fromTheme("dialog-ok")
        if not ok.isNull():
            btn.setIcon(ok)
            btn.setText("")
        else:
            btn.setIcon(QIcon())
            btn.setText("✓")

        def _restore() -> None:
            btn.setToolTip(prev_tip or "Copy transcript")
            if had_icon:
                icon = QIcon.fromTheme("edit-copy")
                btn.setText("")
                if not icon.isNull():
                    btn.setIcon(icon)
                else:
                    btn.setText(prev_text or "⎘")
            else:
                btn.setIcon(QIcon())
                btn.setText(prev_text or "⎘")

        QTimer.singleShot(1200, _restore)


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


class ModelsFetchWorker(QThread):
    """Background GET /models so ChatPage open stays responsive."""

    finished_ok = Signal(object)  # list[dict]
    failed = Signal(str)

    def __init__(self, settings: Settings, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._settings = settings

    def run(self) -> None:
        try:
            from .llm import list_models

            self.finished_ok.emit(list_models(self._settings))
        except Exception as exc:  # noqa: BLE001
            self.failed.emit(str(exc))


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
    """Chat bubble — shared chrome with ToolTraceWidget (radius/margins/border)."""

    _RADIUS = 8
    _MARGINS = (10, 8, 10, 8)
    _SPACING = 4

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
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        self._markdown = markdown
        self._raw = text
        self._role = role

        role_l = role.lower()
        # Same radius/border weight for every role; only fill/accent differs.
        if role_l == "you":
            self.setProperty("nccRole", "you")
            bg, border = "palette(alternate-base)", "palette(mid)"
        elif role_l in ("assistant", "status"):
            self.setProperty("nccRole", "assistant")
            bg, border = "palette(base)", "palette(mid)"
        elif role_l == "error":
            self.setProperty("nccRole", "error")
            bg, border = "palette(alternate-base)", "#c44"
        else:
            self.setProperty("nccRole", "meta")
            bg, border = "palette(alternate-base)", "palette(mid)"

        self.setStyleSheet(
            f"QFrame#nccBubble[nccRole='{self.property('nccRole')}'] {{"
            f"  background: {bg};"
            f"  border: 1px solid {border};"
            f"  border-radius: {self._RADIUS}px;"
            "}"
        )

        layout = QVBoxLayout(self)
        layout.setContentsMargins(*self._MARGINS)
        layout.setSpacing(self._SPACING)

        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        header.setSpacing(4)

        who = QLabel(role)
        who.setObjectName("nccBubbleRole")
        who.setStyleSheet(
            "QLabel#nccBubbleRole {"
            "  font-weight: 700; font-size: 12px;"
            "  color: palette(window-text); padding: 0; margin: 0;"
            "}"
        )
        header.addWidget(who)
        header.addStretch()

        copy_btn = QToolButton()
        copy_btn.setAutoRaise(True)
        copy_btn.setFixedSize(22, 22)
        copy_btn.setToolTip("Copy message")
        copy_btn.setStyleSheet(
            "QToolButton { border: none; padding: 0; margin: 0; }"
        )
        icon = QIcon.fromTheme("edit-copy")
        if not icon.isNull():
            copy_btn.setIcon(icon)
        else:
            copy_btn.setText("⎘")
        copy_btn.clicked.connect(self.copy_to_clipboard)
        self._copy_btn = copy_btn
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
            self.body.setSizePolicy(
                QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
            )
            self.body.setStyleSheet(
                "QTextBrowser { background: transparent; color: palette(text);"
                " padding: 0; margin: 0; border: none; }"
            )
            self.body.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            self.body.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
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
            self.body.setSizePolicy(
                QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum
            )
            self.body.setStyleSheet(
                "color: palette(window-text); padding: 0; margin: 0;"
            )
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
        if not isinstance(self.body, QTextBrowser):
            return
        raw = text or ""
        self.body.document().setDefaultStyleSheet(self._markdown_doc_css())
        if not raw.strip():
            self.body.clear()
            self.body.setFixedHeight(1)
            return
        self.body.setMarkdown(raw)
        doc = self.body.document()
        # Viewport is often 0 before first layout → wrong wrap → huge empty height.
        width = self.body.viewport().width()
        if width < 80:
            width = max(self.width() - 48, 480)
        doc.setTextWidth(float(width))
        h = int(doc.size().height()) + 10
        # Short replies stay short; long replies grow (hard cap for safety).
        self.body.setFixedHeight(max(28, min(h, 12000)))

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
        btn = getattr(self, "_copy_btn", None)
        if btn is None:
            return
        prev_tip = btn.toolTip()
        prev_text = btn.text()
        btn.setToolTip("Copied")
        if btn.icon().isNull():
            btn.setText("✓")
        else:
            ok = QIcon.fromTheme("dialog-ok")
            if not ok.isNull():
                btn.setIcon(ok)
            else:
                btn.setText("✓")
                btn.setIcon(QIcon())

        def _restore() -> None:
            btn.setToolTip(prev_tip or "Copy message")
            if prev_text:
                btn.setText(prev_text)
                btn.setIcon(QIcon())
            else:
                icon = QIcon.fromTheme("edit-copy")
                btn.setText("")
                if not icon.isNull():
                    btn.setIcon(icon)
                else:
                    btn.setText("⎘")

        QTimer.singleShot(1200, _restore)

    def set_message_index(self, index: int | None) -> None:
        self._message_index = index

    def message_index(self) -> int | None:
        return getattr(self, "_message_index", None)


class TranscriptView(QTextBrowser):
    """Document-like working view of the same ChatSession.messages (read-only)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("nccTranscript")
        self.setOpenExternalLinks(True)
        self.setReadOnly(True)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setStyleSheet(
            "QTextBrowser#nccTranscript {"
            "  background: palette(base); color: palette(text);"
            "  padding: 16px 20px; border: none;"
            "  selection-background-color: palette(highlight);"
            "  selection-color: palette(highlighted-text);"
            "}"
        )
        self.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse
            | Qt.TextInteractionFlag.TextSelectableByKeyboard
            | Qt.TextInteractionFlag.LinksAccessibleByMouse
        )
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self._on_menu)
        self._plain_cache = ""
        self._copy_all_cb = None
        self._copy_md_cb = None

    def set_copy_handlers(self, copy_all, copy_md) -> None:
        self._copy_all_cb = copy_all
        self._copy_md_cb = copy_md

    def rebuild(
        self,
        messages: list,
        *,
        title: str | None = None,
        streaming: bool = False,
    ) -> None:
        md = format_messages_markdown(
            list(messages or []),
            include_system=False,
            include_tools=True,
            title=title or "Conversation",
        )
        self._plain_cache = format_messages_plaintext(
            list(messages or []), include_system=False, include_tools=True
        )
        if streaming:
            md = (
                md.rstrip()
                + "\n\n---\n\n"
                + "_A reply is still streaming in the Chat view. "
                "This text updates when that turn finishes._\n"
            )
        elif not (messages or []):
            md = (
                "# Conversation\n\n"
                "_No messages yet. Send a message in Chat, or keep typing here "
                "in the composer below — this view stays open._\n"
            )
            self._plain_cache = ""
        self.document().setDefaultStyleSheet(self._doc_css())
        self.setMarkdown(md)

    def _doc_css(self) -> str:
        pal = self.palette()
        fg = pal.color(QPalette.ColorRole.WindowText).name()
        muted = pal.color(QPalette.ColorRole.PlaceholderText).name()
        code_bg = pal.color(QPalette.ColorRole.AlternateBase).name()
        return (
            f"body {{ color: {fg}; font-size: 14px; }}"
            f"h1 {{ font-size: 18px; font-weight: 700; margin: 0 0 16px 0; }}"
            f"h3 {{ font-size: 13px; font-weight: 700; margin: 18px 0 6px 0;"
            f" color: {muted}; text-transform: none; }}"
            f"p {{ margin: 0 0 8px 0; }}"
            f"code, pre {{ background-color: {code_bg}; color: {fg}; }}"
            f"pre {{ padding: 8px; border-radius: 6px; }}"
            f"a {{ color: {pal.color(QPalette.ColorRole.Link).name()}; }}"
            f"hr {{ border: none; border-top: 1px solid {muted}; margin: 16px 0; }}"
        )

    def _on_menu(self, pos) -> None:
        menu = QMenu(self)
        cursor = self.textCursor()
        if cursor.hasSelection():
            act = menu.addAction("Copy")
            act.triggered.connect(
                lambda: QGuiApplication.clipboard().setText(cursor.selectedText())
            )
            menu.addSeparator()
        if self._copy_all_cb:
            menu.addAction("Copy entire chat", self._copy_all_cb)
        if self._copy_md_cb:
            menu.addAction("Copy entire chat as Markdown", self._copy_md_cb)
        menu.exec(self.mapToGlobal(pos))


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
        self._stick_bottom = True
        self._view_mode = "chat"  # "chat" | "transcript"

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

        self.view_btn = QPushButton("Transcript")
        self.view_btn.setToolTip(
            "Document view of this conversation — select across messages, Ctrl+C"
        )
        self.view_btn.clicked.connect(self.toggle_view)
        bar.addWidget(self.view_btn)

        bar.addStretch()
        layout.addLayout(bar)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.feed_host = QWidget()
        self.feed = QVBoxLayout(self.feed_host)
        self.feed.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.feed.setSpacing(8)
        self.scroll.setWidget(self.feed_host)
        self.scroll.verticalScrollBar().valueChanged.connect(self._on_scroll_moved)

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
        self.transcript = TranscriptView()
        self.transcript.set_copy_handlers(
            self.copy_entire_chat_plain, self.copy_entire_chat_markdown
        )
        self.chat_stack.addWidget(self.transcript)
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

        self._models_worker: ModelsFetchWorker | None = None
        self._models_fetch_gen = 0

        self._populate_providers()
        # Seed combo from settings only — GET /models runs in background.
        self._populate_models(fetch=False)
        self._update_vision_ui()
        self._replay_history_bubbles()
        self.sidebar.refresh(self.session.session_id)
        self._refresh_landing()
        QTimer.singleShot(0, self._start_models_fetch)

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
        """Show centered landing when there is no visible chat yet (chat view only)."""
        if self._view_mode == "transcript":
            self.chat_stack.setCurrentWidget(self.transcript)
            return
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

    @Slot()
    def toggle_view(self) -> None:
        if self._view_mode == "chat":
            self._view_mode = "transcript"
            self.view_btn.setText("Chat")
            self.view_btn.setToolTip("Back to bubble chat (live streaming)")
            self._rebuild_transcript()
            self.chat_stack.setCurrentWidget(self.transcript)
        else:
            self._view_mode = "chat"
            self.view_btn.setText("Transcript")
            self.view_btn.setToolTip(
                "Document view of this conversation — select across messages, Ctrl+C"
            )
            self._refresh_landing()

    def _rebuild_transcript(self) -> None:
        self.transcript.rebuild(
            self.session.messages,
            title=self.session.title or "Conversation",
            streaming=bool(self._busy),
        )

    def _maybe_refresh_transcript(self) -> None:
        if self._view_mode == "transcript":
            self._rebuild_transcript()

    def copy_entire_chat_plain(self) -> None:
        text = format_messages_plaintext(
            self.session.messages, include_system=False, include_tools=True
        )
        if text:
            QGuiApplication.clipboard().setText(text)

    def copy_entire_chat_markdown(self) -> None:
        text = format_messages_markdown(
            self.session.messages,
            include_system=False,
            include_tools=True,
            title=self.session.title or "Conversation",
        )
        if text:
            QGuiApplication.clipboard().setText(text)

    def copy_from_message_index(self, index: int) -> None:
        text = format_from_index_plaintext(
            self.session.messages, index, include_system=False, include_tools=True
        )
        if text:
            QGuiApplication.clipboard().setText(text)

    def _bubble_context_menu(self, bubble: Bubble, pos) -> None:
        menu = QMenu(self)
        menu.addAction(
            "Copy message",
            lambda: QGuiApplication.clipboard().setText(bubble.plain_text() or ""),
        )
        idx = bubble.message_index()
        if idx is None:
            idx = self._guess_message_index(bubble)
        if idx is not None:
            menu.addAction(
                "Copy from here",
                lambda i=idx: self.copy_from_message_index(i),
            )
        menu.addAction("Copy entire chat", self.copy_entire_chat_plain)
        menu.addAction("Copy entire chat as Markdown", self.copy_entire_chat_markdown)
        menu.exec(bubble.mapToGlobal(pos))

    def _guess_message_index(self, bubble: Bubble) -> int | None:
        role_l = (bubble._role or "").lower()
        want = "user" if role_l == "you" else "assistant" if role_l == "assistant" else None
        if not want:
            return None
        needle = (bubble.plain_text() or "").strip()
        last: int | None = None
        for i, msg in enumerate(self.session.messages):
            if not isinstance(msg, dict) or msg.get("role") != want:
                continue
            body = message_plaintext(msg)
            if needle and needle in body:
                last = i
            elif not needle:
                last = i
        return last

    def _wire_bubble_menu(self, bubble: Bubble) -> None:
        bubble.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        bubble.customContextMenuRequested.connect(
            lambda pos, b=bubble: self._bubble_context_menu(b, pos)
        )

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

    def _populate_models(self, *, fetch: bool = True) -> None:
        self._model_guard = True
        self.model_combo.clear()
        if fetch:
            models = self.session.refresh_models()
        else:
            models = list(self.session.available_models)
        current = self.session.settings.model or (
            self.session.model_label
            if self.session.model_label not in ("auto", "unset", "auto (unavailable)")
            else None
        )
        if not models and current:
            models = [{"id": current, "vision": self.session.current_model_vision()}]
        if not models:
            # Keep the combo usable while /models is loading or failing.
            self.model_combo.addItem("auto", "")
            self._model_guard = False
            return
        for m in models:
            mid = m.get("id") or ""
            label = mid + ("  (vision)" if m.get("vision") else "")
            self.model_combo.addItem(label, mid)
        idx = self.model_combo.findData(current) if current else -1
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

    def _start_models_fetch(self) -> None:
        self._models_fetch_gen += 1
        gen = self._models_fetch_gen
        self.model_combo.setToolTip("Loading models…")
        worker = ModelsFetchWorker(self.session.settings, self)
        self._models_worker = worker

        def _ok(models: object, g: int = gen) -> None:
            if g != self._models_fetch_gen:
                return
            self._on_models_loaded(models)

        def _fail(message: str, g: int = gen) -> None:
            if g != self._models_fetch_gen:
                return
            self._on_models_failed(message)

        worker.finished_ok.connect(_ok)
        worker.failed.connect(_fail)
        worker.start()

    @Slot(object)
    def _on_models_loaded(self, models: object) -> None:
        if not isinstance(models, list):
            return
        self.session.available_models = list(models)
        self.model_combo.setToolTip("")
        self._populate_models(fetch=False)
        self._update_vision_ui()

    @Slot(str)
    def _on_models_failed(self, message: str) -> None:
        self.model_combo.setToolTip(f"Could not list models: {message}")
        # Keep configured / auto entry selectable.
        if not self.session.available_models and self.session.settings.model:
            self.session.available_models = [
                {
                    "id": self.session.settings.model,
                    "vision": self.session.current_model_vision(),
                }
            ]
            self._populate_models(fetch=False)
        self.status.setText("Model list unavailable — using configured model")
        self.status.show()

    def refresh_providers_ui(self) -> None:
        """Called from Settings after provider list edits."""
        self._populate_providers()

    def _replay_history_bubbles(self) -> None:
        from .gui_pages import ToolTraceWidget

        # Map tool_call_id / name → args from the preceding assistant message.
        pending_args: dict[str, object] = {}

        for idx, msg in enumerate(self.session.messages):
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
                self._add_bubble("You", text, markdown=False, message_index=idx)
            elif role == "assistant":
                for tc in msg.get("tool_calls") or []:
                    if not isinstance(tc, dict):
                        continue
                    fn = tc.get("function") or {}
                    name = str(fn.get("name") or "")
                    raw = fn.get("arguments") or "{}"
                    try:
                        args = json.loads(raw) if isinstance(raw, str) else raw
                    except json.JSONDecodeError:
                        args = {"_raw": raw}
                    tid = str(tc.get("id") or name)
                    if tid:
                        pending_args[tid] = args
                    if name:
                        pending_args[name] = args
                # Skip tool-only shells (empty content + tool_calls).
                if not text.strip() and (msg.get("tool_calls") or []):
                    continue
                if not text.strip():
                    continue
                self._add_bubble(
                    "Assistant", text, markdown=True, message_index=idx
                )
            elif role == "tool":
                name = str(msg.get("name") or "tool")
                tid = str(msg.get("tool_call_id") or "")
                args = pending_args.pop(tid, None)
                if args is None:
                    args = pending_args.pop(name, {})
                trace = ToolTraceWidget(name, args if args is not None else {})
                trace.set_result(text)
                self._wire_tool_menu(trace, idx)
                self.feed.addWidget(trace)

    def _wire_tool_menu(self, trace, message_index: int | None) -> None:
        trace.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)

        def _menu(pos, t=trace, mid=message_index) -> None:
            menu = QMenu(self)
            menu.addAction(
                "Copy message",
                lambda: QGuiApplication.clipboard().setText(t._payload()),
            )
            if mid is not None:
                menu.addAction(
                    "Copy from here",
                    lambda i=mid: self.copy_from_message_index(i),
                )
            menu.addAction("Copy entire chat", self.copy_entire_chat_plain)
            menu.addAction(
                "Copy entire chat as Markdown", self.copy_entire_chat_markdown
            )
            menu.exec(t.mapToGlobal(pos))

        # Avoid stacking duplicate connections on replay/live reuse.
        try:
            trace.customContextMenuRequested.disconnect()
        except (TypeError, RuntimeError):
            pass
        trace.customContextMenuRequested.connect(_menu)

    def _last_index_for_role(self, role: str) -> int | None:
        last: int | None = None
        for i, msg in enumerate(self.session.messages):
            if isinstance(msg, dict) and msg.get("role") == role:
                last = i
        return last

    def _tag_last_role_bubble(self, bubble: Bubble, role: str) -> None:
        idx = self._last_index_for_role(role)
        if idx is not None:
            bubble.set_message_index(idx)

    def _tag_latest_you_bubble(self) -> None:
        for i in range(self.feed.count() - 1, -1, -1):
            item = self.feed.itemAt(i)
            if item is None:
                continue
            w = item.widget()
            if isinstance(w, Bubble) and (w._role or "").lower() == "you":
                self._tag_last_role_bubble(w, "user")
                return

    def _update_meta(self) -> None:
        """Kept as no-op for call sites; endpoint/key chrome lives in provider editor."""

    def _update_vision_ui(self) -> None:
        vision = self.session.current_model_vision()
        self.attach_btn.setVisible(vision)
        if not vision:
            self._pending_images.clear()
            self._refresh_attach_label()

    def _near_scroll_bottom(self, *, slack: int = 80) -> bool:
        bar = self.scroll.verticalScrollBar()
        return bar.value() >= bar.maximum() - slack

    @Slot(int)
    def _on_scroll_moved(self, _value: int) -> None:
        # User scrolled away from bottom → stop auto-follow until they send again
        # or scroll back down.
        if self._near_scroll_bottom():
            self._stick_bottom = True
        else:
            self._stick_bottom = False

    def _scroll_bottom(self, *, force: bool = False) -> None:
        """Follow new content when stuck to bottom; force on send / errors."""
        if not force and not self._stick_bottom and not self._near_scroll_bottom():
            return

        def _go() -> None:
            bar = self.scroll.verticalScrollBar()
            bar.setValue(bar.maximum())

        # Layout often updates after this call — defer so we hit the real maximum.
        QTimer.singleShot(0, _go)

    def _add_bubble(
        self,
        role: str,
        text: str,
        *,
        markdown: bool = False,
        pixmap: QPixmap | None = None,
        scroll: bool = True,
        message_index: int | None = None,
    ) -> Bubble:
        bubble = Bubble(role, text, markdown=markdown, pixmap=pixmap)
        if message_index is not None:
            bubble.set_message_index(message_index)
        self._wire_bubble_menu(bubble)
        self.feed.addWidget(bubble)
        self._refresh_landing()
        if scroll:
            force = role.lower() in ("you", "error")
            if force:
                self._stick_bottom = True
            self._scroll_bottom(force=force or self._stick_bottom)
        return bubble

    def _discard_empty_stream_bubble(self) -> None:
        """Remove a stream bubble that never received text (tool-only rounds)."""
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
        # Do NOT scroll here — status updates during tool expand would yank the view.

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
        else:
            self.session.set_model(None)
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
        self._populate_models(fetch=False)
        self._update_vision_ui()
        QTimer.singleShot(0, self._start_models_fetch)

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
        self._populate_models(fetch=False)
        self._update_vision_ui()
        QTimer.singleShot(0, self._start_models_fetch)

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
        self._maybe_refresh_transcript()

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
        # Reuse model catalog — do NOT GET /models on every chat switch (UI freeze).
        prev_models = list(self.session.available_models)
        self.session = ChatSession.create(
            settings,
            interactive_auth=False,
            confirm_hook=self.confirm.confirm,
            messages=data.get("messages") or [],
            session_id=data.get("id"),
            title=data.get("title"),
            refresh_models=False,
            available_models=prev_models,
        )
        while self.feed.count():
            item = self.feed.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
        self._populate_models(fetch=False)
        self._update_vision_ui()
        self._replay_history_bubbles()
        self._refresh_landing()
        self.sidebar.refresh(self.session.session_id)
        self._maybe_refresh_transcript()

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
        self._stick_bottom = True
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
        self._scroll_bottom(force=True)
        QTimer.singleShot(0, self._tag_latest_you_bubble)

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
            # Lazy bubble on first token — do not show a fake "Generating…" wall.
            self._discard_empty_stream_bubble()
            self._stream_bubble = None
        elif kind == "assistant_delta":
            piece = event.get("text") or ""
            if not piece:
                return
            if self._stream_bubble is None:
                self._stream_bubble = self._add_bubble(
                    "Assistant", piece, markdown=True
                )
            else:
                self._stream_bubble.append_markdown(piece)
            self._scroll_bottom()
        elif kind == "assistant":
            self._set_activity(None)
            text = event.get("text") or ""
            if event.get("streamed") and self._stream_bubble is not None:
                self._stream_bubble.set_markdown(text)
                # Tag with last assistant message index once committed to session.
                self._tag_last_role_bubble(self._stream_bubble, "assistant")
                self._stream_bubble = None
            elif text.strip():
                self._discard_empty_stream_bubble()
                b = self._add_bubble("Assistant", text, markdown=True)
                self._tag_last_role_bubble(b, "assistant")
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
                # Index of the tool message just appended in session.
                tidx = self._last_index_for_role("tool")
                self._wire_tool_menu(self._last_trace, tidx)
                self._last_trace = None
            else:
                from .gui_pages import ToolTraceWidget

                trace = ToolTraceWidget(str(event.get("name") or "tool"), {})
                trace.set_result(body)
                tidx = self._last_index_for_role("tool")
                self._wire_tool_menu(trace, tidx)
                self.feed.addWidget(trace)
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
            self._maybe_refresh_transcript()
        elif kind == "done":
            self._set_activity(None)
            self._discard_empty_stream_bubble()
            self._update_meta()
            self.session.persist()
            self.sidebar.refresh(self.session.session_id)
            self._maybe_refresh_transcript()

    def _maybe_reauth(self, err: str) -> None:
        low = err.lower()
        if "401" not in low and "403" not in low and "unauthorized" not in low:
            return
        try:
            self.session.settings = prompt_auth_dialog(self.session.settings, self)
            self.session.runtime = ToolRuntime(
                self.session.settings, confirm_hook=self.confirm.confirm
            )
            self._populate_models(fetch=False)
            self._update_meta()
            QTimer.singleShot(0, self._start_models_fetch)
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
        self.setMinimumSize(720, 520)
        self.panel = AssistantPanel(session, confirm)
        self.setCentralWidget(self.panel)
        self.chat_page = self.panel.chat_page
        self._geom_timer = QTimer(self)
        self._geom_timer.setSingleShot(True)
        self._geom_timer.setInterval(400)
        self._geom_timer.timeout.connect(self._persist_geometry)
        self._restore_geometry()

    def _settings(self):
        from PySide6.QtCore import QSettings

        return QSettings("NixOSControlCenter", "ncc-assistant")

    def _restore_geometry(self) -> None:
        raw = self._settings().value("window/geometry")
        if raw is not None and self.restoreGeometry(raw):
            return
        self.resize(1000, 800)

    def _persist_geometry(self) -> None:
        self._settings().setValue("window/geometry", self.saveGeometry())

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        if self.isVisible():
            self._geom_timer.start()

    def moveEvent(self, event) -> None:  # noqa: N802
        super().moveEvent(event)
        if self.isVisible():
            self._geom_timer.start()

    def closeEvent(self, event) -> None:  # noqa: N802
        self._persist_geometry()
        super().closeEvent(event)


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
    # Do not probe the gateway on open (blocks UI when nginx/LLM is slow).
    # Anthropic always needs a key; local openai-compatible often does not.
    try:
        if not settings.api_key and settings.api == "anthropic":
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
        "refresh_models": False,
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
        if not settings.api_key and settings.api == "anthropic":
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
        "refresh_models": False,
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
