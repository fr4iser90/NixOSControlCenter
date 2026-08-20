"""NCC GUI page kit — Header → Content → Activity → Footer (Actions).

Use ``DomainPage`` for every domain ``ui/gui/page.py``. See doc/GUI-DESIGN.md.
"""

from __future__ import annotations

import shutil
import subprocess
from collections.abc import Callable, Sequence
from dataclasses import dataclass

from PySide6.QtCore import QProcess, QProcessEnvironment, QSize, Qt, QTimer
from PySide6.QtWidgets import (
    QFormLayout,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QStyle,
    QTextEdit,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.commit_bar import CommitController
from ncc_gui.dialogs import confirm, error, summarize_command_failure
from ncc_gui.reload import generation_bus, load_activity, save_activity
from ncc_gui.session_ux import confirm_session_write, operating_on_line, session_mode
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_session import current_session
from ncc_gui.theme import APP_STYLE
from ncc_gui.widgets import FormValueLabel, audit_wrapping_labels, layout_debug_enabled


@dataclass(frozen=True)
class DeclaredAction:
    """Footer button contract for tests / catalog checks.

    Every ``add_action`` must set either ``ncc=(domain, verb, …)`` (CLI path the
    button intends) or ``local=True`` (UI-only: refresh, dialogs, raw ssh, …).
    """

    label: str
    ncc: tuple[str, ...] | None
    local: bool


class DomainPage(QWidget):
    """
    Complete page scaffold from gui-engine.

    Order is fixed (app-like footer):
      1. Header (title + subtitle)
      2. Content blocks (stretch)
      3. Activity log (optional)
      4. Footer Actions — domain buttons left, CommitBar right (pinned bottom)

    Config writes go through ``self.commit`` (stage → Save/Undo → Apply).
    """

    def __init__(
        self,
        title: str,
        subtitle: str = "",
        *,
        activity: bool = True,
        activity_max_height: int | None = 180,
        commit_bar: bool = True,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._declared_actions: list[DeclaredAction] = []
        self.setStyleSheet(APP_STYLE)
        # Fill the shell document host — never drive top-level window size.
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self._proc: QProcess | None = None
        self._on_proc_done: Callable[[int], None] | None = None
        # Persist Activity across hard GUI re-exec (generation watcher).
        self._activity_key = (
            "".join(c if c.isalnum() or c in "-_" else "-" for c in title.strip().lower())
            or "page"
        )
        self._root = QVBoxLayout(self)
        self._root.setContentsMargins(20, 16, 20, 16)
        self._root.setSpacing(8)
        root = self._root

        # 1. Header (title + optional trailing controls, then subtitle) — pinned top
        self._header_row = QHBoxLayout()
        heading = QLabel(title)
        heading.setObjectName("nccPageTitle")
        self._header_row.addWidget(heading, stretch=1)
        self._header_trailing = QHBoxLayout()
        self._header_trailing.setSpacing(6)
        self._header_row.addLayout(self._header_trailing)
        root.addLayout(self._header_row, stretch=0)
        self._subtitle = QLabel(subtitle)
        self._subtitle.setObjectName("nccPageSubtitle")
        self._subtitle.setWordWrap(True)
        self._subtitle.setVisible(bool(subtitle))
        root.addWidget(self._subtitle, stretch=0)
        self._scope = QLabel("")
        self._scope.setObjectName("nccOperatingScope")
        self._scope.setWordWrap(True)
        root.addWidget(self._scope, stretch=0)
        self._refresh_operating_scope()
        target_bus().sessionChanged.connect(self._on_session_scope)

        # 2. Content (scrolls inside fixed chrome — does not push footer)
        self._content_host = QWidget()
        self._content = QVBoxLayout(self._content_host)
        self._content.setContentsMargins(0, 0, 0, 0)
        self._content.setSpacing(8)
        self._content_scroll = QScrollArea()
        self._content_scroll.setObjectName("nccContentScroll")
        self._content_scroll.setWidgetResizable(True)
        self._content_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        self._content_scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )
        self._content_scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )
        self._content_scroll.setWidget(self._content_host)
        self._content_scroll.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        root.addWidget(self._content_scroll, stretch=1)

        # 3. Activity (above footer — capped height so it cannot shove footer)
        self._activity_box: QGroupBox | None = None
        self.log: QTextEdit | None = None
        if activity:
            self._activity_box = QGroupBox("Activity")
            self._activity_box.setSizePolicy(
                QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
            )
            log_l = QVBoxLayout(self._activity_box)
            self.log = QTextEdit()
            self.log.setObjectName("nccActivityLog")
            self.log.setReadOnly(True)
            self.log.setPlaceholderText("Command output appears here after an action…")
            cap = 180 if activity_max_height is None else activity_max_height
            self.log.setMinimumHeight(80)
            self.log.setMaximumHeight(max(80, cap))
            log_l.addWidget(self.log)
            root.addWidget(self._activity_box, stretch=0)
            restored = load_activity(self._activity_key)
            if restored.strip():
                self.log.setPlainText(restored)

        # Soft generation switch: refresh widgets, keep Activity / window.
        generation_bus().soft_switched.connect(self._on_soft_generation)

        # 4. Footer — domain buttons (wrap grid, no scrollbar) + CommitBar right
        self._actions_box = QGroupBox("Actions")
        self._actions_box.setObjectName("nccPageFooter")
        self._actions_box.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum
        )
        self._actions_col = QVBoxLayout(self._actions_box)
        footer_row = QHBoxLayout()
        footer_row.setSpacing(8)
        self._button_grid = QGridLayout()
        self._button_grid.setHorizontalSpacing(6)
        self._button_grid.setVerticalSpacing(6)
        self._button_cols = 4
        self._button_count = 0
        # Keep name for older call sites that touch _button_row
        self._button_row = self._button_grid
        btn_wrap = QWidget()
        btn_wrap.setLayout(self._button_grid)
        btn_wrap.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum
        )
        footer_row.addWidget(btn_wrap, stretch=1)
        self._has_action_button = False
        self.commit: CommitController | None = None
        if commit_bar:
            self.commit = CommitController(self)
            footer_row.addWidget(self.commit.bar, stretch=0)
            self._actions_box.setVisible(True)
        else:
            self._actions_box.setVisible(False)
        self._actions_col.addLayout(footer_row)
        root.addWidget(self._actions_box, stretch=0)

    def sizeHint(self) -> QSize:  # noqa: N802
        return QSize(0, 0)

    def minimumSizeHint(self) -> QSize:  # noqa: N802
        return QSize(0, 0)

    # ----- header -----

    def set_subtitle(self, text: str) -> None:
        self._subtitle.setText(text)
        self._subtitle.setVisible(bool(text.strip()))

    def _on_session_scope(self, _session: object = None) -> None:
        self._refresh_operating_scope()

    def _refresh_operating_scope(self) -> None:
        session = current_session()
        mode = session_mode(session)
        self._scope.setText(operating_on_line(session))
        self._scope.setProperty("sessionMode", mode)
        self._scope.style().unpolish(self._scope)
        self._scope.style().polish(self._scope)
        self._scope.update()

    def confirm_scope_write(self, action: str = "This action") -> bool:
        """Block accidental LOCAL writes while a remote host is selected/failed."""
        return confirm_session_write(
            self, current_session(), action=action
        )

    def add_header_action(
        self,
        slot: Callable[[], None],
        *,
        tooltip: str = "Settings",
        icon: str | None = "configure",
    ) -> QToolButton:
        """Compact header control (e.g. settings gear) — not an Actions footer button."""
        btn = QToolButton()
        btn.setToolTip(tooltip)
        btn.setAutoRaise(True)
        btn.setObjectName("nccHeaderAction")
        from PySide6.QtGui import QIcon

        qicon = QIcon.fromTheme(icon or "configure")
        if qicon.isNull():
            qicon = QIcon.fromTheme("preferences-system")
        if qicon.isNull():
            qicon = self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogDetailedView)
        btn.setIcon(qicon)
        if qicon.isNull():
            btn.setText("…")
        btn.clicked.connect(lambda _=False: slot())
        self._header_trailing.addWidget(btn)
        return btn

    # ----- content -----

    def add_block(self, title: str) -> QGroupBox:
        """Framed content block (Settings, Status, Stacks, …)."""
        box = QGroupBox(title)
        self._content.addWidget(box)
        return box

    def add_form_block(self, title: str) -> QFormLayout:
        """Status/settings form. Value cells should use ``add_form_value``."""
        box = self.add_block(title)
        form = QFormLayout(box)
        form.setRowWrapPolicy(QFormLayout.RowWrapPolicy.WrapLongRows)
        form.setFieldGrowthPolicy(
            QFormLayout.FieldGrowthPolicy.ExpandingFieldsGrow
        )
        form.setLabelAlignment(
            Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop
        )
        form.setFormAlignment(
            Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop
        )
        form.setHorizontalSpacing(16)
        form.setVerticalSpacing(8)
        return form

    def add_form_value(
        self,
        form: QFormLayout,
        label: str,
        text: str = "—",
    ) -> FormValueLabel:
        """Status/body row via ``FormValueLabel`` (must use for wrapping text)."""
        value = FormValueLabel(text)
        form.addRow(label, value)
        return value

    def add_list_block(self, title: str) -> tuple[QGroupBox, QListWidget]:
        """Content block with a list (hosts, stacks, users, …)."""
        box = self.add_block(title)
        col = QVBoxLayout(box)
        lst = QListWidget()
        col.addWidget(lst)
        return box, lst

    def showEvent(self, event) -> None:  # noqa: N802
        super().showEvent(event)
        if layout_debug_enabled():
            QTimer.singleShot(
                0,
                lambda: audit_wrapping_labels(self, context=type(self).__name__),
            )

    def add_content_widget(self, widget: QWidget, *, stretch: int = 0) -> None:
        """Add a pre-built widget into the content zone (e.g. splitter)."""
        self._content.addWidget(widget, stretch=stretch)

    def add_content_layout(self, layout) -> None:
        self._content.addLayout(layout)

    def set_busy(self) -> bool:
        """True if a root process is already running (shows error)."""
        if self._proc is not None and self._proc.state() != QProcess.ProcessState.NotRunning:
            error(self, "Busy", "A command is already running.")
            return True
        return False

    # ----- actions -----

    def _ensure_actions_visible(self) -> None:
        self._actions_box.setVisible(True)

    def add_actions_hint(self, text: str) -> QLabel:
        self._ensure_actions_visible()
        tip = QLabel(text)
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        # Insert above button row
        self._actions_col.insertWidget(self._actions_col.count() - 1, tip)
        return tip

    def add_actions_widget(self, widget: QWidget) -> None:
        """Checkbox / extra control inside Actions (above buttons)."""
        self._ensure_actions_visible()
        self._actions_col.insertWidget(self._actions_col.count() - 1, widget)

    def add_action(
        self,
        label: str,
        slot: Callable[[], None],
        *,
        primary: bool = False,
        ncc: Sequence[str] | None = None,
        local: bool = False,
    ) -> QPushButton:
        """Register a footer button.

        Pass ``ncc=("domain", "verb", …)`` when the button runs ``ncc`` (first
        two tokens must be registered in cli-registry). Pass ``local=True`` for
        non-ncc actions (Refresh, dialogs, commit staging, raw ssh, …).
        One of ``ncc`` / ``local`` is required so tests can cover every button.
        """
        if ncc is not None and local:
            raise ValueError(f"add_action({label!r}): ncc= and local= are mutually exclusive")
        if ncc is None and not local:
            raise ValueError(
                f"add_action({label!r}): pass ncc=(domain, verb, …) or local=True"
            )
        argv: tuple[str, ...] | None = None
        if ncc is not None:
            argv = tuple(str(x) for x in ncc)
            if not argv:
                raise ValueError(f"add_action({label!r}): ncc= must be non-empty")
            if any(not a for a in argv):
                raise ValueError(f"add_action({label!r}): ncc= tokens must be non-empty")
        self._declared_actions.append(
            DeclaredAction(label=label, ncc=argv, local=local)
        )

        self._ensure_actions_visible()
        btn = QPushButton(label)
        btn.clicked.connect(lambda _=False: slot())
        if primary:
            btn.setObjectName("nccPrimaryButton")
        idx = self._button_count
        if primary and not self._has_action_button:
            # Shift existing buttons right by one slot
            widgets: list[QWidget] = []
            while self._button_grid.count():
                item = self._button_grid.takeAt(0)
                w = item.widget()
                if w is not None:
                    widgets.append(w)
            self._button_grid.addWidget(btn, 0, 0)
            for i, w in enumerate(widgets, start=1):
                r, c = divmod(i, self._button_cols)
                self._button_grid.addWidget(w, r, c)
            self._button_count = 1 + len(widgets)
        else:
            r, c = divmod(idx, self._button_cols)
            self._button_grid.addWidget(btn, r, c)
            self._button_count = idx + 1
        self._has_action_button = True
        return btn

    # ----- activity -----

    def _persist_activity(self) -> None:
        if self.log is None:
            return
        save_activity(self._activity_key, self.log.toPlainText())

    def _chrome_shell_ancestor(self) -> bool:
        """True when hosted by multi-domain ``NccShell`` (document recreate owns soft)."""
        obj: QWidget | None = self.parentWidget()
        while obj is not None:
            if getattr(obj, "_is_ncc_chrome_shell", False):
                return True
            obj = obj.parentWidget()
        return False

    def _on_soft_generation(self) -> None:
        """Standalone domain windows: reload visible page. Shell: skip (recreate)."""
        if self._chrome_shell_ancestor():
            return
        if not self.isVisible():
            return
        reload_fn = getattr(self, "reload", None)
        if callable(reload_fn):
            try:
                reload_fn()
            except Exception:
                pass

    def log_clear(self) -> None:
        if self.log is not None:
            self.log.clear()
            self._persist_activity()

    def log_append(self, text: str) -> None:
        if self.log is None:
            return
        self.log.append(strip_ansi(text))
        self._persist_activity()

    def log_write(self, text: str) -> None:
        """Append without extra bullet formatting; strips ANSI."""
        if self.log is None:
            return
        plain = strip_ansi(text)
        self.log.moveCursor(self.log.textCursor().MoveOperation.End)
        self.log.insertPlainText(plain)
        self.log.moveCursor(self.log.textCursor().MoveOperation.End)
        self._persist_activity()

    # ----- run ncc -----

    def run_ncc(
        self,
        *args: str,
        need_confirm: str | None = None,
        timeout: float | None = 180,
        follow_target: bool = False,
        target: str | None = None,
        log: bool = True,
        show_error: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        """Sync ``ncc``. With ``follow_target=True``, uses global Target / env."""
        if need_confirm and not confirm(self, need_confirm, f"Run “{need_confirm}” now?"):
            return subprocess.CompletedProcess(args=["ncc", *args], returncode=0, stdout="", stderr="cancelled")
        from ncc_gui.remote import run_ncc as _run
        from ncc_gui.remote import target_from_env

        host = target
        if follow_target and host is None:
            host = target_from_env()
        proc = _run(*args, target=host, timeout=timeout)
        out = strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
        label = " ".join(args[:2]) if args else "ncc"
        pretty = out or ("Done." if proc.returncode == 0 else "Failed.")
        if log:
            where = f" @ {host}" if host else ""
            self.log_append(f"• {label}{where}\n{pretty}\n")
        if show_error and proc.returncode != 0:
            error(self, label, pretty)
        return proc

    def run_ncc_root(
        self,
        args: Sequence[str],
        *,
        label: str = "Apply",
        on_done: Callable[[int], None] | None = None,
        follow_target: bool = False,
    ) -> None:
        """Async elevated ``ncc …``. Prefer passwordless sudo, then pkexec.

        Local order (NOPASSWD admin must not see a password dialog):
          1. already root → ``ncc`` directly
          2. ``sudo -n`` works → ``sudo -n ncc …``
          3. pkexec
          4. interactive sudo

        With ``follow_target=True`` and a connected remote session:
          ``ssh host -- sudo -n ncc …`` (target user needs NOPASSWD sudo).
        """
        if not self.confirm_scope_write(label):
            return
        from ncc_gui.remote import build_elevated_ncc_argv, target_from_env

        host = target_from_env() if follow_target else None
        try:
            program, argv = build_elevated_ncc_argv(args, target=host)
        except PermissionError as e:
            error(self, label, str(e))
            return
        where = f" @ {host}" if host else ""
        self._start_ncc_process(
            program, argv, label=f"{label}{where}", on_done=on_done
        )

    def run_ncc_async(
        self,
        args: Sequence[str],
        *,
        label: str = "Run",
        on_done: Callable[[int], None] | None = None,
        env: dict[str, str] | None = None,
    ) -> None:
        """Async ``ncc …`` as the current user (script may self-elevate via ncc-priv)."""
        ncc = shutil.which("ncc") or "ncc"
        self._start_ncc_process(ncc, list(args), label=label, on_done=on_done, env=env)

    def _start_ncc_process(
        self,
        program: str,
        argv: Sequence[str],
        *,
        label: str,
        on_done: Callable[[int], None] | None,
        env: dict[str, str] | None = None,
    ) -> None:
        if self.set_busy():
            return
        self.log_append(f"• {label}\n")
        self._on_proc_done = on_done
        self._proc = QProcess(self)
        self._proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._proc.readyReadStandardOutput.connect(self._on_root_out)
        self._proc.finished.connect(lambda code, _s: self._finish_root(code, label))
        pe = QProcessEnvironment.systemEnvironment()
        if env:
            for key, val in env.items():
                pe.insert(key, val)
        self._proc.setProcessEnvironment(pe)
        self._proc.start(program, list(argv))
        if not self._proc.waitForStarted(5000):
            error(self, label, "Failed to start.")
            self._proc = None
            self._on_proc_done = None

    def _on_root_out(self) -> None:
        if self._proc is None:
            return
        data = bytes(self._proc.readAllStandardOutput()).decode("utf-8", errors="replace")
        if data:
            self.log_write(data)

    def _finish_root(self, code: int, label: str) -> None:
        self.log_append(f"\n[{label}] exit {code}\n")
        cb = self._on_proc_done
        self._proc = None
        self._on_proc_done = None
        if code != 0:
            log = self.log.toPlainText() if self.log is not None else ""
            short, copyable = summarize_command_failure(
                log, exit_code=code, label=label
            )
            error(
                self,
                label,
                short,
                details=copyable,
                copy_text=copyable,
            )
        if cb is not None:
            cb(code)


# Back-compat alias
PageScaffold = DomainPage
