"""Additional GUI pages and dialogs for the NCC AI assistant shell."""

from __future__ import annotations

import json
import os
import traceback
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal, Slot
from PySide6.QtGui import QFont, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
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


class ToolTraceWidget(QWidget):
    """Compact collapsible tool-call / result row (phase 25)."""

    def __init__(self, name: str, args: object, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 2, 4, 2)
        layout.setSpacing(2)

        header = QHBoxLayout()
        self._toggle = QToolButton()
        self._toggle.setText("▸")
        self._toggle.setCheckable(True)
        self._toggle.setChecked(False)
        self._toggle.toggled.connect(self._on_toggle)
        header.addWidget(self._toggle)

        summary = str(args)
        if len(summary) > 80:
            summary = summary[:77] + "…"
        self._title = QLabel(f"tool {name}({summary})")
        self._title.setStyleSheet("font-family: monospace; color: palette(mid);")
        header.addWidget(self._title, stretch=1)
        layout.addLayout(header)

        self._body = QTextBrowser()
        self._body.setVisible(False)
        self._body.setMaximumHeight(160)
        self._body.setStyleSheet("font-family: monospace; font-size: 11px;")
        layout.addWidget(self._body)
        self._raw_args = args
        self._result = ""

    def _on_toggle(self, checked: bool) -> None:
        self._toggle.setText("▾" if checked else "▸")
        self._body.setVisible(checked)
        self._refresh()

    def set_result(self, text: str) -> None:
        self._result = text
        ok = "ok" if "error" not in text.lower()[:80] else "err"
        self._title.setText(self._title.text().split(" →")[0] + f" → {ok}")
        self._refresh()

    def _refresh(self) -> None:
        self._body.setPlainText(
            f"args:\n{json.dumps(self._raw_args, indent=2, default=str)[:2000]}\n\n"
            f"result:\n{self._result[:3000]}"
        )


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
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._goal = goal
        self._max_steps = max_steps
        self._dry_run = dry_run
        self._profile = profile
        self._playbook = playbook
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

            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
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
        max_s = self.max_steps_spin.value()
        self.budget_label.setText(f"Steps: 0 / {max_s} · tokens: —")
        self.log.append(f"Starting agent: {goal}\n")

        self._worker = AgentWorker(
            goal,
            max_steps=max_s,
            dry_run=self.dry_run_check.isChecked(),
            profile=self.profile_combo.currentText(),
            playbook=playbook,
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
        elif kind == "tool":
            self.log.append(f"▸ {event.get('name')} {event.get('args', '')}")
        elif kind == "tool_result":
            self.log.append(f"  ↳ {(event.get('text') or '')[:400]}")
        elif kind == "assistant":
            self.log.append(f"Assistant: {(event.get('text') or '')[:500]}")
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
        m_layout = QHBoxLayout(market)
        self.template_combo = QComboBox()
        try:
            from .marketplace import list_templates

            for t in list_templates():
                self.template_combo.addItem(t.name, t.name)
        except Exception:
            pass
        m_layout.addWidget(self.template_combo, stretch=1)
        install_btn = QPushButton("Install template")
        install_btn.clicked.connect(self.install_template)
        m_layout.addWidget(install_btn)
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

            result = install_template(name)
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

        self.cal_edit = QLineEdit(spec.onCalendar if spec else "*-*-* 03:15:00")
        form.addRow("OnCalendar", self.cal_edit)

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
            onCalendar=self.cal_edit.text().strip() or "daily",
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


class SettingsPage(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        presence_group = QGroupBox("Presence")
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

        host_group = QGroupBox("Host profile")
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

        config_group = QGroupBox("Configuration")
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

        memory_group = QGroupBox("Memory")
        memory_layout = QVBoxLayout(memory_group)
        self.memory_list = QListWidget()
        self.memory_list.setMaximumHeight(140)
        memory_layout.addWidget(self.memory_list)
        forget_btn = QPushButton("Forget selected")
        forget_btn.clicked.connect(self._forget_memory)
        memory_layout.addWidget(forget_btn)
        layout.addWidget(memory_group)

        layout.addStretch()
        self._load_memory()

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
