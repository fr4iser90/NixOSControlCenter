"""Additional GUI pages and dialogs for the NCC AI assistant shell."""

from __future__ import annotations

import json
import os
import traceback
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal, Slot
from PySide6.QtGui import QFont, QIcon, QKeySequence, QShortcut
from PySide6.QtWidgets import (
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
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QTextBrowser,
    QTextEdit,
    QToolButton,
    QVBoxLayout,
    QWidget,
)


from .trace_format import format_thinking_header, format_tool_header


class ThinkingBlock(QFrame):
    """Collapsible thinking / reasoning block — collapsed by default."""

    _RADIUS = 8
    _MARGINS = (10, 6, 10, 6)
    _SPACING = 4
    _BODY_MAX = 180

    def __init__(
        self,
        parent: QWidget | None = None,
        *,
        compact: bool = False,
        expand_while_streaming: bool = False,
    ) -> None:
        super().__init__(parent)
        self.setObjectName("nccThinking")
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        self._compact = compact
        self._expand_while_streaming = expand_while_streaming
        self._text = ""
        self._streaming = False
        self._elapsed_s: float | None = None
        pad = 6 if compact else 8
        self.setStyleSheet(
            "QFrame#nccThinking {"
            "  background: palette(alternate-base);"
            "  border: 1px solid palette(mid);"
            f"  border-radius: {self._RADIUS}px;"
            "}"
        )
        layout = QVBoxLayout(self)
        layout.setContentsMargins(pad, pad - 2, pad, pad - 2)
        layout.setSpacing(self._SPACING)

        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        header.setSpacing(4)

        self._toggle = QToolButton()
        self._toggle.setAutoRaise(True)
        self._toggle.setFixedSize(22, 22)
        self._toggle.setText("▸")
        self._toggle.setCheckable(True)
        self._toggle.setChecked(False)
        self._toggle.setToolTip("Show / hide thinking")
        self._toggle.setStyleSheet(
            "QToolButton { border: none; padding: 0; margin: 0; }"
        )
        self._toggle.toggled.connect(self._on_toggle)
        header.addWidget(self._toggle)

        self._title = QLabel(format_thinking_header())
        self._title.setObjectName("nccThinkingTitle")
        self._title.setStyleSheet(
            "QLabel#nccThinkingTitle {"
            f"  font-weight: 600; font-size: {'11' if compact else '12'}px;"
            "  color: palette(mid);"
            "  padding: 0; margin: 0;"
            "}"
        )
        header.addWidget(self._title, stretch=1)

        copy_btn = QToolButton()
        copy_btn.setAutoRaise(True)
        copy_btn.setFixedSize(22, 22)
        copy_btn.setToolTip("Copy thinking")
        copy_btn.setStyleSheet(
            "QToolButton { border: none; padding: 0; margin: 0; }"
        )
        icon = QIcon.fromTheme("edit-copy")
        if not icon.isNull():
            copy_btn.setIcon(icon)
        else:
            copy_btn.setText("⎘")
        copy_btn.clicked.connect(self._copy)
        header.addWidget(copy_btn)
        layout.addLayout(header)

        self._body = QTextBrowser()
        self._body.setVisible(False)
        self._body.setFixedHeight(0)
        self._body.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self._body.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self._body.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._body.setStyleSheet(
            "QTextBrowser {"
            "  font-family: monospace; font-size: 11px;"
            "  background: palette(base); color: palette(text);"
            "  border: 1px solid palette(mid); border-radius: 4px;"
            "  padding: 4px; margin: 0;"
            "}"
        )
        layout.addWidget(self._body)
        self.hide()

    def clear(self) -> None:
        self._text = ""
        self._streaming = False
        self._elapsed_s = None
        self._toggle.setChecked(False)
        self._body.clear()
        self._body.setVisible(False)
        self._body.setFixedHeight(0)
        self._title.setText(format_thinking_header())
        self.hide()

    def append_text(self, piece: str) -> None:
        if not piece:
            return
        self._text += piece
        self._streaming = True
        self.show()
        self._title.setText(format_thinking_header(streaming=True))
        if self._expand_while_streaming and not self._toggle.isChecked():
            self._toggle.setChecked(True)
        elif self._toggle.isChecked():
            self._body.setPlainText(self._text)
            self._fit_body_height()

    def finish(self, *, seconds: float | None = None) -> None:
        self._streaming = False
        self._elapsed_s = seconds
        if not self._text.strip():
            self.clear()
            return
        self.show()
        self._title.setText(
            format_thinking_header(seconds=seconds, streaming=False)
        )
        # Collapse when turn finishes (unless user already expanded).
        if self._toggle.isChecked() and not self._expand_while_streaming:
            pass
        else:
            self._toggle.setChecked(False)
        if self._toggle.isChecked():
            self._body.setPlainText(self._text)
            self._fit_body_height()

    def collapse(self) -> None:
        self._toggle.setChecked(False)

    def text(self) -> str:
        return self._text

    def _on_toggle(self, checked: bool) -> None:
        self._toggle.setText("▾" if checked else "▸")
        if checked:
            self._body.setVisible(True)
            self._body.setPlainText(self._text)
            self._fit_body_height()
        else:
            self._body.setVisible(False)
            self._body.setFixedHeight(0)

    def _fit_body_height(self) -> None:
        doc = self._body.document()
        width = self._body.viewport().width()
        if width < 80:
            width = max(self.width() - 24, 280)
        doc.setTextWidth(float(width))
        h = int(doc.size().height()) + 12
        cap = 120 if self._compact else self._BODY_MAX
        self._body.setFixedHeight(max(32, min(h, cap)))

    def _copy(self) -> None:
        from PySide6.QtGui import QGuiApplication

        QGuiApplication.clipboard().setText(self._text)


