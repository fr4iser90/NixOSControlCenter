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
    QSizePolicy,
    QTabWidget,
    QTextEdit,
    QTimeEdit,
    QVBoxLayout,
    QWidget,
)


class FrequencyPicker(QWidget):
    """Schedule picker: mode enum → Daily clock / Weekly / Cron / Simple / Advanced."""

    def __init__(self, parent: QWidget | None = None, *, default: str = "daily") -> None:
        super().__init__(parent)
        from .schedule_freq import (
            CRON_DOM,
            CRON_DOW,
            CRON_HOURS,
            CRON_MINUTES,
            CRON_MONTH,
            FREQUENCY_PRESETS,
            SCHEDULE_MODES,
            WEEKDAYS,
            parse_stored_frequency,
        )

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        self.setMinimumWidth(320)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Minimum)

        mode_tag = QLabel("Schedule mode")
        mode_tag.setStyleSheet("color: palette(placeholder-text); font-size: 10px;")
        lay.addWidget(mode_tag)
        self.mode = QComboBox()
        self.mode.setToolTip(
            "Daily/Weekly: weekday + clock (e.g. Monday 08:40). "
            "Cron: field pickers. Simple: midnight/hourly presets."
        )
        for key, label in SCHEDULE_MODES:
            self.mode.addItem(label, key)
        lay.addWidget(self.mode)

        self.preset = QComboBox()
        for key, label, _tmpl in FREQUENCY_PRESETS:
            self.preset.addItem(label, key)
        lay.addWidget(self.preset)

        self.time_row = QWidget()
        tr = QHBoxLayout(self.time_row)
        tr.setContentsMargins(0, 0, 0, 0)
        tr.setSpacing(6)
        self.weekday = QComboBox()
        for key, label in WEEKDAYS:
            self.weekday.addItem(label, key)
        self.weekday.setToolTip("Weekday (local calendar)")
        wd_box = QVBoxLayout()
        wd_box.setContentsMargins(0, 0, 0, 0)
        wd_box.setSpacing(0)
        wd_tag = QLabel("Weekday")
        wd_tag.setStyleSheet("color: palette(placeholder-text); font-size: 10px;")
        wd_box.addWidget(wd_tag)
        wd_box.addWidget(self.weekday)
        wd_wrap = QWidget()
        wd_wrap.setLayout(wd_box)
        tr.addWidget(wd_wrap, stretch=1)
        self.time_edit = QTimeEdit()
        self.time_edit.setDisplayFormat("HH:mm")
        self.time_edit.setTime(QTime(8, 30))
        self.time_edit.setToolTip("Clock time — uses this machine's local system time")
        tm_box = QVBoxLayout()
        tm_box.setContentsMargins(0, 0, 0, 0)
        tm_box.setSpacing(0)
        tm_tag = QLabel("Time (local)")
        tm_tag.setStyleSheet("color: palette(placeholder-text); font-size: 10px;")
        tm_box.addWidget(tm_tag)
        tm_box.addWidget(self.time_edit)
        tm_wrap = QWidget()
        tm_wrap.setLayout(tm_box)
        tr.addWidget(tm_wrap)
        lay.addWidget(self.time_row)

        self.cron_row = QWidget()
        cr = QHBoxLayout(self.cron_row)
        cr.setContentsMargins(0, 0, 0, 0)
        cr.setSpacing(4)

        def _cron_combo(items: list[tuple[str, str]], tip: str) -> QComboBox:
            c = QComboBox()
            c.setToolTip(tip)
            for val, label in items:
                c.addItem(label, val)
            return c

        self.cron_min = _cron_combo(CRON_MINUTES, "Minute")
        self.cron_hour = _cron_combo(CRON_HOURS, "Hour")
        self.cron_dom = _cron_combo(CRON_DOM, "Day of month")
        self.cron_month = _cron_combo(CRON_MONTH, "Month")
        self.cron_dow = _cron_combo(CRON_DOW, "Day of week")
        for w, lab in (
            (self.cron_min, "min"),
            (self.cron_hour, "h"),
            (self.cron_dom, "dom"),
            (self.cron_month, "mon"),
            (self.cron_dow, "dow"),
        ):
            box = QVBoxLayout()
            box.setContentsMargins(0, 0, 0, 0)
            box.setSpacing(0)
            tag = QLabel(lab)
            tag.setStyleSheet("color: palette(placeholder-text); font-size: 10px;")
            box.addWidget(tag)
            box.addWidget(w)
            wrap = QWidget()
            wrap.setLayout(box)
            cr.addWidget(wrap)
        lay.addWidget(self.cron_row)

        self.custom_edit = QLineEdit()
        self.custom_edit.setPlaceholderText("Raw systemd OnCalendar, e.g. *-*-* 03:15:00")
        lay.addWidget(self.custom_edit)

        self.preview = QLabel("")
        self.preview.setStyleSheet("color: palette(placeholder-text);")
        self.preview.setWordWrap(True)
        lay.addWidget(self.preview)

        self._suppress_mode_defaults = True
        self.mode.currentIndexChanged.connect(self._on_mode_changed)
        self.preset.currentIndexChanged.connect(self._update_preview)
        self.weekday.currentIndexChanged.connect(self._update_preview)
        self.time_edit.timeChanged.connect(lambda _t: self._update_preview())
        self.custom_edit.textChanged.connect(lambda _t: self._update_preview())
        for c in (
            self.cron_min,
            self.cron_hour,
            self.cron_dom,
            self.cron_month,
            self.cron_dow,
        ):
            c.currentIndexChanged.connect(self._update_preview)

        raw_default = str(default or "daily").strip()
        parsed = parse_stored_frequency(raw_default)
        # Bare "daily"/"weekly" aliases → clock UI (08:30), not midnight-only simple.
        if raw_default.lower() in ("daily", "day") and parsed.get("mode") == "simple":
            parsed = {
                "mode": "daily-at",
                "hour": 8,
                "minute": 30,
                "on_calendar": "*-*-* 08:30:00",
            }
        elif raw_default.lower() in ("weekly", "week") and parsed.get("mode") == "simple":
            parsed = {
                "mode": "weekly-at",
                "weekday": "Mon",
                "hour": 8,
                "minute": 30,
                "on_calendar": "Mon *-*-* 08:30:00",
            }
        mode = str(parsed.get("mode") or "daily-at")
        midx = self.mode.findData(mode)
        if midx < 0:
            midx = self.mode.findData("simple")
        if midx >= 0:
            self.mode.setCurrentIndex(midx)
        preset = parsed.get("preset") or "daily"
        pidx = self.preset.findData(preset)
        if pidx >= 0:
            self.preset.setCurrentIndex(pidx)
        if parsed.get("hour") is not None:
            self.time_edit.setTime(
                QTime(int(parsed["hour"]), int(parsed.get("minute") or 0))
            )
        elif mode in ("daily-at", "weekly-at"):
            self.time_edit.setTime(QTime(8, 30))
        if parsed.get("weekday"):
            widx = self.weekday.findData(parsed["weekday"])
            if widx >= 0:
                self.weekday.setCurrentIndex(widx)
        elif mode == "weekly-at":
            widx = self.weekday.findData("Mon")
            if widx >= 0:
                self.weekday.setCurrentIndex(widx)
        for attr, key in (
            ("cron_min", "cron_minute"),
            ("cron_hour", "cron_hour"),
            ("cron_dom", "cron_dom"),
            ("cron_month", "cron_month"),
            ("cron_dow", "cron_dow"),
        ):
            if parsed.get(key) is not None:
                combo = getattr(self, attr)
                cidx = combo.findData(str(parsed[key]))
                if cidx >= 0:
                    combo.setCurrentIndex(cidx)
        if parsed.get("custom"):
            self.custom_edit.setText(str(parsed["custom"]))
        if self.cron_min.currentData() is None:
            self.cron_min.setCurrentIndex(0)
        # Default cron example: Monday 08:30 when no stored cron fields
        if mode == "cron" and parsed.get("cron_hour") is None:
            hidx = self.cron_hour.findData("8")
            midx_c = self.cron_min.findData("30")
            didx = self.cron_dow.findData("1")
            if hidx >= 0:
                self.cron_hour.setCurrentIndex(hidx)
            if midx_c >= 0:
                self.cron_min.setCurrentIndex(midx_c)
            if didx >= 0:
                self.cron_dow.setCurrentIndex(didx)
        self._suppress_mode_defaults = False
        self._sync_visibility()

    def _on_mode_changed(self, _index: int = 0) -> None:
        if not self._suppress_mode_defaults:
            mode = str(self.mode.currentData() or "simple")
            # Sensible defaults when switching into clock modes
            if mode == "weekly-at":
                if self.weekday.currentData() is None:
                    widx = self.weekday.findData("Mon")
                    if widx >= 0:
                        self.weekday.setCurrentIndex(widx)
                # Prefer a daytime example if still at midnight-ish from other modes
                t = self.time_edit.time()
                if t.hour() == 0 and t.minute() == 0:
                    self.time_edit.setTime(QTime(8, 30))
            elif mode == "daily-at":
                t = self.time_edit.time()
                if t.hour() == 0 and t.minute() == 0:
                    self.time_edit.setTime(QTime(8, 30))
            elif mode == "cron":
                if str(self.cron_hour.currentData() or "*") == "*":
                    hidx = self.cron_hour.findData("8")
                    if hidx >= 0:
                        self.cron_hour.setCurrentIndex(hidx)
                if str(self.cron_min.currentData() or "0") == "0":
                    midx = self.cron_min.findData("30")
                    if midx >= 0:
                        self.cron_min.setCurrentIndex(midx)
                if str(self.cron_dow.currentData() or "*") == "*":
                    didx = self.cron_dow.findData("1")
                    if didx >= 0:
                        self.cron_dow.setCurrentIndex(didx)
        self._sync_visibility()

    def _sync_visibility(self) -> None:
        mode = str(self.mode.currentData() or "simple")
        self.preset.setVisible(mode == "simple")
        self.time_row.setVisible(mode in ("daily-at", "weekly-at"))
        self.weekday.parentWidget().setVisible(mode == "weekly-at")
        self.cron_row.setVisible(mode == "cron")
        self.custom_edit.setVisible(mode == "advanced")
        self._update_preview()

    def _update_preview(self) -> None:
        from .schedule_freq import describe_schedule_human, system_local_tz_label

        cal = self.on_calendar()
        human = describe_schedule_human(cal)
        tz = system_local_tz_label()
        self.preview.setText(
            f"→ {human}\n"
            f"OnCalendar: {cal}\n"
            f"Uses local system time: {tz} (not UTC)"
        )

    def on_calendar(self) -> str:
        from .schedule_freq import cron_fields_to_on_calendar, normalize_on_calendar

        mode = str(self.mode.currentData() or "simple")
        if mode == "simple":
            return normalize_on_calendar(str(self.preset.currentData() or "daily"))
        if mode == "daily-at":
            t = self.time_edit.time()
            return normalize_on_calendar("daily-at", hour=t.hour(), minute=t.minute())
        if mode == "weekly-at":
            t = self.time_edit.time()
            return normalize_on_calendar(
                "weekly-at",
                hour=t.hour(),
                minute=t.minute(),
                weekday=str(self.weekday.currentData() or "Sun"),
            )
        if mode == "cron":
            return cron_fields_to_on_calendar(
                str(self.cron_min.currentData() or "0"),
                str(self.cron_hour.currentData() or "*"),
                str(self.cron_dom.currentData() or "*"),
                str(self.cron_month.currentData() or "*"),
                str(self.cron_dow.currentData() or "*"),
            )
        return normalize_on_calendar(self.custom_edit.text().strip() or "daily")


