"""Doomscroll plugin settings UI (Plugins tab — not core Settings)."""

from __future__ import annotations

import time

from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)


class DoomscrollSettingsWidget(QWidget):
    """Watch → When → On interrupt → Session (enum checkboxes only)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)

        focus_group = QGroupBox("Doomscroll prevention")
        focus_form = QFormLayout(focus_group)

        def _section(title: str) -> QLabel:
            lab = QLabel(title)
            lab.setStyleSheet("font-weight: 600; padding-top: 6px;")
            return lab

        self.doom_enable = QCheckBox("Enable this plugin")

        from ...preferences import (
            DOOMSCROLL_APP_CHOICES,
            DOOMSCROLL_SITE_TAG_META,
            DOOMSCROLL_SITE_TAGS,
        )

        self.doom_app_checks: dict[str, QCheckBox] = {}
        apps_box = QWidget()
        apps_lay = QHBoxLayout(apps_box)
        apps_lay.setContentsMargins(0, 0, 0, 0)
        app_labels = {
            "firefox": "Firefox",
            "chromium": "Chromium",
            "brave": "Brave",
            "librewolf": "LibreWolf",
            "browsers": "All browsers",
        }
        for app_id in DOOMSCROLL_APP_CHOICES:
            cb = QCheckBox(app_labels.get(app_id, app_id))
            self.doom_app_checks[app_id] = cb
            apps_lay.addWidget(cb)
        apps_lay.addStretch(1)

        self.doom_site_checks: dict[str, QCheckBox] = {}
        sites_box = QWidget()
        sites_lay = QVBoxLayout(sites_box)
        sites_lay.setContentsMargins(0, 0, 0, 0)
        row: QHBoxLayout | None = None
        for i, tag in enumerate(DOOMSCROLL_SITE_TAGS):
            if i % 3 == 0:
                row = QHBoxLayout()
                sites_lay.addLayout(row)
            meta = DOOMSCROLL_SITE_TAG_META.get(tag) or {}
            cb = QCheckBox(str(meta.get("label") or tag))
            cb.setToolTip(f"Match + block: {', '.join(meta.get('domains') or ())}")
            self.doom_site_checks[tag] = cb
            assert row is not None
            row.addWidget(cb)
        if row is not None:
            row.addStretch(1)

        self.doom_after = QSpinBox()
        self.doom_after.setRange(1, 240)
        self.doom_after.setSuffix(" min")
        self.doom_after.setToolTip(
            "TIME: while matching, streak accumulates. Interrupt at this many minutes."
        )
        self.doom_videos = QSpinBox()
        self.doom_videos.setRange(0, 50)
        self.doom_videos.setSpecialValueText("off")
        self.doom_videos.setToolTip(
            "CLIPS: each new MPRIS URL/title while matching +1. 0 = off. "
            "Whichever hits first (clips OR minutes) intervenes."
        )
        self.doom_match = QComboBox()
        self.doom_match.addItem("Browser + selected sites", "browser-sites")
        self.doom_match.addItem("Any time in listed apps", "listed-apps")
        self.doom_cool = QSpinBox()
        self.doom_cool.setRange(5, 240)
        self.doom_cool.setSuffix(" min")
        self.doom_cool.setToolTip("Minimum gap between interrupts.")

        self.doom_lockout = QSpinBox()
        self.doom_lockout.setRange(0, 240)
        self.doom_lockout.setSpecialValueText("off")
        self.doom_lockout.setSuffix(" min")
        self.doom_lockout.setToolTip(
            "After interrupt: nft sinkhole for domains from selected Sites "
            "(Shorts → youtube.com). 0 = no timed block."
        )
        self.doom_style = QComboBox()
        self.doom_style.addItem("Notify only", "nudge")
        self.doom_style.addItem("Companion pop-up", "companion")
        self.doom_style.addItem("Companion + agent nudge", "agent")
        self.doom_pause = QCheckBox("Pause media (MPRIS) on interrupt")
        self.doom_follow = QCheckBox("Jump to browser desktop before interrupt")
        self.doom_block = QCheckBox("Block input (fullscreen overlay until dismiss)")
        self.doom_chat = QCheckBox("Also paste message into Companion chat")
        self.doom_pause.setToolTip(
            "Stops playing media in the watched browser via MPRIS Pause."
        )
        self.doom_follow.setToolTip(
            "Switch to the browser's virtual desktop so the dialog appears over it."
        )
        self.doom_block.setToolTip(
            "Fullscreen always-on-top overlay — no clicks/scroll until dismiss."
        )
        self.doom_chat.setToolTip(
            "Off by default — interrupt is a dialog/overlay, not a chat bubble."
        )

        self.doom_session_status = QLabel("")
        self.doom_session_status.setStyleSheet("color: palette(placeholder-text);")
        self.doom_session_status.setWordWrap(True)

        try:
            from ...preferences import (
                get_doomscroll_after_min,
                get_doomscroll_apps,
                get_doomscroll_block_input,
                get_doomscroll_cooldown_min,
                get_doomscroll_enable,
                get_doomscroll_follow_target,
                get_doomscroll_inject_chat,
                get_doomscroll_lockout_min,
                get_doomscroll_match_mode,
                get_doomscroll_max_videos,
                get_doomscroll_pause_media,
                get_doomscroll_site_tags,
                get_doomscroll_style,
            )

            self.doom_enable.setChecked(get_doomscroll_enable())
            self.doom_after.setValue(get_doomscroll_after_min())
            self.doom_videos.setValue(get_doomscroll_max_videos())
            self.doom_cool.setValue(get_doomscroll_cooldown_min())
            self.doom_lockout.setValue(get_doomscroll_lockout_min())
            selected_apps = set(get_doomscroll_apps())
            for app_id, cb in self.doom_app_checks.items():
                cb.setChecked(app_id in selected_apps)
            selected_tags = set(get_doomscroll_site_tags())
            for tag, cb in self.doom_site_checks.items():
                cb.setChecked(tag in selected_tags)
            self.doom_pause.setChecked(get_doomscroll_pause_media())
            self.doom_follow.setChecked(get_doomscroll_follow_target())
            self.doom_block.setChecked(get_doomscroll_block_input())
            self.doom_chat.setChecked(get_doomscroll_inject_chat())
            for combo, val in (
                (self.doom_style, get_doomscroll_style()),
                (self.doom_match, get_doomscroll_match_mode()),
            ):
                i = combo.findData(val)
                if i >= 0:
                    combo.setCurrentIndex(i)
        except Exception:
            self.doom_enable.setChecked(False)
            self.doom_after.setValue(20)
            self.doom_videos.setValue(0)
            self.doom_cool.setValue(30)
            self.doom_lockout.setValue(0)
            if "firefox" in self.doom_app_checks:
                self.doom_app_checks["firefox"].setChecked(True)
            if "youtube-shorts" in self.doom_site_checks:
                self.doom_site_checks["youtube-shorts"].setChecked(True)
            self.doom_pause.setChecked(True)
            self.doom_follow.setChecked(True)
            self.doom_block.setChecked(False)
            self.doom_chat.setChecked(False)
            i = self.doom_style.findData("companion")
            if i >= 0:
                self.doom_style.setCurrentIndex(i)
            i = self.doom_match.findData("browser-sites")
            if i >= 0:
                self.doom_match.setCurrentIndex(i)

        def _save_doom_enable(checked: bool) -> None:
            from ...preferences import set_doomscroll_enable

            set_doomscroll_enable(checked)

        def _save_doom_after(v: int) -> None:
            from ...preferences import set_doomscroll_after_min

            set_doomscroll_after_min(v)

        def _save_doom_videos(v: int) -> None:
            from ...preferences import set_doomscroll_max_videos

            set_doomscroll_max_videos(v)

        def _save_doom_cool(v: int) -> None:
            from ...preferences import set_doomscroll_cooldown_min

            set_doomscroll_cooldown_min(v)

        def _save_doom_lockout(v: int) -> None:
            from ...preferences import set_doomscroll_lockout_min

            set_doomscroll_lockout_min(v)

        def _save_doom_style(_i: int = 0) -> None:
            from ...preferences import set_doomscroll_style
            from ...watchdogs import ensure_doomscroll_watchdog

            style = str(self.doom_style.currentData() or "companion")
            set_doomscroll_style(style)
            if style == "agent":
                ensure_doomscroll_watchdog(enable_for_agent=True)

        def _save_doom_apps(_checked: bool = False) -> None:
            from ...preferences import set_doomscroll_apps

            selected = [k for k, cb in self.doom_app_checks.items() if cb.isChecked()]
            set_doomscroll_apps(selected)

        def _save_doom_sites(_checked: bool = False) -> None:
            from ...preferences import set_doomscroll_site_tags

            selected = [k for k, cb in self.doom_site_checks.items() if cb.isChecked()]
            set_doomscroll_site_tags(selected)

        def _save_doom_match(_i: int = 0) -> None:
            from ...preferences import set_doomscroll_match_mode

            set_doomscroll_match_mode(
                str(self.doom_match.currentData() or "browser-sites")
            )

        def _save_doom_pause(checked: bool) -> None:
            from ...preferences import set_doomscroll_pause_media

            set_doomscroll_pause_media(checked)

        def _save_doom_follow(checked: bool) -> None:
            from ...preferences import set_doomscroll_follow_target

            set_doomscroll_follow_target(checked)

        def _save_doom_block(checked: bool) -> None:
            from ...preferences import set_doomscroll_block_input

            set_doomscroll_block_input(checked)

        def _save_doom_chat(checked: bool) -> None:
            from ...preferences import set_doomscroll_inject_chat

            set_doomscroll_inject_chat(checked)

        self.doom_enable.toggled.connect(_save_doom_enable)
        self.doom_after.valueChanged.connect(_save_doom_after)
        self.doom_videos.valueChanged.connect(_save_doom_videos)
        self.doom_cool.valueChanged.connect(_save_doom_cool)
        self.doom_lockout.valueChanged.connect(_save_doom_lockout)
        self.doom_style.currentIndexChanged.connect(_save_doom_style)
        self.doom_match.currentIndexChanged.connect(_save_doom_match)
        for cb in self.doom_app_checks.values():
            cb.toggled.connect(_save_doom_apps)
        for cb in self.doom_site_checks.values():
            cb.toggled.connect(_save_doom_sites)
        self.doom_pause.toggled.connect(_save_doom_pause)
        self.doom_follow.toggled.connect(_save_doom_follow)
        self.doom_block.toggled.connect(_save_doom_block)
        self.doom_chat.toggled.connect(_save_doom_chat)

        snooze_btn = QPushButton("Snooze 30 min")
        snooze_btn.clicked.connect(self._doomscroll_snooze)
        clear_snooze_btn = QPushButton("Clear snooze")
        clear_snooze_btn.clicked.connect(self._doomscroll_clear_snooze)
        refresh_btn = QPushButton("Refresh status")
        refresh_btn.clicked.connect(self._doomscroll_refresh_status)
        snooze_row = QWidget()
        snooze_lay = QHBoxLayout(snooze_row)
        snooze_lay.setContentsMargins(0, 0, 0, 0)
        snooze_lay.addWidget(snooze_btn)
        snooze_lay.addWidget(clear_snooze_btn)
        snooze_lay.addWidget(refresh_btn)
        snooze_lay.addStretch(1)

        focus_form.addRow(self.doom_enable)
        focus_form.addRow(_section("Watch"))
        focus_form.addRow("Apps", apps_box)
        focus_form.addRow("Sites", sites_box)
        focus_form.addRow(_section("When to interrupt"))
        focus_form.addRow("After (time)", self.doom_after)
        focus_form.addRow("Or after N clips", self.doom_videos)
        focus_form.addRow("Match", self.doom_match)
        focus_form.addRow("Cooldown", self.doom_cool)
        focus_form.addRow(_section("On interrupt"))
        focus_form.addRow("Net block", self.doom_lockout)
        focus_form.addRow("Style", self.doom_style)
        focus_form.addRow(self.doom_pause)
        focus_form.addRow(self.doom_follow)
        focus_form.addRow(self.doom_block)
        focus_form.addRow(self.doom_chat)
        focus_form.addRow(_section("Session"))
        focus_form.addRow(snooze_row)
        focus_form.addRow(self.doom_session_status)

        focus_hint = QLabel(
            "Feature plugin (Plugins tab) — not MCP / templates / watchdogs. "
            "Defaults: off · Firefox · YouTube Shorts · 20 min · clips off · "
            "cooldown 30 · net block off · companion · pause+jump on. "
            "Sites drive match + block domains (no freitext)."
        )
        focus_hint.setWordWrap(True)
        focus_hint.setStyleSheet("color: palette(placeholder-text);")
        focus_form.addRow(focus_hint)
        root.addWidget(focus_group)
        self._doomscroll_refresh_status()

    def _doomscroll_snooze(self) -> None:
        try:
            from ...focus import snooze

            snooze(30)
            self._doomscroll_refresh_status()
            QMessageBox.information(self, "Doomscroll", "Snoozed for 30 minutes.")
        except Exception as exc:
            QMessageBox.warning(self, "Doomscroll", str(exc))

    def _doomscroll_clear_snooze(self) -> None:
        try:
            from ...focus import clear_snooze

            clear_snooze()
            self._doomscroll_refresh_status()
            QMessageBox.information(self, "Doomscroll", "Snooze cleared.")
        except Exception as exc:
            QMessageBox.warning(self, "Doomscroll", str(exc))

    def _doomscroll_refresh_status(self) -> None:
        try:
            from ...focus import status
            from ...preferences import (
                get_doomscroll_block_domains,
                get_doomscroll_site_tags,
            )

            st = status()
            parts: list[str] = []
            snooze_until = float(st.get("snooze_until") or 0.0)
            left = int(snooze_until - time.time())
            if left > 0:
                parts.append(f"Snoozed ~{left // 60}m {left % 60}s left")
            else:
                parts.append("Snooze: off")
            lock_left = int(st.get("lockout_remaining_sec") or 0)
            if lock_left > 0:
                parts.append(f"Net lockout ~{lock_left // 60}m left")
            tags = get_doomscroll_site_tags()
            domains = get_doomscroll_block_domains()
            parts.append(f"Sites: {', '.join(tags) or '—'}")
            parts.append(
                f"Block domains: {', '.join(domains[:4])}"
                + ("…" if len(domains) > 4 else "")
            )
            if st.get("matching_now"):
                parts.append("matching now")
            self.doom_session_status.setText(" · ".join(parts))
        except Exception as exc:
            self.doom_session_status.setText(f"Status unavailable: {exc}")
