"""Hardware — configured vs detected inventory + autoDetect draft toggle."""

from __future__ import annotations

import json

from PySide6.QtWidgets import QCheckBox, QFormLayout, QLabel, QWidget

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import error
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage

_OP = "hardware-autodetect"


def _load_status() -> tuple[dict, str]:
    proc = run_ncc("hardware", "status", "--json")
    err = ((proc.stderr or "") + (proc.stdout or "")).strip()
    if proc.returncode != 0:
        return {}, err or "ncc hardware status failed"
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return {}, "Invalid JSON from ncc hardware status"
    if not isinstance(data, dict):
        return {}, "Unexpected status payload"
    return data, ""


def _fmt_ram(val) -> str:
    if val is None:
        return "auto / unset"
    return f"{val} GB"


def _match_badge(ok: bool | None) -> str:
    if ok is True:
        return "match"
    if ok is False:
        return "differs"
    return "—"


class HardwarePage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Hardware",
            "Configured CPU, GPU, and RAM versus what this machine reports. "
            "Auto-detect runs system checks (default on) and can update the "
            "hardware config before builds. Toggle stages a draft — Apply writes.",
            parent=parent,
        )
        self._live_auto = True
        self._loading = False
        self._status: dict = {}

        badge_row = QWidget()
        badge_l = QFormLayout(badge_row)
        self.auto_badge = QLabel("—")
        self.auto_badge.setObjectName("nccPageSubtitle")
        badge_l.addRow("Auto-detect", self.auto_badge)
        self.auto_chk = QCheckBox("Enable hardware auto-detection (system checks)")
        badge_l.addRow("", self.auto_chk)
        self.add_content_widget(badge_row)

        form = self.add_form_block("Inventory")
        self.cpu_cfg = QLabel("—")
        self.cpu_det = QLabel("—")
        self.cpu_match = QLabel("—")
        form.addRow("CPU (configured)", self.cpu_cfg)
        form.addRow("CPU (detected)", self.cpu_det)
        form.addRow("CPU", self.cpu_match)

        self.gpu_cfg = QLabel("—")
        self.gpu_det = QLabel("—")
        self.gpu_match = QLabel("—")
        form.addRow("GPU (configured)", self.gpu_cfg)
        form.addRow("GPU (detected)", self.gpu_det)
        form.addRow("GPU", self.gpu_match)

        self.ram_cfg = QLabel("—")
        self.ram_det = QLabel("—")
        self.ram_match = QLabel("—")
        form.addRow("RAM (configured)", self.ram_cfg)
        form.addRow("RAM (detected)", self.ram_det)
        form.addRow("RAM", self.ram_match)

        self.hint = QLabel("")
        self.hint.setObjectName("nccPageSubtitle")
        self.hint.setWordWrap(True)
        self.add_content_widget(self.hint)

        self.add_actions_hint(
            "Auto-detect maps to system-manager.enableChecks. "
            "Inventory is read-only here for now."
        )
        self.add_action("Refresh", self.reload)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._on_pending_changed)

        self.auto_chk.stateChanged.connect(self._on_auto_toggled)
        self.reload()

    def _pending_auto(self) -> bool | None:
        assert self.commit is not None
        for ch in self.commit.pending:
            if ch.meta.get("op") == _OP:
                return bool(ch.meta.get("autoDetect"))
        return None

    def _apply_labels(self) -> None:
        data = self._status
        cfg = data.get("configured") if isinstance(data.get("configured"), dict) else {}
        det = data.get("detected") if isinstance(data.get("detected"), dict) else {}
        match = data.get("match") if isinstance(data.get("match"), dict) else {}

        self.cpu_cfg.setText(str(cfg.get("cpu") or "—"))
        self.cpu_det.setText(str(det.get("cpu") or "—"))
        self.cpu_match.setText(_match_badge(match.get("cpu")))

        self.gpu_cfg.setText(str(cfg.get("gpu") or "—"))
        self.gpu_det.setText(str(det.get("gpu") or "—"))
        self.gpu_match.setText(_match_badge(match.get("gpu")))

        self.ram_cfg.setText(_fmt_ram(cfg.get("ramGB")))
        self.ram_det.setText(_fmt_ram(det.get("ramGB")))
        self.ram_match.setText(_match_badge(match.get("ram")))

        pending = self._pending_auto()
        auto = self._live_auto if pending is None else pending
        self._loading = True
        try:
            self.auto_chk.setChecked(auto)
        finally:
            self._loading = False

        if pending is None:
            self.auto_badge.setText("On" if self._live_auto else "Off")
            self.hint.setText("Showing live settings.")
        else:
            self.auto_badge.setText(
                ("On" if pending else "Off") + " · pending"
            )
            self.hint.setText(
                "Draft auto-detect toggle — Save / Undo, then Apply to write."
            )

    def _on_pending_changed(self) -> None:
        self._apply_labels()

    def _on_auto_toggled(self, *_args) -> None:
        if self._loading:
            return
        assert self.commit is not None
        want = self.auto_chk.isChecked()
        if want == self._live_auto:
            self.commit.discard_where(
                lambda c: c.meta.get("op") == _OP,
                log="• discarded autoDetect draft (matches live)\n",
            )
            self._apply_labels()
            return
        val = "true" if want else "false"
        self.commit.stage_replace(
            PendingChange(
                summary=f"hardware set autoDetect={val}",
                argv=["hardware", "set", f"autoDetect={val}"],
                elevated=True,
                meta={"op": _OP, "autoDetect": want},
            ),
            same=lambda a, b: a.meta.get("op") == b.meta.get("op") == _OP,
        )

    def reload(self) -> None:
        data, err = _load_status()
        if err:
            error(self, "Hardware", err)
            self.log_append(f"• status error\n{err}\n")
            return
        self._status = data
        self._live_auto = bool(data.get("autoDetect", True))
        self._apply_labels()

    def _flush_pending(self, changes: list[PendingChange]) -> None:
        assert self.commit is not None
        if not changes:
            return
        ch = changes[-1]
        summary = "; ".join(c.summary for c in changes)

        def done(code: int) -> None:
            if code != 0:
                return
            self.commit.notify_apply_finished(True, summary)
            self.reload()

        self.run_ncc_root(ch.argv, label=ch.summary, on_done=done)


def create_page() -> HardwarePage:
    return HardwarePage()


Page = HardwarePage
