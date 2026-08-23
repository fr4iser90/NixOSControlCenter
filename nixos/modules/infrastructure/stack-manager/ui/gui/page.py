"""Stacks — Fleet / Host / Catalog (DomainPage kit).

Inventory = SSH client list via gui-engine ``target_state`` (no hard-coded hosts).
Pins/filters/cache = cockpit under ``~/.config/ncc/``.

Perf (gui-engine PERFORMANCE.md):
  - Never sync-probe the whole fleet on the UI thread
  - Paint from cache immediately; Refresh probes async with Loading banner
  - Click / selection never triggers network
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, QRunnable, Qt, QThreadPool, Signal, QTimer
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.ansi import strip_ansi
from ncc_gui.dialogs import confirm, info
from ncc_gui.scaffold import DomainPage
from ncc_gui.target_bus import bus as target_bus
from ncc_gui.target_session import session_controller
from ncc_gui.target_state import get_active_target, list_host_pairs

_PREFS = Path.home() / ".config" / "ncc" / "stacks-ui.json"
_CACHE = Path.home() / ".config" / "ncc" / "stacks-fleet-cache.json"
# Soft TTL: prefer re-probe on Refresh; still show stale while waiting
_CACHE_SOFT_TTL_S = 180
_CACHE_HARD_TTL_S = 3600


@dataclass(frozen=True)
class WorkloadRow:
    kind: str
    name: str
    status: str
    label: str
    detail: str
    pin_key: str


def _load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def _save_json(path: Path, data: Any) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except OSError:
        pass


def _prefs() -> dict[str, Any]:
    raw = _load_json(_PREFS, {})
    return raw if isinstance(raw, dict) else {}


def _set_prefs(data: dict[str, Any]) -> None:
    _save_json(_PREFS, data)


def _pin_set() -> set[str]:
    pins = _prefs().get("pins")
    if isinstance(pins, list):
        return {str(p) for p in pins}
    return set()


def _toggle_pin(key: str) -> bool:
    data = _prefs()
    pins = set(str(p) for p in (data.get("pins") or []) if p)
    if key in pins:
        pins.discard(key)
        now = False
    else:
        pins.add(key)
        now = True
    data["pins"] = sorted(pins)
    _set_prefs(data)
    return now


def _tags_map() -> dict[str, list[str]]:
    raw = _prefs().get("tags")
    if not isinstance(raw, dict):
        return {}
    out: dict[str, list[str]] = {}
    for key, val in raw.items():
        if not key:
            continue
        if isinstance(val, list):
            out[str(key)] = sorted({str(t).strip() for t in val if str(t).strip()})
    return out


def _host_tags(key: str) -> list[str]:
    return list(_tags_map().get(key) or [])


def _merged_host_tags(key: str, declarative: dict[str, list[str]]) -> list[str]:
    merged = set(_host_tags(key))
    for t in declarative.get(key) or []:
        if str(t).strip():
            merged.add(str(t).strip())
    return sorted(merged, key=str.lower)


def _set_host_tags(key: str, tags: list[str]) -> None:
    data = _prefs()
    tags_map = _tags_map()
    clean = sorted({t.strip() for t in tags if t.strip()})
    if clean:
        tags_map[key] = clean
    else:
        tags_map.pop(key, None)
    data["tags"] = tags_map
    _set_prefs(data)


def _all_tag_names() -> list[str]:
    names: set[str] = set()
    for vals in _tags_map().values():
        names.update(vals)
    return sorted(names, key=str.lower)


def _setup_dismissed() -> bool:
    return bool(_prefs().get("setup_dismissed"))


def _setup_complete() -> bool:
    return bool(_prefs().get("setup_complete"))


def _mark_setup_complete() -> None:
    data = _prefs()
    data["setup_complete"] = True
    data.pop("setup_dismissed", None)
    _set_prefs(data)


def _toggle_pin(key: str) -> bool:
    data = _prefs()
    pins = set(str(p) for p in (data.get("pins") or []) if p)
    if key in pins:
        pins.discard(key)
        now = False
    else:
        pins.add(key)
        now = True
    data["pins"] = sorted(pins)
    _set_prefs(data)
    return now


def _cache_entry(host_key: str) -> tuple[dict[str, Any] | None, bool]:
    """Return (status|None, stale). Never blocks."""
    blob = _load_json(_CACHE, {})
    if not isinstance(blob, dict):
        return None, False
    entry = blob.get(host_key)
    if not isinstance(entry, dict):
        return None, False
    ts = entry.get("ts")
    status = entry.get("status")
    if not isinstance(status, dict) or not isinstance(ts, (int, float)):
        return None, False
    age = time.time() - float(ts)
    if age > _CACHE_HARD_TTL_S:
        return None, False
    return status, age > _CACHE_SOFT_TTL_S


def _cache_put(host_key: str, status: dict[str, Any]) -> None:
    blob = _load_json(_CACHE, {})
    if not isinstance(blob, dict):
        blob = {}
    blob[host_key] = {"ts": time.time(), "status": status}
    _save_json(_CACHE, blob)


def _fetch_status(target: str | None) -> dict[str, Any] | None:
    """Worker-thread safe status fetch."""
    from ncc_gui.remote import run_ncc

    try:
        proc = run_ncc("stacks", "status", "--json", target=target, timeout=18)
    except Exception:
        return None
    raw = (proc.stdout or "").strip()
    if proc.returncode != 0 or not raw:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


class _JobSignals(QObject):
    status_done = Signal(str, object)  # cache_key, status|None
    host_done = Signal(object)  # payload dict
    catalog_done = Signal(object)  # payload dict
    progress = Signal(str)


class _StatusJob(QRunnable):
    def __init__(self, cache_key: str, target: str | None, signals: _JobSignals, gen: int) -> None:
        super().__init__()
        self._key = cache_key
        self._target = target
        self._signals = signals
        self._gen = gen
        self.setAutoDelete(True)

    def run(self) -> None:
        self._signals.progress.emit(f"Loading status · {self._key}…")
        data = _fetch_status(self._target)
        if data is not None:
            _cache_put(self._key, data)
        self._signals.status_done.emit(self._key, data)


class _HostJob(QRunnable):
    def __init__(self, signals: _JobSignals, gen: int) -> None:
        super().__init__()
        self._signals = signals
        self._gen = gen
        self.setAutoDelete(True)

    def run(self) -> None:
        from ncc_gui.remote import run_ncc, target_from_env

        self._signals.progress.emit("Loading host workloads…")
        host = target_from_env()
        status = _fetch_status(host)
        if status is not None:
            _cache_put(host or "local", status)

        def pipe(verb: str) -> list[str]:
            try:
                proc = run_ncc("stacks", verb, target=host, timeout=25)
            except Exception:
                return []
            return [
                ln.strip()
                for ln in ((proc.stdout or "") + (proc.stderr or "")).splitlines()
                if ln.strip() and "|" in ln.strip()
            ]

        stacks_lines: list[str] = []
        try:
            ls = run_ncc("stacks", "list-stacks", target=host, timeout=25)
            for line in ((ls.stdout or "") + (ls.stderr or "")).splitlines():
                line = line.strip()
                if (
                    not line
                    or line.lower().startswith("name")
                    or "docker stacks" in line.lower()
                ):
                    continue
                name = line.split()[0] if line.split() else line
                if name.startswith("[") or name.startswith("==="):
                    continue
                stacks_lines.append(line)
        except Exception:
            pass

        self._signals.host_done.emit(
            {
                "gen": self._gen,
                "status": status,
                "containers": pipe("list-containers"),
                "ports": pipe("list-ports"),
                "domains": pipe("list-domains"),
                "stacks": stacks_lines,
            }
        )


class _CatalogJob(QRunnable):
    def __init__(
        self,
        *,
        mode: str,
        family: str,
        signals: _JobSignals,
        gen: int,
    ) -> None:
        super().__init__()
        self._mode = mode
        self._family = family
        self._signals = signals
        self._gen = gen
        self.setAutoDelete(True)

    def run(self) -> None:
        from ncc_gui.remote import run_ncc, target_from_env

        self._signals.progress.emit("Loading catalog…")
        host = target_from_env()
        if self._mode == "profiles":
            args = ["stacks", "list-profiles", "--remote", "--plain"]
        else:
            args = ["stacks", "list-catalog", "--remote", "--plain"]
            if self._family:
                args.extend(["--family", self._family])
        try:
            proc = run_ncc(*args, target=host, timeout=120)
        except Exception as exc:
            self._signals.catalog_done.emit(
                {"gen": self._gen, "ok": False, "error": str(exc), "lines": []}
            )
            return
        raw = strip_ansi((proc.stdout or "") + "\n" + (proc.stderr or ""))
        lines = [ln.strip() for ln in raw.splitlines() if ln.strip() and "|" in ln.strip()]
        self._signals.catalog_done.emit(
            {
                "gen": self._gen,
                "ok": proc.returncode == 0 or bool(lines),
                "error": "" if proc.returncode == 0 else strip_ansi(proc.stderr or ""),
                "lines": lines,
                "mode": self._mode,
                "family": self._family,
            }
        )


class _StacksSetupDialog(QDialog):
    """First-run: pick profile → fetch (if needed) → init with Activity log on parent."""

    def __init__(self, parent: StacksPage, profiles: list[str]) -> None:
        super().__init__(parent)
        self._page = parent
        self.setWindowTitle("Stacks setup")
        self.resize(480, 360)
        root = QVBoxLayout(self)
        root.addWidget(
            QLabel(
                "Phase 2: fetch catalog on the Target, then run the profile installer. "
                "Output appears in Activity below the page."
            )
        )
        self.lbl_preflight = QLabel("Preflight: …")
        self.lbl_preflight.setWordWrap(True)
        root.addWidget(self.lbl_preflight)
        form = QFormLayout()
        self.profile = QComboBox()
        for name in profiles:
            self.profile.addItem(name)
        if profiles:
            self.profile.setCurrentIndex(0)
        form.addRow("Profile", self.profile)
        self.dns_box = QWidget()
        dns_form = QFormLayout(self.dns_box)
        dns_hint = QLabel(
            "Optional Cloudflare credentials for homelab gateway (writes ddns-updater.env). "
            "Skip for compute profiles."
        )
        dns_hint.setWordWrap(True)
        dns_form.addRow(dns_hint)
        self.cf_email = QLineEdit()
        self.cf_email.setPlaceholderText("CF API email")
        dns_form.addRow("CF email", self.cf_email)
        self.cf_token = QLineEdit()
        self.cf_token.setEchoMode(QLineEdit.EchoMode.Password)
        self.cf_token.setPlaceholderText("CF API token")
        dns_form.addRow("CF token", self.cf_token)
        root.addWidget(self.dns_box)
        self.profile.currentIndexChanged.connect(self._sync_dns_visibility)
        self._sync_dns_visibility()
        root.addLayout(form)
        buttons = QDialogButtonBox()
        run_btn = buttons.addButton("Run setup", QDialogButtonBox.ButtonRole.AcceptRole)
        dismiss_btn = buttons.addButton(
            "Dismiss", QDialogButtonBox.ButtonRole.RejectRole
        )
        cancel_btn = buttons.addButton(
            QDialogButtonBox.StandardButton.Cancel
        )
        run_btn.clicked.connect(self._on_run)
        dismiss_btn.clicked.connect(self._on_dismiss)
        cancel_btn.clicked.connect(self.reject)
        root.addWidget(buttons)
        self._refresh_preflight()

    def _sync_dns_visibility(self) -> None:
        profile = self.profile.currentText().strip()
        homelab = not profile.startswith("compute-")
        self.dns_box.setVisible(homelab)

    def _refresh_preflight(self) -> None:
        status = self._page._host_status_from_cache()
        if not status:
            self.lbl_preflight.setText(
                "Preflight: status unknown — Refresh on Host tab, then try again."
            )
            return
        docker = "ok" if status.get("docker_running") else "needs docker"
        cat = "ok" if status.get("catalog_present") else "needs fetch"
        prof = str(status.get("profiles") or "").strip() or "none declared"
        virt = str(status.get("virt_user") or "—")
        self.lbl_preflight.setText(
            f"Docker: {docker} · Catalog: {cat} · "
            f"Declared profiles: {prof} · Virt user: {virt}"
        )

    def _on_dismiss(self) -> None:
        data = _prefs()
        data["setup_dismissed"] = True
        _set_prefs(data)
        self.reject()

    def _on_run(self) -> None:
        profile = self.profile.currentText().strip()
        if not profile:
            info(self, "Stacks setup", "Pick a profile first.")
            return
        cf_email = self.cf_email.text().strip()
        cf_token = self.cf_token.text().strip()
        if (
            not profile.startswith("compute-")
            and (cf_email or cf_token)
            and not (cf_email and cf_token)
        ):
            info(
                self,
                "Stacks setup",
                "Provide both CF email and token, or leave both empty.",
            )
            return
        self.accept()
        self._page._run_setup_chain(
            profile,
            cf_email=cf_email,
            cf_token=cf_token,
        )


class StacksPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Stacks",
            "Fleet from SSH targets · Host workloads on the connected Target · "
            "Catalog browse/install. Pins & filters stay in this cockpit.",
            parent=parent,
            commit_bar=False,
        )
        self._workloads: list[WorkloadRow] = []
        self._pool = QThreadPool.globalInstance()
        self._jobs = _JobSignals()
        self._jobs.status_done.connect(self._on_status_done)
        self._jobs.host_done.connect(self._on_host_done)
        self._jobs.catalog_done.connect(self._on_catalog_done)
        self._jobs.progress.connect(self._set_loading)
        self._fleet_gen = 0
        self._host_gen = 0
        self._catalog_gen = 0
        self._fleet_pending = 0
        self._loading_depth = 0
        self._declarative_tags: dict[str, list[str]] = {}

        self.loading = QLabel("")
        self.loading.setObjectName("nccOperatingScope")
        self.loading.setWordWrap(True)
        self.loading.setVisible(False)
        self.add_content_widget(self.loading)

        self.tabs = QTabWidget()
        self._build_fleet_tab()
        self._build_host_tab()
        self._build_catalog_tab()
        self._build_metrics_tab()
        self.add_content_widget(self.tabs, stretch=1)

        self.add_action("Refresh", self.reload, primary=True, local=True)
        self.btn_fetch = self.add_action(
            "Fetch catalog",
            self._run_fetch,
            ncc=("stacks", "fetch"),
        )
        self.btn_setup = self.add_action(
            "Start setup…",
            self._open_setup_wizard,
            local=True,
        )
        self.btn_use_target = self.add_action(
            "Use as Target…", self._fleet_use_target, local=True
        )
        self.btn_pin = self.add_action("Pin / Unpin", self._toggle_selected_pin, local=True)
        self.btn_edit_tags = self.add_action(
            "Edit tags…",
            self._edit_fleet_tags,
            local=True,
        )
        self.btn_init_swarm = self.add_action(
            "Init Swarm",
            lambda: self._run(("swarm", "init"), "Init Swarm", confirm=True),
            ncc=("stacks", "swarm"),
        )
        self.btn_install = self.add_action(
            "Install selected…",
            self._catalog_install,
            ncc=("stacks", "install"),
        )

        self.tabs.currentChanged.connect(self._on_tab_changed)
        target_bus().changed.connect(self._on_target_changed)

        # Instant paint from cache — no network on construct
        self._paint_fleet(cache_only=True)
        self._paint_host_from_cache()
        self._paint_metrics_from_cache()
        self._sync_actions()
        if not _setup_complete() and not _setup_dismissed():
            QTimer.singleShot(600, self._maybe_first_run_hint)
        QTimer.singleShot(0, self._load_declarative_tags)

    # ----- loading banner -----

    def _set_loading(self, msg: str) -> None:
        text = (msg or "").strip()
        if text:
            self.loading.setText(f"Loading — {text}")
            self.loading.setVisible(True)
        else:
            self._loading_depth = max(0, self._loading_depth)
            if self._fleet_pending <= 0 and self._loading_depth <= 0:
                self.loading.setText("")
                self.loading.setVisible(False)

    def _loading_begin(self, msg: str) -> None:
        self._loading_depth += 1
        self._set_loading(msg)

    def _loading_end(self) -> None:
        self._loading_depth = max(0, self._loading_depth - 1)
        if self._fleet_pending <= 0 and self._loading_depth <= 0:
            self.loading.setText("")
            self.loading.setVisible(False)

    # ----- tabs -----

    def _build_fleet_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Hosts from the SSH client list (Target bar). "
            "List paints from cache instantly — Refresh probes in the background."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        filt = QHBoxLayout()
        self.fleet_tag_filter = QComboBox()
        self.fleet_tag_filter.addItem("All tags", "")
        for tag in _all_tag_names():
            self.fleet_tag_filter.addItem(f"tag:{tag}", tag)
        self.fleet_tag_filter.currentIndexChanged.connect(self._paint_fleet_filtered)
        filt.addWidget(self.fleet_tag_filter)
        filt.addStretch(1)
        lay.addLayout(filt)
        self.fleet_list = QListWidget()
        self.fleet_list.itemDoubleClicked.connect(lambda _i: self._fleet_use_target())
        self.fleet_list.currentItemChanged.connect(self._on_fleet_select)
        lay.addWidget(self.fleet_list, stretch=1)
        self.fleet_detail = QLabel("Select a host")
        self.fleet_detail.setObjectName("nccPageSubtitle")
        self.fleet_detail.setWordWrap(True)
        lay.addWidget(self.fleet_detail)
        self.tabs.addTab(w, "Fleet")

    def _build_host_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        self.host_chip = QLabel("—")
        self.host_chip.setObjectName("nccPageSubtitle")
        self.host_chip.setWordWrap(True)
        lay.addWidget(self.host_chip)
        ov = QHBoxLayout()
        self.ov_docker = QLabel("Docker: —")
        self.ov_swarm = QLabel("Swarm: —")
        self.ov_mode = QLabel("Mode: —")
        self.ov_profiles = QLabel("Profiles: —")
        for lab in (self.ov_docker, self.ov_swarm, self.ov_mode, self.ov_profiles):
            lab.setObjectName("nccPageSubtitle")
            ov.addWidget(lab)
        ov.addStretch(1)
        lay.addLayout(ov)
        filt = QHBoxLayout()
        self.filter_kind = QComboBox()
        self.filter_kind.addItem("All kinds", "all")
        self.filter_kind.addItem("Containers", "container")
        self.filter_kind.addItem("Ports", "port")
        self.filter_kind.addItem("Domains", "domain")
        self.filter_kind.addItem("Stacks", "stack")
        self.filter_kind.currentIndexChanged.connect(self._apply_host_filter)
        filt.addWidget(self.filter_kind)
        self.filter_status = QComboBox()
        self.filter_status.addItem("All statuses", "all")
        self.filter_status.addItem("Running / up only", "running")
        self.filter_status.addItem("Unhealthy / down", "bad")
        self.filter_status.currentIndexChanged.connect(self._apply_host_filter)
        filt.addWidget(self.filter_status)
        self.host_search = QLineEdit()
        self.host_search.setPlaceholderText("Search workloads…")
        self.host_search.textChanged.connect(self._apply_host_filter)
        filt.addWidget(self.host_search, stretch=1)
        lay.addLayout(filt)
        self.host_list = QListWidget()
        self.host_list.currentItemChanged.connect(self._on_host_select)
        lay.addWidget(self.host_list, stretch=1)
        self.host_detail = QLabel("Select a row for details")
        self.host_detail.setObjectName("nccPageSubtitle")
        self.host_detail.setWordWrap(True)
        lay.addWidget(self.host_detail)
        self.tabs.addTab(w, "Host")

    def _build_catalog_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Catalog against the current Target (--remote). "
            "Refresh / mode change loads async (Loading banner)."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        setup = QVBoxLayout()
        setup_title = QLabel("First-run setup")
        setup_title.setObjectName("nccPageSubtitle")
        setup.addWidget(setup_title)
        self.setup_preflight = QLabel("Preflight: Refresh Host tab for status")
        self.setup_preflight.setObjectName("nccPageSubtitle")
        self.setup_preflight.setWordWrap(True)
        setup.addWidget(self.setup_preflight)
        lay.addLayout(setup)
        row = QHBoxLayout()
        self.catalog_mode = QComboBox()
        self.catalog_mode.addItem("Profiles", "profiles")
        self.catalog_mode.addItem("Services (group/service)", "services")
        self.catalog_mode.currentIndexChanged.connect(lambda _i: self._reload_catalog_async())
        row.addWidget(self.catalog_mode)
        self.catalog_family = QComboBox()
        self.catalog_family.addItem("All families", "")
        self.catalog_family.addItem("Homelab", "homelab")
        self.catalog_family.addItem("Compute", "compute")
        self.catalog_family.currentIndexChanged.connect(lambda _i: self._reload_catalog_async())
        row.addWidget(self.catalog_family)
        self.catalog_search = QLineEdit()
        self.catalog_search.setPlaceholderText("Filter catalog…")
        self.catalog_search.textChanged.connect(self._apply_catalog_filter)
        row.addWidget(self.catalog_search, stretch=1)
        lay.addLayout(row)
        self.catalog_list = QListWidget()
        self.catalog_list.currentItemChanged.connect(self._on_catalog_select)
        lay.addWidget(self.catalog_list, stretch=1)
        self.catalog_detail = QLabel("Select a catalog entry")
        self.catalog_detail.setObjectName("nccPageSubtitle")
        self.catalog_detail.setWordWrap(True)
        lay.addWidget(self.catalog_detail)
        self.tabs.addTab(w, "Catalog")

    def _build_metrics_tab(self) -> None:
        w = QWidget()
        lay = QVBoxLayout(w)
        tip = QLabel(
            "Fleet metrics from cached status (no extra probes). "
            "Refresh on Fleet tab updates this dashboard."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)
        form = QFormLayout()
        self.met_hosts = QLabel("—")
        self.met_docker_up = QLabel("—")
        self.met_swarm = QLabel("—")
        self.met_profiles = QLabel("—")
        self.met_tags = QLabel("—")
        self.met_catalog = QLabel("—")
        for lab in (
            self.met_hosts,
            self.met_docker_up,
            self.met_swarm,
            self.met_profiles,
            self.met_tags,
            self.met_catalog,
        ):
            lab.setWordWrap(True)
        form.addRow("Hosts cached", self.met_hosts)
        form.addRow("Docker up", self.met_docker_up)
        form.addRow("Swarm active", self.met_swarm)
        form.addRow("Declared profiles", self.met_profiles)
        form.addRow("Fleet tags (cockpit + config)", self.met_tags)
        form.addRow("Catalog on host", self.met_catalog)
        lay.addLayout(form)
        lay.addStretch(1)
        self.tabs.addTab(w, "Metrics")

    # ----- reload orchestration -----

    def reload(self) -> None:
        """User Refresh: re-paint from cache, then async probe current tab scope."""
        tab = self.tabs.currentIndex()
        self._paint_fleet(cache_only=True)
        self._paint_metrics_from_cache()
        self._update_setup_preflight()
        self._load_declarative_tags()
        if tab == 0:
            self._probe_fleet_async()
        elif tab == 1:
            self._reload_host_async()
        elif tab == 2:
            self._reload_catalog_async()
        else:
            self._paint_metrics_from_cache()
        self._sync_actions()

    def _on_target_changed(self, _t) -> None:
        # Instant — never re-probe entire fleet on Connect
        self._paint_fleet(cache_only=True)
        self._paint_host_from_cache()
        self._paint_metrics_from_cache()
        self._update_setup_preflight()
        if self.tabs.currentIndex() == 1:
            self._reload_host_async()
        self._sync_actions()

    def _on_tab_changed(self, _idx: int) -> None:
        self._sync_actions()
        if self.tabs.currentIndex() == 1 and not self._workloads:
            self._reload_host_async()
        if self.tabs.currentIndex() == 2 and self.catalog_list.count() == 0:
            self._reload_catalog_async()
        if self.tabs.currentIndex() == 3:
            self._paint_metrics_from_cache()

    def _paint_fleet_filtered(self) -> None:
        self._paint_fleet(cache_only=True)

    # ----- fleet -----

    def _paint_fleet(self, *, cache_only: bool) -> None:
        del cache_only  # always cache-only for paint
        cur_tag = self.fleet_tag_filter.currentData()
        self.fleet_tag_filter.blockSignals(True)
        self.fleet_tag_filter.clear()
        self.fleet_tag_filter.addItem("All tags", "")
        for tag in _all_tag_names():
            self.fleet_tag_filter.addItem(f"tag:{tag}", tag)
        if cur_tag:
            idx = self.fleet_tag_filter.findData(cur_tag)
            if idx >= 0:
                self.fleet_tag_filter.setCurrentIndex(idx)
        self.fleet_tag_filter.blockSignals(False)

        self.fleet_list.clear()
        pins = _pin_set()
        active = get_active_target()
        tag_filter = str(self.fleet_tag_filter.currentData() or "")

        def add(key: str, title: str) -> None:
            if tag_filter and tag_filter not in _merged_host_tags(
                key, self._declarative_tags
            ):
                return
            status, stale = _cache_entry(key)
            self._add_fleet_item(
                key=key,
                title=title,
                status=status,
                stale=stale,
                pinned=key in pins,
                active=(active is None and key == "local")
                or (active is not None and active == key),
                grey=status is not None and not self._status_implies_stacks(status),
            )

        add("local", "This machine")
        for host, user in list_host_pairs():
            add(f"{user}@{host}", f"{user}@{host}")

        items: list[QListWidgetItem] = []
        while self.fleet_list.count():
            items.append(self.fleet_list.takeItem(0))
        items.sort(
            key=lambda it: (
                0
                if isinstance(it.data(Qt.ItemDataRole.UserRole), dict)
                and str((it.data(Qt.ItemDataRole.UserRole) or {}).get("key")) in pins
                else 1,
                it.text().lower(),
            )
        )
        for it in items:
            self.fleet_list.addItem(it)

    def _probe_fleet_async(self) -> None:
        self._fleet_gen += 1
        gen = self._fleet_gen
        keys: list[tuple[str, str | None]] = [("local", None)]
        for host, user in list_host_pairs():
            t = f"{user}@{host}"
            keys.append((t, t))
        self._fleet_pending = len(keys)
        self._loading_begin(f"Probing {len(keys)} host(s)…")
        for cache_key, target in keys:
            job = _StatusJob(cache_key, target, self._jobs, gen)
            self._pool.start(job)

    def _on_status_done(self, cache_key: str, status: object) -> None:
        self._fleet_pending = max(0, self._fleet_pending - 1)
        if self._fleet_pending <= 0:
            self._loading_end()
            self._set_loading("")
        # Update matching row in place
        st = status if isinstance(status, dict) else None
        for i in range(self.fleet_list.count()):
            item = self.fleet_list.item(i)
            if item is None:
                continue
            data = item.data(Qt.ItemDataRole.UserRole)
            if not isinstance(data, dict) or data.get("key") != cache_key:
                continue
            title = str(data.get("title") or cache_key)
            pinned = cache_key in _pin_set()
            active = get_active_target()
            is_active = (active is None and cache_key == "local") or (
                active is not None and active == cache_key
            )
            label, detail = self._fleet_label(
                key=cache_key,
                title=title,
                status=st,
                stale=False,
                pinned=pinned,
                active=is_active,
                grey=st is not None and not self._status_implies_stacks(st),
            )
            item.setText(label)
            item.setData(
                Qt.ItemDataRole.UserRole,
                {"key": cache_key, "title": title, "detail": detail},
            )
            if st is not None and not self._status_implies_stacks(st):
                item.setForeground(Qt.GlobalColor.gray)
            else:
                item.setForeground(self.palette().text().color())
            # Refresh detail if selected
            if item is self.fleet_list.currentItem():
                self.fleet_detail.setText(detail)
            break
        if self._fleet_pending <= 0:
            self._set_loading("")
            self._paint_metrics_from_cache()
            self._update_setup_preflight()

    def _add_fleet_item(
        self,
        *,
        key: str,
        title: str,
        status: dict[str, Any] | None,
        stale: bool,
        pinned: bool,
        active: bool,
        grey: bool = False,
    ) -> None:
        label, detail = self._fleet_label(
            key=key,
            title=title,
            status=status,
            stale=stale,
            pinned=pinned,
            active=active,
            grey=grey,
        )
        item = QListWidgetItem(label)
        item.setData(
            Qt.ItemDataRole.UserRole,
            {"key": key, "title": title, "detail": detail},
        )
        if grey or status is None:
            item.setForeground(Qt.GlobalColor.gray)
        self.fleet_list.addItem(item)

    def _fleet_label(
        self,
        *,
        key: str,
        title: str,
        status: dict[str, Any] | None,
        stale: bool,
        pinned: bool,
        active: bool,
        grey: bool,
    ) -> tuple[str, str]:
        mode = self._mode_label(status)
        docker = self._docker_label(status)
        star = "★ " if pinned else ""
        cur = " · current" if active else ""
        grey_s = " · no stacks agent" if grey else ""
        stale_s = " · cached" if stale and status else ""
        miss = " · not probed" if status is None else ""
        tag_s = ""
        tags = _merged_host_tags(key, self._declarative_tags)
        if tags:
            tag_s = f" · tags:{','.join(tags)}"
        label = f"{star}{title}  [{docker} · {mode}]{cur}{tag_s}{grey_s}{stale_s}{miss}"
        detail = self._status_detail(title, status, key=key)
        return label, detail

    def _merged_tags_for(self, key: str) -> list[str]:
        return _merged_host_tags(key, self._declarative_tags)

    def _load_declarative_tags(self) -> None:
        from ncc_gui.remote import run_ncc

        try:
            proc = run_ncc("stacks", "fleet-tags", "--json", target=None, timeout=20)
        except Exception:
            return
        raw = (proc.stdout or "").strip()
        if proc.returncode != 0 or not raw:
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return
        ft = data.get("fleetTags")
        if isinstance(ft, dict):
            clean: dict[str, list[str]] = {}
            for k, v in ft.items():
                if isinstance(v, list):
                    clean[str(k)] = sorted(
                        {str(t).strip() for t in v if str(t).strip()}
                    )
            self._declarative_tags = clean
            self._paint_fleet(cache_only=True)
            self._paint_metrics_from_cache()

    @staticmethod
    def _status_implies_stacks(status: dict[str, Any] | None) -> bool:
        if not status:
            return False
        return "docker_installed" in status or "swarm_status" in status

    @staticmethod
    def _docker_label(status: dict[str, Any] | None) -> str:
        if not status:
            return "unknown"
        if not status.get("docker_installed"):
            return "no docker"
        if status.get("docker_running"):
            return "docker up"
        return "docker down"

    @staticmethod
    def _mode_label(status: dict[str, Any] | None) -> str:
        if not status:
            return "?"
        role = str(status.get("swarm_role") or "").strip()
        swarm = str(status.get("swarm_status") or "").strip()
        if role in ("manager", "worker"):
            return f"{role}/{swarm or '?'}"
        if swarm == "active":
            return "swarm"
        return "single"

    def _status_detail(
        self,
        title: str,
        status: dict[str, Any] | None,
        *,
        key: str = "",
    ) -> str:
        if not status:
            return (
                f"{title}\nNo cached status yet. Press Refresh to probe "
                "(selection never blocks)."
            )
        profiles = str(status.get("profiles") or "").strip() or "—"
        cat = "yes" if status.get("catalog_present") else "no"
        tags = ", ".join(self._merged_tags_for(key)) if key else "—"
        return (
            f"{title}\n"
            f"Docker installed: {status.get('docker_installed')}\n"
            f"Docker running: {status.get('docker_running')}\n"
            f"Catalog present: {cat}\n"
            f"Swarm: {status.get('swarm_status')} "
            f"(declared role: {status.get('swarm_role') or '—'})\n"
            f"Profiles: {profiles}\n"
            f"Domain: {status.get('domain') or '—'}\n"
            f"Virt user: {status.get('virt_user') or '—'}\n"
            f"Tags: {tags}"
        )

    # ----- host -----

    def _paint_host_from_cache(self) -> None:
        active = get_active_target()
        where = active or "This machine"
        self.host_chip.setText(f"Target: {where}")
        status, stale = _cache_entry(active or "local")
        if status is None:
            self.ov_docker.setText("Docker: — (Refresh to load)")
            self.ov_swarm.setText("Swarm: —")
            self.ov_mode.setText("Mode: —")
            self.ov_profiles.setText("Profiles: —")
            return
        mark = " · cached" if stale else ""
        self.ov_docker.setText(f"Docker: {self._docker_label(status)}{mark}")
        self.ov_swarm.setText(f"Swarm: {status.get('swarm_status') or '—'}")
        self.ov_mode.setText(f"Mode: {self._mode_label(status)}")
        prof = str(status.get("profiles") or "").strip() or "—"
        self.ov_profiles.setText(f"Profiles: {prof}")

    def _reload_host_async(self) -> None:
        self._host_gen += 1
        self._loading_begin("Loading host workloads…")
        self._pool.start(_HostJob(self._jobs, self._host_gen))

    def _on_host_done(self, payload: object) -> None:
        self._loading_end()
        if not isinstance(payload, dict):
            return
        if payload.get("gen") != self._host_gen:
            return
        active = get_active_target()
        self.host_chip.setText(f"Target: {active or 'This machine'}")
        data = payload.get("status")
        if isinstance(data, dict):
            self.ov_docker.setText(f"Docker: {self._docker_label(data)}")
            self.ov_swarm.setText(f"Swarm: {data.get('swarm_status') or '—'}")
            self.ov_mode.setText(f"Mode: {self._mode_label(data)}")
            prof = str(data.get("profiles") or "").strip() or "—"
            self.ov_profiles.setText(f"Profiles: {prof}")
        else:
            self.ov_docker.setText("Docker: unavailable")
            self.ov_swarm.setText("Swarm: —")
            self.ov_mode.setText("Mode: —")
            self.ov_profiles.setText("Profiles: —")

        rows: list[WorkloadRow] = []
        for line in payload.get("containers") or []:
            if not isinstance(line, str):
                continue
            parts = line.split("|")
            name = parts[0] if parts else "?"
            status = parts[1] if len(parts) > 1 else "?"
            image = parts[2] if len(parts) > 2 else ""
            ports = parts[3] if len(parts) > 3 else ""
            rows.append(
                WorkloadRow(
                    kind="container",
                    name=name,
                    status=status,
                    label=f"container  {name}  [{status}]",
                    detail=f"Container: {name}\nStatus: {status}\nImage: {image}\nPorts: {ports or '—'}",
                    pin_key=f"container:{name}",
                )
            )
        for line in payload.get("ports") or []:
            if not isinstance(line, str):
                continue
            parts = line.split("|")
            name = parts[0] if parts else "?"
            proto = parts[1] if len(parts) > 1 else "?"
            host_ip = parts[2] if len(parts) > 2 else ""
            host_port = parts[3] if len(parts) > 3 else "?"
            cport = parts[4] if len(parts) > 4 else "?"
            bind = f"{host_ip}:{host_port}" if host_ip else host_port
            rows.append(
                WorkloadRow(
                    kind="port",
                    name=name,
                    status="published",
                    label=f"port  {bind} → {name}:{cport}/{proto}",
                    detail=f"Container: {name}\nPublished: {bind}/{proto}\nContainer port: {cport}",
                    pin_key=f"port:{bind}:{name}",
                )
            )
        for line in payload.get("domains") or []:
            if not isinstance(line, str):
                continue
            parts = line.split("|")
            source = parts[0] if parts else "?"
            domain = parts[1] if len(parts) > 1 else "?"
            rows.append(
                WorkloadRow(
                    kind="domain",
                    name=domain,
                    status=source,
                    label=f"domain  {domain}  ({source})",
                    detail=f"Domain: {domain}\nSource: {source}",
                    pin_key=f"domain:{domain}",
                )
            )
        for line in payload.get("stacks") or []:
            if not isinstance(line, str):
                continue
            name = line.split()[0] if line.split() else line
            status = " ".join(line.split()[1:]) if len(line.split()) > 1 else "stack"
            rows.append(
                WorkloadRow(
                    kind="stack",
                    name=name,
                    status=status,
                    label=f"stack  {line}",
                    detail=f"Stack: {name}\n{line}",
                    pin_key=f"stack:{name}",
                )
            )
        self._workloads = rows
        self._apply_host_filter()
        self._update_setup_preflight()
        self._paint_metrics_from_cache()

    def _apply_host_filter(self) -> None:
        self.host_list.clear()
        kind = self.filter_kind.currentData() or "all"
        status_f = self.filter_status.currentData() or "all"
        q = (self.host_search.text() or "").strip().lower()
        pins = _pin_set()

        def rank(row: WorkloadRow) -> tuple[int, int, str]:
            pinned = 0 if row.pin_key in pins else 1
            bad = 0 if self._is_bad(row.status) else 1
            return (pinned, bad, row.label.lower())

        shown = 0
        for row in sorted(self._workloads, key=rank):
            if kind != "all" and row.kind != kind:
                continue
            if status_f == "running" and not self._is_running(row.status):
                continue
            if status_f == "bad" and not self._is_bad(row.status):
                continue
            if q and q not in row.label.lower() and q not in row.name.lower():
                continue
            star = "★ " if row.pin_key in pins else ""
            item = QListWidgetItem(f"{star}{row.label}")
            item.setData(Qt.ItemDataRole.UserRole, row)
            self.host_list.addItem(item)
            shown += 1
        if shown == 0:
            self.host_list.addItem(
                QListWidgetItem("No workloads yet — press Refresh on the Host tab")
            )
        self.host_detail.setText("Select a row for details")

    @staticmethod
    def _is_running(status: str) -> bool:
        s = status.lower()
        return any(x in s for x in ("up", "running", "active", "published"))

    @staticmethod
    def _is_bad(status: str) -> bool:
        s = status.lower()
        return any(x in s for x in ("exit", "unhealthy", "dead", "down", "restarting"))

    # ----- catalog -----

    def _reload_catalog_async(self) -> None:
        self._catalog_gen += 1
        mode = self.catalog_mode.currentData() or "profiles"
        family = self.catalog_family.currentData() or ""
        self._loading_begin("Loading catalog…")
        self.catalog_list.clear()
        self.catalog_list.addItem(QListWidgetItem("Loading…"))
        self._pool.start(
            _CatalogJob(
                mode=str(mode),
                family=str(family),
                signals=self._jobs,
                gen=self._catalog_gen,
            )
        )

    def _on_catalog_done(self, payload: object) -> None:
        self._loading_end()
        if not isinstance(payload, dict) or payload.get("gen") != self._catalog_gen:
            return
        self.catalog_list.clear()
        mode = payload.get("mode") or "profiles"
        family = str(payload.get("family") or "")
        lines = payload.get("lines") or []
        if not lines:
            msg = "No catalog entries"
            if not payload.get("ok"):
                msg = str(payload.get("error") or msg)
            self.catalog_list.addItem(QListWidgetItem(msg))
            return
        for line in lines:
            if not isinstance(line, str) or "|" not in line:
                continue
            if mode == "profiles":
                parts = line.split("|")
                if len(parts) < 4:
                    continue
                name, fam, arch, ok = parts[0], parts[1], parts[2], parts[3]
                if family == "homelab" and fam == "compute":
                    continue
                if family == "compute" and fam != "compute":
                    continue
                label = f"{name}  ({fam}/{arch})"
                detail = f"Profile: {name}\nFamily: {fam}\nArch: {arch}\nCompat: {ok}"
                kind, key = "profile", name
            else:
                parts = line.split("|", 1)
                rel = parts[0]
                variants = parts[1] if len(parts) > 1 else ""
                label = rel + (f"  [{variants}]" if variants else "")
                detail = f"Service: {rel}\nVariants: {variants or '—'}"
                kind, key = "service", rel
            item = QListWidgetItem(label)
            item.setData(
                Qt.ItemDataRole.UserRole,
                {"kind": kind, "key": key, "detail": detail},
            )
            self.catalog_list.addItem(item)
        self._apply_catalog_filter()

    def _apply_catalog_filter(self) -> None:
        q = (self.catalog_search.text() or "").strip().lower()
        for i in range(self.catalog_list.count()):
            item = self.catalog_list.item(i)
            if item is None:
                continue
            data = item.data(Qt.ItemDataRole.UserRole)
            text = item.text().lower()
            if isinstance(data, dict):
                text += " " + str(data.get("key", "")).lower()
            item.setHidden(bool(q) and q not in text)

    # ----- selection / actions -----

    def _sync_actions(self) -> None:
        tab = self.tabs.currentIndex()
        self.btn_use_target.setVisible(tab == 0)
        self.btn_pin.setVisible(tab in (0, 1))
        self.btn_edit_tags.setVisible(tab == 0)
        self.btn_init_swarm.setVisible(tab == 1)
        self.btn_fetch.setVisible(tab in (1, 2))
        self.btn_setup.setVisible(tab in (1, 2))
        self.btn_install.setVisible(tab == 2)

    def _on_fleet_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            return
        data = current.data(Qt.ItemDataRole.UserRole)
        if isinstance(data, dict):
            self.fleet_detail.setText(str(data.get("detail") or current.text()))
        else:
            self.fleet_detail.setText(current.text())

    def _on_host_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            return
        row = current.data(Qt.ItemDataRole.UserRole)
        if isinstance(row, WorkloadRow):
            self.host_detail.setText(row.detail)
        else:
            self.host_detail.setText(current.text())

    def _on_catalog_select(self, current: QListWidgetItem | None, _prev) -> None:
        if current is None:
            return
        data = current.data(Qt.ItemDataRole.UserRole)
        if isinstance(data, dict):
            self.catalog_detail.setText(str(data.get("detail") or current.text()))
        else:
            self.catalog_detail.setText(current.text())

    def _fleet_use_target(self) -> None:
        item = self.fleet_list.currentItem()
        if item is None:
            info(self, "Target", "Select a host in the Fleet list first.")
            return
        data = item.data(Qt.ItemDataRole.UserRole)
        key = data.get("key") if isinstance(data, dict) else None
        ctrl = session_controller()
        if not key or key == "local":
            ctrl.set_candidate(None)
            info(
                self,
                "Target",
                "Candidate set to this machine. Disconnect in the Target bar if still remote.",
            )
            self.tabs.setCurrentIndex(1)
            return
        ctrl.set_candidate(str(key))
        ctrl.connect_target(str(key))
        self.tabs.setCurrentIndex(1)

    def _toggle_selected_pin(self) -> None:
        tab = self.tabs.currentIndex()
        key = None
        if tab == 0:
            item = self.fleet_list.currentItem()
            data = item.data(Qt.ItemDataRole.UserRole) if item else None
            if isinstance(data, dict):
                key = str(data.get("key") or "")
        elif tab == 1:
            item = self.host_list.currentItem()
            row = item.data(Qt.ItemDataRole.UserRole) if item else None
            if isinstance(row, WorkloadRow):
                key = row.pin_key
        if not key:
            info(self, "Pin", "Select a fleet host or workload row first.")
            return
        now = _toggle_pin(key)
        self.log_append(f"• {'Pinned' if now else 'Unpinned'} {key}\n")
        self._paint_fleet(cache_only=True)
        self._apply_host_filter()

    def _catalog_install(self) -> None:
        item = self.catalog_list.currentItem()
        data = item.data(Qt.ItemDataRole.UserRole) if item else None
        if not isinstance(data, dict):
            info(self, "Install", "Select a catalog profile or service first.")
            return
        kind = data.get("kind")
        key = str(data.get("key") or "")
        if not key:
            return
        where = get_active_target() or "this machine"
        if kind == "profile":
            label = f"Install profile {key} on {where}"
            args = ("install", "--profile", key)
        else:
            label = f"Install service {key} on {where}"
            args = ("install", key)
        if not confirm(
            self,
            "Install",
            f"{label}?\n\nSame requirements as CLI (virt user on Target).",
        ):
            return
        self._run(args, label, confirm=False)

    def _run(self, args: tuple[str, ...], label: str, *, confirm: bool = False) -> None:
        need = label if confirm else None
        self.run_ncc("stacks", *args, follow_target=True, need_confirm=need)
        if self.tabs.currentIndex() == 1:
            self._reload_host_async()

    def _host_status_from_cache(self) -> dict[str, Any] | None:
        active = get_active_target()
        status, _ = _cache_entry(active or "local")
        return status

    def _update_setup_preflight(self) -> None:
        status = self._host_status_from_cache()
        if not status:
            self.setup_preflight.setText(
                "Preflight: unknown — open Host tab and Refresh."
            )
            return
        docker = "ok" if status.get("docker_running") else "needs docker"
        cat = "ok" if status.get("catalog_present") else "needs fetch"
        prof = str(status.get("profiles") or "").strip() or "none"
        self.setup_preflight.setText(
            f"Preflight on Target: docker {docker} · catalog {cat} · profiles {prof}"
        )

    def _paint_metrics_from_cache(self) -> None:
        keys = ["local"]
        for host, user in list_host_pairs():
            keys.append(f"{user}@{host}")
        probed = 0
        docker_up = 0
        swarm_active = 0
        catalog_hosts = 0
        profile_set: set[str] = set()
        for key in keys:
            status, _ = _cache_entry(key)
            if status is None:
                continue
            probed += 1
            if status.get("docker_running"):
                docker_up += 1
            if str(status.get("swarm_status") or "") == "active":
                swarm_active += 1
            if status.get("catalog_present"):
                catalog_hosts += 1
            prof = str(status.get("profiles") or "")
            for p in prof.replace(",", " ").split():
                if p.strip():
                    profile_set.add(p.strip())
        tags_map = _tags_map()
        decl = self._declarative_tags
        parts: list[str] = []
        keys = sorted(set(tags_map.keys()) | set(decl.keys()))
        for k in keys:
            merged = _merged_host_tags(k, decl)
            if merged:
                parts.append(f"{k}=[{','.join(merged)}]")
        tag_summary = ", ".join(parts) if parts else "—"
        total = len(keys)
        self.met_hosts.setText(f"{probed} of {total} hosts cached")
        self.met_docker_up.setText(f"{docker_up}/{probed or total}")
        self.met_swarm.setText(f"{swarm_active}/{probed or total}")
        self.met_profiles.setText(
            ", ".join(sorted(profile_set, key=str.lower)) if profile_set else "—"
        )
        self.met_tags.setText(tag_summary)
        self.met_catalog.setText(f"{catalog_hosts}/{probed or total} with catalog")

    def _maybe_first_run_hint(self) -> None:
        status = self._host_status_from_cache()
        if status and status.get("catalog_present") and self._workloads:
            _mark_setup_complete()
            return
        info(
            self,
            "Stacks setup",
            "Phase 2: Catalog tab → Fetch catalog → Start setup → pick profile. "
            "Activity shows the install log.",
        )
        self.tabs.setCurrentIndex(2)

    def _collect_profile_names(self) -> list[str]:
        names: list[str] = []
        for i in range(self.catalog_list.count()):
            item = self.catalog_list.item(i)
            if item is None:
                continue
            data = item.data(Qt.ItemDataRole.UserRole)
            if isinstance(data, dict) and data.get("kind") == "profile":
                key = str(data.get("key") or "").strip()
                if key:
                    names.append(key)
        status = self._host_status_from_cache()
        if status:
            prof = str(status.get("profiles") or "")
            for p in prof.replace(",", " ").split():
                p = p.strip()
                if p and p not in names:
                    names.append(p)
        return sorted(set(names), key=str.lower)

    def _open_setup_wizard(self) -> None:
        profiles = self._collect_profile_names()
        if not profiles:
            self._reload_catalog_async()
            info(
                self,
                "Stacks setup",
                "Loading catalog… Press Start setup again when profiles appear.",
            )
            return
        dlg = _StacksSetupDialog(self, profiles)
        dlg.exec()

    def _run_fetch(self) -> None:
        where = get_active_target() or "this machine"
        if not confirm(
            self,
            "Fetch catalog",
            f"Clone/update NCC-Stacks on {where}?\n\n"
            "Runs as the virt user on the Target (see Activity if it fails).",
        ):
            return
        self.log_append("• fetch catalog\n")
        proc = self.run_ncc("stacks", "fetch", follow_target=True, need_confirm=None)
        if proc.returncode == 0:
            info(self, "Fetch catalog", "Catalog updated.")
            self._reload_host_async()
            self._paint_metrics_from_cache()
            self._update_setup_preflight()
        else:
            err = (proc.stderr or proc.stdout or "failed").strip()
            info(self, "Fetch catalog", err[:500])

    def _run_setup_chain(
        self,
        profile: str,
        *,
        cf_email: str = "",
        cf_token: str = "",
    ) -> None:
        status = self._host_status_from_cache()
        needs_fetch = not (status and status.get("catalog_present"))
        where = get_active_target() or "this machine"
        self.log_append(f"• setup profile {profile} on {where}\n")

        if needs_fetch:
            self.log_append("• fetch catalog (required before init)\n")
            proc = self.run_ncc(
                "stacks",
                "fetch",
                follow_target=True,
                need_confirm=None,
                timeout=600,
            )
            if proc.returncode != 0:
                self.log_append((proc.stderr or proc.stdout or "fetch failed") + "\n")
                return

        if (
            not profile.startswith("compute-")
            and cf_email
            and cf_token
        ):
            self.log_append("• write DNS env (Cloudflare)\n")
            proc = self.run_ncc(
                "stacks",
                "dns-env",
                f"--cf-email={cf_email}",
                f"--cf-token={cf_token}",
                follow_target=True,
                need_confirm=None,
                timeout=120,
            )
            if proc.returncode != 0:
                self.log_append((proc.stderr or proc.stdout or "dns-env failed") + "\n")
                return

        self.log_append(f"• init --profile {profile}\n")
        proc = self.run_ncc(
            "stacks",
            "init",
            "--profile",
            profile,
            follow_target=True,
            need_confirm=None,
            timeout=3600,
        )
        if proc.returncode == 0:
            _mark_setup_complete()
            info(self, "Stacks setup", f"Profile {profile} installed.")
            self._reload_host_async()
            self._paint_metrics_from_cache()
            self._update_setup_preflight()
        else:
            self.log_append((proc.stderr or proc.stdout or "init failed") + "\n")

    def _edit_fleet_tags(self) -> None:
        item = self.fleet_list.currentItem()
        if item is None:
            info(self, "Tags", "Select a fleet host first.")
            return
        data = item.data(Qt.ItemDataRole.UserRole)
        if not isinstance(data, dict):
            return
        key = str(data.get("key") or "")
        if not key:
            return
        dlg = QDialog(self)
        dlg.setWindowTitle(f"Tags — {key}")
        lay = QVBoxLayout(dlg)
        lay.addWidget(QLabel("Comma-separated operator tags (cockpit only):"))
        edit = QLineEdit(",".join(_host_tags(key)))
        lay.addWidget(edit)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(dlg.accept)
        buttons.rejected.connect(dlg.reject)
        lay.addWidget(buttons)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        raw = edit.text()
        tags = [t.strip() for t in raw.replace(";", ",").split(",") if t.strip()]
        _set_host_tags(key, tags)
        self.log_append(f"• tags {key}: {', '.join(tags) or 'cleared'}\n")
        self._paint_fleet(cache_only=True)
        self._paint_metrics_from_cache()


def create_page() -> StacksPage:
    return StacksPage()


Page = StacksPage
HomelabPage = StacksPage
