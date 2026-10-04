"""Agent template catalog + configure modal for the NCC AI GUI."""

from __future__ import annotations

from typing import Any

from PySide6.QtCore import Qt, QThread, QTime, Signal
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QTimeEdit,
    QVBoxLayout,
    QWidget,
)


class FrequencyPicker(QWidget):
    """Preset / daily-at / weekly-at / custom OnCalendar picker."""

    def __init__(self, parent: QWidget | None = None, *, default: str = "daily") -> None:
        super().__init__(parent)
        from .schedule_freq import FREQUENCY_PRESETS, WEEKDAYS

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)

        self.preset = QComboBox()
        for key, label, _tmpl in FREQUENCY_PRESETS:
            self.preset.addItem(label, key)
        lay.addWidget(self.preset)

        self.time_row = QWidget()
        tr = QHBoxLayout(self.time_row)
        tr.setContentsMargins(0, 0, 0, 0)
        self.weekday = QComboBox()
        for key, label in WEEKDAYS:
            self.weekday.addItem(label, key)
        tr.addWidget(self.weekday)
        self.time_edit = QTimeEdit()
        self.time_edit.setDisplayFormat("HH:mm")
        self.time_edit.setTime(QTime(3, 15))
        tr.addWidget(self.time_edit)
        lay.addWidget(self.time_row)

        self.custom_edit = QLineEdit()
        self.custom_edit.setPlaceholderText(
            "systemd OnCalendar, e.g. *-*-* 03:15:00  or cron: 15 3 * * *"
        )
        lay.addWidget(self.custom_edit)

        self.preview = QLabel("")
        self.preview.setStyleSheet("color: palette(placeholder-text);")
        self.preview.setWordWrap(True)
        lay.addWidget(self.preview)

        self.preset.currentIndexChanged.connect(self._sync_visibility)
        self.weekday.currentIndexChanged.connect(self._update_preview)
        self.time_edit.timeChanged.connect(lambda _t: self._update_preview())
        self.custom_edit.textChanged.connect(lambda _t: self._update_preview())

        # Apply default
        from .schedule_freq import parse_stored_frequency

        parsed = parse_stored_frequency(str(default or "daily"))
        preset = parsed.get("preset") or "daily"
        # Map aliases like "weekly" that normalize to themselves
        idx = self.preset.findData(preset)
        if idx < 0 and preset in ("hourly", "daily", "weekly"):
            idx = self.preset.findData(preset)
        if idx < 0:
            idx = self.preset.findData("custom")
        if idx >= 0:
            self.preset.setCurrentIndex(idx)
        if parsed.get("hour") is not None:
            self.time_edit.setTime(
                QTime(int(parsed["hour"]), int(parsed.get("minute") or 0))
            )
        if parsed.get("weekday"):
            widx = self.weekday.findData(parsed["weekday"])
            if widx >= 0:
                self.weekday.setCurrentIndex(widx)
        if parsed.get("custom"):
            self.custom_edit.setText(str(parsed["custom"]))
        self._sync_visibility()

    def _sync_visibility(self) -> None:
        key = self.preset.currentData()
        self.time_row.setVisible(key in ("daily-at", "weekly-at"))
        self.weekday.setVisible(key == "weekly-at")
        self.custom_edit.setVisible(key == "custom")
        self._update_preview()

    def _update_preview(self) -> None:
        cal = self.on_calendar()
        self.preview.setText(f"Schedule: {cal}")

    def on_calendar(self) -> str:
        from .schedule_freq import normalize_on_calendar

        key = str(self.preset.currentData() or "daily")
        if key == "custom":
            return normalize_on_calendar(self.custom_edit.text().strip() or "daily")
        t = self.time_edit.time()
        return normalize_on_calendar(
            key,
            hour=t.hour(),
            minute=t.minute(),
            weekday=str(self.weekday.currentData() or "Sun"),
        )


