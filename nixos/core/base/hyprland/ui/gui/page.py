"""Hyprland — Hall of Fame rice store (applyable entries + previews)."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtWidgets import (
    QCheckBox,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.commit_bar import PendingChange
from ncc_gui.dialogs import confirm_rebuild, error, info
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage

_HYPRLAND_OP = "hyprland-set"
_PREVIEW_W = 260
_PREVIEW_H = 146
_THUMB_W = 220
_THUMB_H = 124


def _hyprland_bin() -> str:
    return os.environ.get("NCC_HYPRLAND_BIN", "ncc-hyprland")


def _catalog_json_path() -> Path | None:
    raw = os.environ.get("NCC_HYPRLAND_CATALOG", "").strip()
    if not raw:
        return None
    return Path(raw)


def _catalog_mk_path() -> Path:
    return (
        Path(os.environ.get("NIXOS_DIR", "/etc/nixos"))
        / "core"
        / "base"
        / "hyprland"
        / "lib"
        / "mk-catalog-json.nix"
    )


def load_catalog() -> dict:
    catalog = _catalog_json_path()
    if catalog is not None:
        if not catalog.is_file():
            raise RuntimeError(f"Hyprland catalog not found: {catalog}")
        text = catalog.read_text(encoding="utf-8")
        if not text.strip():
            raise RuntimeError(f"Hyprland catalog file is empty: {catalog}")
        return json.loads(text)

    mk = _catalog_mk_path()
    if not mk.is_file():
        raise RuntimeError(
            "Hyprland catalog not found — set NCC_HYPRLAND_CATALOG or launch via ncc-gui / ncc hyprland --gui"
        )
    proc = subprocess.run(
        [
            "nix-instantiate",
            "--eval",
            "--strict",
            "-E",
            f"import {mk} {{ pkgs = import <nixpkgs> {{}}; }}",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "catalog eval failed")
    out = Path(proc.stdout.strip())
    if not out.is_file():
        raise RuntimeError(f"Hyprland catalog output missing: {out}")
    return json.loads(out.read_text(encoding="utf-8"))


def _parse_status(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def _make_item(text: str, data=None) -> QListWidgetItem:
    item = QListWidgetItem(text)
    item.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable)
    if data is not None:
        item.setData(Qt.ItemDataRole.UserRole, data)
    return item


def _pixmap_from_store(path: str | None, w: int, h: int) -> QPixmap | None:
    if not path:
        return None
    p = Path(path)
    if not p.is_file():
        return None
    pix = QPixmap(str(p))
    if pix.isNull():
        return None
    return pix.scaled(
        w,
        h,
        Qt.AspectRatioMode.KeepAspectRatio,
        Qt.TransformationMode.SmoothTransformation,
    )


def _icon_from_store(path: str | None) -> QIcon:
    pix = _pixmap_from_store(path, _THUMB_W, _THUMB_H)
    return QIcon(pix) if pix is not None else QIcon()


def _format_rice_details(rice: dict, *, active_id: str | None) -> str:
    method = rice.get("applyMethod") or "reference"
    lines = [
        rice.get("name") or rice.get("id") or "",
        "",
        f"Apply: {rice.get('applyLabel') or method}",
        f"Creator: {rice.get('creator') or '—'}",
        f"Contest: #{rice.get('contest')} ({rice.get('theme')}) · rank #{rice.get('rank')}",
        "",
        rice.get("description") or "",
        "",
        f"Dotfiles: {rice.get('dotfilesUrl') or '—'}",
    ]
    flake = rice.get("flake")
    if isinstance(flake, dict) and flake.get("url"):
        ref = flake.get("ref") or "master"
        lines.append(f"Flake: {flake['url']} ({ref})")
    rid = rice.get("id")
    if rid and rid == active_id:
        lines.extend(["", "✓ Currently selected rice"])
    if method == "flake":
        lines.extend(
            [
                "",
                "NCC clones upstream dotfiles and patches host flake.nix.",
                "Rebuild imports the flake module when this rice is active.",
            ]
        )
    elif method == "dotfiles":
        lines.extend(
            [
                "",
                "NCC clones upstream dotfiles to /var/lib/ncc/hyprland/collections/",
                "and wires hyprland.conf on rebuild (nothing in ~/).",
            ]
        )
    elif method == "wallpaper":
        lines.extend(
            [
                "",
                "NCC applies the contest wallpaper via hyprpaper.",
            ]
        )
    return "\n".join(lines)


def _format_validate_block(report: dict) -> str:
    v100 = bool(report.get("validated100"))
    lines = [
        "",
        f"── 100% validate: {'YES' if v100 else 'NO / REJECTED'} ──",
    ]
    for line in report.get("checks") or []:
        lines.append(f"✓ {line}")
    for line in report.get("warnings") or []:
        lines.append(f"⚠ {line}")
    for line in report.get("errors") or []:
        lines.append(f"✗ {line}")
    if not v100:
        lines.append("Apply blocked until validated100=YES.")
    return "\n".join(lines)


def _validate_report_text(report: dict) -> str:
    v100 = bool(report.get("validated100"))
    parts = [f"validated100: {'YES' if v100 else 'NO'}"]
    if report.get("hyprConfig"):
        parts.append(f"Config: {report['hyprConfig']}")
    for line in report.get("errors") or []:
        parts.append(f"✗ {line}")
    for line in report.get("warnings") or []:
        parts.append(f"⚠ {line}")
    parts.append("")
    if v100:
        parts.append("VALIDATED 100% — apply allowed.")
    else:
        parts.append("REJECTED — not 100%. Apply blocked.")
    return "\n".join(parts)


class HyprlandPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Hyprland",
            "Hall of Fame gallery (preview) + NCC collection apply store. "
            "Apply only for collection rices that pass validated100.",
            parent=parent,
        )
        self._catalog: dict = {"storeRices": [], "galleryRices": [], "categories": []}
        self._store_rices: list[dict] = []
        self._gallery_rices: list[dict] = []
        self._live = {
            "enable": "false",
            "rice": "null",
            "wallpaper.rice": "null",
            "wallpaper.path": "null",
        }
        self._loading = False

        top = QHBoxLayout()
        self.enable = QCheckBox("Hyprland module enabled")
        self.enable.stateChanged.connect(self._on_enable_changed)
        top.addWidget(self.enable)
        top.addStretch(1)
        wrap = QWidget()
        wrap.setLayout(top)
        self.add_content_widget(wrap)

        tip = QLabel(
            "Gallery = HoF previews. Apply store = NCC-Hyperland-Collection only. "
            "Save → Apply when a rice is validated100."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        self.add_content_widget(tip)

        split = QSplitter(Qt.Orientation.Horizontal)

        left = QGroupBox("Contests")
        ll = QVBoxLayout(left)
        self.categories = QListWidget()
        self.categories.currentItemChanged.connect(self._on_category)
        ll.addWidget(self.categories)
        split.addWidget(left)

        mid = QGroupBox("Gallery (preview)")
        ml = QVBoxLayout(mid)
        self.rices = QListWidget()
        self.rices.setViewMode(QListWidget.ViewMode.IconMode)
        self.rices.setIconSize(QSize(_THUMB_W, _THUMB_H))
        self.rices.setGridSize(QSize(_THUMB_W + 24, _THUMB_H + 44))
        self.rices.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.rices.setMovement(QListWidget.Movement.Static)
        self.rices.setSpacing(8)
        self.rices.currentItemChanged.connect(self._on_rice_selected)
        ml.addWidget(self.rices)
        split.addWidget(mid)

        right = QGroupBox("Preview")
        rl = QVBoxLayout(right)

        self.preview_img = QLabel("Select a rice")
        self.preview_img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.preview_img.setMinimumHeight(_PREVIEW_H + 8)
        self.preview_img.setObjectName("nccPageSubtitle")
        rl.addWidget(self.preview_img)

        self.apply_badge = QLabel("")
        self.apply_badge.setObjectName("nccPageSubtitle")
        self.apply_badge.setWordWrap(True)
        rl.addWidget(self.apply_badge)

        self.details = QTextEdit()
        self.details.setReadOnly(True)
        self.details.setMinimumHeight(160)
        rl.addWidget(self.details)
        split.addWidget(right)
        split.setSizes([160, 420, 320])
        self.add_content_widget(split, stretch=1)

        self.draft_lbl = QLabel("")
        self.draft_lbl.setObjectName("nccPageSubtitle")
        self.draft_lbl.setWordWrap(True)
        self.add_content_widget(self.draft_lbl)

        assert self.commit is not None
        self.commit.set_flush_handler(self._flush_pending)
        self.commit.set_pending_changed(self._on_pending_changed)

        self.add_action("Reload", self.reload, local=True)
        self.add_action("Rebuild…", self._rebuild, ncc=("system", "build"))

        self.reload()

    def _store_rices_for_category(self, cat_kind: str, cat: dict) -> list[dict]:
        rices = list(self._gallery_rices)
        if cat_kind == "all":
            return sorted(rices, key=lambda r: (-(r.get("contest") or 0), r.get("rank") or 0))
        cid = str(cat.get("contest") or "")
        return sorted(
            [r for r in rices if str(r.get("contest")) == cid],
            key=lambda r: r.get("rank") or 0,
        )

    def _active_rice_id(self) -> str | None:
        v = self._live.get("rice", "null")
        return None if v in ("null", "", "None") else v

    def _rebuild(self) -> None:
        if not confirm_rebuild(self, "Rebuild && switch the running system."):
            return
        self.run_ncc_root(["system", "build", "switch"], label="Rebuild && switch")

    def _pending_hyprland(self) -> PendingChange | None:
        assert self.commit is not None
        for ch in self.commit.pending:
            if ch.meta.get("op") == _HYPRLAND_OP:
                return ch
        return None

    def _on_enable_changed(self, _state: int = 0) -> None:
        if self._loading:
            return
        self._stage_from_state()

    def _fill_categories(self) -> None:
        self.categories.clear()
        self.categories.addItem(_make_item("All contests", ("all", {})))
        for cat in self._catalog.get("categories") or []:
            if not isinstance(cat, dict):
                continue
            title = str(cat.get("title") or cat.get("id") or "")
            self.categories.addItem(_make_item(title, ("contest", cat)))
        if self.categories.count() > 0:
            self.categories.setCurrentRow(0)

    def _on_category(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None:
            return
        raw = cur.data(Qt.ItemDataRole.UserRole)
        if not raw:
            return
        kind, cat = raw
        self._loading = True
        try:
            self.rices.clear()
            active = self._display_rice_id()
            select_row = 0
            for row, rice in enumerate(self._store_rices_for_category(kind, cat)):
                rid = rice.get("id") or ""
                mark = " ✓" if rid == active else ""
                label = f"#{rice.get('rank')} {rice.get('name')}{mark}"
                item = _make_item(label, rice)
                item.setIcon(_icon_from_store(rice.get("previewStorePath")))
                item.setSizeHint(QSize(_THUMB_W + 16, _THUMB_H + 36))
                self.rices.addItem(item)
                if rid == active:
                    select_row = row
            if self.rices.count() > 0:
                self.rices.setCurrentRow(select_row)
        finally:
            self._loading = False

    def _on_rice_selected(self, cur: QListWidgetItem | None, _prev=None) -> None:
        self._show_details(cur, _prev)
        if self._loading or cur is None:
            return
        rice = cur.data(Qt.ItemDataRole.UserRole)
        if not isinstance(rice, dict):
            return
        if not rice.get("applyable"):
            return
        rid = str(rice.get("id") or "")
        report = self._validate_rice(rid) if rid else None
        if report is not None:
            self.details.setPlainText(
                self.details.toPlainText() + _format_validate_block(report)
            )
        self._maybe_warn_validate(report)
        if report is not None and not report.get("validated100"):
            self.log_append(f"• REJECTED {rid} — not validated 100%; not staged\n")
            return
        if report is None:
            self.log_append(f"• validate unavailable for {rid} — not staged\n")
            return
        self._stage_from_state(rice=rice)

    def _show_details(self, cur: QListWidgetItem | None, _prev=None) -> None:
        if cur is None:
            self.preview_img.setText("Select a rice")
            self.preview_img.setPixmap(QPixmap())
            self.apply_badge.setText("")
            self.details.clear()
            return
        rice = cur.data(Qt.ItemDataRole.UserRole)
        if not isinstance(rice, dict):
            return
        pix = _pixmap_from_store(rice.get("previewStorePath"), _PREVIEW_W, _PREVIEW_H)
        if pix is not None:
            self.preview_img.setPixmap(pix)
            self.preview_img.setText("")
        else:
            self.preview_img.setPixmap(QPixmap())
            self.preview_img.setText("No preview")
        self.apply_badge.setText(rice.get("applyLabel") or rice.get("applyMethod") or "")
        self.details.setPlainText(
            _format_rice_details(rice, active_id=self._display_rice_id())
        )

    def _validate_rice(self, rice_id: str) -> dict | None:
        proc = run_ncc(
            "hyprland",
            "rice",
            "validate",
            rice_id,
            "--json",
            timeout=300,
        )
        if proc.returncode not in (0, 1) or not (proc.stdout or "").strip():
            self.log_append(f"• validate unavailable for {rice_id}\n")
            return None
        try:
            report = json.loads(proc.stdout)
        except json.JSONDecodeError:
            self.log_append(f"• validate parse error for {rice_id}\n")
            return None
        return report if isinstance(report, dict) else None

    def _maybe_warn_validate(self, report: dict | None) -> None:
        if not report:
            return
        if report.get("validated100"):
            return
        info(self, "Rice REJECTED — not 100% validated", _validate_report_text(report))

    def _display_rice_id(self) -> str | None:
        ch = self._pending_hyprland()
        if ch is not None:
            snap = ch.meta.get("snapshot")
            if isinstance(snap, dict):
                rid = str(snap.get("rice", "null"))
                if rid not in ("null", "", "None"):
                    return rid
        return self._active_rice_id()

    def _selected_rice(self) -> dict | None:
        item = self.rices.currentItem()
        if item is None:
            return None
        rice = item.data(Qt.ItemDataRole.UserRole)
        return rice if isinstance(rice, dict) else None

    def _stage_from_state(self, *, rice: dict | None = None) -> None:
        assert self.commit is not None
        enable = "true" if self.enable.isChecked() else "false"
        selected = rice or self._selected_rice()
        rice_id = str(selected.get("id") or "null") if selected else "null"

        snap = {
            "enable": enable,
            "rice": rice_id,
            "wallpaper.rice": "null",
            "wallpaper.path": "null",
        }
        if snap == self._live:
            self.commit.discard_where(
                lambda c: c.meta.get("op") == _HYPRLAND_OP,
                log="• discarded hyprland draft (matches live)\n",
            )
            self._update_draft_label()
            return

        summary = f"hyprland set enable={enable} rice={rice_id} wallpaper.rice=null"
        argv = [
            "hyprland",
            "set",
            f"enable={enable}",
            f"rice={rice_id}",
            "wallpaper.rice=null",
            "wallpaper.path=null",
        ]
        self.commit.stage_replace(
            PendingChange(
                summary=summary,
                argv=argv,
                elevated=True,
                meta={"op": _HYPRLAND_OP, "snapshot": dict(snap)},
            ),
            same=lambda a, b: a.meta.get("op") == b.meta.get("op") == _HYPRLAND_OP,
        )
        self._update_draft_label()

    def _select_rice_by_id(self, rice_id: str | None) -> None:
        if not rice_id or rice_id in ("null", "", "None"):
            return
        self._loading = True
        try:
            for row in range(self.rices.count()):
                item = self.rices.item(row)
                if item is None:
                    continue
                rice = item.data(Qt.ItemDataRole.UserRole)
                if isinstance(rice, dict) and rice.get("id") == rice_id:
                    self.rices.setCurrentRow(row)
                    return
        finally:
            self._loading = False

    def _on_pending_changed(self) -> None:
        ch = self._pending_hyprland()
        if ch is None:
            self._apply_live_to_widgets()
        else:
            snap = ch.meta.get("snapshot")
            if isinstance(snap, dict):
                self._apply_snapshot({str(k): str(v) for k, v in snap.items()})
        self._update_draft_label()

    def _apply_snapshot(self, snap: dict[str, str]) -> None:
        self._loading = True
        try:
            self.enable.setChecked(snap.get("enable", "false") == "true")
            self._select_rice_by_id(snap.get("rice"))
        finally:
            self._loading = False

    def _apply_live_to_widgets(self) -> None:
        self._apply_snapshot(self._live)

    def _update_draft_label(self) -> None:
        ch = self._pending_hyprland()
        store_n = len(self._store_rices)
        gallery_n = len(self._gallery_rices)
        if ch is None:
            active = self._active_rice_id()
            extra = f" Active rice: {active}." if active else ""
            self.draft_lbl.setText(
                f"Applyable: {store_n} · Gallery: {gallery_n} preview-only.{extra}"
            )
        else:
            self.draft_lbl.setText(
                "Draft ready — Save, then Apply to write systemConfig."
            )

    def reload(self) -> None:
        try:
            self._catalog = load_catalog()
        except Exception as exc:  # noqa: BLE001
            error(self, "Catalog", str(exc))
            self._catalog = {"storeRices": [], "galleryRices": [], "categories": []}
        self._store_rices = [
            r
            for r in (self._catalog.get("storeRices") or [])
            if isinstance(r, dict) and r.get("applyable")
        ]
        self._gallery_rices = [
            r
            for r in (
                self._catalog.get("galleryRices")
                or self._catalog.get("rices")
                or self._store_rices
            )
            if isinstance(r, dict)
        ]

        proc = run_ncc("hyprland", "status")
        kv = _parse_status(proc.stdout or "")
        if proc.returncode == 0:
            self._live = {
                "enable": kv.get("enable", "false"),
                "rice": kv.get("rice", "null"),
                "wallpaper.rice": kv.get("wallpaper.rice", "null"),
                "wallpaper.path": kv.get("wallpaper.path", "null"),
            }
            installed = kv.get("collection.installed", "false") == "true"
            method = kv.get("collection.method", "")
            if installed and method:
                self.log_append(
                    f"• collection installed ({method}) hypr={kv.get('collection.hyprConfig', '')}\n"
                )
        else:
            self.log_append("• hyprland status unavailable — showing defaults\n")

        self._fill_categories()
        ch = self._pending_hyprland()
        if ch is not None and isinstance(ch.meta.get("snapshot"), dict):
            snap = {str(k): str(v) for k, v in ch.meta["snapshot"].items()}
            self._apply_snapshot(snap)
        else:
            self._apply_live_to_widgets()
        self._update_draft_label()
        if self.categories.count() > 0 and self.rices.count() == 0:
            self.categories.setCurrentRow(0)

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


def create_page() -> HyprlandPage:
    return HyprlandPage()


Page = HyprlandPage
