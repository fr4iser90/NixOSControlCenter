"""Commit bar — pending changes → Save / Undo → Apply → optional rebuild.

Used by every ``DomainPage``. Domain pages stage changes; they must not
write config until ``Apply``. See doc/GUI-DESIGN.md (§ Commit bar).
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import Any

from PySide6.QtCore import QSettings
from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


SETTINGS_ORG = "NixOSControlCenter"
SETTINGS_APP = "ncc-gui"
SKIP_REBUILD_KEY = "commit/autoRebuildWithoutPrompt"


@dataclass
class PendingChange:
    """One staged config change (not yet applied to disk)."""

    summary: str
    # ncc argv after ``ncc`` (e.g. ["packages", "add", "firefox", "--no-build"])
    argv: list[str]
    elevated: bool = False
    undo_argv: list[str] | None = None
    undo_elevated: bool = False
    meta: dict[str, Any] = field(default_factory=dict)


def _settings() -> QSettings:
    return QSettings(SETTINGS_ORG, SETTINGS_APP)


def auto_rebuild_without_prompt() -> bool:
    return bool(_settings().value(SKIP_REBUILD_KEY, False, type=bool))


def set_auto_rebuild_without_prompt(value: bool) -> None:
    s = _settings()
    s.setValue(SKIP_REBUILD_KEY, bool(value))
    s.sync()


def _copy_changes(changes: Sequence[PendingChange]) -> list[PendingChange]:
    return [
        PendingChange(
            summary=c.summary,
            argv=list(c.argv),
            elevated=c.elevated,
            undo_argv=list(c.undo_argv) if c.undo_argv else None,
            undo_elevated=c.undo_elevated,
            meta=dict(c.meta),
        )
        for c in changes
    ]


class RebuildRequiredDialog(QDialog):
    """Modal after Apply: config written, system needs rebuild & switch."""

    def __init__(self, parent: QWidget | None, summary: str) -> None:
        super().__init__(parent)
        self.setWindowTitle("Build required")
        self._accepted_rebuild = False
        lay = QVBoxLayout(self)
        lay.addWidget(
            QLabel(
                "Configuration was saved.\n\n"
                f"{summary}\n\n"
                "It is not active on the system yet. "
                "A rebuild & switch to the next generation is required "
                "before the changes take effect."
            )
        )
        self.chk_skip = QCheckBox(
            "Don't show again — always rebuild && switch after Apply"
        )
        lay.addWidget(self.chk_skip)
        buttons = QDialogButtonBox()
        self.btn_rebuild = buttons.addButton(
            "Rebuild && switch", QDialogButtonBox.ButtonRole.AcceptRole
        )
        self.btn_cancel = buttons.addButton(
            "Not now", QDialogButtonBox.ButtonRole.RejectRole
        )
        lay.addWidget(buttons)
        self.btn_rebuild.clicked.connect(self._accept_rebuild)
        self.btn_cancel.clicked.connect(self.reject)

    def _accept_rebuild(self) -> None:
        self._accepted_rebuild = True
        if self.chk_skip.isChecked():
            set_auto_rebuild_without_prompt(True)
        self.accept()

    def want_rebuild(self) -> bool:
        return self._accepted_rebuild


def offer_rebuild_after_apply(parent: QWidget | None, summary: str) -> bool:
    """Return True if rebuild & switch should run now."""
    if auto_rebuild_without_prompt():
        return True
    dlg = RebuildRequiredDialog(parent, summary)
    dlg.exec()
    return dlg.want_rebuild()


class CommitBar(QWidget):
    """Always-visible footer controls: Undo · Save · Apply (right-aligned)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        self.status = QLabel("No pending changes")
        self.status.setObjectName("nccPageSubtitle")
        self.status.setWordWrap(True)
        row.addWidget(self.status, stretch=1)
        self.btn_undo = QPushButton("Undo")
        self.btn_save = QPushButton("Save")
        self.btn_apply = QPushButton("Apply")
        self.btn_apply.setDefault(True)
        self.btn_apply.setObjectName("nccPrimaryButton")
        for b in (self.btn_undo, self.btn_save, self.btn_apply):
            row.addWidget(b)
        self.btn_undo.setEnabled(False)
        self.btn_save.setEnabled(False)
        self.btn_apply.setEnabled(False)


