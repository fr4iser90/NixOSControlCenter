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

from PySide6.QtCore import QObject, Qt, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QFont, QKeyEvent, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
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
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from .auth import apply_api_key, probe_needs_auth, with_cached_credentials
from .config import Settings
from .history import list_sessions, load_session
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
        self.header_combo.addItem("Authorization (Bearer)", "Authorization")
        form.addRow("Header", self.header_combo)
        layout.addLayout(form)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self.key_edit.setFocus()

    def values(self) -> tuple[str, str | None]:
        key = self.key_edit.text()
        mode = self.header_combo.currentData()
        if mode == "auto":
            return key, None
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


class SessionSidebar(QWidget):
    """Persistent chat history list (left of the chat feed)."""

    session_selected = Signal(str)
    new_requested = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setObjectName("nccSessionSidebar")
        self.setMinimumWidth(200)
        self.setMaximumWidth(320)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 8, 0)
        lay.setSpacing(6)

        head = QHBoxLayout()
        title = QLabel("History")
        title.setStyleSheet("font-weight: 700;")
        head.addWidget(title)
        head.addStretch()
        new_btn = QPushButton("New")
        new_btn.setToolTip("Start a new chat session")
        new_btn.clicked.connect(self.new_requested.emit)
        head.addWidget(new_btn)
        lay.addLayout(head)

        self.list = QListWidget()
        self.list.setObjectName("nccSessionList")
        self.list.setWordWrap(True)
        self.list.setSpacing(2)
        self.list.itemClicked.connect(self._on_click)
        lay.addWidget(self.list, stretch=1)

        hint = QLabel("Saved under ~/.config/ncc-assistant/sessions")
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(mid); font-size: 11px;")
        lay.addWidget(hint)

    def refresh(self, current_id: str | None = None) -> None:
        self.list.clear()
        for s in list_sessions():
            updated = (s.get("updated") or "")[:16].replace("T", " ")
            model = s.get("model") or ""
            title = s.get("title") or "Untitled"
            item = QListWidgetItem(f"{title}\n{updated} · {s.get('message_count', 0)} msgs"
                                   + (f" · {model}" if model else ""))
            item.setData(Qt.ItemDataRole.UserRole, s["id"])
            item.setToolTip(s["id"])
            self.list.addItem(item)
            if current_id and s["id"] == current_id:
                self.list.setCurrentItem(item)

    def _on_click(self, item: QListWidgetItem) -> None:
        sid = item.data(Qt.ItemDataRole.UserRole)
        if sid:
            self.session_selected.emit(str(sid))


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

        role_l = role.lower()
        if role_l == "you":
            self.setStyleSheet(
                "QFrame#nccBubble { background: palette(alternate-base); border-radius: 12px; }"
            )
        elif role_l in ("assistant", "status"):
            border = (
                "border: 1px solid palette(highlight);"
                if role_l == "status"
                else "border: 1px solid palette(mid);"
            )
            self.setStyleSheet(
                f"QFrame#nccBubble {{ background: palette(base); {border} border-radius: 12px; }}"
            )
        elif role_l == "error":
            self.setStyleSheet(
                "QFrame#nccBubble { background: palette(alternate-base); "
                "border: 1px solid #c44; border-radius: 10px; }"
            )
        else:
            self.setStyleSheet(
                "QFrame#nccBubble { background: transparent; "
                "border: 1px dashed palette(mid); border-radius: 10px; }"
            )

        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 10, 14, 10)
        layout.setSpacing(6)

        who = QLabel(role)
        who.setStyleSheet("font-weight: 700; color: palette(mid);")
        layout.addWidget(who)

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
            self.body.setStyleSheet("background: transparent; padding: 0;")
            self.body.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            self.set_markdown(text)
            layout.addWidget(self.body)
        else:
            self.body = QLabel(text)
            self.body.setWordWrap(True)
            self.body.setTextInteractionFlags(
                Qt.TextInteractionFlag.TextSelectableByMouse
                | Qt.TextInteractionFlag.TextSelectableByKeyboard
            )
            layout.addWidget(self.body)

    def set_markdown(self, text: str) -> None:
        self._raw = text
        if isinstance(self.body, QTextBrowser):
            self.body.setMarkdown(text or "")
            doc = self.body.document()
            doc.setTextWidth(self.body.viewport().width() or 700)
            h = int(doc.size().height()) + 8
            self.body.setFixedHeight(max(h, 24))

    def append_markdown(self, piece: str) -> None:
        self.set_markdown((self._raw or "") + piece)


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

        root = QHBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(0)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setChildrenCollapsible(False)

        self.sidebar = SessionSidebar()
        self.sidebar.new_requested.connect(self.on_new_session)
        self.sidebar.session_selected.connect(self._load_session_id)
        splitter.addWidget(self.sidebar)

        chat_host = QWidget()
        layout = QVBoxLayout(chat_host)
        layout.setContentsMargins(8, 0, 0, 0)
        layout.setSpacing(8)

        bar = QHBoxLayout()
        self.model_combo = QComboBox()
        self.model_combo.setMinimumWidth(220)
        self.model_combo.currentIndexChanged.connect(self.on_model_changed)
        bar.addWidget(QLabel("Model"))
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
        self.meta = QLabel()
        self.meta.setStyleSheet("color: palette(mid);")
        bar.addWidget(self.meta)
        layout.addLayout(bar)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.feed_host = QWidget()
        self.feed = QVBoxLayout(self.feed_host)
        self.feed.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.feed.setSpacing(10)
        self.scroll.setWidget(self.feed_host)
        layout.addWidget(self.scroll, stretch=1)

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
        splitter.setSizes([240, 800])
        root.addWidget(splitter)

        self._pulse_timer = QTimer(self)
        self._pulse_timer.setInterval(450)
        self._pulse_timer.timeout.connect(self._pulse_status)

        self._populate_models()
        self._update_meta()
        self._update_vision_ui()
        self._replay_history_bubbles()
        self.sidebar.refresh(self.session.session_id)

        if len(self.session.messages) <= 1:
            writes = "on" if session.settings.writes_enabled else "off"
            rebuild = "on" if session.settings.allow_rebuild else "off"
            self._add_bubble(
                "NCC",
                "Ask about your NixOS Control Center configuration. "
                f"Config writes: **{writes}**. System rebuilds: **{rebuild}**. "
                "Dangerous tools ask for confirmation in this window.",
                markdown=True,
            )

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
            self.session.set_model(self.model_combo.currentData())
        self._model_guard = False

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
        s = self.session.settings
        auth = "key" if s.api_key else "no key"
        self.meta.setText(f"{s.endpoint}  |  {auth}")

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
        self._scroll_bottom()
        return bubble

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
        if self._status_bubble is None:
            self._status_bubble = self._add_bubble("Status", text + "...")
        else:
            labels = self._status_bubble.findChildren(QLabel)
            if labels:
                labels[-1].setText(text + "...")
            self._scroll_bottom()

    def _pulse_status(self) -> None:
        if not self.status.isVisible():
            return
        base = self.status.text().rstrip(".")
        self._pulse = (self._pulse + 1) % 4
        shown = base + ("." * self._pulse if self._pulse else "...")
        self.status.setText(shown)
        if self._status_bubble is not None:
            labels = self._status_bubble.findChildren(QLabel)
            if labels:
                labels[-1].setText(shown)

    def _set_busy(self, busy: bool) -> None:
        self._busy = busy
        self.send_btn.setEnabled(not busy)
        self.attach_btn.setEnabled(not busy and self.attach_btn.isVisible())
        self.composer.setReadOnly(busy)
        self.model_combo.setEnabled(not busy)
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
            self._update_vision_ui()
            self._update_meta()

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
        self._add_bubble("NCC", "New session started.", markdown=True)
        self._update_meta()
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
        self._update_meta()
        self._update_vision_ui()
        self._replay_history_bubbles()
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
            self._stream_bubble = self._add_bubble("Assistant", "", markdown=True)
        elif kind == "assistant_delta":
            if self._stream_bubble is None:
                self._stream_bubble = self._add_bubble("Assistant", "", markdown=True)
            self._stream_bubble.append_markdown(event.get("text") or "")
            self._scroll_bottom()
        elif kind == "assistant":
            self._set_activity(None)
            if event.get("streamed") and self._stream_bubble is not None:
                self._stream_bubble.set_markdown(event.get("text") or "")
                self._stream_bubble = None
            else:
                self._add_bubble(
                    "Assistant", event.get("text") or "", markdown=True
                )
            self._update_meta()
        elif kind == "tool":
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
            self._stream_bubble = None
            self._add_bubble("Error", event.get("text") or "")
            self._maybe_reauth(str(event.get("text") or ""))
        elif kind == "done":
            self._set_activity(None)
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
    settings = with_cached_credentials(
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
    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("NCC AI")
    app.setDesktopFileName("ncc-assistant")

    settings = with_cached_credentials(
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

    window = MainWindow(session, confirm)
    window.show()
    window.chat_page.composer.setFocus()
    return int(app.exec())
