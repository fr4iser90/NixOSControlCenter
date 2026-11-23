"""GitHub Agent Companion dialogs: Rights page + Campaign dashboard.

Callers: ``companion.window._github_agent_rights_dialog``,
``_github_agent_campaign_dialog``, header chip via
``format_github_agent_header_chip``. No other Rights UI exists (old
QInputDialog chain in window.py is replaced). Reads/writes
``preferences.json`` ``githubAgent`` + campaign skip-forever keys.

User: "Rights als eine Seite … Campaign-Dashboard … Allowlist-Picker …
Wave-Filter … Status-Chip … Confirm vor erstem Act … Kein Doppel-Tray …"
"""

from __future__ import annotations

from typing import Any

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)


class GithubAgentRightsDialog(QDialog):
    """Single-page rights / autopilot / wave filters / workspace pickers."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("GitHub Agent — Rights & Autopilot")
        self.resize(560, 640)

        from core.store.preferences import get_github_agent_rights
        from core.store.workspaces import list_workspaces

        rights = get_github_agent_rights()
        root = QVBoxLayout(self)

        form = QFormLayout()
        self.allow_write = QCheckBox(
            "Allow docs stub writes (AGENTS / impressum / privacy / skills)"
        )
        self.allow_write.setChecked(bool(rights.get("allowWrite")))
        form.addRow(self.allow_write)

        self.confirm = QComboBox()
        for c in ("writes", "always", "never"):
            self.confirm.addItem(c, c)
        idx = self.confirm.findData(rights.get("confirm") or "writes")
        self.confirm.setCurrentIndex(max(0, idx))
        form.addRow("Confirm mode", self.confirm)

        self.autopilot = QComboBox()
        for c in ("off", "analyze", "act-safe"):
            self.autopilot.addItem(c, c)
        idx = self.autopilot.findData(rights.get("autopilot") or "off")
        self.autopilot.setCurrentIndex(max(0, idx))
        form.addRow("Autopilot (idle)", self.autopilot)

        self.dirty = QComboBox()
        for c in ("skip", "abort"):
            self.dirty.addItem(c, c)
        idx = self.dirty.findData(rights.get("dirtyPolicy") or "skip")
        self.dirty.setCurrentIndex(max(0, idx))
        form.addRow("Dirty worktree", self.dirty)

        self.max_tick = QSpinBox()
        self.max_tick.setRange(1, 20)
        self.max_tick.setValue(int(rights.get("maxPerTick") or 6))
        form.addRow("Max per tick", self.max_tick)

        self.include_arch = QCheckBox("Include archive-candidates when planning tasks")
        self.include_arch.setChecked(bool(rights.get("includeArchived")))
        form.addRow(self.include_arch)

        self.wave_filter = QComboBox()
        for key, label in (
            ("all", "All docs gaps"),
            ("legal", "Only impressum / privacy"),
            ("agents-md", "Only AGENTS.md"),
            ("skills", "Only skills"),
        ):
            self.wave_filter.addItem(label, key)
        idx = self.wave_filter.findData(rights.get("waveFilter") or "all")
        self.wave_filter.setCurrentIndex(max(0, idx))
        form.addRow("Wave filter", self.wave_filter)

        self.clean_only = QCheckBox("Wave: clean worktrees only")
        self.clean_only.setChecked(bool(rights.get("waveCleanOnly")))
        form.addRow(self.clean_only)
        root.addLayout(form)

        ws_box = QGroupBox("Workspaces (empty allowlist = all except deny)")
        ws_l = QHBoxLayout(ws_box)
        allow_col = QVBoxLayout()
        allow_col.addWidget(QLabel("Allowlist"))
        self.allow_list = QListWidget()
        self.allow_list.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
        allow_col.addWidget(self.allow_list)
        deny_col = QVBoxLayout()
        deny_col.addWidget(QLabel("Denylist (untouched)"))
        self.deny_list = QListWidget()
        self.deny_list.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
        deny_col.addWidget(self.deny_list)
        ws_l.addLayout(allow_col)
        ws_l.addLayout(deny_col)
        root.addWidget(ws_box)

        allow_set = set(rights.get("allowlist") or [])
        deny_set = set(rights.get("denylist") or [])
        try:
            workspaces = list_workspaces()
        except Exception:
            workspaces = []
        for w in workspaces:
            a = QListWidgetItem(f"{w.id}")
            a.setData(Qt.ItemDataRole.UserRole, w.id)
            a.setToolTip(str(w.path))
            self.allow_list.addItem(a)
            if w.id in allow_set:
                a.setSelected(True)
            d = QListWidgetItem(f"{w.id}")
            d.setData(Qt.ItemDataRole.UserRole, w.id)
            d.setToolTip(str(w.path))
            self.deny_list.addItem(d)
            if w.id in deny_set:
                d.setSelected(True)

        hint = QLabel(
            "Tip: pick allowlist for a safe first wave. Denylist wins. "
            "Enabling writes asks for confirm on the next Act."
        )
        hint.setWordWrap(True)
        root.addWidget(hint)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._save)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

    def _selected_ids(self, widget: QListWidget) -> list[str]:
        out: list[str] = []
        for item in widget.selectedItems():
            wid = item.data(Qt.ItemDataRole.UserRole)
            if wid:
                out.append(str(wid))
        return out

    def _save(self) -> None:
        from core.store.preferences import (
            set_github_agent_allow_write,
            set_github_agent_allowlist,
            set_github_agent_autopilot,
            set_github_agent_confirm,
            set_github_agent_denylist,
            set_github_agent_dirty_policy,
            set_github_agent_include_archived,
            set_github_agent_max_per_tick,
            set_github_agent_wave_clean_only,
            set_github_agent_wave_filter,
        )

        set_github_agent_confirm(str(self.confirm.currentData()))
        set_github_agent_allow_write(self.allow_write.isChecked())
        set_github_agent_autopilot(str(self.autopilot.currentData()))
        set_github_agent_dirty_policy(str(self.dirty.currentData()))
        set_github_agent_max_per_tick(int(self.max_tick.value()))
        set_github_agent_include_archived(self.include_arch.isChecked())
        set_github_agent_wave_filter(str(self.wave_filter.currentData()))
        set_github_agent_wave_clean_only(self.clean_only.isChecked())
        set_github_agent_allowlist(self._selected_ids(self.allow_list))
        set_github_agent_denylist(self._selected_ids(self.deny_list))
        self.accept()


class GithubAgentCampaignDialog(QDialog):
    """Queue / done / skipped with progress + skip-forever."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("GitHub Agent — Campaign")
        self.resize(620, 520)

        root = QVBoxLayout(self)
        self.status = QLabel("")
        self.status.setWordWrap(True)
        root.addWidget(self.status)
        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        root.addWidget(self.progress)

        self.tabs_hint = QLabel(
            "Queue · Done · Skipped (select skipped → Skip forever)"
        )
        root.addWidget(self.tabs_hint)

        self.queue = QListWidget()
        # Never name this ``done`` — shadows QDialog.done() and crashes on close.
        self.done_list = QListWidget()
        self.skipped = QListWidget()
        self.skipped.setSelectionMode(QListWidget.SelectionMode.ExtendedSelection)
        lists = QHBoxLayout()
        for title, widget in (
            ("Queue", self.queue),
            ("Done", self.done_list),
            ("Skipped", self.skipped),
        ):
            col = QVBoxLayout()
            col.addWidget(QLabel(title))
            col.addWidget(widget)
            lists.addLayout(col)
        root.addLayout(lists, stretch=1)

        row = QHBoxLayout()
        skip_btn = QPushButton("Skip forever (selected skipped)")
        skip_btn.clicked.connect(self._skip_forever)
        refresh_btn = QPushButton("Refresh")
        refresh_btn.clicked.connect(self._reload)
        row.addWidget(skip_btn)
        row.addWidget(refresh_btn)
        row.addStretch(1)
        root.addLayout(row)

        close = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        close.rejected.connect(self.reject)
        close.accepted.connect(self.accept)
        root.addWidget(close)
        self._reload()

    def _reload(self) -> None:
        from core.store.github_agent_campaign import load_github_agent_campaign
        from core.store.preferences import get_github_agent_autopilot

        camp = load_github_agent_campaign()
        ap = get_github_agent_autopilot()
        q = camp.get("queue") or []
        d = camp.get("done") or []
        s = camp.get("skipped") or []
        total = len(q) + len(d) + len(s)
        applied = int((camp.get("stats") or {}).get("applied") or len(d))
        pct = (
            int(100 * applied / total)
            if total
            else (100 if camp.get("status") == "done" else 0)
        )
        self.progress.setValue(pct)
        last = str(camp.get("lastTickAt") or "—")
        if "T" in last:
            last = last.split("T", 1)[1][:5]
        self.status.setText(
            f"status={camp.get('status')} · autopilot={ap} · queue={len(q)} · "
            f"done={len(d)} · skipped={len(s)} · last tick {last}"
        )
        self.queue.clear()
        for item in q:
            if not isinstance(item, dict):
                continue
            dirty = " · dirty" if item.get("dirty") else ""
            row = QListWidgetItem(
                f"{item.get('workspaceId')} · {item.get('gapId')} · "
                f"{item.get('priority')}{dirty}"
            )
            row.setData(Qt.ItemDataRole.UserRole, item)
            self.queue.addItem(row)
        self.done_list.clear()
        for item in d:
            if not isinstance(item, dict):
                continue
            self.done_list.addItem(
                f"{item.get('workspaceId')} · {item.get('gapId')} · "
                f"{item.get('path') or ''}"
            )
        self.skipped.clear()
        for item in s:
            if not isinstance(item, dict):
                continue
            row = QListWidgetItem(
                f"{item.get('workspaceId')} · {item.get('gapId')} · "
                f"{item.get('reason')}"
            )
            row.setData(Qt.ItemDataRole.UserRole, item)
            self.skipped.addItem(row)

    def _skip_forever(self) -> None:
        from core.store.preferences import add_github_agent_skip_forever

        n = 0
        for item in self.skipped.selectedItems():
            data = item.data(Qt.ItemDataRole.UserRole)
            if not isinstance(data, dict):
                continue
            wid = str(data.get("workspaceId") or "")
            gid = str(data.get("gapId") or "")
            if wid and gid and gid != "*":
                add_github_agent_skip_forever(wid, gid)
                n += 1
        QMessageBox.information(
            self, "Skip forever", f"Marked {n} gap(s) skip-forever."
        )
        self._reload()


