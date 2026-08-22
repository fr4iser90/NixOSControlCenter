"""Root shell header: Target (left) + status + Settings (right).

Layout contract (binding):
  [ Target cluster | status… ] -------------------- [ ⚙ ]

Target is **left-packed** in its own non-expanding widget. Stretch only sits
between the left cluster and the settings button — never between “Target” and
the combo (that was why the combo looked glued to the right).
"""

from __future__ import annotations

import subprocess

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFontMetrics, QIcon
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QSizePolicy,
    QStyle,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.chrome_prefs import (
    show_target_enabled,
)
from ncc_gui.dialogs import error
from ncc_gui.session_ux import chip_text, session_mode
from ncc_gui.settings import open_settings_dialog
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_session import TargetSession, session_controller
from ncc_gui.target_state import list_host_targets
from ncc_gui.theme import APP_STYLE

_BAR_HEIGHT = 48
_COMBO_W = 220


class _AddHostDialog(QDialog):
    """Quick-add into the shared SSH client list (~/.creds)."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Add target host")
        self.setModal(True)
        self.setMinimumWidth(360)
        self._open_hosts_clicked = False
        layout = QVBoxLayout(self)
        hint = QLabel(
            "Adds to the SSH client list (ncc ssh client / ~/.creds)."
        )
        hint.setObjectName("nccTargetStatus")
        hint.setWordWrap(True)
        layout.addWidget(hint)
        form = QFormLayout()
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("hostname or IP")
        self.user_edit = QLineEdit()
        self.user_edit.setPlaceholderText("ssh user")
        form.addRow("Host", self.host_edit)
        form.addRow("User", self.user_edit)
        layout.addLayout(form)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        open_hosts = buttons.addButton(
            "Open SSH…", QDialogButtonBox.ButtonRole.ActionRole
        )
        open_hosts.clicked.connect(self._open_hosts)
        layout.addWidget(buttons)
        self.host_edit.setFocus()

    def _open_hosts(self) -> None:
        self._open_hosts_clicked = True
        self.reject()

    def values(self) -> tuple[str, str]:
        host = self.host_edit.text().strip()
        user = self.user_edit.text().strip()
        if "@" in host and not user:
            user, _, host = host.rpartition("@")
            user, host = user.strip(), host.strip()
        return host, user


class _EditHostDialog(QDialog):
    """Edit username for an SSH client entry (~/.creds via ncc ssh client edit)."""

    def __init__(
        self,
        parent: QWidget | None,
        *,
        host: str,
        user: str,
    ) -> None:
        win = parent.window() if parent is not None else None
        super().__init__(win if win is not None else parent)
        self.setWindowTitle("Edit SSH target")
        self.setModal(True)
        self.setMinimumWidth(380)
        self.setStyleSheet(APP_STYLE)
        layout = QVBoxLayout(self)
        hint = QLabel(
            "Updates the SSH client list (ncc ssh client edit → ~/.creds)."
        )
        hint.setObjectName("nccTargetStatus")
        hint.setWordWrap(True)
        layout.addWidget(hint)
        form = QFormLayout()
        self.host_edit = QLineEdit(host)
        self.host_edit.setEnabled(False)
        self.user_edit = QLineEdit(user)
        form.addRow("Host", self.host_edit)
        form.addRow("User", self.user_edit)
        layout.addLayout(form)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)
        self.user_edit.setFocus()

    def values(self) -> tuple[str, str]:
        return self.host_edit.text().strip(), self.user_edit.text().strip()


class TargetBar(QWidget):
    """Root header: optional Target (left) + Settings (right)."""

    targetChanged = Signal(object)
    sessionChanged = Signal(object)
    actionRequested = Signal(str)
    chromeChanged = Signal()  # show_target toggled

    def __init__(
        self,
        parent: QWidget | None = None,
        *,
        hint: str = "",
        persist: bool = True,
    ) -> None:
        super().__init__(parent)
        self._persist = persist
        self._hint_default = hint or ""
        self._status_full = ""
        self.setObjectName("nccTargetBar")
        self.setStyleSheet(APP_STYLE)
        self.setFixedHeight(_BAR_HEIGHT)
        self.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Fixed)
        self._ctrl = session_controller()
        self._key_offer_host: str | None = None
        self._key_offer_password: str | None = None

        row = QHBoxLayout(self)
        row.setContentsMargins(12, 6, 12, 6)
        row.setSpacing(8)

        # --- LEFT: Target cluster (non-expanding) ---
        self._target_cluster = QWidget()
        self._target_cluster.setSizePolicy(
            QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed
        )
        left = QHBoxLayout(self._target_cluster)
        left.setContentsMargins(0, 0, 0, 0)
        left.setSpacing(8)

        # Truth chip: where mutations actually go (selection ≠ connection).
        self._chip = QLabel("LOCAL")
        self._chip.setObjectName("nccSessionChip")
        self._chip.setSizePolicy(
            QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed
        )
        self._chip.setToolTip(
            "Session scope. LOCAL = this machine. "
            "REMOTE only after a successful Connect."
        )
        left.addWidget(self._chip)

        self.combo = QComboBox()
        self.combo.setFixedWidth(_COMBO_W)
        self.combo.setSizePolicy(QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed)
        self.combo.setToolTip(
            "Host candidate only.\n"
            "Pick a host, then Connect — pages stay on LOCAL until Connect succeeds."
        )
        left.addWidget(self.combo)

        self.btn_add = QToolButton()
        self.btn_add.setObjectName("nccHeaderAction")
        self.btn_add.setText("+")
        self.btn_add.setToolTip(
            "Quick-add a host to the SSH client list (~/.creds)."
        )
        self.btn_add.clicked.connect(self._on_add)
        left.addWidget(self.btn_add)

        self.btn_edit = QToolButton()
        self.btn_edit.setObjectName("nccHeaderAction")
        edit_icon = QIcon.fromTheme("document-edit")
        if edit_icon.isNull():
            edit_icon = QIcon.fromTheme("edit")
        if edit_icon.isNull():
            edit_icon = self.style().standardIcon(
                QStyle.StandardPixmap.SP_FileDialogDetailedView
            )
        if not edit_icon.isNull():
            self.btn_edit.setIcon(edit_icon)
        else:
            self.btn_edit.setText("✎")
        self.btn_edit.setToolTip(
            "Edit the selected Target (SSH client user) — stays on this page."
        )
        self.btn_edit.clicked.connect(self._on_edit_targets)
        left.addWidget(self.btn_edit)

        self.btn_connect = QPushButton("Connect")
        self.btn_connect.setObjectName("nccPrimaryButton")
        self.btn_connect.setToolTip(
            "Probe the selected host over SSH and switch the GUI to its NCC."
        )
        self.btn_connect.clicked.connect(self._on_connect)
        left.addWidget(self.btn_connect)

        self.btn_disconnect = QPushButton("Disconnect")
        self.btn_disconnect.setToolTip("Return to this machine’s NCC.")
        self.btn_disconnect.clicked.connect(self._on_disconnect)
        left.addWidget(self.btn_disconnect)

        row.addWidget(self._target_cluster, stretch=0)

        self.status = QLabel("")
        self.status.setObjectName("nccTargetStatus")
        self.status.setWordWrap(False)
        self.status.setAlignment(
            Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft
        )
        self.status.setSizePolicy(
            QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred
        )
        self.status.setMinimumWidth(0)
        # Status sits in the flexible middle — but stretch must NEVER depend on
        # status visibility (hidden widgets get no layout space → group centers).
        row.addWidget(self.status, stretch=0)
        row.addStretch(1)

        # --- RIGHT: Settings (always pinned to the trailing edge) ---
        self.btn_settings = QToolButton()
        self.btn_settings.setObjectName("nccHeaderAction")
        self.btn_settings.setToolTip("Control Center settings")
        icon = QIcon.fromTheme("configure")
        if icon.isNull():
            icon = QIcon.fromTheme("preferences-system")
        if icon.isNull():
            icon = self.style().standardIcon(
                QStyle.StandardPixmap.SP_FileDialogDetailedView
            )
        if not icon.isNull():
            self.btn_settings.setIcon(icon)
        else:
            self.btn_settings.setText("⚙")
        self.btn_settings.clicked.connect(self._on_settings)
        row.addWidget(self.btn_settings, stretch=0)

        self.reload_hosts()
        self.combo.currentIndexChanged.connect(self._on_index)
        self._ctrl.sessionChanged.connect(self._on_session)
        self._ctrl.authNeeded.connect(self._on_auth_needed)
        self._ctrl.bootstrap_from_disk()
        self._sync_combo_from_session(self._ctrl.session())
        self.apply_chrome_prefs()
        self._apply_session_ui(self._ctrl.session())

    def target_chrome_visible(self) -> bool:
        return show_target_enabled()

    def apply_chrome_prefs(self) -> None:
        """Show/hide Target cluster from prefs; force local when hidden."""
        show = show_target_enabled()
        self._target_cluster.setVisible(show)
        if not show:
            # Fleet chrome off → always this machine.
            if self._ctrl.session().connected is not None:
                self._ctrl.disconnect_target()
            else:
                self._ctrl.set_candidate(None)
            self._set_status("")
            self.btn_connect.setVisible(False)
            self.btn_disconnect.setVisible(False)
        else:
            self._sync_combo_from_session(self._ctrl.session())
            self._apply_session_ui(self._ctrl.session())

    def reload_hosts(self) -> None:
        self.combo.blockSignals(True)
        sess = self._ctrl.session()
        pick = sess.candidate or sess.connected
        self.combo.clear()
        self.combo.addItem("This machine", None)
        for target in list_host_targets():
            self.combo.addItem(target, target)
        idx = 0
        if pick:
            for i in range(self.combo.count()):
                if self.combo.itemData(i) == pick:
                    idx = i
                    break
            else:
                self.combo.addItem(pick, pick)
                idx = self.combo.count() - 1
        self.combo.setCurrentIndex(idx)
        self.combo.blockSignals(False)

    def current_target(self) -> str | None:
        return self._ctrl.session().connected

    def current_candidate(self) -> str | None:
        if not show_target_enabled():
            return None
        data = self.combo.currentData()
        if data is None:
            return None
        host = str(data).strip()
        return host or None

    def set_target(self, target: str | None, *, emit: bool = True) -> None:
        want = (target or "").strip() or None
        self.combo.blockSignals(True)
        for i in range(self.combo.count()):
            if self.combo.itemData(i) == want:
                self.combo.setCurrentIndex(i)
                break
        else:
            if want:
                self.combo.addItem(want, want)
                self.combo.setCurrentIndex(self.combo.count() - 1)
            else:
                self.combo.setCurrentIndex(0)
        self.combo.blockSignals(False)
        self._ctrl.set_candidate(want)
        if emit and want is None:
            self.targetChanged.emit(None)

    def _on_settings(self) -> None:
        if open_settings_dialog(self):
            self.apply_chrome_prefs()
            self.chromeChanged.emit()
            # chromePrefsChanged already emitted by SettingsDialog on OK

    def _on_edit_targets(self) -> None:
        """Edit selected target in-place — no domain switch."""
        cand = self.current_candidate()
        if not cand or "@" not in cand:
            error(
                self,
                "Edit target",
                "Select a remote host in the Target list first "
                "(not “This machine”).\n\n"
                "Full list management: open SSH in the sidebar.",
            )
            return
        user, _, host = cand.rpartition("@")
        user, host = user.strip(), host.strip()
        if not host or not user:
            error(self, "Edit target", f"Invalid target: {cand}")
            return
        dlg = _EditHostDialog(self, host=host, user=user)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        new_host, new_user = dlg.values()
        if not new_user:
            error(self, "Edit target", "Username is required.")
            return
        try:
            proc = subprocess.run(
                ["ncc", "ssh", "client", "edit", new_host, new_user],
                check=False,
                capture_output=True,
                text=True,
                timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            error(self, "Edit target", str(exc))
            return
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "ncc ssh client edit failed").strip()
            error(self, "Edit target", err)
            return
        target = f"{new_user}@{new_host}"
        self.reload_hosts()
        self.set_target(target, emit=False)
        self._apply_session_ui(self._ctrl.session())

    def _on_add(self) -> None:
        dlg = _AddHostDialog(self)
        result = dlg.exec()
        if dlg._open_hosts_clicked:
            target_bus().navigate.emit("ssh")
            return
        if result != QDialog.DialogCode.Accepted:
            return
        host, user = dlg.values()
        if not host or not user:
            error(self, "Add host", "Host and user are required.")
            return
        try:
            proc = subprocess.run(
                ["ncc", "ssh", "client", "add", host, user],
                check=False,
                capture_output=True,
                text=True,
                timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            error(self, "Add host", str(exc))
            return
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "ncc ssh client add failed").strip()
            error(self, "Add host", err)
            return
        target = f"{user}@{host}"
        self.reload_hosts()
        self.set_target(target, emit=False)
        self._apply_session_ui(self._ctrl.session())

    def _on_auth_needed(self, host: object, detail: object) -> None:
        """BatchMode probe failed auth — password + Connect / Cancel only."""
        if not isinstance(host, str) or not host.strip():
            return
        from ncc_gui.ssh_auth_dialog import prompt_ssh_auth

        host_s = host.strip()
        choice = prompt_ssh_auth(self, host_s, detail=str(detail or ""))
        self._ctrl.dismiss_auth_prompt()
        if choice.action != "connect" or not choice.password:
            self._clear_key_offer()
            return
        # Offer key save only after this password Connect succeeds.
        self._key_offer_host = host_s
        self._key_offer_password = choice.password
        self._ctrl.connect_with_password(host_s, choice.password)

    def _clear_key_offer(self) -> None:
        self._key_offer_host = None
        self._key_offer_password = None

    def _maybe_offer_key_save(self, session: TargetSession) -> None:
        host = self._key_offer_host
        password = self._key_offer_password
        if not host or not password:
            return
        if session.state == "connecting":
            return
        if session.connected != host:
            # Password Connect failed / cancelled path
            self._clear_key_offer()
            return
        # Successful connection after password — ask once about saving the key.
        self._clear_key_offer()
        from ncc_gui.chrome_prefs import remember_skip_ssh_key_offer
        from ncc_gui.dialogs import error, info
        from ncc_gui.ssh_auth_dialog import prompt_save_ssh_key
        from ncc_gui.target_probe import copy_ssh_key

        choice = prompt_save_ssh_key(self, host)
        if choice.dont_ask_again:
            remember_skip_ssh_key_offer(host)
        if not choice.save:
            return
        ok, err = copy_ssh_key(host, password)
        if ok:
            info(self, "SSH key", f"Public key installed on {host}.")
        else:
            error(self, "SSH key", err or "ssh-copy-id failed")

    def _on_index(self, _i: int) -> None:
        if not show_target_enabled():
            return
        self._ctrl.set_candidate(self.current_candidate())

    def _on_connect(self) -> None:
        if not show_target_enabled():
            return
        before = self._ctrl.session().connected
        cand = self.current_candidate()
        if cand is None:
            self._ctrl.disconnect_target()
            return
        s = self._ctrl.connect_target(cand)
        if cand is None and s.connected != before:
            self.targetChanged.emit(s.connected)
            target_bus().changed.emit(s.connected)

    def _on_disconnect(self) -> None:
        before = self._ctrl.session().connected
        s = self._ctrl.disconnect_target()
        self._sync_combo_from_session(s)
        if before is not None:
            self.targetChanged.emit(None)
        target_bus().changed.emit(None)

    def _on_session(self, session: object) -> None:
        if not isinstance(session, TargetSession):
            return
        if show_target_enabled():
            self._apply_session_ui(session)
        self.sessionChanged.emit(session)
        if session.state == "connecting":
            return
        self._maybe_offer_key_save(session)
        prev = getattr(self, "_emitted_connected", object())
        if session.connected != prev:
            self._emitted_connected = session.connected
            self.targetChanged.emit(session.connected)
            target_bus().changed.emit(session.connected)

    def _sync_combo_from_session(self, s: TargetSession) -> None:
        pick = s.candidate if s.candidate is not None else s.connected
        self.combo.blockSignals(True)
        if pick is None:
            self.combo.setCurrentIndex(0)
        else:
            found = False
            for i in range(self.combo.count()):
                if self.combo.itemData(i) == pick:
                    self.combo.setCurrentIndex(i)
                    found = True
                    break
            if not found:
                self.combo.addItem(pick, pick)
                self.combo.setCurrentIndex(self.combo.count() - 1)
        self.combo.blockSignals(False)

    def _set_status(self, text: str) -> None:
        full = (text or "").strip()
        self._status_full = full
        if not full or not show_target_enabled():
            self.status.clear()
            self.status.setToolTip("")
            self.status.setVisible(False)
            return
        self.status.setVisible(True)
        self.status.setToolTip(full)
        self._elide_status()

    def _elide_status(self) -> None:
        full = self._status_full
        if not full:
            return
        width = max(self.status.width(), 40)
        elided = QFontMetrics(self.status.font()).elidedText(
            full, Qt.TextElideMode.ElideRight, width
        )
        self.status.setText(elided)

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        self._elide_status()

    def _apply_session_ui(self, s: TargetSession) -> None:
        mode = session_mode(s)
        self._set_session_chrome(mode, chip_text(s))

        if not show_target_enabled():
            self._set_status("")
            self.btn_connect.setVisible(False)
            self.btn_disconnect.setVisible(False)
            return

        remote_pick = self.current_candidate() is not None
        connected = s.connected is not None
        self.btn_add.setVisible(True)

        if s.state == "connecting":
            self._set_status(s.message)
            self.btn_connect.setEnabled(False)
            self.btn_connect.setText("Connecting…")
            self.btn_connect.setVisible(True)
            self.btn_disconnect.setEnabled(False)
            self.btn_disconnect.setVisible(True)
            return

        if connected:
            msg = s.message or ""
            if msg.startswith("Connected · "):
                parts = msg.split(" · ", 2)
                msg = " · ".join(parts[1:]) if len(parts) > 2 else msg
            self._set_status(msg)
            self.btn_connect.setText("Re-probe")
            self.btn_connect.setEnabled(True)
            self.btn_connect.setVisible(True)
            self.btn_disconnect.setEnabled(True)
            self.btn_disconnect.setVisible(True)
            return

        if mode == "failed":
            # Detail lives in the gate banner; keep bar status short.
            self._set_status(s.message or "Connect failed — still LOCAL")
            self.btn_connect.setText("Retry")
            self.btn_connect.setEnabled(True)
            self.btn_connect.setVisible(True)
            self.btn_disconnect.setEnabled(False)
            self.btn_disconnect.setVisible(False)
            return

        if remote_pick or s.state == "candidate":
            self._set_status(s.message or "Press Connect — still on LOCAL")
            self.btn_connect.setText("Connect")
            self.btn_connect.setEnabled(True)
            self.btn_connect.setVisible(True)
            self.btn_disconnect.setEnabled(False)
            self.btn_disconnect.setVisible(False)
            return

        self._set_status("")
        self.btn_connect.setVisible(False)
        self.btn_disconnect.setVisible(False)

    def _set_session_chrome(self, mode: str, text: str) -> None:
        self._chip.setText(text)
        self._chip.setProperty("sessionMode", mode)
        self.setProperty("sessionMode", mode)
        # Force stylesheet re-eval for dynamic properties.
        self._chip.style().unpolish(self._chip)
        self._chip.style().polish(self._chip)
        self.style().unpolish(self)
        self.style().polish(self)
        self._chip.update()
        self.update()