class ToolTraceWidget(QFrame):
    """Tool row — same chrome as chat Bubble (radius/margins/border/header)."""

    _RADIUS = 8
    _MARGINS = (10, 8, 10, 8)
    _SPACING = 4
    _BODY_MAX = 160

    def __init__(
        self,
        name: str,
        args: object,
        parent: QWidget | None = None,
        *,
        compact: bool = False,
    ) -> None:
        super().__init__(parent)
        self.setObjectName("nccToolTrace")
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        self._compact = compact
        self.setStyleSheet(
            "QFrame#nccToolTrace {"
            "  background: palette(base);"
            "  border: 1px solid palette(mid);"
            f"  border-radius: {self._RADIUS}px;"
            "}"
        )
        margins = (8, 4, 8, 4) if compact else self._MARGINS
        layout = QVBoxLayout(self)
        layout.setContentsMargins(*margins)
        layout.setSpacing(self._SPACING)

        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        header.setSpacing(4)

        self._toggle = QToolButton()
        self._toggle.setAutoRaise(True)
        self._toggle.setFixedSize(22, 22)
        self._toggle.setText("▸")
        self._toggle.setCheckable(True)
        self._toggle.setChecked(False)
        self._toggle.setToolTip("Show / hide tool details")
        self._toggle.setStyleSheet(
            "QToolButton { border: none; padding: 0; margin: 0; }"
        )
        self._toggle.toggled.connect(self._on_toggle)
        header.addWidget(self._toggle)

        self._name = name
        self._raw_args = args
        self._result = ""
        self._ms: int | None = None
        self._status = "…"
        self._title = QLabel(format_tool_header(name, status=self._status))
        self._title.setObjectName("nccToolTraceTitle")
        self._title.setStyleSheet(
            "QLabel#nccToolTraceTitle {"
            f"  font-weight: 700; font-size: {'11' if compact else '12'}px;"
            "  font-family: monospace;"
            "  color: palette(window-text); padding: 0; margin: 0;"
            "}"
        )
        self._title.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse
        )
        header.addWidget(self._title, stretch=1)

        copy_btn = QToolButton()
        copy_btn.setAutoRaise(True)
        copy_btn.setFixedSize(22, 22)
        copy_btn.setToolTip("Copy tool args + result")
        copy_btn.setStyleSheet(
            "QToolButton { border: none; padding: 0; margin: 0; }"
        )
        icon = QIcon.fromTheme("edit-copy")
        if not icon.isNull():
            copy_btn.setIcon(icon)
        else:
            copy_btn.setText("⎘")
        copy_btn.clicked.connect(self._copy)
        self._copy_btn = copy_btn
        header.addWidget(copy_btn)
        layout.addLayout(header)

        self._body = QTextBrowser()
        self._body.setVisible(False)
        self._body.setFixedHeight(0)
        self._body.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self._body.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self._body.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._body.setStyleSheet(
            "QTextBrowser {"
            "  font-family: monospace; font-size: 11px;"
            "  background: palette(alternate-base); color: palette(text);"
            "  border: 1px solid palette(mid); border-radius: 4px;"
            "  padding: 4px; margin: 0;"
            "}"
        )
        layout.addWidget(self._body)

    def _sync_title(self) -> None:
        self._title.setText(
            format_tool_header(self._name, ms=self._ms, status=self._status)
        )

    def _on_toggle(self, checked: bool) -> None:
        self._toggle.setText("▾" if checked else "▸")
        if checked:
            self._body.setVisible(True)
            self._refresh()
            from PySide6.QtCore import QTimer

            QTimer.singleShot(0, self._keep_in_view)
        else:
            self._body.setVisible(False)
            self._body.setFixedHeight(0)

    def _fit_body_height(self) -> None:
        """Height follows content — no empty 180px pane."""
        doc = self._body.document()
        width = self._body.viewport().width()
        if width < 80:
            width = max(self.width() - 24, 400)
        doc.setTextWidth(float(width))
        h = int(doc.size().height()) + 12
        cap = 100 if self._compact else self._BODY_MAX
        self._body.setFixedHeight(max(36, min(h, cap)))

    def _keep_in_view(self) -> None:
        """Keep this row visible when expanding — do not jump the feed to the bottom."""
        from PySide6.QtWidgets import QScrollArea

        w: QWidget | None = self.parentWidget()
        while w is not None:
            if isinstance(w, QScrollArea):
                w.ensureWidgetVisible(self, 0, 16)
                return
            w = w.parentWidget()

    def set_duration_ms(self, ms: int) -> None:
        self._ms = max(0, int(ms))
        self._sync_title()

    def set_result(self, text: str) -> None:
        self._result = text
        low = text.lower()[:80]
        self._status = "✗" if ("error" in low or "failed" in low) else "✓"
        self._sync_title()
        if self._toggle.isChecked():
            self._refresh()

    def _payload(self) -> str:
        return (
            f"tool: {self._name}\n"
            f"args:\n{json.dumps(self._raw_args, indent=2, default=str)[:2000]}\n\n"
            f"result:\n{self._result[:3000]}"
        )

    def _copy(self) -> None:
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtCore import QTimer

        QGuiApplication.clipboard().setText(self._payload())
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
            btn.setToolTip(prev_tip or "Copy tool args + result")
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

    def _refresh(self) -> None:
        self._body.setPlainText(self._payload())
        self._fit_body_height()