class TimezonePicker(QComboBox):
    def __init__(self, parent: QWidget | None = None, *, default: str = "Europe/Berlin") -> None:
        super().__init__(parent)
        from .schedule_freq import COMMON_TIMEZONES

        self.setEditable(False)
        for tz in COMMON_TIMEZONES:
            self.addItem(tz)
        if default:
            idx = self.findText(default)
            if idx >= 0:
                self.setCurrentIndex(idx)
            else:
                self.addItem(default)
                self.setCurrentIndex(self.count() - 1)


class TemplateConfigureDialog(QDialog):
    """Dynamic param form for an agent template (create or edit instance)."""

    def __init__(
        self,
        template_id: str,
        parent: QWidget | None = None,
        *,
        instance: Any | None = None,
        run_once_mode: bool = False,
        seed_params: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(parent)
        from .agent_templates import get_agent_template

        self._tmpl = get_agent_template(template_id)
        if self._tmpl is None:
            raise ValueError(f"Unknown template: {template_id}")
        self._instance = instance
        self._editing = instance is not None
        self._run_once_mode = bool(run_once_mode)
        if self._run_once_mode:
            title_verb = "Run once"
        elif self._editing:
            title_verb = "Edit"
        else:
            title_verb = "Configure"
        self.setWindowTitle(f"{title_verb} — {self._tmpl.title}")
        self.resize(640, 820)
        self._fields: dict[str, Any] = {}
        existing_params = dict(instance.params) if instance is not None else {}
        if seed_params:
            for k, v in seed_params.items():
                existing_params.setdefault(k, v)

        root = QVBoxLayout(self)
        desc = QLabel(self._tmpl.description)
        desc.setWordWrap(True)
        root.addWidget(desc)
        if self._run_once_mode:
            once_hint = QLabel(
                "Run once: fills params, saves a temporary instance, runs immediately. "
                "No recurring schedule is created."
            )
            once_hint.setWordWrap(True)
            once_hint.setStyleSheet("color: palette(placeholder-text);")
            root.addWidget(once_hint)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        form_host = QWidget()
        form = QFormLayout(form_host)
        scroll.setWidget(form_host)
        root.addWidget(scroll, stretch=1)

        # Provider / model (always available — not part of template schema)
        llm_box = QGroupBox("LLM for this instance")
        llm_form = QFormLayout(llm_box)
        self.provider_combo = QComboBox()
        self.provider_combo.addItem("(default / Chat selection)", "")
        try:
            from .providers import load_providers
            from .preferences import get_last_provider_id

            last = get_last_provider_id()
            for p in load_providers():
                self.provider_combo.addItem(f"{p.name}  ·  {p.endpoint}", p.id)
            want = (instance.provider_id if instance else None) or last or ""
            idx = self.provider_combo.findData(want)
            if idx >= 0:
                self.provider_combo.setCurrentIndex(idx)
        except Exception:
            pass
        llm_form.addRow("Provider", self.provider_combo)

        model_row = QHBoxLayout()
        self.model_combo = QComboBox()
        self.model_combo.setEditable(True)
        self.model_combo.setMinimumWidth(220)
        model_row.addWidget(self.model_combo, stretch=1)
        refresh_models = QPushButton("Refresh")
        refresh_models.clicked.connect(self._refresh_models)
        model_row.addWidget(refresh_models)
        llm_form.addRow("Model", model_row)
        llm_hint = QLabel(
            "Runs of this instance use this provider/model. "
            "Leave default to follow Chat’s current selection."
        )
        llm_hint.setWordWrap(True)
        llm_hint.setStyleSheet("color: palette(placeholder-text);")
        llm_form.addRow(llm_hint)
        form.addRow(llm_box)

        preset_model = (instance.model if instance else None) or existing_params.get("_model")
        if preset_model:
            self.model_combo.setEditText(str(preset_model))
        self.provider_combo.currentIndexChanged.connect(lambda _i: self._refresh_models())
        # Lazy model list
        from PySide6.QtCore import QTimer

        QTimer.singleShot(0, self._refresh_models)

        for p in self._tmpl.params:
            label = p.label + (" *" if p.required else "")
            value = existing_params.get(p.id, p.default)
            widget: QWidget
            if p.type == "enum":
                combo = QComboBox()
                for opt in p.options:
                    combo.addItem(opt, opt)
                if value is not None:
                    idx = combo.findData(str(value))
                    if idx >= 0:
                        combo.setCurrentIndex(idx)
                widget = combo
            elif p.type == "secretRef":
                combo = QComboBox()
                combo.setEditable(True)
                from .secrets import list_secrets

                for s in list_secrets():
                    combo.addItem(f"{s.name} ({s.label})", s.name)
                if value:
                    combo.setEditText(str(value))
                elif p.default:
                    combo.setEditText(str(p.default))
                widget = combo
            elif p.type == "workspaceList":
                listw = QListWidget()
                listw.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
                from .workspaces import list_workspaces

                selected = set()
                if isinstance(value, list):
                    selected = {str(x) for x in value}
                elif isinstance(value, str) and value.strip():
                    selected = {x.strip() for x in value.split(",") if x.strip()}
                for ws in list_workspaces():
                    item = QListWidgetItem(f"{ws.id} — {ws.path}")
                    item.setData(Qt.ItemDataRole.UserRole, ws.id)
                    listw.addItem(item)
                    if ws.id in selected:
                        item.setSelected(True)
                listw.setMinimumHeight(100)
                widget = listw
            elif p.type == "stringList":
                edit = QLineEdit()
                if isinstance(value, list):
                    edit.setText(", ".join(str(x) for x in value))
                elif value is not None:
                    edit.setText(str(value))
                edit.setPlaceholderText("comma-separated")
                widget = edit
            elif p.type == "cronOrInterval":
                widget = FrequencyPicker(default=str(value or p.default or "daily"))
            elif p.type == "timezone":
                widget = TimezonePicker(default=str(value or p.default or "Europe/Berlin"))
            else:
                edit = QLineEdit()
                if value is not None:
                    edit.setText(str(value))
                if p.description:
                    edit.setToolTip(p.description)
                widget = edit
            self._fields[p.id] = (p, widget)
            # Frequency picker is multi-row — full width, not squeezed into form field col.
            if p.type == "cronOrInterval":
                form.addRow(QLabel(label))
                form.addRow(widget)
            else:
                form.addRow(label, widget)

        self.schedule_cb = QCheckBox("Enable recurring schedule (from Check frequency)")
        if self._run_once_mode:
            self.schedule_cb.setChecked(False)
            self.schedule_cb.setEnabled(False)
            self.schedule_cb.setToolTip("Disabled for Run once — use Configure to schedule.")
        elif instance is not None:
            self.schedule_cb.setChecked(bool(instance.enabled_schedule))
        else:
            self.schedule_cb.setChecked(bool(self._tmpl.schedule_kind))
        root.addWidget(self.schedule_cb)

        root.addWidget(self._build_transparency_panel(), stretch=1)
        from PySide6.QtCore import QTimer

        QTimer.singleShot(0, self._initial_prompt_fill)

        buttons = QDialogButtonBox()
        self._run_after = False
        if self._run_once_mode:
            run_btn = buttons.addButton(
                "Run once", QDialogButtonBox.ButtonRole.AcceptRole
            )
            run_btn.clicked.connect(self._accept_run)
        else:
            ok_btn = buttons.addButton("OK", QDialogButtonBox.ButtonRole.AcceptRole)
            ok_btn.setToolTip(
                "Save instance; enable schedule if the checkbox above is on"
            )
            run_btn = buttons.addButton(
                "Run once", QDialogButtonBox.ButtonRole.ActionRole
            )
            run_btn.setToolTip(
                "Save without enabling a new schedule, then run immediately"
            )
            ok_btn.clicked.connect(self._accept_save)
            run_btn.clicked.connect(self._accept_run_once)
        cancel = buttons.addButton(QDialogButtonBox.StandardButton.Cancel)
        cancel.clicked.connect(self.reject)
        root.addWidget(buttons)

    def _refresh_models(self) -> None:
        from .auth import with_cached_credentials
        from .config import Settings
        from .llm import list_models
        from .providers import apply_provider_settings, get_provider

        current = self.model_combo.currentText().strip()
        self.model_combo.blockSignals(True)
        self.model_combo.clear()
        self.model_combo.addItem("(auto / server default)", "")
        try:
            settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
            pid = self.provider_combo.currentData()
            if pid:
                prov = get_provider(str(pid))
                if prov is not None:
                    settings = apply_provider_settings(settings, prov)
                    settings = with_cached_credentials(settings)
            for m in list_models(settings):
                mid = str(m.get("id") or "")
                if mid:
                    self.model_combo.addItem(mid, mid)
        except Exception:
            pass
        if current:
            idx = self.model_combo.findData(current)
            if idx >= 0:
                self.model_combo.setCurrentIndex(idx)
            else:
                self.model_combo.setEditText(current)
        self.model_combo.blockSignals(False)

    def _build_transparency_panel(self) -> QWidget:
        """OpenHands-style: show + edit agent prompt; catalog skill/goal read-only."""
        from .agent_templates import load_skill_text

        box = QGroupBox("What will run (transparent · editable)")
        lay = QVBoxLayout(box)
        lay.setContentsMargins(8, 8, 8, 8)
        lay.setSpacing(4)

        t = self._tmpl
        mcp = ", ".join(t.mcp) if t.mcp else "(none)"
        secrets = ", ".join(t.requires_secrets) if t.requires_secrets else "(none)"
        meta = QLabel(
            f"<b>Profile</b> {t.profile} · <b>MCP</b> {mcp} · "
            f"<b>Secrets</b> {secrets} · <b>dryRun</b> {t.dry_run} · "
            f"<b>maxSteps</b> {t.max_steps or '—'} · "
            f"<b>harness</b> {t.harness or 'auto'} · "
            f"<b>skill</b> <code>{t.skill or '(inline goal only)'}</code>"
        )
        meta.setWordWrap(True)
        meta.setTextFormat(Qt.TextFormat.RichText)
        lay.addWidget(meta)

        hint = QLabel(
            "<b>Rendered prompt</b> is what the agent gets — edit freely. "
            "Catalog <b>Goal</b> / <b>Skill</b> stay read-only (packaged SSOT). "
            "Run once: edits apply to this run only unless you save the override. "
            "OK + checkbox: persist override on this instance (not the catalog)."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")
        lay.addWidget(hint)

        tabs = QTabWidget()
        self._prompt_preview = QTextEdit()
        self._prompt_preview.setReadOnly(False)
        self._prompt_preview.setPlaceholderText("Agent prompt (editable)…")
        self._prompt_preview.setAcceptRichText(False)
        tabs.addTab(self._prompt_preview, "Rendered prompt ✎")

        self._goal_view = QTextEdit()
        self._goal_view.setReadOnly(True)
        goal_raw = (t.goal_template or "").replace("\\n", "\n")
        self._goal_view.setPlainText(goal_raw or "(no goalTemplate)")
        tabs.addTab(self._goal_view, "Goal template")

        self._skill_view = QTextEdit()
        self._skill_view.setReadOnly(True)
        skill_text = load_skill_text(t.skill)
        if skill_text.strip():
            self._skill_view.setPlainText(skill_text)
        elif t.skill:
            self._skill_view.setPlainText(
                f"(skill file not found: {t.skill})\n"
                "Packaged under prompts/ or NCC_PROMPTS_ROOT."
            )
        else:
            self._skill_view.setPlainText("(no skill file — goal template only)")
        tabs.addTab(self._skill_view, "Skill script")
        lay.addWidget(tabs, stretch=1)

        self._save_prompt_cb = QCheckBox(
            "Save edited prompt on this instance (keep for later runs / Cron)"
        )
        self._save_prompt_cb.setChecked(
            bool(self._instance and getattr(self._instance, "prompt_override", None))
        )
        if self._run_once_mode:
            self._save_prompt_cb.setToolTip(
                "Off = this Run once only. On = also store override on the saved instance."
            )
        lay.addWidget(self._save_prompt_cb)

        row = QHBoxLayout()
        refresh = QPushButton("Reset to catalog render")
        refresh.setToolTip(
            "Re-build from goal template + skill + current params (discards edits)"
        )
        refresh.clicked.connect(self._refresh_prompt_preview)
        row.addWidget(refresh)
        row.addStretch()
        lay.addLayout(row)
        box.setMinimumHeight(240)
        self._catalog_prompt_baseline = ""
        return box

    def _refresh_prompt_preview(self) -> None:
        from .agent_templates import render_goal

        try:
            params = self._collect_params()
            text = render_goal(self._tmpl, params)
        except Exception as exc:  # noqa: BLE001
            text = f"(preview error: {exc})"
        self._catalog_prompt_baseline = text
        self._prompt_preview.setPlainText(text)

    def _initial_prompt_fill(self) -> None:
        """Prefer saved instance override; else catalog render."""
        saved = ""
        if self._instance is not None:
            saved = (getattr(self._instance, "prompt_override", None) or "").strip()
        if saved:
            self._prompt_preview.setPlainText(saved)
            try:
                from .agent_templates import render_goal

                self._catalog_prompt_baseline = render_goal(
                    self._tmpl, self._collect_params()
                )
            except Exception:
                self._catalog_prompt_baseline = ""
            return
        self._refresh_prompt_preview()

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
        self.schedule_cb.setChecked(False)
        self.accept()

    def _accept_run_once(self) -> None:
        """From Configure: run immediately without turning schedule on."""
        self._run_after = True
        # Keep user's schedule checkbox if editing an already-scheduled instance,
        # but never force-enable schedule just because they clicked Run once.
        if not self._editing:
            self.schedule_cb.setChecked(False)
        self.accept()

    def result_payload(self) -> dict[str, Any]:
        mid = self.model_combo.currentData()
        model = mid if mid else self.model_combo.currentText().strip()
        if model in ("", "(auto / server default)"):
            model = ""
        enable_sched = bool(self.schedule_cb.isChecked()) and not self._run_once_mode
        if self._run_after and self._run_once_mode:
            enable_sched = False
        # Editor text is the prompt for this action (ephemeral unless save checkbox).
        run_prompt = self._prompt_preview.toPlainText().strip() or None
        return {
            "params": self._collect_params(),
            "enable_schedule": enable_sched,
            "run_after": self._run_after,
            "provider_id": self.provider_combo.currentData() or "",
            "model": model,
            "instance_id": self._instance.id if self._instance else None,
            "update_existing": self._editing,
            "prompt_override": run_prompt,
            "save_prompt_override": bool(self._save_prompt_cb.isChecked()),
        }


class _TemplateCard(QFrame):
    configure = Signal(str)
    run_once = Signal(str)

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
        run = QPushButton("Run once")
        run.setToolTip("Fill params and run immediately (no schedule)")
        run.clicked.connect(lambda: self.run_once.emit(tmpl.id))
        head.addWidget(run)
        plus = QPushButton("⚙")
        plus.setFixedWidth(36)
        plus.setToolTip("Configure / schedule")
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

    def __init__(
        self,
        instance_id: str,
        parent: QWidget | None = None,
        *,
        prompt_override: str | None = None,
    ) -> None:
        super().__init__(parent)
        self._instance_id = instance_id
        self._prompt_override = prompt_override

    def run(self) -> None:
        try:
            from .agent_templates import run_instance

            summary = "finished"
            for ev in run_instance(
                self._instance_id, prompt_override=self._prompt_override
            ):
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
            "Workflows: dialog shows <b>prompt</b> (editable). "
            "Run once = this run; checkbox = save override on instance. "
            "Catalog skill/goal stay packaged. Briefing = <code>workspace-brief</code>. "
            "Definitions: module <code>doc/surfaces.md</code>."
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
        edit_btn = QPushButton("Edit…")
        edit_btn.clicked.connect(self._edit_selected)
        irow.addWidget(edit_btn)
        run_btn = QPushButton("Run once")
        run_btn.setToolTip("Run the selected saved instance once (no schedule change)")
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
        self.instance_list.itemDoubleClicked.connect(lambda _i: self._edit_selected())
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
                card.run_once.connect(self._run_once_configure)
                self._host_layout.addWidget(card)

        section("Workflows", catalog)
        section("Beta / experimental", beta)
        self._host_layout.addStretch()

        self.instance_list.clear()
        for inst in list_instances():
            llm = ""
            if inst.provider_id or inst.model:
                llm = f"  ·  {inst.provider_id or 'default'}/{inst.model or 'auto'}"
            ov = "  ·  prompt✎" if inst.prompt_override else ""
            item = QListWidgetItem(
                f"{inst.title}  ·  {inst.template_id}  ·  {inst.id}{llm}{ov}"
            )
            item.setData(Qt.ItemDataRole.UserRole, inst.id)
            self.instance_list.addItem(item)

    def _save_from_dialog(self, template_id: str, payload: dict[str, Any]) -> str | None:
        from .agent_templates import instantiate

        result = instantiate(
            template_id,
            payload["params"],
            instance_id=payload.get("instance_id"),
            enable_schedule=bool(payload["enable_schedule"]),
            provider_id=str(payload.get("provider_id") or ""),
            model=str(payload.get("model") or ""),
            update_existing=bool(payload.get("update_existing")),
            prompt_override=payload.get("prompt_override"),
            save_prompt_override=bool(payload.get("save_prompt_override")),
        )
        if not result.get("ok"):
            QMessageBox.warning(self, "Templates", result.get("error") or "Failed")
            return None
        llm = result["instance"]
        ov = "yes" if llm.get("promptOverride") else "catalog"
        QMessageBox.information(
            self,
            "Templates",
            f"Saved instance {llm.get('id')}\n"
            f"Provider: {llm.get('providerId') or '(default)'}  "
            f"Model: {llm.get('model') or '(auto)'}\n"
            f"Prompt override: {ov}\n"
            f"Playbook: {result.get('playbook')}\n"
            f"Schedule: {result.get('schedule') or '(none)'}",
        )
        self.reload()
        return str(llm.get("id") or "")

    def _configure(self, template_id: str) -> None:
        try:
            dlg = TemplateConfigureDialog(template_id, self)
        except ValueError as exc:
            QMessageBox.warning(self, "Templates", str(exc))
            return
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        payload = dlg.result_payload()
        iid = self._save_from_dialog(template_id, payload)
        if iid and payload.get("run_after"):
            self._run_instance(iid, prompt_override=payload.get("prompt_override"))

    def _run_once_configure(self, template_id: str) -> None:
        try:
            dlg = TemplateConfigureDialog(template_id, self, run_once_mode=True)
        except ValueError as exc:
            QMessageBox.warning(self, "Templates", str(exc))
            return
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        payload = dlg.result_payload()
        payload["enable_schedule"] = False
        payload["run_after"] = True
        iid = self._save_from_dialog(template_id, payload)
        if iid:
            self._run_instance(iid, prompt_override=payload.get("prompt_override"))

    def _edit_selected(self) -> None:
        from .agent_templates import get_instance

        item = self.instance_list.currentItem()
        if not item:
            QMessageBox.information(self, "Templates", "Select an instance to edit.")
            return
        inst = get_instance(str(item.data(Qt.ItemDataRole.UserRole)))
        if inst is None:
            QMessageBox.warning(self, "Templates", "Instance not found.")
            return
        try:
            dlg = TemplateConfigureDialog(inst.template_id, self, instance=inst)
        except ValueError as exc:
            QMessageBox.warning(self, "Templates", str(exc))
            return
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        payload = dlg.result_payload()
        iid = self._save_from_dialog(inst.template_id, payload)
        if iid and payload.get("run_after"):
            self._run_instance(iid, prompt_override=payload.get("prompt_override"))

    def _run_selected(self) -> None:
        item = self.instance_list.currentItem()
        if not item:
            QMessageBox.information(self, "Templates", "Select an instance.")
            return
        self._run_instance(str(item.data(Qt.ItemDataRole.UserRole)))

    def _run_instance(
        self, instance_id: str, *, prompt_override: str | None = None
    ) -> None:
        if self._run_worker and self._run_worker.isRunning():
            QMessageBox.information(self, "Templates", "A run is already in progress.")
            return
        worker = _InstanceRunWorker(
            instance_id, self, prompt_override=prompt_override
        )
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
