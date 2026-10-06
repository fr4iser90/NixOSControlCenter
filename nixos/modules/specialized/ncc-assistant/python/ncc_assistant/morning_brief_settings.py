"""Legacy brief prefs UI (sources / preview). Prefer template workspace-brief + Cron."""

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
    """Legacy source toggles for digest lines. Not a FeaturePlugin."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)

        box = QGroupBox("Workspace brief (legacy prefs)")
        form = QFormLayout(box)

        self.enable = QCheckBox(
            "Enable scheduled digest prefs (prefer Cron + workspace-brief)"
        )
        self.provider = QComboBox()
        self.provider.addItem("GitHub", "github")

        from .preferences import (
            MORNING_BRIEF_SOURCES,
            get_daily_digest_enable,
            get_daily_digest_on_calendar,
            get_morning_brief_auto_refresh,
            get_morning_brief_sources,
            get_workflow_providers,
        )
        from .templates_ui import FrequencyPicker

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

        self.auto_refresh = QCheckBox("Refresh GitHub digest before brief (required)")
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
            from .preferences import set_daily_digest_enable

            set_daily_digest_enable(checked)

        def _save_cal() -> None:
            from .preferences import set_daily_digest_on_calendar

            try:
                set_daily_digest_on_calendar(self.cal.on_calendar())
            except Exception:
                pass

        def _save_provider(_i: int = 0) -> None:
            from .preferences import set_workflow_providers

            set_workflow_providers([str(self.provider.currentData() or "github")])

        def _save_sources(_c: bool = False) -> None:
            from .preferences import set_morning_brief_sources

            set_morning_brief_sources(
                [sid for sid, cb in self.source_checks.items() if cb.isChecked()]
            )

        def _save_auto(checked: bool) -> None:
            from .preferences import set_morning_brief_auto_refresh

            set_morning_brief_auto_refresh(checked)

        self.enable.toggled.connect(_save_enable)
        self.provider.currentIndexChanged.connect(_save_provider)
        self.auto_refresh.toggled.connect(_save_auto)
        for cb in self.source_checks.values():
            cb.toggled.connect(_save_sources)
        try:
            self.cal.changed.connect(_save_cal)
        except Exception:
            pass

        hint = QLabel(
            "Uses the ★ active workspace only. "
            "Brief popup only after a successful digest with real items "
            "(or a clear setup error). Empty = no popup."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")

        form.addRow(self.enable)
        form.addRow("Provider", self.provider)
        form.addRow("Sources", src_box)
        form.addRow(self.auto_refresh)
        form.addRow("When", self.cal)
        form.addRow(hint)

        btns = QHBoxLayout()
        preview = QPushButton("Preview")
        preview.clicked.connect(self._preview)
        fire = QPushButton("Refresh + brief now")
        fire.clicked.connect(self._fire_now)
        btns.addWidget(preview)
        btns.addWidget(fire)
        btns.addStretch(1)
        form.addRow(btns)

        root.addWidget(box)

    def _preview(self) -> None:
        try:
            from .morning_brief import build_brief_lines

            lines = build_brief_lines()
            QMessageBox.information(
                self,
                "Workspace brief preview",
                "\n".join(lines) if lines else "(no open PRs/issues/tasks — no popup)",
            )
        except Exception as exc:
            QMessageBox.warning(self, "Workspace brief", str(exc))

    def _fire_now(self) -> None:
        try:
            from datetime import datetime

            from .morning_brief import build_brief_lines
            from .preferences import (
                get_active_workspace_id,
                set_morning_brief_last_fired,
            )
            from .workflows import refresh_github_digest

            wid = get_active_workspace_id()
            if not wid:
                QMessageBox.warning(
                    self,
                    "Workspace brief",
                    "Set an active workspace (★) first.",
                )
                return
            result = refresh_github_digest(workspace_id=wid)
            if not result.get("ok", True):
                QMessageBox.warning(
                    self,
                    "Workspace brief",
                    str(result.get("hint") or result.get("error") or "Refresh failed"),
                )
                return
            lines = build_brief_lines()
            today = datetime.now().astimezone().strftime("%Y-%m-%d")
            set_morning_brief_last_fired(today)
            QMessageBox.information(
                self,
                "Workspace brief",
                "\n".join(lines)
                if lines
                else "(digest ok — nothing open; no automatic popup)",
            )
        except Exception as exc:
            QMessageBox.warning(self, "Workspace brief", str(exc))