class DiffReviewDialog(QDialog):
    """Side-by-side / unified diff review with Apply selected (phase 8)."""

    def __init__(
        self,
        proposals: list[dict],
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle("Diff review")
        self.resize(900, 600)
        self._proposals = proposals
        self.selected_paths: list[str] = []

        layout = QVBoxLayout(self)
        self.list = QListWidget()
        for p in proposals:
            path = p.get("module_path", "?")
            item = QListWidgetItem(path)
            item.setFlags(item.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            item.setCheckState(Qt.CheckState.Checked)
            self.list.addItem(item)
        self.list.currentRowChanged.connect(self._show_diff)
        layout.addWidget(self.list, stretch=1)

        self.diff = QTextBrowser()
        self.diff.setStyleSheet("font-family: monospace;")
        layout.addWidget(self.diff, stretch=2)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.button(QDialogButtonBox.StandardButton.Ok).setText("Apply selected")
        buttons.accepted.connect(self._accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

        if proposals:
            self.list.setCurrentRow(0)

    def _show_diff(self, row: int) -> None:
        if row < 0 or row >= len(self._proposals):
            return
        p = self._proposals[row]
        self.diff.setPlainText(p.get("diff") or p.get("proposed_nix") or "(empty)")

    def _accept(self) -> None:
        self.selected_paths = []
        for i in range(self.list.count()):
            item = self.list.item(i)
            if item.checkState() == Qt.CheckState.Checked:
                self.selected_paths.append(item.text())
        self.accept()


class AgentWorker(QThread):
    event = Signal(object)
    failed = Signal(str)
    finished_signal = Signal()

    def __init__(
        self,
        goal: str,
        *,
        max_steps: int,
        dry_run: bool,
        profile: str,
        playbook: str | None = None,
        harness: str | None = None,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._goal = goal
        self._max_steps = max_steps
        self._dry_run = dry_run
        self._profile = profile
        self._playbook = playbook
        self._harness = harness
        self._cancelled = False
        self._runner = None

    def cancel(self) -> None:
        self._cancelled = True
        if self._runner is not None and hasattr(self._runner, "cancel"):
            self._runner.cancel()

    def run(self) -> None:
        try:
            from .agent import AgentRunner, AgentSettings
            from .auth import with_cached_credentials
            from .config import Settings
            from .harness import get_harness, looks_like_coding_goal, resolve_harness_name

            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
            mode = (self._harness or "auto").strip().lower()
            force = mode if mode in ("native", "qwen", "dsh") else None
            tags = ["coding"] if looks_like_coding_goal(self._goal) else []
            hname = resolve_harness_name(tags=tags, force=force)
            self.event.emit({"kind": "status", "text": f"Harness: {hname}"})

            if hname != "native":
                for ev in get_harness(hname).send(self._goal):
                    if self._cancelled:
                        self.event.emit({"kind": "cancelled"})
                        break
                    self.event.emit(ev)
                self.finished_signal.emit()
                return

            agent_settings = AgentSettings(
                goal=self._goal,
                max_steps=self._max_steps,
                dry_run=self._dry_run,
                profile=self._profile,
                playbook=self._playbook,
            )
            self._runner = AgentRunner(settings, agent_settings)
            for ev in self._runner.run():
                if self._cancelled:
                    self.event.emit({"kind": "cancelled"})
                    break
                self.event.emit(ev)
            self.finished_signal.emit()
        except Exception as exc:
            self.failed.emit(f"{exc}\n{traceback.format_exc()}")
            self.finished_signal.emit()


class AgentPage(QWidget):
    def __init__(self, confirm, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.confirm = confirm
        self._worker: AgentWorker | None = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        form_group = QGroupBox("Agent")
        form = QFormLayout(form_group)

        self.goal_edit = QTextEdit()
        self.goal_edit.setPlaceholderText("Enter a goal for the agent…")
        self.goal_edit.setFixedHeight(80)
        form.addRow("Goal", self.goal_edit)

        self.playbook_combo = QComboBox()
        self.playbook_combo.addItem("(none)", None)
        try:
            from .playbooks import list_playbooks

            for pb in list_playbooks():
                self.playbook_combo.addItem(pb.name, pb.name)
        except Exception:
            pass
        form.addRow("Playbook", self.playbook_combo)

        self.profile_combo = QComboBox()
        self.profile_combo.addItems(["read-only", "config-writer", "ops", "cautious", "autonomous"])
        self.profile_combo.setCurrentText(os.environ.get("AGENT_PROFILE", "read-only"))
        form.addRow("Profile", self.profile_combo)

        self.dry_run_check = QCheckBox("Dry run (propose only)")
        self.dry_run_check.setChecked(os.environ.get("AGENT_DRY_RUN", "0") == "1")
        form.addRow("", self.dry_run_check)

        self.max_steps_spin = QSpinBox()
        self.max_steps_spin.setRange(1, 100)
        self.max_steps_spin.setValue(int(os.environ.get("AGENT_MAX_STEPS", "24")))
        form.addRow("Max steps", self.max_steps_spin)

        self.harness_combo = QComboBox()
        for key, label in (
            ("auto", "auto"),
            ("native", "native"),
            ("qwen", "qwen"),
            ("dsh", "dsh"),
        ):
            self.harness_combo.addItem(label, key)
        try:
            from .preferences import get_default_harness_mode

            hi = self.harness_combo.findData(get_default_harness_mode())
            if hi >= 0:
                self.harness_combo.setCurrentIndex(hi)
        except Exception:
            pass
        form.addRow("Harness", self.harness_combo)

        layout.addWidget(form_group)

        btn_row = QHBoxLayout()
        self.run_btn = QPushButton("Run Agent")
        self.run_btn.clicked.connect(self.on_run)
        btn_row.addWidget(self.run_btn)
        self.stop_btn = QPushButton("Stop")
        self.stop_btn.setEnabled(False)
        self.stop_btn.clicked.connect(self.on_stop)
        btn_row.addWidget(self.stop_btn)
        btn_row.addStretch()
        self.budget_label = QLabel("Steps: 0 / 24 · tokens: —")
        btn_row.addWidget(self.budget_label)
        layout.addLayout(btn_row)

        self.log = QTextBrowser()
        self.log.setStyleSheet("font-family: monospace;")
        layout.addWidget(self.log, stretch=1)

        # In-window shortcuts (global hotkeys via desktop Actions — phase 23)
        QShortcut(QKeySequence("Ctrl+Shift+P"), self, activated=self._pause_presence)
        QShortcut(QKeySequence("Ctrl+Shift+R"), self, activated=self._resume_presence)

    def _pause_presence(self) -> None:
        from .presence import pause

        pause(reason="GUI shortcut")
        self.log.append("[presence] paused")

    def _resume_presence(self) -> None:
        from .presence import resume

        resume(reason="GUI shortcut")
        self.log.append("[presence] available")

    @Slot()
    def on_run(self) -> None:
        playbook = self.playbook_combo.currentData()
        goal = self.goal_edit.toPlainText().strip()
        if playbook and not goal:
            from .playbooks import get_playbook

            pb = get_playbook(playbook)
            goal = pb.goal if pb else ""
        if not goal:
            QMessageBox.warning(self, "Agent", "Enter a goal or pick a playbook.")
            return

        self.run_btn.setEnabled(False)
        self.stop_btn.setEnabled(True)
        self.log.clear()
        self._think_logged = False
        max_s = self.max_steps_spin.value()
        self.budget_label.setText(f"Steps: 0 / {max_s} · tokens: —")
        self.log.append(f"Starting agent: {goal}\n")

        harness = str(self.harness_combo.currentData() or "auto")
        try:
            from .preferences import set_default_harness_mode

            set_default_harness_mode(harness)
        except Exception:
            pass
        self._worker = AgentWorker(
            goal,
            max_steps=max_s,
            dry_run=self.dry_run_check.isChecked(),
            profile=self.profile_combo.currentText(),
            playbook=playbook,
            harness=harness,
            parent=self,
        )
        self._worker.event.connect(self.on_event)
        self._worker.failed.connect(self.on_fail)
        self._worker.finished_signal.connect(self._on_finished)
        self._worker.start()

    @Slot()
    def on_stop(self) -> None:
        if self._worker:
            self._worker.cancel()
        self.log.append("\n[Cancelling…]")

    @Slot(object)
    def on_event(self, event: object) -> None:
        if not isinstance(event, dict):
            return
        kind = event.get("kind", "")
        max_s = self.max_steps_spin.value()
        if kind == "step":
            step = event.get("step", 0)
            tokens = event.get("tokens") or event.get("usage") or "—"
            self.budget_label.setText(f"Steps: {step} / {max_s} · tokens: {tokens}")
            self.log.append(f"\n--- Step {step}/{max_s} ---")
        elif kind == "budget_exhausted":
            self.log.append(f"\n[Budget exhausted] {event.get('text', 'max steps')}")
            self.budget_label.setText(f"Steps: EXHAUSTED / {max_s}")
        elif kind == "thinking_delta":
            # Compact: one line, not full dump
            if not getattr(self, "_think_logged", False):
                self.log.append("▸ Thinking…")
                self._think_logged = True
        elif kind == "tool":
            self._think_logged = False
            name = event.get("name") or "tool"
            self.log.append(f"▸ {name}")
        elif kind == "tool_result":
            body = (event.get("text") or "")[:120]
            self.log.append(f"  ↳ {body}{'…' if len(event.get('text') or '') > 120 else ''}")
        elif kind == "assistant_delta":
            pass
        elif kind == "assistant":
            self._think_logged = False
            self.log.append(f"Assistant: {(event.get('text') or '')[:500]}")
        elif kind == "status":
            text = event.get("text") or event.get("phase") or ""
            if text:
                self.log.append(f"· {text}")
        elif kind == "run_spawn":
            self.log.append(
                f"▸ Subagent: {event.get('title') or event.get('name') or 'child'}"
            )
        elif kind == "agent_finish":
            self.log.append(f"\n[Finish] success={event.get('success')} {event.get('summary')}")
        elif kind == "job_finished":
            self.log.append(f"\n[Job done] {event.get('job_id')} success={event.get('success')}")
        elif kind == "cancelled":
            self.log.append("\n[Cancelled]")
        elif kind == "error":
            self.log.append(f"\n[Error] {event.get('text', '')}")

    @Slot(str)
    def on_fail(self, message: str) -> None:
        self.log.append(f"\n[Failed] {message}")

    @Slot()
    def _on_finished(self) -> None:
        self.run_btn.setEnabled(True)
        self.stop_btn.setEnabled(False)


class ToolsPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["Name", "Kind", "Enabled", "Description"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        layout.addWidget(self.table, stretch=1)

        btn_row = QHBoxLayout()
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self.refresh_tools)
        btn_row.addWidget(refresh_btn)
        toggle_btn = QPushButton("Toggle enabled")
        toggle_btn.clicked.connect(self.toggle_enabled)
        btn_row.addWidget(toggle_btn)
        test_btn = QPushButton("Test selected")
        test_btn.clicked.connect(self.test_tool)
        btn_row.addWidget(test_btn)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        market = QGroupBox("MCP marketplace")
        m_layout = QFormLayout(market)
        self.template_combo = QComboBox()
        try:
            from .marketplace import list_templates

            for t in list_templates():
                self.template_combo.addItem(t.name, t.name)
        except Exception:
            pass
        m_layout.addRow("Template", self.template_combo)
        self.mcp_workspace_combo = QComboBox()
        self.mcp_workspace_combo.addItem("(cwd / default)", "")
        try:
            from .workspaces import list_workspaces

            for ws in list_workspaces():
                self.mcp_workspace_combo.addItem(f"{ws.id} — {ws.path}", ws.id)
        except Exception:
            pass
        m_layout.addRow("Workspace", self.mcp_workspace_combo)
        install_btn = QPushButton("Install template")
        install_btn.clicked.connect(self.install_template)
        m_layout.addRow(install_btn)
        layout.addWidget(market)

        self.refresh_tools()

    @Slot()
    def refresh_tools(self) -> None:
        self.table.setRowCount(0)
        try:
            from .registry import get_registry, reload_registry

            reload_registry()
            tools = get_registry().list_all()
        except Exception:
            tools = []

        for tool in tools:
            row = self.table.rowCount()
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(tool.name))
            self.table.setItem(row, 1, QTableWidgetItem(tool.kind))
            self.table.setItem(row, 2, QTableWidgetItem("Yes" if tool.enabled else "No"))
            self.table.setItem(row, 3, QTableWidgetItem(tool.description[:120]))

    @Slot()
    def toggle_enabled(self) -> None:
        row = self.table.currentRow()
        if row < 0:
            return
        name = self.table.item(row, 0).text()
        from .registry import get_registry

        reg = get_registry()
        entry = reg.get(name)
        if not entry:
            return
        reg.set_enabled(name, not entry.enabled)
        self.refresh_tools()

    @Slot()
    def test_tool(self) -> None:
        row = self.table.currentRow()
        if row < 0:
            return
        name = self.table.item(row, 0).text()
        from .auth import with_cached_credentials
        from .config import Settings
        from .runtime import ToolRuntime

        settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
        runtime = ToolRuntime(settings)
        # Safe defaults for common tools
        args: dict = {}
        if name == "list_modules":
            args = {}
        elif name == "memory_list":
            args = {"limit": 5}
        elif name == "config_health_report":
            args = {}
        elif name == "search_knowledge":
            args = {"query": "ncc", "limit": 3}
        else:
            QMessageBox.information(
                self,
                "Test",
                f"No default args for {name}. Use CLI: ncc ai tool {name} --args '{{}}'",
            )
            return
        result = runtime.call(name, args)
        QMessageBox.information(self, "Test result", json.dumps(result, indent=2)[:3000])

    @Slot()
    def install_template(self) -> None:
        name = self.template_combo.currentData()
        if not name:
            return
        try:
            from .marketplace import WRITE_RISK_WARNING, install_template

            ws = self.mcp_workspace_combo.currentData() or None
            result = install_template(name, workspace_id=ws or None)
            msg = json.dumps(result, indent=2)
            if result.get("warning") or "write" in msg.lower():
                msg = f"{WRITE_RISK_WARNING}\n\n{msg}"
            QMessageBox.information(self, "Marketplace", msg)
            self.refresh_tools()
        except Exception as exc:
            QMessageBox.warning(self, "Marketplace", str(exc))


class JobsPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        self.list = QListWidget()
        layout.addWidget(self.list, stretch=1)

        btn_row = QHBoxLayout()
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self.refresh_jobs)
        btn_row.addWidget(refresh_btn)
        detail_btn = QPushButton("Show details")
        detail_btn.clicked.connect(self.show_details)
        btn_row.addWidget(detail_btn)
        export_btn = QPushButton("Export")
        export_btn.clicked.connect(self.export_job)
        btn_row.addWidget(export_btn)
        rollback_btn = QPushButton("Rollback assistant")
        rollback_btn.clicked.connect(self.rollback_assistant)
        btn_row.addWidget(rollback_btn)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        self.detail_log = QTextBrowser()
        self.detail_log.setMaximumHeight(220)
        layout.addWidget(self.detail_log)
        self._job_ids: list[str] = []
        self.refresh_jobs()

    @Slot()
    def refresh_jobs(self) -> None:
        self.list.clear()
        self._job_ids = []
        try:
            from .jobs import get_job_store

            jobs = get_job_store().list_jobs()
        except Exception:
            jobs = []
        if not jobs:
            self.list.addItem("No jobs found")
            return
        for job in jobs:
            jid = job.id if hasattr(job, "id") else job.get("id", "?")
            status = job.status if hasattr(job, "status") else job.get("status", "?")
            goal = job.goal if hasattr(job, "goal") else job.get("goal", "")
            self._job_ids.append(str(jid))
            self.list.addItem(f"[{status}] {jid}: {str(goal)[:50]}")

    @Slot()
    def show_details(self) -> None:
        row = self.list.currentRow()
        if row < 0 or row >= len(self._job_ids):
            return
        jid = self._job_ids[row]
        from .jobs import get_job_store

        store = get_job_store()
        job = store.get(jid)
        events = store.get_events(jid)
        lines = [json.dumps(job.to_dict() if job and hasattr(job, "to_dict") else {}, indent=2)]
        lines.append("\n--- events ---")
        for ev in events[-50:]:
            data = ev.data if hasattr(ev, "data") else ev
            kind = ev.kind if hasattr(ev, "kind") else data.get("kind")
            lines.append(f"{getattr(ev, 'timestamp', '')} {kind}: {json.dumps(data)[:200]}")
        self.detail_log.setPlainText("\n".join(lines))

    @Slot()
    def export_job(self) -> None:
        row = self.list.currentRow()
        if row < 0 or row >= len(self._job_ids):
            return
        from .export_transcript import export_job_markdown, export_to_file
        from .paths import config_home

        jid = self._job_ids[row]
        path = export_to_file(export_job_markdown(jid), config_home() / "exports" / f"job-{jid}.md")
        QMessageBox.information(self, "Export", f"Wrote {path}")

    @Slot()
    def rollback_assistant(self) -> None:
        from .auth import with_cached_credentials
        from .config import Settings
        from .runtime import ToolRuntime

        settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
        rt = ToolRuntime(settings)
        backups = rt.list_config_backups(10)
        gens = rt.list_boot_generations(10)
        text = (
            "Config backups:\n"
            + json.dumps(backups, indent=2)[:2000]
            + "\n\nBoot generations:\n"
            + json.dumps(gens, indent=2)[:2000]
            + "\n\nTo roll back a generation: sudo nixos-rebuild switch --rollback\n"
            "Or pick a generation via boot menu / nix-env --list-generations."
        )
        self.detail_log.setPlainText(text)
        QMessageBox.information(self, "Rollback", "See details panel for backups & generations.")


class ScheduleEditDialog(QDialog):
    """Create/edit a user schedule."""

    def __init__(self, spec=None, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        from .schedule_templates import ScheduleSpec

        self.setWindowTitle("Edit schedule" if spec else "New schedule")
        self.resize(480, 360)
        self._spec = spec

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name_edit = QLineEdit(spec.name if spec else "")
        self.name_edit.setEnabled(spec is None or getattr(spec, "source", "") != "nix")
        form.addRow("Name", self.name_edit)

        self.desc_edit = QLineEdit(spec.description if spec else "")
        form.addRow("Description", self.desc_edit)

        from .templates_ui import FrequencyPicker

        self.cal_picker = FrequencyPicker(
            default=(spec.onCalendar if spec else "*-*-* 03:15:00")
        )
        form.addRow("Schedule", self.cal_picker)

        self.kind_combo = QComboBox()
        self.kind_combo.addItems(["agent", "probe"])
        if spec:
            self.kind_combo.setCurrentText(getattr(spec, "kind", None) or "agent")
        form.addRow("Kind", self.kind_combo)

        self.probe_edit = QLineEdit(
            (spec.probe if spec and getattr(spec, "probe", None) else "disk-nix") or "disk-nix"
        )
        form.addRow("Probe (if probe)", self.probe_edit)

        self.threshold_spin = QSpinBox()
        self.threshold_spin.setRange(50, 99)
        thr = getattr(spec, "thresholdPct", None) if spec else 85
        self.threshold_spin.setValue(int(thr) if thr is not None else 85)
        form.addRow("Threshold %", self.threshold_spin)

        self.playbook_combo = QComboBox()
        self.playbook_combo.setEditable(True)
        self.playbook_combo.addItem("(none)", "")
        try:
            from .playbooks import list_playbooks

            for pb in list_playbooks():
                self.playbook_combo.addItem(pb.name, pb.name)
        except Exception:
            pass
        if spec and spec.playbook:
            idx = self.playbook_combo.findData(spec.playbook)
            if idx >= 0:
                self.playbook_combo.setCurrentIndex(idx)
            else:
                self.playbook_combo.setEditText(spec.playbook)
        elif spec and getattr(spec, "escalatePlaybook", None):
            self.playbook_combo.setEditText(spec.escalatePlaybook)
        form.addRow("Playbook / escalate", self.playbook_combo)

        self.goal_edit = QTextEdit()
        self.goal_edit.setPlaceholderText("Optional goal (if no playbook)")
        self.goal_edit.setFixedHeight(60)
        if spec and spec.goal:
            self.goal_edit.setPlainText(spec.goal)
        form.addRow("Goal", self.goal_edit)

        self.profile_combo = QComboBox()
        self.profile_combo.addItems(["read-only", "config-writer", "ops", "cautious", "autonomous"])
        if spec:
            self.profile_combo.setCurrentText(spec.profile or "read-only")
        form.addRow("Profile", self.profile_combo)

        self.dry_run = QCheckBox("Dry run")
        self.dry_run.setChecked(True if not spec else bool(spec.dryRun))
        form.addRow("", self.dry_run)

        self.enable_check = QCheckBox("Enabled")
        self.enable_check.setChecked(True if not spec else bool(spec.enable))
        form.addRow("", self.enable_check)

        self.max_steps = QSpinBox()
        self.max_steps.setRange(1, 100)
        self.max_steps.setValue(int(spec.maxSteps) if spec and spec.maxSteps else 15)
        form.addRow("Max steps", self.max_steps)

        layout.addLayout(form)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def to_spec(self):
        from .schedule_templates import ScheduleSpec

        pb = self.playbook_combo.currentData()
        if pb is None or pb == "":
            pb = self.playbook_combo.currentText().strip() or None
        goal = self.goal_edit.toPlainText().strip() or None
        kind = self.kind_combo.currentText()
        return ScheduleSpec(
            name=self.name_edit.text().strip(),
            description=self.desc_edit.text().strip(),
            onCalendar=self.cal_picker.on_calendar() or "daily",
            playbook=pb if kind == "agent" else None,
            goal=goal if kind == "agent" else None,
            profile=self.profile_combo.currentText(),
            dryRun=self.dry_run.isChecked(),
            maxSteps=self.max_steps.value(),
            enable=self.enable_check.isChecked(),
            kind=kind,
            probe=(self.probe_edit.text().strip() or "disk-nix") if kind == "probe" else None,
            thresholdPct=float(self.threshold_spin.value()) if kind == "probe" else None,
            escalatePlaybook=pb if kind == "probe" else None,
            source="user",
        )


class SchedulesPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        layout.addWidget(
            QLabel(
                "Templates → load into your user schedules (~/.config/ncc-assistant/schedules/). "
                "Nix timers need a rebuild (Copy Nix snippet). Presence pause skips runs."
            )
        )

        split = QSplitter(Qt.Orientation.Horizontal)

        # Left: templates
        left = QWidget()
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(0, 0, 0, 0)
        left_l.addWidget(QLabel("Templates (builtin)"))
        self.template_list = QListWidget()
        left_l.addWidget(self.template_list, stretch=1)
        t_btns = QHBoxLayout()
        load_btn = QPushButton("Load → user")
        load_btn.clicked.connect(self.load_template)
        t_btns.addWidget(load_btn)
        left_l.addLayout(t_btns)
        split.addWidget(left)

        # Right: user + nix
        right = QWidget()
        right_l = QVBoxLayout(right)
        right_l.setContentsMargins(0, 0, 0, 0)
        right_l.addWidget(QLabel("My schedules (editable)"))
        self.user_list = QListWidget()
        self.user_list.currentRowChanged.connect(self._on_user_selected)
        right_l.addWidget(self.user_list, stretch=1)

        u_btns = QHBoxLayout()
        new_btn = QPushButton("New")
        new_btn.clicked.connect(self.new_schedule)
        u_btns.addWidget(new_btn)
        edit_btn = QPushButton("Edit")
        edit_btn.clicked.connect(self.edit_schedule)
        u_btns.addWidget(edit_btn)
        del_btn = QPushButton("Delete")
        del_btn.clicked.connect(self.delete_schedule)
        u_btns.addWidget(del_btn)
        run_btn = QPushButton("Run now")
        run_btn.clicked.connect(self.run_schedule)
        u_btns.addWidget(run_btn)
        nix_btn = QPushButton("Copy Nix")
        nix_btn.clicked.connect(self.copy_nix)
        u_btns.addWidget(nix_btn)
        right_l.addLayout(u_btns)

        right_l.addWidget(QLabel("From Nix (read-only systemd timers)"))
        self.nix_list = QListWidget()
        right_l.addWidget(self.nix_list)
        split.addWidget(right)

        layout.addWidget(split, stretch=2)

        self.detail = QTextBrowser()
        self.detail.setMaximumHeight(140)
        self.detail.setStyleSheet("font-family: monospace; font-size: 11px;")
        layout.addWidget(self.detail)

        wd = QGroupBox("Watchdogs")
        wd_layout = QVBoxLayout(wd)
        self.wd_list = QListWidget()
        wd_layout.addWidget(self.wd_list)
        fire_btn = QPushButton("Fire selected event (dry)")
        fire_btn.clicked.connect(self.fire_watchdog)
        wd_layout.addWidget(fire_btn)
        layout.addWidget(wd)

        self._user_names: list[str] = []
        self._template_names: list[str] = []
        self._load()

    def _load(self) -> None:
        from .schedule_templates import list_templates, list_user_schedules, list_nix_schedules

        self.template_list.clear()
        self._template_names = []
        for t in list_templates():
            self._template_names.append(t.name)
            self.template_list.addItem(f"{t.name} — {t.description or t.playbook or ''}")

        self.user_list.clear()
        self._user_names = []
        users = list_user_schedules()
        if not users:
            self.user_list.addItem("(none — load a template or create new)")
        else:
            for s in users:
                self._user_names.append(s.name)
                en = "on" if s.enable else "off"
                if (s.kind or "agent") == "probe":
                    label = f"probe={s.probe}≥{s.thresholdPct or 85}%"
                else:
                    label = s.playbook or (s.goal or "")[:40]
                self.user_list.addItem(f"[{en}] {s.name}: {s.onCalendar} — {label}")

        self.nix_list.clear()
        nix = list_nix_schedules()
        if not nix:
            self.nix_list.addItem("(no Nix schedules — copy snippet + rebuild)")
        else:
            for s in nix:
                en = "on" if s.enable else "off"
                label = s.playbook or (s.goal or "")[:40]
                self.nix_list.addItem(f"[{en}] {s.name}: {s.onCalendar} — {label}")

        self.wd_list.clear()
        try:
            from .watchdogs import list_watchdogs

            for w in list_watchdogs():
                self.wd_list.addItem(
                    f"{'[on]' if w.enable else '[off]'} {w.id} event={w.event} cooldown={w.cooldown_sec}s"
                )
        except Exception as exc:
            self.wd_list.addItem(f"(watchdogs unavailable: {exc})")

    def _selected_user(self):
        from .schedule_templates import get_user_schedule

        row = self.user_list.currentRow()
        if row < 0 or row >= len(self._user_names):
            return None
        return get_user_schedule(self._user_names[row])

    @Slot(int)
    def _on_user_selected(self, row: int) -> None:
        from .schedule_templates import nix_snippet

        spec = self._selected_user()
        if not spec:
            self.detail.clear()
            return
        self.detail.setPlainText(
            json.dumps(spec.to_dict(), indent=2)
            + "\n\n# Nix snippet\n"
            + nix_snippet(spec)
        )

    @Slot()
    def load_template(self) -> None:
        from .schedule_templates import load_template_as_user

        row = self.template_list.currentRow()
        if row < 0 or row >= len(self._template_names):
            QMessageBox.information(self, "Schedules", "Select a template first.")
            return
        name = self._template_names[row]
        try:
            spec = load_template_as_user(name)
            QMessageBox.information(
                self,
                "Schedules",
                f"Loaded “{spec.name}” into user schedules.\n"
                "Edit as needed, then Copy Nix + rebuild for a systemd timer — "
                "or Run now without rebuild.",
            )
            self._load()
            # select the loaded one
            if spec.name in self._user_names:
                self.user_list.setCurrentRow(self._user_names.index(spec.name))
        except Exception as exc:
            QMessageBox.warning(self, "Schedules", str(exc))

    @Slot()
    def new_schedule(self) -> None:
        from .schedule_templates import save_user_schedule

        dlg = ScheduleEditDialog(parent=self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        spec = dlg.to_spec()
        if not spec.name:
            QMessageBox.warning(self, "Schedules", "Name required.")
            return
        if (spec.kind or "agent") == "probe":
            if not spec.probe:
                QMessageBox.warning(self, "Schedules", "Probe id required for kind=probe.")
                return
        elif not spec.playbook and not spec.goal:
            QMessageBox.warning(self, "Schedules", "Playbook or goal required.")
            return
        save_user_schedule(spec)
        self._load()

    @Slot()
    def edit_schedule(self) -> None:
        from .schedule_templates import save_user_schedule

        spec = self._selected_user()
        if not spec:
            QMessageBox.information(self, "Schedules", "Select a user schedule.")
            return
        dlg = ScheduleEditDialog(spec, parent=self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        updated = dlg.to_spec()
        if not updated.name:
            QMessageBox.warning(self, "Schedules", "Name required.")
            return
        # rename: delete old file if name changed
        if updated.name != spec.name:
            from .schedule_templates import delete_user_schedule

            delete_user_schedule(spec.name)
        save_user_schedule(updated)
        self._load()

    @Slot()
    def delete_schedule(self) -> None:
        from .schedule_templates import delete_user_schedule

        spec = self._selected_user()
        if not spec:
            return
        if (
            QMessageBox.question(
                self,
                "Delete schedule",
                f"Delete user schedule “{spec.name}”?",
            )
            != QMessageBox.StandardButton.Yes
        ):
            return
        delete_user_schedule(spec.name)
        self._load()
        self.detail.clear()

    @Slot()
    def run_schedule(self) -> None:
        spec = self._selected_user()
        if not spec:
            QMessageBox.information(self, "Schedules", "Select a user schedule.")
            return
        try:
            if (spec.kind or "agent") == "probe":
                from .probes import run_disk_probe_and_maybe_escalate

                result = run_disk_probe_and_maybe_escalate(
                    threshold_pct=float(spec.thresholdPct or 85),
                    escalate=True,
                    playbook=spec.escalatePlaybook or "disk-nix-gc-advisor",
                )
                self.detail.setPlainText(json.dumps(result, indent=2)[:4000])
                msg = (
                    "Escalated to GC advisor"
                    if result.get("escalated")
                    else "Under threshold — probe only (no LLM)"
                )
                QMessageBox.information(self, "Schedules", msg)
                return

            from .agent import run_agent
            from .auth import with_cached_credentials
            from .config import Settings

            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
            goal = spec.goal
            if spec.playbook and not goal:
                from .playbooks import get_playbook

                pb = get_playbook(spec.playbook)
                goal = pb.goal if pb else None
            if not goal:
                QMessageBox.warning(self, "Schedules", "No goal/playbook to run.")
                return
            lines = [f"Running {spec.name}…"]
            for ev in run_agent(
                goal,
                settings,
                max_steps=spec.maxSteps or 15,
                dry_run=spec.dryRun,
                profile=spec.profile,
                playbook=spec.playbook,
            ):
                kind = ev.get("kind")
                if kind in ("agent_finish", "job_finished", "error", "budget_exhausted"):
                    lines.append(json.dumps(ev)[:300])
            self.detail.setPlainText("\n".join(lines))
            QMessageBox.information(self, "Schedules", f"Finished run for {spec.name} (see details).")
        except Exception as exc:
            QMessageBox.warning(self, "Schedules", str(exc))

    @Slot()
    def copy_nix(self) -> None:
        from .schedule_templates import nix_snippet
        from PySide6.QtGui import QGuiApplication

        spec = self._selected_user()
        if not spec:
            QMessageBox.information(self, "Schedules", "Select a user schedule.")
            return
        snippet = nix_snippet(spec)
        QGuiApplication.clipboard().setText(snippet)
        self.detail.setPlainText(snippet)
        QMessageBox.information(
            self,
            "Schedules",
            "Nix snippet copied to clipboard.\n"
            "Paste into systemConfig ncc-assistant, then rebuild for a systemd timer.",
        )

    @Slot()
    def fire_watchdog(self) -> None:
        item = self.wd_list.currentItem()
        if not item:
            return
        parts = item.text().split()
        wid = parts[1] if len(parts) > 1 else ""
        try:
            from .watchdogs import list_watchdogs, fire_event

            event = next((w.event for w in list_watchdogs() if w.id == wid), wid)
            result = fire_event(event, force=True)
            QMessageBox.information(self, "Watchdog", json.dumps(result, indent=2)[:3000])
        except Exception as exc:
            QMessageBox.warning(self, "Watchdog", str(exc))


class _SecretEditorDialog(QDialog):
    def __init__(self, parent: QWidget | None = None, *, name: str = "github_token") -> None:
        super().__init__(parent)
        self.setWindowTitle("Agent secret")
        self.resize(420, 200)
        form = QFormLayout(self)
        self.name_edit = QLineEdit(name)
        form.addRow("Name", self.name_edit)
        self.label_edit = QLineEdit()
        self.label_edit.setPlaceholderText("GitHub PAT")
        form.addRow("Label", self.label_edit)
        self.value_edit = QLineEdit()
        self.value_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.value_edit.setPlaceholderText("Paste token — never stored in systemConfig")
        form.addRow("Value", self.value_edit)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        form.addRow(buttons)

    def values(self) -> tuple[str, str, str]:
        return (
            self.name_edit.text().strip(),
            self.value_edit.text(),
            self.label_edit.text().strip(),
        )


class _WorkspaceEditorDialog(QDialog):
    """Add one repo (folder picker) or scan a parent Git folder."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Add workspace")
        self.resize(520, 360)
        root = QVBoxLayout(self)

        mode_row = QHBoxLayout()
        self.mode_single = QPushButton("Single repo folder")
        self.mode_single.setCheckable(True)
        self.mode_single.setChecked(True)
        self.mode_parent = QPushButton("Scan parent folder (e.g. ~/Git)")
        self.mode_parent.setCheckable(True)
        self.mode_single.clicked.connect(lambda: self._set_mode("single"))
        self.mode_parent.clicked.connect(lambda: self._set_mode("parent"))
        mode_row.addWidget(self.mode_single)
        mode_row.addWidget(self.mode_parent)
        root.addLayout(mode_row)

        hint = QLabel(
            "Single: pick one project that contains .git.\n"
            "Scan parent: pick ~/Git (or similar); every child repo is registered "
            "as its own workspace (id from folder name)."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")
        root.addWidget(hint)

        form = QFormLayout()
        path_row = QHBoxLayout()
        self.path_edit = QLineEdit()
        self.path_edit.setPlaceholderText(str(Path.home() / "Git"))
        browse = QPushButton("Browse…")
        browse.clicked.connect(self._browse)
        path_row.addWidget(self.path_edit, stretch=1)
        path_row.addWidget(browse)
        form.addRow("Folder", path_row)

        self.id_edit = QLineEdit()
        self.id_edit.setPlaceholderText("auto from folder name")
        form.addRow("Id", self.id_edit)
        self.label_edit = QLineEdit()
        form.addRow("Label", self.label_edit)
        self.github_edit = QLineEdit()
        self.github_edit.setPlaceholderText("owner/repo (optional, auto-detect)")
        form.addRow("GitHub", self.github_edit)
        root.addLayout(form)

        self._mode = "single"
        self._set_mode("single")

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

    def _set_mode(self, mode: str) -> None:
        self._mode = mode
        self.mode_single.setChecked(mode == "single")
        self.mode_parent.setChecked(mode == "parent")
        single = mode == "single"
        self.id_edit.setEnabled(single)
        self.label_edit.setEnabled(single)
        self.github_edit.setEnabled(single)

    def _browse(self) -> None:
        start = self.path_edit.text().strip() or str(Path.home() / "Git")
        if not Path(start).is_dir():
            start = str(Path.home())
        chosen = QFileDialog.getExistingDirectory(self, "Select folder", start)
        if not chosen:
            return
        self.path_edit.setText(chosen)
        p = Path(chosen)
        if self._mode == "single":
            if not self.id_edit.text().strip():
                from .workspaces import slug_from_path

                self.id_edit.setText(slug_from_path(p))
            if not self.label_edit.text().strip():
                self.label_edit.setText(p.name)
            if not self.github_edit.text().strip():
                from .workspaces import detect_github_slug

                gh = detect_github_slug(p)
                if gh:
                    self.github_edit.setText(gh)

    def apply(self) -> list:
        from .workspaces import import_from_parent, upsert_workspace

        path = self.path_edit.text().strip()
        if not path:
            raise ValueError("Pick a folder.")
        if self._mode == "parent":
            return import_from_parent(path)
        wid = self.id_edit.text().strip()
        if not wid:
            from .workspaces import slug_from_path

            wid = slug_from_path(Path(path))
        return [
            upsert_workspace(
                wid,
                path,
                label=self.label_edit.text().strip() or None,
                github=self.github_edit.text().strip() or None,
            )
        ]


class SettingsPage(QWidget):
    """Scrollable settings: LLM → secrets → workspaces → agent → tools → memory."""

    providers_changed = Signal()

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        outer.addWidget(scroll)

        host = QWidget()
        layout = QVBoxLayout(host)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(14)
        scroll.setWidget(host)

        intro = QLabel(
            "Configure how the assistant talks to models, which secrets/MCP tokens "
            "it may use, and which local git workspaces templates can target."
        )
        intro.setWordWrap(True)
        intro.setStyleSheet("color: palette(placeholder-text);")
        layout.addWidget(intro)

        # --- 1. LLM ---
        providers_group = QGroupBox("1 · LLM providers")
        pg = QVBoxLayout(providers_group)
        self.provider_list = QListWidget()
        self.provider_list.setMinimumHeight(120)
        self.provider_list.setMaximumHeight(180)
        self.provider_list.itemDoubleClicked.connect(lambda _i: self._edit_provider())
        pg.addWidget(self.provider_list)
        prow = QHBoxLayout()
        add_btn = QPushButton("Add…")
        add_btn.clicked.connect(self._add_provider)
        prow.addWidget(add_btn)
        edit_btn = QPushButton("Edit…")
        edit_btn.clicked.connect(self._edit_provider)
        prow.addWidget(edit_btn)
        rm_btn = QPushButton("Remove")
        rm_btn.clicked.connect(self._remove_provider)
        prow.addWidget(rm_btn)
        prow.addStretch()
        pg.addLayout(prow)
        hint = QLabel(
            "Chat/model API keys → credentials.json (0600). "
            "If the model list says Auth failed, edit the provider and paste a fresh key."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")
        pg.addWidget(hint)
        layout.addWidget(providers_group)

        # --- 2. Secrets ---
        secrets_group = QGroupBox("2 · Agent secrets")
        sg = QVBoxLayout(secrets_group)
        self.secret_list = QListWidget()
        self.secret_list.setMinimumHeight(90)
        self.secret_list.setMaximumHeight(140)
        sg.addWidget(self.secret_list)
        srow = QHBoxLayout()
        s_add = QPushButton("Add / rotate…")
        s_add.clicked.connect(self._add_secret)
        srow.addWidget(s_add)
        s_del = QPushButton("Delete")
        s_del.clicked.connect(self._delete_secret)
        srow.addWidget(s_del)
        srow.addStretch()
        sg.addLayout(srow)
        s_hint = QLabel(
            "Named tokens for templates/MCP (typical: github_token). "
            "Separate from LLM keys. Stored in secrets.json (0600), never in systemConfig."
        )
        s_hint.setWordWrap(True)
        s_hint.setStyleSheet("color: palette(placeholder-text);")
        sg.addWidget(s_hint)
        layout.addWidget(secrets_group)

        # --- 3. Workspaces ---
        ws_group = QGroupBox("3 · Workspaces (local git)")
        wg = QVBoxLayout(ws_group)
        self.workspace_list = QListWidget()
        self.workspace_list.setMinimumHeight(110)
        self.workspace_list.setMaximumHeight(180)
        wg.addWidget(self.workspace_list)
        wrow = QHBoxLayout()
        w_add = QPushButton("Add…")
        w_add.clicked.connect(self._add_workspace)
        wrow.addWidget(w_add)
        w_scan = QPushButton("Scan ~/Git…")
        w_scan.clicked.connect(self._scan_git_parent)
        wrow.addWidget(w_scan)
        w_del = QPushButton("Delete")
        w_del.clicked.connect(self._delete_workspace)
        wrow.addWidget(w_del)
        wrow.addStretch()
        wg.addLayout(wrow)
        w_hint = QLabel(
            "Each workspace is one git repo path used by Templates / git MCP.\n"
            "• Add… → folder picker (single repo or scan a parent like ~/Git)\n"
            "• Scan ~/Git… → quick pick of your projects folder"
        )
        w_hint.setWordWrap(True)
        w_hint.setStyleSheet("color: palette(placeholder-text);")
        wg.addWidget(w_hint)
        layout.addWidget(ws_group)

        # --- 4. Agent runtime ---
        presence_group = QGroupBox("4 · Agent presence")
        presence_layout = QFormLayout(presence_group)
        self.presence_combo = QComboBox()
        self.presence_combo.addItems(["available", "paused", "autonomous"])
        try:
            from .presence import get_presence

            self.presence_combo.setCurrentText(get_presence().state)
        except Exception:
            pass
        self.presence_combo.currentTextChanged.connect(self._on_presence_changed)
        presence_layout.addRow("Status", self.presence_combo)
        layout.addWidget(presence_group)

        # --- Trace UX ---
        trace_group = QGroupBox("4b · Trace display")
        trace_form = QFormLayout(trace_group)
        self.density_combo = QComboBox()
        self.density_combo.addItem("Comfortable", "comfortable")
        self.density_combo.addItem("Compact", "compact")
        try:
            from .preferences import (
                get_expand_thinking_while_streaming,
                get_trace_density,
                set_expand_thinking_while_streaming,
                set_trace_density,
            )

            di = self.density_combo.findData(get_trace_density())
            if di >= 0:
                self.density_combo.setCurrentIndex(di)
            self._expand_think_check = QCheckBox("Expand thinking while streaming")
            self._expand_think_check.setChecked(get_expand_thinking_while_streaming())
        except Exception:
            set_trace_density = None  # type: ignore[assignment]
            set_expand_thinking_while_streaming = None  # type: ignore[assignment]
            self._expand_think_check = QCheckBox("Expand thinking while streaming")

        def _on_density(_i: int = 0) -> None:
            from .preferences import set_trace_density as _set

            _set(str(self.density_combo.currentData() or "comfortable"))

        def _on_expand(checked: bool) -> None:
            from .preferences import set_expand_thinking_while_streaming as _set

            _set(checked)

        self.density_combo.currentIndexChanged.connect(_on_density)
        self._expand_think_check.toggled.connect(_on_expand)
        trace_form.addRow("Density", self.density_combo)
        trace_form.addRow("", self._expand_think_check)
        layout.addWidget(trace_group)

        # --- LLM request reliability ---
        llm_net = QGroupBox("4c · LLM request (timeout / retry)")
        llm_form = QFormLayout(llm_net)
        self.timeout_spin = QSpinBox()
        self.timeout_spin.setRange(30, 3600)
        self.timeout_spin.setSuffix(" s")
        self.timeout_spin.setToolTip(
            "Wall-clock timeout for chat/completions HTTP calls"
        )
        self.retries_spin = QSpinBox()
        self.retries_spin.setRange(0, 5)
        self.retries_spin.setToolTip(
            "Extra attempts after transient errors (timeout / 429 / 5xx). "
            "0 = try once only."
        )
        try:
            from .preferences import (
                get_llm_retries,
                get_llm_timeout_sec,
                set_llm_retries,
                set_llm_timeout_sec,
            )

            self.timeout_spin.setValue(get_llm_timeout_sec())
            self.retries_spin.setValue(get_llm_retries())
        except Exception:
            self.timeout_spin.setValue(300)
            self.retries_spin.setValue(1)

        def _on_timeout(v: int) -> None:
            from .preferences import set_llm_timeout_sec as _set

            _set(v)

        def _on_retries(v: int) -> None:
            from .preferences import set_llm_retries as _set

            _set(v)

        self.timeout_spin.valueChanged.connect(_on_timeout)
        self.retries_spin.valueChanged.connect(_on_retries)
        llm_form.addRow("HTTP timeout", self.timeout_spin)
        llm_form.addRow("Auto-retries", self.retries_spin)
        llm_hint = QLabel(
            "Applies to native chat/agent LLM calls. Companion Retry button "
            "resends the last user message after an error. Auto-retries only "
            "run when no tokens were streamed yet."
        )
        llm_hint.setWordWrap(True)
        llm_hint.setStyleSheet("color: palette(placeholder-text);")
        llm_form.addRow(llm_hint)
        layout.addWidget(llm_net)

        host_group = QGroupBox("5 · Host profile")
        host_layout = QVBoxLayout(host_group)
        try:
            from .host_profiles import resolve_active_profile, list_host_profiles

            active = resolve_active_profile()
            host_layout.addWidget(
                QLabel(f"Active: {active.name if active else '(default hostname)'}")
            )
            profiles = list_host_profiles()
            names = ", ".join(p.name for p in profiles) if profiles else "(none)"
            host_layout.addWidget(QLabel(f"Profiles: {names}"))
        except Exception as exc:
            host_layout.addWidget(QLabel(f"(profiles: {exc})"))
        layout.addWidget(host_group)

        # --- 6. Tools / maintenance ---
        config_group = QGroupBox("6 · Maintenance")
        config_layout = QVBoxLayout(config_group)
        config_layout.addWidget(QLabel(f"Confirm mode: {os.environ.get('AGENT_CONFIRM', 'writes')}"))
        config_layout.addWidget(
            QLabel(f"Allow write: {'Yes' if os.environ.get('AGENT_ALLOW_WRITE', '0') == '1' else 'No'}")
        )
        config_layout.addWidget(
            QLabel(
                f"Allow rebuild: {'Yes' if os.environ.get('AGENT_ALLOW_REBUILD', '0') == '1' else 'No'}"
            )
        )
        open_btn = QPushButton("Open config directory")
        open_btn.clicked.connect(self._open_config_dir)
        config_layout.addWidget(open_btn)
        sync_btn = QPushButton("Sync knowledge overlay")
        sync_btn.clicked.connect(self._sync_knowledge)
        config_layout.addWidget(sync_btn)
        shortcuts_btn = QPushButton("Install desktop shortcuts")
        shortcuts_btn.clicked.connect(self._install_shortcuts)
        config_layout.addWidget(shortcuts_btn)
        export_btn = QPushButton("Export latest transcript")
        export_btn.clicked.connect(self._export_transcript)
        config_layout.addWidget(export_btn)
        red_btn = QPushButton("Run red-team guards")
        red_btn.clicked.connect(self._red_team)
        config_layout.addWidget(red_btn)
        layout.addWidget(config_group)

        # --- 7. Memory ---
        memory_group = QGroupBox("7 · Memory")
        memory_layout = QVBoxLayout(memory_group)
        self.memory_list = QListWidget()
        self.memory_list.setMinimumHeight(90)
        self.memory_list.setMaximumHeight(160)
        memory_layout.addWidget(self.memory_list)
        forget_btn = QPushButton("Forget selected")
        forget_btn.clicked.connect(self._forget_memory)
        memory_layout.addWidget(forget_btn)
        layout.addWidget(memory_group)

        layout.addStretch(1)
        self._load_memory()
        self._reload_providers()
        self._reload_secrets()
        self._reload_workspaces()

    def _reload_secrets(self) -> None:
        from .secrets import list_secrets

        self.secret_list.clear()
        for s in list_secrets():
            item = QListWidgetItem(f"{s.name}  ·  {s.label}  ·  updated {s.updated or '-'}")
            item.setData(Qt.ItemDataRole.UserRole, s.name)
            self.secret_list.addItem(item)

    def _add_secret(self) -> None:
        from .secrets import set_secret

        dlg = _SecretEditorDialog(self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        name, value, label = dlg.values()
        try:
            set_secret(name, value, label=label or None)
        except ValueError as exc:
            QMessageBox.warning(self, "Secrets", str(exc))
            return
        self._reload_secrets()

    def _delete_secret(self) -> None:
        from .secrets import delete_secret

        item = self.secret_list.currentItem()
        if not item:
            return
        name = str(item.data(Qt.ItemDataRole.UserRole))
        if delete_secret(name):
            self._reload_secrets()

    def _reload_workspaces(self) -> None:
        from .workspaces import list_workspaces

        self.workspace_list.clear()
        for ws in list_workspaces():
            gh = f"  ·  github:{ws.github}" if ws.github else ""
            item = QListWidgetItem(f"{ws.id}  ·  {ws.path}{gh}")
            item.setData(Qt.ItemDataRole.UserRole, ws.id)
            self.workspace_list.addItem(item)

    def _add_workspace(self) -> None:
        dlg = _WorkspaceEditorDialog(self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        try:
            imported = dlg.apply()
        except ValueError as exc:
            QMessageBox.warning(self, "Workspaces", str(exc))
            return
        self._reload_workspaces()
        QMessageBox.information(
            self,
            "Workspaces",
            f"Registered {len(imported)} workspace(s):\n"
            + "\n".join(f"• {w.id} → {w.path}" for w in imported[:12]),
        )

    def _scan_git_parent(self) -> None:
        from .workspaces import import_from_parent

        start = str(Path.home() / "Git")
        if not Path(start).is_dir():
            start = str(Path.home())
        chosen = QFileDialog.getExistingDirectory(
            self, "Select parent folder containing git projects", start
        )
        if not chosen:
            return
        try:
            imported = import_from_parent(chosen)
        except ValueError as exc:
            QMessageBox.warning(self, "Workspaces", str(exc))
            return
        self._reload_workspaces()
        QMessageBox.information(
            self,
            "Workspaces",
            f"Imported {len(imported)} repo(s) from {chosen}",
        )

    def _delete_workspace(self) -> None:
        from .workspaces import delete_workspace

        item = self.workspace_list.currentItem()
        if not item:
            return
        if delete_workspace(str(item.data(Qt.ItemDataRole.UserRole))):
            self._reload_workspaces()

    def _reload_providers(self) -> None:
        from .providers import load_providers

        self.provider_list.clear()
        for p in load_providers():
            auth = p.auth_header or "Bearer"
            extras = f" +{len(p.extra_headers)} hdr" if p.extra_headers else ""
            item = QListWidgetItem(f"{p.name}  ·  {p.api}  ·  {auth}{extras}  ·  {p.endpoint}")
            item.setData(Qt.ItemDataRole.UserRole, p.id)
            self.provider_list.addItem(item)

    def _add_provider(self) -> None:
        from .provider_ui import edit_provider_dialog

        if edit_provider_dialog(self, provider=None) is None:
            return
        self._reload_providers()
        self.providers_changed.emit()

    def _edit_provider(self) -> None:
        from .provider_ui import edit_provider_dialog
        from .providers import get_provider

        item = self.provider_list.currentItem()
        if not item:
            QMessageBox.information(self, "Providers", "Select a provider to edit.")
            return
        prov = get_provider(str(item.data(Qt.ItemDataRole.UserRole)))
        if prov is None:
            return
        if edit_provider_dialog(self, provider=prov) is None:
            return
        self._reload_providers()
        self.providers_changed.emit()

    def _remove_provider(self) -> None:
        from .providers import remove_provider

        item = self.provider_list.currentItem()
        if not item:
            return
        pid = item.data(Qt.ItemDataRole.UserRole)
        if not remove_provider(str(pid)):
            QMessageBox.information(
                self,
                "Providers",
                "Keep at least one provider (or select a different one to remove).",
            )
            return
        self._reload_providers()
        self.providers_changed.emit()

    def _on_presence_changed(self, status: str) -> None:
        try:
            from .presence import set_presence

            set_presence(status)  # type: ignore[arg-type]
        except Exception:
            pass

    def _open_config_dir(self) -> None:
        import subprocess

        from .paths import config_home

        subprocess.Popen(["xdg-open", str(config_home())])

    def _sync_knowledge(self) -> None:
        from .paths import knowledge_overlay_dir

        overlay = knowledge_overlay_dir()
        note = overlay / "user-notes.md"
        if not note.is_file():
            note.write_text("# User knowledge overlay\n\n", encoding="utf-8")
        QMessageBox.information(
            self,
            "Knowledge",
            f"Overlay ready at {overlay}\nsearch_knowledge prefers overlay hits.",
        )

    def _install_shortcuts(self) -> None:
        try:
            from .shortcuts import install_user_shortcuts, shortcut_help

            path = install_user_shortcuts()
            QMessageBox.information(self, "Shortcuts", f"Installed {path}\n\n{shortcut_help()}")
        except Exception as exc:
            QMessageBox.warning(self, "Shortcuts", str(exc))

    def _export_transcript(self) -> None:
        try:
            from .export_transcript import export_latest

            path = export_latest()
            QMessageBox.information(self, "Export", f"Exported to: {path}")
        except Exception as e:
            QMessageBox.warning(self, "Export", f"Export failed: {e}")

    def _red_team(self) -> None:
        try:
            from .auth import with_cached_credentials
            from .config import Settings
            from .red_team import run_red_team_checks
            from .runtime import ToolRuntime

            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
            report = run_red_team_checks(ToolRuntime(settings, dry_run=True))
            QMessageBox.information(self, "Red team", json.dumps(report.to_dict(), indent=2)[:4000])
        except Exception as exc:
            QMessageBox.warning(self, "Red team", str(exc))

    def _load_memory(self) -> None:
        self.memory_list.clear()
        self._memory_ids: list[str] = []
        try:
            from .memory import list_notes

            for note in list_notes(limit=20):
                self._memory_ids.append(note.id)
                self.memory_list.addItem(f"{note.id}: {note.content[:70]}")
        except Exception:
            self.memory_list.addItem("(Memory not available)")

    def _forget_memory(self) -> None:
        row = self.memory_list.currentRow()
        if row < 0 or row >= len(getattr(self, "_memory_ids", [])):
            return
        from .memory import forget_note

        forget_note(self._memory_ids[row])
        self._load_memory()
