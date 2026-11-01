"""Workflow run-readiness dialog — checklist + fix buttons before Configure/Run.

Caller: ``companion.window._run_template`` (always opens when preflight is needed,
or when the operator should confirm greens). No other dialog covers remediations
(scan / secret paste / MCP install) in one place.

Reads/writes via ``core.catalogs.workflow_readiness`` remediations only
(workspaces registry, secrets.json 0600, mcp-servers.json 0600).

User: "ja bbitte" — Start → check requirements → fetch/add missing.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from core.catalogs.workflow_readiness import (
    ReadinessItem,
    ReadinessReport,
    assess_workflow_readiness,
    auto_remediate_mcp,
    default_git_parent,
    remediate_install_mcp,
    remediate_scan_workspaces,
    remediate_set_secret,
)


class WorkflowReadinessDialog(QDialog):
    """Show gaps for one workflow; Fix buttons remediate; Continue when ready."""

    def __init__(
        self,
        template_id: str,
        parent: QWidget | None = None,
        *,
        active_workspace_id: str | None = None,
    ) -> None:
        super().__init__(parent)
        self._template_id = template_id
        self._active_workspace_id = active_workspace_id
        self._report: ReadinessReport = assess_workflow_readiness(template_id)
        self._use_all_workspaces = False

        self.setWindowTitle(f"Ready to run — {self._report.title}")
        self.resize(560, 480)

        root = QVBoxLayout(self)
        intro = QLabel(
            "Before Configure / Run once: missing pieces are listed below. "
            "Fix what you can here; host packages (git / uv / gh) need a system install."
        )
        intro.setWordWrap(True)
        root.addWidget(intro)

        self._list = QListWidget()
        self._list.setWordWrap(True)
        root.addWidget(self._list, stretch=1)

        self._status = QLabel("")
        self._status.setWordWrap(True)
        root.addWidget(self._status)

        self._all_ws = QCheckBox("Use all registered workspaces for this run")
        self._all_ws.setToolTip(
            "When checked, the Configure dialog seeds every registered repo "
            "into the Repositories list (not only ★)."
        )
        root.addWidget(self._all_ws)

        action_row = QHBoxLayout()
        self._fix_btn = QPushButton("Fix selected")
        self._fix_btn.clicked.connect(self._fix_selected)
        action_row.addWidget(self._fix_btn)
        self._auto_btn = QPushButton("Install ready MCPs")
        self._auto_btn.clicked.connect(self._auto_mcp)
        action_row.addWidget(self._auto_btn)
        self._rescan_btn = QPushButton("Re-check")
        self._rescan_btn.clicked.connect(self._refresh)
        action_row.addWidget(self._rescan_btn)
        action_row.addStretch()
        root.addLayout(action_row)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Cancel
            | QDialogButtonBox.StandardButton.Ok
        )
        self._continue = buttons.button(QDialogButtonBox.StandardButton.Ok)
        self._continue.setText("Continue")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        root.addWidget(buttons)

        self._refresh()

    def use_all_workspaces(self) -> bool:
        return bool(self._all_ws.isChecked() or self._use_all_workspaces)

    def _refresh(self) -> None:
        self._report = assess_workflow_readiness(self._template_id)
        self._list.clear()
        for item in self._report.items:
            mark = {"ok": "✓", "warn": "!", "block": "✗"}.get(item.severity, "?")
            text = f"{mark}  {item.title}"
            if item.detail:
                text += f"\n    {item.detail}"
            if item.hint and item.severity != "ok":
                text += f"\n    → {item.hint}"
            row = QListWidgetItem(text)
            row.setData(Qt.ItemDataRole.UserRole, item)
            if item.severity == "block":
                row.setForeground(Qt.GlobalColor.red)
            elif item.severity == "warn":
                row.setForeground(Qt.GlobalColor.darkYellow)
            else:
                row.setForeground(Qt.GlobalColor.darkGreen)
            self._list.addItem(row)

        if self._report.ready:
            self._status.setText(
                "All blocking checks passed — Continue opens Configure."
            )
            self._continue.setEnabled(True)
        else:
            n = len(self._report.blocking)
            self._status.setText(
                f"{n} blocking issue(s). Fix them (or install host packages), then Re-check."
            )
            self._continue.setEnabled(False)

        has_mcp_fix = any(i.fix == "install_mcp" for i in self._report.items)
        self._auto_btn.setEnabled(has_mcp_fix)

    def _selected_item(self) -> ReadinessItem | None:
        row = self._list.currentItem()
        if row is None:
            return None
        data = row.data(Qt.ItemDataRole.UserRole)
        return data if isinstance(data, ReadinessItem) else None

    def _fix_selected(self) -> None:
        item = self._selected_item()
        if item is None:
            for candidate in self._report.actionable:
                item = candidate
                break
        if item is None or item.fix == "none":
            QMessageBox.information(
                self,
                "Readiness",
                "Select a row that can be fixed here, or install the host package it names.",
            )
            return
        if item.fix == "scan_workspaces":
            self._do_scan()
        elif item.fix == "set_secret" and item.secret_name:
            self._do_secret(item.secret_name)
        elif item.fix == "install_mcp" and item.mcp_name:
            self._do_mcp(item.mcp_name)
        elif item.fix == "host_package":
            QMessageBox.information(
                self,
                "Host package",
                item.hint
                or f"Install `{item.host_bin}` on this host, then click Re-check.",
            )
        self._refresh()

    def _do_scan(self) -> None:
        start = str(default_git_parent())
        path = QFileDialog.getExistingDirectory(
            self,
            "Scan parent folder for git repos",
            start,
        )
        if not path:
            return
        result = remediate_scan_workspaces(path)
        if not result.get("ok"):
            QMessageBox.warning(self, "Scan", result.get("error") or "Scan failed")
            return
        imported = result.get("imported") or []
        QMessageBox.information(
            self,
            "Scan",
            f"Registered {len(imported)} repo(s) under {path}\n"
            f"Total workspaces: {result.get('total')}",
        )
        if len(imported) > 1:
            self._all_ws.setChecked(True)
            self._use_all_workspaces = True

    def _do_secret(self, name: str) -> None:
        value, ok = QInputDialog.getText(
            self,
            "Set secret",
            f"Paste value for secret '{name}' (stored 0600, never shown in prompts):",
            QLineEdit.EchoMode.Password,
        )
        if not ok:
            return
        result = remediate_set_secret(name, value)
        if not result.get("ok"):
            QMessageBox.warning(self, "Secret", result.get("error") or "Failed")
            return
        QMessageBox.information(self, "Secret", f"Saved '{name}'.")

    def _do_mcp(self, name: str) -> None:
        result = remediate_install_mcp(
            name, workspace_id=self._active_workspace_id
        )
        if not result.get("ok"):
            msg = result.get("error") or "Install failed"
            hint = result.get("hint")
            if hint:
                msg = f"{msg}\n\n{hint}"
            QMessageBox.warning(self, "MCP", msg)
            return
        QMessageBox.information(
            self, "MCP", f"Installed MCP '{result.get('name') or name}'."
        )

    def _auto_mcp(self) -> None:
        results = auto_remediate_mcp(self._report)
        if not results:
            QMessageBox.information(self, "MCP", "No MCP installs were ready yet.")
            self._refresh()
            return
        failed = [r for r in results if not r.get("ok")]
        ok_n = len(results) - len(failed)
        if failed:
            err = failed[0].get("error") or "failed"
            QMessageBox.warning(
                self,
                "MCP",
                f"Installed {ok_n}, failed {len(failed)}.\nFirst error: {err}",
            )
        else:
            QMessageBox.information(self, "MCP", f"Installed {ok_n} MCP server(s).")
        self._refresh()
