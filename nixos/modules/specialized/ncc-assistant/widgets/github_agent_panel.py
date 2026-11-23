"""GitHub Agent companion panel — zoned UX (actions / strip / board).

Callers: ``companion.window`` embeds ``GithubAgentPanel`` on PANEL_GITHUB.
Signals: ``actionRequested`` (analyze/act/tick/pause/resume/campaign/rights/facts),
``projectSelected`` (workspace id). Filter chips write ``githubAgent`` prefs.
"""

from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QButtonGroup,
    QFrame,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)


WAVE_FILTERS: tuple[tuple[str, str], ...] = (
    ("all", "All"),
    ("legal", "Legal"),
    ("agents-md", "AGENTS"),
    ("skills", "Skills"),
)


class GithubAgentPanel(QWidget):
    """Three zones: action toolbar, campaign strip, workspace board."""

    actionRequested = Signal(str)
    projectSelected = Signal(str)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._active_workspace_id = ""
        self._refreshing_filters = False

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # Zone 1 — actions
        actions = QHBoxLayout()
        actions.setSpacing(6)
        self.btn_start = QPushButton("Start agent")
        self.btn_start.setToolTip("Analyze fleet + open chat narration")
        self.btn_start.setDefault(True)
        self.btn_start.clicked.connect(lambda: self.actionRequested.emit("analyze"))
        actions.addWidget(self.btn_start)

        self.btn_act = QPushButton("Act wave")
        self.btn_act.setToolTip("Arm campaign + apply docs stubs (policy)")
        self.btn_act.clicked.connect(lambda: self.actionRequested.emit("act"))
        actions.addWidget(self.btn_act)

        # Caller: companion.window._on_github_panel_action("site_check")
        self.btn_site = QPushButton("Site-check wave")
        self.btn_site.setToolTip(
            "Static TLS/header/SEO/external check for workspace domains"
        )
        self.btn_site.clicked.connect(lambda: self.actionRequested.emit("site_check"))
        actions.addWidget(self.btn_site)

        self.btn_tick = QPushButton("Tick once")
        self.btn_tick.setToolTip("Resume one campaign tick")
        self.btn_tick.clicked.connect(lambda: self.actionRequested.emit("tick"))
        actions.addWidget(self.btn_tick)

        self.btn_pause = QPushButton("Pause")
        self.btn_pause.setToolTip("Pause running campaign")
        self.btn_pause.setVisible(False)
        self.btn_pause.clicked.connect(lambda: self.actionRequested.emit("pause"))
        actions.addWidget(self.btn_pause)

        self.btn_resume = QPushButton("Resume")
        self.btn_resume.setToolTip("Resume paused campaign")
        self.btn_resume.setVisible(False)
        self.btn_resume.clicked.connect(lambda: self.actionRequested.emit("resume"))
        actions.addWidget(self.btn_resume)
        actions.addStretch(1)
        root.addLayout(actions)

        # Zone 2 — campaign strip + settings
        strip = QFrame()
        strip.setObjectName("nccGhaStrip")
        strip.setFrameShape(QFrame.Shape.StyledPanel)
        strip_l = QHBoxLayout(strip)
        strip_l.setContentsMargins(8, 6, 8, 6)
        strip_l.setSpacing(8)

        self.strip_status = QPushButton("Campaign · —")
        self.strip_status.setObjectName("nccMuted")
        self.strip_status.setFlat(True)
        self.strip_status.setStyleSheet("text-align: left;")
        self.strip_status.setCursor(Qt.CursorShape.PointingHandCursor)
        self.strip_status.setToolTip("Open campaign dashboard")
        self.strip_status.clicked.connect(lambda: self.actionRequested.emit("campaign"))
        strip_l.addWidget(self.strip_status, stretch=1)

        self.btn_campaign = QPushButton("Campaign…")
        self.btn_campaign.setFlat(True)
        self.btn_campaign.clicked.connect(lambda: self.actionRequested.emit("campaign"))
        strip_l.addWidget(self.btn_campaign)

        self.btn_rights = QPushButton("Rights…")
        self.btn_rights.setFlat(True)
        self.btn_rights.clicked.connect(lambda: self.actionRequested.emit("rights"))
        strip_l.addWidget(self.btn_rights)

        self.btn_facts = QPushButton("Facts…")
        self.btn_facts.setFlat(True)
        self.btn_facts.clicked.connect(lambda: self.actionRequested.emit("facts"))
        strip_l.addWidget(self.btn_facts)

        self.btn_domains = QPushButton("Domains…")
        self.btn_domains.setFlat(True)
        self.btn_domains.setToolTip("Attach public domains to workspaces")
        self.btn_domains.clicked.connect(lambda: self.actionRequested.emit("domains"))
        strip_l.addWidget(self.btn_domains)
        root.addWidget(strip)

        # Zone 3 — filters + board
        filt = QHBoxLayout()
        filt.setSpacing(4)
        filt_lab = QLabel("Filter")
        filt_lab.setObjectName("nccMuted")
        filt_lab.setToolTip("Applies to next Act wave, not the board list")
        filt.addWidget(filt_lab)

        self._filter_group = QButtonGroup(self)
        self._filter_group.setExclusive(True)
        self._filter_btns: dict[str, QPushButton] = {}
        for key, label in WAVE_FILTERS:
            b = QPushButton(label)
            b.setCheckable(True)
            b.setFlat(True)
            b.setProperty("waveFilter", key)
            self._filter_group.addButton(b)
            self._filter_btns[key] = b
            filt.addWidget(b)
        self._filter_group.buttonClicked.connect(self._on_wave_filter_clicked)

        self.btn_clean_only = QPushButton("Clean only")
        self.btn_clean_only.setCheckable(True)
        self.btn_clean_only.setFlat(True)
        self.btn_clean_only.setToolTip("Wave: clean worktrees only")
        self.btn_clean_only.toggled.connect(self._on_clean_only_toggled)
        filt.addWidget(self.btn_clean_only)
        filt.addStretch(1)
        root.addLayout(filt)

        self.board_header = QLabel("Workspaces")
        self.board_header.setStyleSheet("font-weight: 600;")
        root.addWidget(self.board_header)

        self.board = QListWidget()
        self.board.setFont(QFont("monospace"))
        self.board.setUniformItemSizes(True)
        self.board.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self.board.itemClicked.connect(self._on_board_click)
        self.board.itemActivated.connect(self._on_board_click)
        root.addWidget(self.board, stretch=1)

    def refresh(self, *, active_workspace_id: str | None = None) -> None:
        if active_workspace_id is not None:
            self._active_workspace_id = str(active_workspace_id or "")
        self._load_filters()
        self._load_campaign_strip()
        self._load_board()

    def refresh_live(self) -> None:
        """Cheap poll: campaign strip + Pause/Resume only (no board rebuild)."""
        self._load_campaign_strip()

    def _load_filters(self) -> None:
        from core.store.preferences import (
            get_github_agent_wave_clean_only,
            get_github_agent_wave_filter,
        )

        self._refreshing_filters = True
        try:
            wf = get_github_agent_wave_filter()
            btn = self._filter_btns.get(wf) or self._filter_btns["all"]
            btn.setChecked(True)
            self.btn_clean_only.setChecked(bool(get_github_agent_wave_clean_only()))
        finally:
            self._refreshing_filters = False

    def _on_wave_filter_clicked(self, button: QPushButton) -> None:
        if self._refreshing_filters:
            return
        from core.store.preferences import set_github_agent_wave_filter

        key = str(button.property("waveFilter") or "all")
        set_github_agent_wave_filter(key)
        self._load_campaign_strip()

    def _on_clean_only_toggled(self, checked: bool) -> None:
        if self._refreshing_filters:
            return
        from core.store.preferences import set_github_agent_wave_clean_only

        set_github_agent_wave_clean_only(bool(checked))
        self._load_campaign_strip()

    def _load_campaign_strip(self) -> None:
        try:
            from core.store.github_agent_campaign import load_github_agent_campaign
            from core.store.preferences import (
                get_github_agent_autopilot,
                get_github_agent_wave_clean_only,
                get_github_agent_wave_filter,
            )

            camp = load_github_agent_campaign()
            ap = get_github_agent_autopilot()
            qn = len(camp.get("queue") or [])
            st = str(camp.get("status") or "idle")
            stats = camp.get("stats") or {}
            wf = get_github_agent_wave_filter()
            clean = "clean-only" if get_github_agent_wave_clean_only() else "all-trees"
            self.strip_status.setText(
                f"Campaign · {st} · queue {qn} · "
                f"applied {stats.get('applied', 0)} · autopilot={ap} · "
                f"filter={wf}/{clean}"
            )
            self.btn_pause.setVisible(st == "running")
            self.btn_resume.setVisible(st == "paused")
        except Exception as exc:  # noqa: BLE001
            self.strip_status.setText(f"Campaign · error: {exc}")
            self.btn_pause.setVisible(False)
            self.btn_resume.setVisible(False)

    def _load_board(self) -> None:
        from core.workflows.github_agent_board import format_github_board_row

        self.board.clear()
        try:
            from core.store.github_agent_snapshot import load_github_agent_snapshot

            snap = load_github_agent_snapshot()
        except Exception as exc:  # noqa: BLE001
            self.board_header.setText("Workspaces")
            self.board.addItem(f"(error: {exc})")
            return
        if snap is None:
            self.board_header.setText("Workspaces · no snapshot")
            self.board.addItem("No snapshot — Start agent")
            return
        projects = [p for p in (snap.get("projects") or []) if isinstance(p, dict)]
        if not projects:
            self.board_header.setText("Workspaces · 0")
            self.board.addItem("(no projects in snapshot)")
            return

        dirty_n = 0
        for p in projects:
            flags = [str(x) for x in (p.get("driftFlags") or [])]
            if "dirty_worktree" in flags:
                dirty_n += 1
        self.board_header.setText(
            f"Workspaces · {len(projects)} · {dirty_n} dirty"
        )

        for p in projects:
            wid = str(p.get("workspaceId") or "")
            state = str(p.get("state") or "?")
            gaps = [g for g in (p.get("gaps") or []) if not g.get("present")]
            nxt = p.get("nextTask") or {}
            nxt_title = str(nxt.get("title") or "—")
            flags = [str(x) for x in (p.get("driftFlags") or [])]
            dirty = "dirty_worktree" in flags
            text = format_github_board_row(
                workspace_id=wid,
                state=state,
                gaps=len(gaps),
                next_title=nxt_title,
                dirty=dirty,
                active=bool(wid and wid == self._active_workspace_id),
            )
            row = QListWidgetItem(text)
            tip = str(p.get("path") or "")
            if p.get("github"):
                tip = f"{tip}\n{p.get('github')}"
            if dirty:
                tip = (
                    f"{tip}\nDirty worktree — commit or stash before Act "
                    "(dirty policy skips writes)."
                )
            row.setToolTip(tip or wid)
            row.setData(Qt.ItemDataRole.UserRole, wid)
            if dirty:
                row.setForeground(Qt.GlobalColor.darkYellow)
            self.board.addItem(row)

    def _on_board_click(self, item: QListWidgetItem | None) -> None:
        if item is None:
            return
        wid = item.data(Qt.ItemDataRole.UserRole)
        if wid:
            self.projectSelected.emit(str(wid))
