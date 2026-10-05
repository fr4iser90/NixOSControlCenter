"""Morning Brief plugin settings (Plugins tab)."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class MorningBriefSettingsWidget(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)

        box = QGroupBox("Morning Brief")
        form = QFormLayout(box)

        self.enable = QCheckBox("Enable Morning Brief")
        self.provider = QComboBox()
        self.provider.addItem("GitHub", "github")

        from ...preferences import (
            MORNING_BRIEF_SOURCES,
            get_daily_digest_enable,
            get_daily_digest_on_calendar,
            get_morning_brief_auto_refresh,
            get_morning_brief_sources,
            get_workflow_providers,
        )
        from ...templates_ui import FrequencyPicker

        self.source_checks: dict[str, QCheckBox] = {}
        src_box = QWidget()
        src_lay = QHBoxLayout(src_box)
        src_lay.setContentsMargins(0, 0, 0, 0)
        labels = {
            "github-prs": "PRs",
            "github-issues": "Issues",
            "tasks": "Tasks",
            "roadmap": "Roadmap",
        }
        for sid in MORNING_BRIEF_SOURCES:
            cb = QCheckBox(labels.get(sid, sid))
            self.source_checks[sid] = cb
            src_lay.addWidget(cb)
        src_lay.addStretch(1)

        self.auto_refresh = QCheckBox("Refresh GitHub digest before brief")
        cal_default = "*-*-* 08:30:00"
        try:
            self.enable.setChecked(get_daily_digest_enable())
            self.auto_refresh.setChecked(get_morning_brief_auto_refresh())
            cal_default = get_daily_digest_on_calendar()
            selected = set(get_morning_brief_sources())
            for sid, cb in self.source_checks.items():
                cb.setChecked(sid in selected)
            provs = get_workflow_providers()
            if provs:
                pi = self.provider.findData(provs[0])
                if pi >= 0:
                    self.provider.setCurrentIndex(pi)
        except Exception:
            self.enable.setChecked(True)
            self.auto_refresh.setChecked(True)
            for sid, cb in self.source_checks.items():
                cb.setChecked(True)

        self.cal = FrequencyPicker(default=cal_default)

        def _save_enable(checked: bool) -> None:
            from ...preferences import set_daily_digest_enable

            set_daily_digest_enable(checked)

        def _save_cal() -> None:
            from ...preferences import set_daily_digest_on_calendar

            try:
                set_daily_digest_on_calendar(self.cal.on_calendar())
            except Exception:
                pass

        def _save_provider(_i: int = 0) -> None:
            from ...preferences import set_workflow_providers

            set_workflow_providers([str(self.provider.currentData() or "github")])

        def _save_sources(_c: bool = False) -> None:
            from ...preferences import set_morning_brief_sources

            set_morning_brief_sources(
                [k for k, cb in self.source_checks.items() if cb.isChecked()]
            )

        def _save_refresh(checked: bool) -> None:
            from ...preferences import set_morning_brief_auto_refresh

            set_morning_brief_auto_refresh(checked)

        self.enable.toggled.connect(_save_enable)
        self.provider.currentIndexChanged.connect(_save_provider)
        self.auto_refresh.toggled.connect(_save_refresh)
        for cb in self.source_checks.values():
            cb.toggled.connect(_save_sources)
        for child in self.cal.findChildren(QWidget):
            if hasattr(child, "currentIndexChanged"):
                child.currentIndexChanged.connect(lambda *_: _save_cal())
            if hasattr(child, "timeChanged"):
                child.timeChanged.connect(lambda *_: _save_cal())
            if hasattr(child, "valueChanged"):
                child.valueChanged.connect(lambda *_: _save_cal())

        preview_btn = QPushButton("Preview brief now")
        preview_btn.clicked.connect(self._preview)
        fire_btn = QPushButton("Fire brief now (mark today done)")
        fire_btn.clicked.connect(self._fire_now)

        form.addRow(self.enable)
        form.addRow("Sources", src_box)
        form.addRow("Provider", self.provider)
        form.addRow("Schedule", self.cal)
        form.addRow(self.auto_refresh)
        row = QWidget()
        row_lay = QHBoxLayout(row)
        row_lay.setContentsMargins(0, 0, 0, 0)
        row_lay.addWidget(preview_btn)
        row_lay.addWidget(fire_btn)
        row_lay.addStretch(1)
        form.addRow(row)

        hint = QLabel(
            "Fires once per day after the schedule time (Companion/tray tick). "
            "Edit tasks/roadmap on the Workflows tab. Not MCP / templates / watchdogs."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")
        form.addRow(hint)
        root.addWidget(box)

        # Alias used by PluginsPage enable sync (also checks .enable)
        self.doom_enable = self.enable

    def _preview(self) -> None:
        try:
            from .logic import build_brief_lines

            lines = build_brief_lines()
            QMessageBox.information(
                self,
                "Morning Brief preview",
                "\n".join(lines) if lines else "(empty)",
            )
        except Exception as exc:
            QMessageBox.warning(self, "Morning Brief", str(exc))

    def _fire_now(self) -> None:
        try:
            from datetime import datetime

            from ...preferences import (
                get_morning_brief_auto_refresh,
                set_morning_brief_last_fired,
            )
            from .logic import build_brief_lines

            if get_morning_brief_auto_refresh():
                try:
                    from ...workflows import refresh_github_digest

                    refresh_github_digest()
                except Exception:
                    pass
            lines = build_brief_lines()
            today = datetime.now().astimezone().strftime("%Y-%m-%d")
            set_morning_brief_last_fired(today)
            QMessageBox.information(
                self,
                "Morning Brief",
                "\n".join(lines) if lines else "(empty)",
            )
        except Exception as exc:
            QMessageBox.warning(self, "Morning Brief", str(exc))