class GithubAgentDomainsDialog(QDialog):
    """Attach public domains/URLs to a workspace for the site-check wave."""

    def __init__(
        self,
        parent: QWidget | None = None,
        *,
        initial_workspace_id: str | None = None,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle("GitHub Agent — Domains")
        self.resize(520, 220)

        from core.store.workspaces import list_workspaces

        root = QVBoxLayout(self)
        form = QFormLayout()
        self.ws = QComboBox()
        for w in list_workspaces():
            label = w.id
            if w.domains:
                label = f"{w.id} · {len(w.domains)} domain(s)"
            self.ws.addItem(label, w.id)
        if initial_workspace_id:
            idx = self.ws.findData(initial_workspace_id)
            if idx >= 0:
                self.ws.setCurrentIndex(idx)
        form.addRow("Workspace", self.ws)

        self.domains = QLineEdit()
        self.domains.setPlaceholderText("scan.fr4iser.com, https://fr4iser.com/")
        form.addRow("Domains", self.domains)
        root.addLayout(form)

        hint = QLabel(
            "Comma-separated public hosts or URLs. Used by Site-check wave "
            "(TLS, security headers, SEO, first-paint externals). "
            "Private/localhost targets are refused."
        )
        hint.setWordWrap(True)
        hint.setObjectName("nccMuted")
        root.addWidget(hint)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._save)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

        self.ws.currentIndexChanged.connect(self._load_current)
        self._load_current()

    def _load_current(self) -> None:
        from core.store.workspaces import get_workspace

        wid = self.ws.currentData()
        ws = get_workspace(str(wid)) if wid else None
        self.domains.setText(", ".join((ws.domains if ws else []) or []))

    def _save(self) -> None:
        from core.store.workspaces import set_workspace_domains

        wid = self.ws.currentData()
        if not wid:
            QMessageBox.warning(self, "Domains", "No workspace selected.")
            return
        raw = [x.strip() for x in self.domains.text().split(",") if x.strip()]
        try:
            set_workspace_domains(str(wid), raw)
        except ValueError as exc:
            QMessageBox.warning(self, "Domains", str(exc))
            return
        self.accept()


def format_github_agent_header_chip(
    camp: dict[str, Any] | None, autopilot: str
) -> str:
    """Compact header chip text."""
    if not camp:
        return f"GH · autopilot={autopilot}"
    q = len(camp.get("queue") or [])
    st = camp.get("status") or "idle"
    last = str(camp.get("lastTickAt") or "")
    if "T" in last:
        last = last.split("T", 1)[1][:5]
    else:
        last = "—"
    return f"GH · {autopilot} · {st} · q={q} · tick {last}"
