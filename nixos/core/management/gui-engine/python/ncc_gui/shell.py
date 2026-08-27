"""Multi-domain shell: Chrome (nav/target/gate) + one Document (domain page).

Architecture (see doc/performance.md, GUI-DESIGN §12):

* **Process** — soft/hard generation in ``ncc_gui.reload`` (kit hash).
* **State** — catalog in ``ShellChromeState``; target in ``target_session``.
* **View** — this chrome projects state; domain pages are ephemeral documents
  (rebuilt on navigate, except sticky ``ai`` / ``ssh``). Soft generation
  refreshes the catalog and **recreates** the current document.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from PySide6.QtCore import QSettings, QSize, QTimer, Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.branding import app_icon
from ncc_gui.catalog import DomainInfo
from ncc_gui.chrome_prefs import hide_inactive_features
from ncc_gui.reload import generation_bus
from ncc_gui.shell_state import STICKY_DOMAIN_IDS, ShellChromeState
from ncc_gui.target_bar import TargetBar
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_probe import EXPECTED_CONFIG_VERSION
from ncc_gui.session_ux import session_mode
from ncc_gui.target_session import TargetSession, session_controller
from ncc_gui.target_state import LOCAL_ONLY_DOMAINS
from ncc_gui.theme import APP_STYLE

PageBuilder = Callable[[DomainInfo], QWidget]

_ROLE_SECTION = Qt.ItemDataRole.UserRole
_ROLE_DOMAIN = Qt.ItemDataRole.UserRole + 1

_SETTINGS_ORG = "NixOSControlCenter"
_SETTINGS_APP = "ncc-gui"
_GEOMETRY_KEY = "shell/geometry"

# Domains visible while a remote session is gated (plus LOCAL_ONLY always).
_GATE_ALLOW: dict[str, frozenset[str]] = {
    "blocked": frozenset({"ssh"}),
    "needs_install": frozenset({"ssh", "install"}),
    "needs_update": frozenset({"ssh", "install", "system"}),
}


@dataclass
class _NavRow:
    """Nav list row: section header or domain id."""

    kind: str  # "section" | "domain"
    info: DomainInfo | None = None


class NccShell(QMainWindow):
    """Chrome = sidebar + target + gate; Document = one mounted domain page."""

    def __init__(
        self,
        domains: list[DomainInfo],
        build_page: PageBuilder,
        title: str = "NixOS Control Center",
    ) -> None:
        super().__init__()
        # DomainPage soft-reload skips when under chrome shell (document recreate).
        self._is_ncc_chrome_shell = True
        self.setWindowTitle(title)
        self.setMinimumSize(800, 520)
        self.setStyleSheet(APP_STYLE)

        self._build_page = build_page
        self._state = ShellChromeState(domains=list(domains))
        # Catalog ``enabled`` = module active on the GUI host (cfg.enable at build).
        self._catalog_active = {d.id: d.enabled for d in domains}
        self._nav_rows: list[_NavRow] = []
        self._current_id: str | None = None
        self._current_page: QWidget | None = None
        self._sticky: dict[str, QWidget] = {}
        self._geom_lock: QSize | None = None
        self._geom_save_timer = QTimer(self)
        self._geom_save_timer.setSingleShot(True)
        self._geom_save_timer.setInterval(400)
        self._geom_save_timer.timeout.connect(self._persist_geometry)

        self._restore_geometry()

        self._doc_host = QWidget()
        self._doc_host.setObjectName("nccDocumentHost")
        self._doc_host.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self._doc_layout = QVBoxLayout(self._doc_host)
        self._doc_layout.setContentsMargins(0, 0, 0, 0)
        self._doc_layout.setSpacing(0)

        # Hidden park for sticky documents (ai / ssh) while another domain is shown.
        self._park = QWidget(self)
        self._park.hide()
        self._park_layout = QVBoxLayout(self._park)
        self._park_layout.setContentsMargins(0, 0, 0, 0)

        self._nav = QListWidget()
        self._nav.setObjectName("nccNav")
        self._nav.setFixedWidth(200)

        self._rebuild_nav()
        self._nav.currentRowChanged.connect(self._on_nav_row)
        generation_bus().soft_switched.connect(self._on_soft_generation)

        self._target = TargetBar(persist=True)
        self._target.targetChanged.connect(self._on_target)
        self._target.chromeChanged.connect(self._on_chrome_prefs)
        target_bus().chromePrefsChanged.connect(self._on_chrome_prefs)
        session_controller().sessionChanged.connect(self._on_session)
        target_bus().navigate.connect(self._on_navigate)

        self._gate = self._build_gate_banner()

        root = QWidget()
        root.setObjectName("nccShellRoot")
        outer = QVBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        outer.addWidget(self._target, stretch=0)
        outer.addWidget(self._gate, stretch=0)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        left = QVBoxLayout()
        brand_row = QHBoxLayout()
        brand_row.setContentsMargins(12, 14, 12, 0)
        brand_row.setSpacing(10)
        icon_lbl = QLabel()
        icon = app_icon()
        if not icon.isNull():
            self.setWindowIcon(icon)
            icon_lbl.setPixmap(icon.pixmap(36, 36))
        brand_row.addWidget(icon_lbl)
        brand_col = QVBoxLayout()
        brand_col.setSpacing(0)
        brand = QLabel("NCC")
        brand.setObjectName("nccPageTitle")
        brand_col.addWidget(brand)
        hint = QLabel("Control Center")
        hint.setObjectName("nccPageSubtitle")
        brand_col.addWidget(hint)
        brand_row.addLayout(brand_col, stretch=1)
        left.addLayout(brand_row)
        left.addWidget(self._nav, stretch=1)
        left_wrap = QWidget()
        left_wrap.setLayout(left)
        left_wrap.setFixedWidth(200)
        body.addWidget(left_wrap)
        body.addWidget(self._doc_host, stretch=1)
        body_w = QWidget()
        body_w.setLayout(body)
        body_w.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        outer.addWidget(body_w, stretch=1)
        self.setCentralWidget(root)

        self._on_session(session_controller().session())
        self._select_first_visible()

    # ----- document mount (View) -----

    def _persist_page(self, page: QWidget | None) -> None:
        if page is None:
            return
        fn = getattr(page, "_persist_activity", None)
        if callable(fn):
            try:
                fn()
            except Exception:
                pass

    def _clear_doc_layout(self) -> None:
        while self._doc_layout.count():
            item = self._doc_layout.takeAt(0)
            w = item.widget()
            if w is not None:
                w.setParent(None)

    def _park_page(self, domain_id: str, page: QWidget) -> None:
        self._persist_page(page)
        page.setParent(self._park)
        self._park_layout.addWidget(page)
        page.hide()
        self._sticky[domain_id] = page

    def _destroy_page(self, page: QWidget) -> None:
        self._persist_page(page)
        page.setParent(None)
        page.deleteLater()

    def _drop_sticky(self, domain_id: str | None = None) -> None:
        if domain_id is None:
            ids = list(self._sticky.keys())
        else:
            ids = [domain_id] if domain_id in self._sticky else []
        for did in ids:
            page = self._sticky.pop(did, None)
            if page is not None:
                self._destroy_page(page)

    def _unmount_current(self, *, keep_sticky: bool) -> None:
        page = self._current_page
        did = self._current_id
        self._current_page = None
        self._current_id = None
        self._state.current_domain_id = None
        if page is None or did is None:
            return
        self._clear_doc_layout()
        if keep_sticky and did in STICKY_DOMAIN_IDS:
            self._park_page(did, page)
        else:
            self._destroy_page(page)

    def _mount_domain(self, domain_id: str, *, force: bool = False) -> None:
        """Show domain document. ``force`` rebuilds even if already current."""
        info = self._state.info(domain_id)
        if info is None or not info.enabled:
            return
        if (
            not force
            and self._current_id == domain_id
            and self._current_page is not None
        ):
            return

        # Keep window geometry stable across document swaps (user resize only).
        geom = self.geometry()

        self._unmount_current(keep_sticky=not force)

        if force:
            self._drop_sticky(domain_id)

        page = self._sticky.pop(domain_id, None)
        if page is None:
            page = self._build_page(info)
        else:
            page.show()

        page.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self._clear_doc_layout()
        self._doc_layout.addWidget(page)
        self._current_page = page
        self._current_id = domain_id
        self._state.current_domain_id = domain_id

        if self.isVisible():
            self.setGeometry(geom)

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        if self.isVisible():
            self._geom_lock = self.size()
            self._geom_save_timer.start()

    def moveEvent(self, event) -> None:  # noqa: N802
        super().moveEvent(event)
        if self.isVisible():
            self._geom_save_timer.start()

    def closeEvent(self, event) -> None:  # noqa: N802
        self._persist_geometry()
        super().closeEvent(event)

    def _settings(self) -> QSettings:
        return QSettings(_SETTINGS_ORG, _SETTINGS_APP)

    def _restore_geometry(self) -> None:
        raw = self._settings().value(_GEOMETRY_KEY)
        if raw is not None and self.restoreGeometry(raw):
            self._geom_lock = self.size()
            return
        self.resize(1120, 740)
        self._geom_lock = QSize(1120, 740)

    def _persist_geometry(self) -> None:
        self._settings().setValue(_GEOMETRY_KEY, self.saveGeometry())

    def sizeHint(self) -> QSize:  # noqa: N802
        if self._geom_lock is not None:
            return self._geom_lock
        return QSize(1120, 740)

    # ----- gate / chrome -----

    def _build_gate_banner(self) -> QFrame:
        frame = QFrame()
        frame.setObjectName("nccGateBanner")
        frame.hide()
        frame.setMinimumHeight(44)
        frame.setMaximumHeight(72)
        row = QHBoxLayout(frame)
        row.setContentsMargins(12, 8, 12, 8)
        self._gate_msg = QLabel()
        self._gate_msg.setObjectName("nccGateMessage")
        self._gate_msg.setWordWrap(True)
        self._gate_msg.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred
        )
        row.addWidget(self._gate_msg, stretch=1)
        self._gate_btn = QPushButton()
        self._gate_btn.setObjectName("nccPrimaryButton")
        self._gate_btn.clicked.connect(self._on_gate_action)
        row.addWidget(self._gate_btn)
        self._gate_secondary = QPushButton("Open System")
        self._gate_secondary.clicked.connect(self._on_gate_secondary)
        row.addWidget(self._gate_secondary)
        self._gate_action = ""
        self._gate_secondary_action = ""
        return frame

    def _rebuild_nav(self) -> None:
        self._nav.blockSignals(True)
        self._nav.clear()
        self._nav_rows = []

        for group_id, title in (("core", "Core"), ("features", "Features")):
            group_domains = [info for info in self._state.domains if info.group == group_id]
            if not group_domains:
                continue

            hdr = QListWidgetItem(title)
            hdr.setFlags(Qt.ItemFlag.NoItemFlags)
            font = QFont()
            font.setBold(True)
            font.setPointSize(max(font.pointSize() - 1, 9))
            hdr.setFont(font)
            hdr.setData(_ROLE_SECTION, True)
            self._nav.addItem(hdr)
            self._nav_rows.append(_NavRow(kind="section"))

            for info in group_domains:
                item = QListWidgetItem(f"  {info.label}")
                item.setFlags(
                    Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled
                )
                item.setData(_ROLE_SECTION, False)
                item.setData(_ROLE_DOMAIN, info.id)
                self._nav.addItem(item)
                self._nav_rows.append(_NavRow(kind="domain", info=info))

        self._nav.blockSignals(False)

    def _on_nav_row(self, row: int) -> None:
        if row < 0 or row >= len(self._nav_rows):
            return
        nav = self._nav_rows[row]
        if nav.kind != "domain" or nav.info is None:
            return
        self._mount_domain(nav.info.id)

    def select_domain(self, domain_id: str) -> None:
        for i, row in enumerate(self._nav_rows):
            if row.kind == "domain" and row.info and row.info.id == domain_id:
                item = self._nav.item(i)
                if item is not None and not item.isHidden():
                    self._nav.setCurrentRow(i)
                return

    def current_domain_id(self) -> str | None:
        return self._current_id or self._state.current_domain_id

    def _select_first_visible(self) -> None:
        for i, row in enumerate(self._nav_rows):
            if row.kind != "domain":
                continue
            item = self._nav.item(i)
            if item is not None and not item.isHidden():
                self._nav.setCurrentRow(i)
                return

    def _on_chrome_prefs(self) -> None:
        """Target chrome toggled — refresh gate / nav for local-only mode."""
        self._on_session(session_controller().session())

    def _on_navigate(self, domain_id: object) -> None:
        if isinstance(domain_id, str) and domain_id.strip():
            self.select_domain(domain_id.strip())

    def _on_target(self, target: object) -> None:
        t = target if isinstance(target, str) and target.strip() else None
        target_bus().changed.emit(t)
        cur = self._nav.currentRow()
        item = self._nav.item(cur) if cur >= 0 else None
        if item is None or item.isHidden() or (
            cur < len(self._nav_rows) and self._nav_rows[cur].kind == "section"
        ):
            self._select_first_visible()

    def _on_session(self, session: object) -> None:
        if not isinstance(session, TargetSession):
            return
        target_bus().sessionChanged.emit(session)
        self._update_gate_banner(session)
        self._apply_nav_for_session(session)
        cur = self._nav.currentRow()
        item = self._nav.item(cur) if cur >= 0 else None
        if item is None or item.isHidden() or (
            cur < len(self._nav_rows) and self._nav_rows[cur].kind == "section"
        ):
            self._select_first_visible()

    def _set_gate_kind(self, kind: str) -> None:
        self._gate.setProperty("gateKind", kind)
        self._gate.style().unpolish(self._gate)
        self._gate.style().polish(self._gate)
        self._gate.update()

    def _update_gate_banner(self, s: TargetSession) -> None:
        # No fleet chrome → no gate strip.
        if not self._target.target_chrome_visible():
            self._gate.hide()
            return
        gate = s.state
        mode = session_mode(s)

        # Pending select: soft strip so selection ≠ connection is obvious.
        if mode == "pending" and gate == "candidate":
            host = s.candidate or "host"
            self._gate_msg.setText(
                f"{host} selected — still operating on LOCAL. "
                "Press Connect to switch the session."
            )
            self._gate_btn.setText("Connect")
            self._gate_btn.setEnabled(True)
            self._gate_btn.show()
            self._gate_secondary.setText("Clear")
            self._gate_secondary.show()
            self._gate_action = "connect"
            self._gate_secondary_action = "clear"
            self._set_gate_kind("warn")
            self._gate.show()
            return

        if gate in ("idle", "ready", "connecting"):
            self._gate.hide()
            return
        if gate not in ("blocked", "needs_install", "needs_update"):
            self._gate.hide()
            return

        self._gate_msg.setText(s.message or "")
        if gate == "needs_install":
            self._gate_btn.setText("Open Install")
            self._gate_btn.setEnabled(True)
            self._gate_btn.show()
            self._gate_secondary.hide()
            self._gate_action = "install"
            self._gate_secondary_action = ""
            self._set_gate_kind("warn")
        elif gate == "needs_update":
            self._gate_btn.setText(f"Update to {EXPECTED_CONFIG_VERSION}")
            self._gate_btn.setEnabled(True)
            self._gate_btn.show()
            self._gate_secondary.hide()
            self._gate_action = "update"
            self._gate_secondary_action = ""
            self._set_gate_kind("warn")
        elif s.connected:
            # Connected but blocked (e.g. not NixOS) — leave remote session.
            self._gate_btn.setText("Disconnect")
            self._gate_btn.setEnabled(True)
            self._gate_btn.show()
            self._gate_secondary.hide()
            self._gate_action = "disconnect"
            self._gate_secondary_action = ""
            self._set_gate_kind("danger")
        else:
            # Unreachable / failed Connect — still LOCAL; make it unmissable.
            if not (s.message or "").strip():
                self._gate.hide()
                return
            self._gate_btn.setText("Retry Connect")
            self._gate_btn.setEnabled(bool(s.candidate))
            self._gate_btn.setVisible(bool(s.candidate))
            self._gate_secondary.setText("Use this machine")
            self._gate_secondary.show()
            self._gate_action = "retry"
            self._gate_secondary_action = "clear"
            self._set_gate_kind("danger")
        self._gate.show()

    def _on_gate_secondary(self) -> None:
        action = getattr(self, "_gate_secondary_action", "")
        if action == "clear":
            self._gate_action = "clear"
            self._on_gate_action()
            return
        self.select_domain("system")

    def _on_gate_action(self) -> None:
        action = getattr(self, "_gate_action", "")
        ctrl = session_controller()
        if action == "disconnect":
            ctrl.disconnect_target()
            target_bus().changed.emit(None)
        elif action == "clear":
            ctrl.disconnect_target()
            self._target.set_target(None, emit=True)
            target_bus().changed.emit(None)
        elif action == "connect" or action == "retry":
            host = ctrl.session().candidate
            if host:
                ctrl.connect_target(host)
        elif action == "install":
            self.select_domain("install")
            target_bus().navigate.emit("install")
        elif action == "update":
            # Open System + source modal (Host tree or GitHub branch → Target).
            self.select_domain("system")
            target_bus().navigate.emit("system")
            target_bus().systemAction.emit("update-config")

    def _on_soft_generation(self) -> None:
        """Catalog/data changed, same GUI kit — refresh chrome + recreate document."""
        keep_id = self.current_domain_id()
        if not self._state.refresh_catalog():
            return

        # Drop parked sticky docs — generation may have new domain page dumps.
        self._drop_sticky()

        self._catalog_active = {d.id: d.enabled for d in self._state.domains}
        self._rebuild_nav()
        self._apply_nav_for_session(session_controller().session())

        keep_visible = False
        if keep_id:
            for i, row in enumerate(self._nav_rows):
                if row.kind == "domain" and row.info and row.info.id == keep_id:
                    item = self._nav.item(i)
                    keep_visible = item is not None and not item.isHidden()
                    break
        if keep_id and keep_visible:
            # Remount even if same id — fresh widgets from new catalog paths.
            self._nav.blockSignals(True)
            for i, row in enumerate(self._nav_rows):
                if row.kind == "domain" and row.info and row.info.id == keep_id:
                    item = self._nav.item(i)
                    if item is not None and not item.isHidden():
                        self._nav.setCurrentRow(i)
                    break
            self._nav.blockSignals(False)
            self._mount_domain(keep_id, force=True)
        else:
            self._unmount_current(keep_sticky=False)
            self._select_first_visible()

    def _apply_nav_for_session(self, session: TargetSession) -> None:
        """Project sidebar visibility.

        Rules (config manager):
        * Core domains: always visible (gate permitting) — enable is a page field.
        * Feature domains: visible unless Settings → Hide inactive features.
        * Active/Off badge from Target systemConfig when connected; else catalog.
        """
        remote = session.connected
        gate = session.state
        hide_inactive = hide_inactive_features()

        allow: frozenset[str] | None = None
        if remote and gate in _GATE_ALLOW:
            allow = _GATE_ALLOW[gate] | LOCAL_ONLY_DOMAINS
        elif remote and gate == "connecting":
            allow = LOCAL_ONLY_DOMAINS

        probe = session.probe
        target_enables: dict[str, bool] = {}
        if probe is not None and isinstance(probe.module_enables, dict):
            target_enables = dict(probe.module_enables)
        elif probe is not None and probe.desktop_enable is not None:
            target_enables = {"desktop": probe.desktop_enable}

        use_target_active = bool(remote) and gate == "ready" and bool(target_enables)

        for info in self._state.domains:
            catalog_on = self._catalog_active.get(info.id, False)
            if use_target_active and info.id in target_enables:
                active = bool(target_enables[info.id])
            else:
                active = catalog_on

            # Gate: only allowlisted domains while remote is blocked/install/update.
            if info.id in LOCAL_ONLY_DOMAINS:
                # SSH stays local; still respect catalog presence.
                visible = True
            elif allow is not None:
                visible = info.id in allow
            elif info.group == "core":
                visible = True
            elif hide_inactive:
                visible = active
            else:
                visible = True

            info.enabled = visible

            # Stash for badge rendering (not a DomainInfo field).
            setattr(info, "_active", active)

        visible_in_group: dict[str, int] = {"core": 0, "features": 0}
        for i, row in enumerate(self._nav_rows):
            item = self._nav.item(i)
            if item is None:
                continue
            if row.kind == "section":
                continue
            assert row.info is not None
            visible = row.info.enabled
            active = bool(getattr(row.info, "_active", True))
            item.setHidden(not visible)
            if visible:
                visible_in_group[row.info.group] = (
                    visible_in_group.get(row.info.group, 0) + 1
                )
                label = row.info.label
                if active:
                    item.setText(f"  {label}")
                    item.setToolTip("")
                else:
                    item.setText(f"  {label} · Off")
                    where = remote or "this machine"
                    item.setToolTip(
                        f"{label} disabled on {where} (systemConfig) — "
                        "open to review or enable"
                    )
            elif remote and allow is not None:
                item.setText(f"  {row.info.label}")
                item.setToolTip(f"Connect / unlock on {remote} first")
            else:
                item.setText(f"  {row.info.label}")
                item.setToolTip(f"Hidden (“{row.info.id}”)")

        for i, row in enumerate(self._nav_rows):
            if row.kind != "section":
                continue
            item = self._nav.item(i)
            if item is None:
                continue
            title = item.text().strip().lower()
            group = "core" if title == "core" else "features"
            item.setHidden(visible_in_group.get(group, 0) == 0)