class CommitController:
    """Pending-change state machine shared by all domain pages."""

    def __init__(self, page: Any) -> None:
        self.page = page
        self.bar = CommitBar(page)
        self.pending: list[PendingChange] = []
        self._checkpoints: list[list[PendingChange]] = []
        self._saved = False
        self._on_flush: Callable[[list[PendingChange]], None] | None = None
        self._on_pending_changed: Callable[[], None] | None = None
        self.bar.btn_undo.clicked.connect(self.undo)
        self.bar.btn_save.clicked.connect(self.save)
        self.bar.btn_apply.clicked.connect(self.apply)

    def set_flush_handler(
        self, handler: Callable[[list[PendingChange]], None]
    ) -> None:
        """Domain provides how to write pending changes (usually ncc calls)."""
        self._on_flush = handler

    def set_pending_changed(
        self, handler: Callable[[], None] | None
    ) -> None:
        """Optional: refresh draft UI when pending list changes (incl. Undo)."""
        self._on_pending_changed = handler

    def stage(self, change: PendingChange) -> None:
        self.pending.append(change)
        self._saved = False
        self._refresh_bar()
        self.page.log_append(f"• staged: {change.summary}\n")
        self._emit_pending_changed()

    def stage_replace(
        self,
        change: PendingChange,
        *,
        same: Callable[[PendingChange, PendingChange], bool],
    ) -> None:
        """Replace any pending change that ``same`` matches, then stage."""
        self.pending = [c for c in self.pending if not same(c, change)]
        self.stage(change)

    def discard_where(
        self,
        pred: Callable[[PendingChange], bool],
        *,
        log: str | None = None,
    ) -> int:
        """Remove pending items matching ``pred``. Returns how many removed."""
        before = len(self.pending)
        self.pending = [c for c in self.pending if not pred(c)]
        removed = before - len(self.pending)
        if removed == 0:
            return 0
        self._saved = False
        self._refresh_bar()
        if log:
            self.page.log_append(log)
        self._emit_pending_changed()
        return removed

    def stage_many(self, changes: Sequence[PendingChange]) -> None:
        for c in changes:
            self.pending.append(c)
        self._saved = False
        self._refresh_bar()
        if changes:
            self.page.log_append(
                "• staged: " + "; ".join(c.summary for c in changes) + "\n"
            )
        self._emit_pending_changed()

    def save(self) -> None:
        if not self.pending:
            return
        self._checkpoints.append(_copy_changes(self.pending))
        self._saved = True
        self._refresh_bar()
        self.page.log_append(
            f"• saved draft ({len(self.pending)} change(s)) — Undo restores last save\n"
        )
        self._emit_pending_changed()

    def undo(self) -> None:
        if not self._saved and self._checkpoints:
            self.pending = _copy_changes(self._checkpoints[-1])
            self._saved = True
            self._refresh_bar()
            self.page.log_append("• undo — discarded unsaved edits (last save)\n")
            self._emit_pending_changed()
            return
        if self._checkpoints:
            self._checkpoints.pop()
            if self._checkpoints:
                self.pending = _copy_changes(self._checkpoints[-1])
                self._saved = True
            else:
                self.pending = []
                self._saved = False
            self._refresh_bar()
            self.page.log_append("• undo — restored previous saved draft\n")
            self._emit_pending_changed()
            return
        if self.pending:
            removed = self.pending.pop()
            self._saved = False
            self._refresh_bar()
            self.page.log_append(f"• undo — removed staged: {removed.summary}\n")
            self._emit_pending_changed()

    def apply(self) -> None:
        if not self.pending:
            return
        if self._on_flush is None:
            QMessageBox.warning(
                self.page,
                "Apply",
                "This page has no Apply handler yet.",
            )
            return
        self._on_flush(list(self.pending))

    def notify_apply_finished(
        self,
        ok: bool,
        summary: str,
        *,
        offer_rebuild: bool = True,
    ) -> None:
        """Call from domain after flush completes.

        ``offer_rebuild=False`` for non-Nix writes (e.g. SSH client list).
        """
        if not ok:
            return
        self.pending.clear()
        self._checkpoints.clear()
        self._saved = False
        self._refresh_bar()
        self.page.log_append(f"• applied to config: {summary}\n")
        self._emit_pending_changed()
        if not offer_rebuild:
            from ncc_gui.dialogs import info

            info(
                self.page,
                "Saved",
                "Changes were written.\n\nNo system rebuild is required for this.",
            )
            return
        if offer_rebuild_after_apply(self.page, summary):
            self.page.run_ncc_root(
                ["system", "build", "switch"],
                label="Rebuild && switch",
            )
        else:
            from ncc_gui.dialogs import info

            info(
                self.page,
                "Config updated",
                "Saved to configuration.\n\n"
                "Rebuild & switch when you want it active on the system.",
            )

    def clear(self) -> None:
        self.pending.clear()
        self._checkpoints.clear()
        self._saved = False
        self._refresh_bar()
        self._emit_pending_changed()

    def _emit_pending_changed(self) -> None:
        if self._on_pending_changed is not None:
            self._on_pending_changed()

    def _refresh_bar(self) -> None:
        n = len(self.pending)
        if n == 0:
            self.bar.status.setText("No pending changes")
        elif self._saved:
            self.bar.status.setText(f"{n} saved change(s) — ready to Apply")
        else:
            self.bar.status.setText(f"{n} pending — Save draft or Apply")
        self.bar.btn_undo.setEnabled(bool(self.pending) or bool(self._checkpoints))
        self.bar.btn_save.setEnabled(n > 0 and not self._saved)
        self.bar.btn_apply.setEnabled(n > 0)