class TimezonePicker(QComboBox):
    def __init__(self, parent: QWidget | None = None, *, default: str = "Europe/Berlin") -> None:
        super().__init__(parent)
        from .schedule_freq import COMMON_TIMEZONES

        self.setEditable(True)
        for tz in COMMON_TIMEZONES:
            self.addItem(tz)
        if default:
            idx = self.findText(default)
            if idx >= 0:
                self.setCurrentIndex(idx)
            else:
                self.setEditText(default)


class TemplateConfigureDialog(QDialog):
    """Dynamic param form for an agent template."""

    def __init__(self, template_id: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        from .agent_templates import get_agent_template

        self._tmpl = get_agent_template(template_id)
        if self._tmpl is None:
            raise ValueError(f"Unknown template: {template_id}")
        self.setWindowTitle(f"Configure — {self._tmpl.title}")
        self.resize(540, 640)
        self._fields: dict[str, Any] = {}

        root = QVBoxLayout(self)
        desc = QLabel(self._tmpl.description)
        desc.setWordWrap(True)
        root.addWidget(desc)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        form_host = QWidget()
        form = QFormLayout(form_host)
        scroll.setWidget(form_host)
        root.addWidget(scroll, stretch=1)

        for p in self._tmpl.params:
            label = p.label + (" *" if p.required else "")
            widget: QWidget
            if p.type == "enum":
                combo = QComboBox()
                for opt in p.options:
                    combo.addItem(opt, opt)
                if p.default is not None:
                    idx = combo.findData(str(p.default))
                    if idx >= 0:
                        combo.setCurrentIndex(idx)
                widget = combo
            elif p.type == "secretRef":
                combo = QComboBox()
                combo.setEditable(True)
                from .secrets import list_secrets

                for s in list_secrets():
                    combo.addItem(f"{s.name} ({s.label})", s.name)
                if p.default:
                    combo.setEditText(str(p.default))
                widget = combo
            elif p.type == "workspaceList":
                listw = QListWidget()
                listw.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
                from .workspaces import list_workspaces

                for ws in list_workspaces():
                    item = QListWidgetItem(f"{ws.id} — {ws.path}")
                    item.setData(Qt.ItemDataRole.UserRole, ws.id)
                    listw.addItem(item)
                listw.setMinimumHeight(100)
                widget = listw
            elif p.type == "stringList":
                edit = QLineEdit()
                if p.default is not None:
                    if isinstance(p.default, list):
                        edit.setText(", ".join(str(x) for x in p.default))
                    else:
                        edit.setText(str(p.default))
                edit.setPlaceholderText("comma-separated")
                widget = edit
            elif p.type == "cronOrInterval":
                widget = FrequencyPicker(default=str(p.default or "daily"))
            elif p.type == "timezone":
                widget = TimezonePicker(default=str(p.default or "Europe/Berlin"))
            else:
                edit = QLineEdit()
                if p.default is not None:
                    edit.setText(str(p.default))
                if p.description:
                    edit.setToolTip(p.description)
                widget = edit
            self._fields[p.id] = (p, widget)
            form.addRow(label, widget)

        self.schedule_cb = QCheckBox("Enable schedule from check frequency")
        self.schedule_cb.setChecked(bool(self._tmpl.schedule_kind))
        root.addWidget(self.schedule_cb)

        buttons = QDialogButtonBox()
        save_btn = buttons.addButton("Save instance", QDialogButtonBox.ButtonRole.AcceptRole)
        run_btn = buttons.addButton("Save & Run once", QDialogButtonBox.ButtonRole.ActionRole)
        cancel = buttons.addButton(QDialogButtonBox.StandardButton.Cancel)
        root.addWidget(buttons)

        self._run_after = False
        save_btn.clicked.connect(self._accept_save)
        run_btn.clicked.connect(self._accept_run)
        cancel.clicked.connect(self.reject)

    def _collect_params(self) -> dict[str, Any]:
        params: dict[str, Any] = {}
        for pid, (p, widget) in self._fields.items():
            if p.type == "enum":
                params[pid] = widget.currentData() or widget.currentText()
            elif p.type == "secretRef":
                data = widget.currentData()
                params[pid] = data if data else widget.currentText().strip()
            elif p.type == "workspaceList":
                ids = [
                    item.data(Qt.ItemDataRole.UserRole)
                    for item in widget.selectedItems()
                ]
                params[pid] = [str(x) for x in ids if x]
            elif p.type == "stringList":
                text = widget.text().strip()
                params[pid] = [x.strip() for x in text.split(",") if x.strip()]
            elif p.type == "cronOrInterval":
                params[pid] = widget.on_calendar()
            elif p.type == "timezone":
                params[pid] = widget.currentText().strip()
            else:
                params[pid] = widget.text().strip()
        return params

    def _accept_save(self) -> None:
        self._run_after = False
        self.accept()

    def _accept_run(self) -> None:
        self._run_after = True
        self.accept()

    def result_payload(self) -> dict[str, Any]:
        return {
            "params": self._collect_params(),
            "enable_schedule": self.schedule_cb.isChecked(),
            "run_after": self._run_after,
        }


class _TemplateCard(QFrame):
    configure = Signal(str)

    def __init__(self, tmpl: Any, badges: list[dict[str, str]], parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFrameShape(QFrame.Shape.StyledPanel)
        self.setStyleSheet(
            "QFrame { border: 1px solid palette(mid); border-radius: 8px; padding: 8px; }"
        )
        lay = QVBoxLayout(self)
        head = QHBoxLayout()
        title = QLabel(tmpl.title)
        f = title.font()
        f.setBold(True)
        title.setFont(f)
        head.addWidget(title, stretch=1)
        cat = QLabel(tmpl.category)
        cat.setStyleSheet("color: palette(placeholder-text);")
        head.addWidget(cat)
        plus = QPushButton("+")
        plus.setFixedWidth(32)
        plus.setToolTip("Configure")
        plus.clicked.connect(lambda: self.configure.emit(tmpl.id))
        head.addWidget(plus)
        lay.addLayout(head)
        desc = QLabel(tmpl.description)
        desc.setWordWrap(True)
        lay.addWidget(desc)
        if badges:
            badge_row = QHBoxLayout()
            for b in badges:
                lab = QLabel(b["label"])
                kind = b.get("kind") or "ok"
                if kind == "ok":
                    lab.setStyleSheet(
                        "background: #1f6f4a; color: white; border-radius: 4px; padding: 2px 6px;"
                    )
                elif kind == "warn":
                    lab.setStyleSheet(
                        "background: #5a5a5a; color: white; border-radius: 4px; padding: 2px 6px;"
                    )
                else:
                    lab.setStyleSheet(
                        "background: #8a3a3a; color: white; border-radius: 4px; padding: 2px 6px;"
                    )
                badge_row.addWidget(lab)
            badge_row.addStretch()
            lay.addLayout(badge_row)


class _InstanceRunWorker(QThread):
    finished_ok = Signal(str)
    failed = Signal(str)

    def __init__(self, instance_id: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._instance_id = instance_id

    def run(self) -> None:
        try:
            from .agent_templates import run_instance

            summary = "finished"
            for ev in run_instance(self._instance_id):
                if ev.get("kind") == "agent_finish":
                    summary = str(ev.get("summary") or "finished")
                elif ev.get("kind") == "error":
                    summary = str(ev.get("text") or ev)
            self.finished_ok.emit(summary)
        except Exception as exc:  # noqa: BLE001
            self.failed.emit(str(exc))


class TemplatesPage(QWidget):
    """Catalog of agent workflow templates + saved instances."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._run_worker: _InstanceRunWorker | None = None
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        intro = QLabel(
            "Each template bundles an agent prompt, skill instructions, and the MCPs "
            "needed to make it useful. Configure one to save an instance (optional schedule)."
        )
        intro.setWordWrap(True)
        layout.addWidget(intro)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self._host = QWidget()
        self._host_layout = QVBoxLayout(self._host)
        scroll.setWidget(self._host)
        layout.addWidget(scroll, stretch=1)

        inst_box = QGroupBox("Installed instances")
        il = QVBoxLayout(inst_box)
        self.instance_list = QListWidget()
        self.instance_list.setMaximumHeight(140)
        il.addWidget(self.instance_list)
        irow = QHBoxLayout()
        run_btn = QPushButton("Run selected")
        run_btn.clicked.connect(self._run_selected)
        irow.addWidget(run_btn)
        del_btn = QPushButton("Delete")
        del_btn.clicked.connect(self._delete_selected)
        irow.addWidget(del_btn)
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self.reload)
        irow.addWidget(refresh_btn)
        irow.addStretch()
        il.addLayout(irow)
        layout.addWidget(inst_box)

        self.reload()

    def reload(self) -> None:
        while self._host_layout.count():
            item = self._host_layout.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()

        from .agent_templates import list_agent_templates, list_instances, template_badges

        catalog = [
            t
            for t in list_agent_templates()
            if t.tier in ("catalog", "proven", "")
        ]
        beta = [t for t in list_agent_templates() if t.tier == "beta"]

        def section(title: str, items: list) -> None:
            self._host_layout.addWidget(QLabel(f"<b>{title} ({len(items)})</b>"))
            for tmpl in items:
                card = _TemplateCard(tmpl, template_badges(tmpl))
                card.configure.connect(self._configure)
                self._host_layout.addWidget(card)

        section("Workflow templates", catalog)
        section("Beta / experimental", beta)
        self._host_layout.addStretch()

        self.instance_list.clear()
        for inst in list_instances():
            item = QListWidgetItem(f"{inst.title}  ·  {inst.template_id}  ·  {inst.id}")
            item.setData(Qt.ItemDataRole.UserRole, inst.id)
            self.instance_list.addItem(item)

    def _configure(self, template_id: str) -> None:
        from .agent_templates import instantiate

        try:
            dlg = TemplateConfigureDialog(template_id, self)
        except ValueError as exc:
            QMessageBox.warning(self, "Templates", str(exc))
            return
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        payload = dlg.result_payload()
        result = instantiate(
            template_id,
            payload["params"],
            enable_schedule=bool(payload["enable_schedule"]),
        )
        if not result.get("ok"):
            QMessageBox.warning(self, "Templates", result.get("error") or "Failed")
            return
        QMessageBox.information(
            self,
            "Templates",
            f"Saved instance {result['instance']['id']}\n"
            f"Playbook: {result.get('playbook')}\n"
            f"Schedule: {result.get('schedule') or '(none)'}",
        )
        self.reload()
        if payload.get("run_after"):
            self._run_instance(result["instance"]["id"])

    def _run_selected(self) -> None:
        item = self.instance_list.currentItem()
        if not item:
            QMessageBox.information(self, "Templates", "Select an instance.")
            return
        self._run_instance(str(item.data(Qt.ItemDataRole.UserRole)))

    def _run_instance(self, instance_id: str) -> None:
        if self._run_worker and self._run_worker.isRunning():
            QMessageBox.information(self, "Templates", "A run is already in progress.")
            return
        worker = _InstanceRunWorker(instance_id, self)
        self._run_worker = worker

        def _ok(summary: str) -> None:
            QMessageBox.information(
                self, "Templates", f"{summary}\n\nSee Jobs tab for the full trace."
            )

        def _fail(message: str) -> None:
            QMessageBox.warning(self, "Templates", message)

        worker.finished_ok.connect(_ok)
        worker.failed.connect(_fail)
        worker.start()
        QMessageBox.information(
            self, "Templates", f"Started instance {instance_id} in background…"
        )

    def _delete_selected(self) -> None:
        from .agent_templates import delete_instance

        item = self.instance_list.currentItem()
        if not item:
            return
        iid = str(item.data(Qt.ItemDataRole.UserRole))
        if delete_instance(iid):
            self.reload()
