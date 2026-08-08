"""Desktop — DomainPage kit (Settings draft → CommitBar → Activity)."""

from __future__ import annotations

from PySide6.QtWidgets import QCheckBox, QComboBox, QLabel

from ncc_gui.commit_bar import PendingChange
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage

_DESKTOP_OP = "desktop-set"


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def _snapshot_equal(a: dict[str, str], b: dict[str, str]) -> bool:
    keys = ("enable", "environment", "manager", "server", "dark")
    return all(a.get(k) == b.get(k) for k in keys)


class DesktopPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Desktop",
            "Change desktop environment, login screen, display server, and theme. "
            "Edits stay as a draft until Apply. Rebuild is offered after Apply. "
            "Changing DE, login, or Wayland/X11 usually needs a re-login.",
            parent=parent,
        )
        self._live: dict[str, str] = {
            "enable": "true",
            "environment": "plasma",
            "manager": "sddm",
            "server": "wayland",
            "dark": "true",
        }
        self._loading = False

        form = self.add_form_block("Settings")

        self.env = QComboBox()
        for v, lab in (
            ("plasma", "Plasma (KDE)"),
            ("gnome", "GNOME"),
            ("xfce", "XFCE"),
        ):
            self.env.addItem(lab, v)
        form.addRow("Desktop environment", self.env)

        self.manager = QComboBox()
        for v, lab in (
            ("sddm", "SDDM"),
            ("gdm", "GDM"),
            ("lightdm", "LightDM"),
        ):
            self.manager.addItem(lab, v)
        form.addRow("Login screen", self.manager)

        self.server = QComboBox()
        for v, lab in (
            ("wayland", "Wayland"),
            ("x11", "X11"),
            ("hybrid", "Hybrid"),
        ):
            self.server.addItem(lab, v)
        form.addRow("Display server", self.server)

        self.dark = QComboBox()
        self.dark.addItem("Dark", "true")
        self.dark.addItem("Light", "false")
        form.addRow("Theme", self.dark)

        self.enable = QCheckBox("Desktop module enabled")
        self.enable.setChecked(True)
        form.addRow("", self.enable)

        self.draft_lbl = QLabel("")
        self.draft_lbl.setObjectName("nccPageSubtitle")
        self.draft_lbl.setWordWrap(True)
        self.add_content_widget(self.draft_lbl)

        self.add_actions_hint(
            "Tweaks stage a draft (CommitBar). Apply writes config; "
            "rebuild makes it active on the system."
        )
        self.add_action("Reload", self.reload)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._on_pending_changed)

        self.env.currentIndexChanged.connect(self._on_env_changed)
        self.manager.currentIndexChanged.connect(self._on_field_changed)
        self.server.currentIndexChanged.connect(self._on_field_changed)
        self.dark.currentIndexChanged.connect(self._on_field_changed)
        self.enable.stateChanged.connect(self._on_field_changed)

        self.reload()

    def _set_combo(self, combo: QComboBox, value: str) -> None:
        for i in range(combo.count()):
            if combo.itemData(i) == value:
                combo.setCurrentIndex(i)
                return

    def _widget_snapshot(self) -> dict[str, str]:
        return {
            "enable": "true" if self.enable.isChecked() else "false",
            "environment": str(self.env.currentData()),
            "manager": str(self.manager.currentData()),
            "server": str(self.server.currentData()),
            "dark": str(self.dark.currentData()),
        }

    def _apply_snapshot(self, snap: dict[str, str]) -> None:
        self._loading = True
        try:
            self._set_combo(self.env, snap.get("environment", "plasma"))
            self._set_combo(self.manager, snap.get("manager", "sddm"))
            self._set_combo(self.server, snap.get("server", "wayland"))
            self._set_combo(self.dark, snap.get("dark", "true"))
            self.enable.setChecked(snap.get("enable", "true") == "true")
        finally:
            self._loading = False

    def _pending_desktop(self) -> PendingChange | None:
        assert self.commit is not None
        for ch in self.commit.pending:
            if ch.meta.get("op") == _DESKTOP_OP:
                return ch
        return None

    def _sync_manager_hint(self) -> None:
        env = self.env.currentData()
        if env == "gnome":
            self._set_combo(self.manager, "gdm")
        elif env == "plasma":
            self._set_combo(self.manager, "sddm")

    def _on_env_changed(self, _idx: int = 0) -> None:
        if self._loading:
            return
        self._loading = True
        try:
            self._sync_manager_hint()
        finally:
            self._loading = False
        self._stage_from_widgets()

    def _on_field_changed(self, *_args) -> None:
        if self._loading:
            return
        self._stage_from_widgets()

    def _stage_from_widgets(self) -> None:
        assert self.commit is not None
        snap = self._widget_snapshot()
        if _snapshot_equal(snap, self._live):
            self.commit.discard_where(
                lambda c: c.meta.get("op") == _DESKTOP_OP,
                log="• discarded desktop draft (matches live)\n",
            )
            self._update_draft_label()
            return
        env = snap["environment"]
        mgr = snap["manager"]
        server = snap["server"]
        dark = snap["dark"]
        enable = snap["enable"]
        summary = (
            f"desktop set env={env} login={mgr} server={server} "
            f"theme={'dark' if dark == 'true' else 'light'}"
        )
        argv = [
            "desktop",
            "set",
            f"enable={enable}",
            f"environment={env}",
            f"manager={mgr}",
            f"server={server}",
            f"session={env}",
            f"dark={dark}",
        ]
        self.commit.stage_replace(
            PendingChange(
                summary=summary,
                argv=argv,
                elevated=True,
                meta={"op": _DESKTOP_OP, "snapshot": dict(snap)},
            ),
            same=lambda a, b: a.meta.get("op") == b.meta.get("op") == _DESKTOP_OP,
        )
        self._update_draft_label()

    def _on_pending_changed(self) -> None:
        ch = self._pending_desktop()
        if ch is None:
            self._apply_snapshot(self._live)
        else:
            snap = ch.meta.get("snapshot")
            if isinstance(snap, dict):
                self._apply_snapshot({str(k): str(v) for k, v in snap.items()})
        self._update_draft_label()

    def _update_draft_label(self) -> None:
        ch = self._pending_desktop()
        if ch is None:
            self.draft_lbl.setText("Showing live settings.")
        else:
            self.draft_lbl.setText(
                "Draft settings (not written yet) — Save / Undo, then Apply."
            )

    def reload(self) -> None:
        proc = run_ncc("desktop", "status")
        kv = _parse_kv(proc.stdout or "")
        self._live = {
            "enable": kv.get("enable", "true"),
            "environment": kv.get("environment", "plasma"),
            "manager": kv.get("display.manager", "sddm"),
            "server": kv.get("display.server", "wayland"),
            "dark": "true" if kv.get("theme.dark", "true") == "true" else "false",
        }
        if proc.returncode != 0:
            from ncc_gui.ansi import strip_ansi

            self.log_append(
                "• Reload failed\n"
                + strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
                + "\n"
            )
        # Keep draft if present; otherwise show live
        ch = self._pending_desktop()
        if ch is not None and isinstance(ch.meta.get("snapshot"), dict):
            snap = {str(k): str(v) for k, v in ch.meta["snapshot"].items()}
            self._apply_snapshot(snap)
        else:
            self._apply_snapshot(self._live)
        self._update_draft_label()

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        assert self.commit is not None
        if not changes:
            return
        # Coalesce: last desktop-set wins (should be one)
        ch = changes[-1]
        summary = "; ".join(c.summary for c in changes)

        def done(code: int) -> None:
            if code != 0:
                return
            self.commit.notify_apply_finished(True, summary)
            self.reload()

        self.run_ncc_root(ch.argv, label=ch.summary, on_done=done)


def create_page() -> DesktopPage:
    return DesktopPage()


Page = DesktopPage
