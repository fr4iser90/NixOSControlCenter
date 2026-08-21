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

from PySide6.QtCore import QObject, QRunnable, Qt, QThreadPool, Signal
from PySide6.QtWidgets import (
    QComboBox,
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

        self.loading = QLabel("")
        self.loading.setObjectName("nccOperatingScope")
        self.loading.setWordWrap(True)
        self.loading.setVisible(False)
        self.add_content_widget(self.loading)

        self.tabs = QTabWidget()
        self._build_fleet_tab()
        self._build_host_tab()
        self._build_catalog_tab()
        self.add_content_widget(self.tabs, stretch=1)

        self.add_action("Refresh", self.reload, primary=True, local=True)
        self.btn_use_target = self.add_action(
            "Use as Target…", self._fleet_use_target, local=True
        )
        self.btn_pin = self.add_action("Pin / Unpin", self._toggle_selected_pin, local=True)
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
        self._sync_actions()

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

    # ----- reload orchestration -----

    def reload(self) -> None:
        """User Refresh: re-paint from cache, then async probe current tab scope."""
        tab = self.tabs.currentIndex()
        self._paint_fleet(cache_only=True)
        if tab == 0:
            self._probe_fleet_async()
        elif tab == 1:
            self._reload_host_async()
        else:
            self._reload_catalog_async()
        self._sync_actions()

    def _on_target_changed(self, _t) -> None:
        # Instant — never re-probe entire fleet on Connect
        self._paint_fleet(cache_only=True)
        self._paint_host_from_cache()
        if self.tabs.currentIndex() == 1:
            self._reload_host_async()
        self._sync_actions()

    def _on_tab_changed(self, _idx: int) -> None:
        self._sync_actions()
        if self.tabs.currentIndex() == 1 and not self._workloads:
            self._reload_host_async()
        if self.tabs.currentIndex() == 2 and self.catalog_list.count() == 0:
            self._reload_catalog_async()

    # ----- fleet -----

    def _paint_fleet(self, *, cache_only: bool) -> None:
        del cache_only  # always cache-only for paint
        self.fleet_list.clear()
        pins = _pin_set()
        active = get_active_target()

        def add(key: str, title: str) -> None:
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
        label = f"{star}{title}  [{docker} · {mode}]{cur}{grey_s}{stale_s}{miss}"
        detail = self._status_detail(title, status)
        return label, detail

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

    @staticmethod
    def _status_detail(title: str, status: dict[str, Any] | None) -> str:
        if not status:
            return (
                f"{title}\nNo cached status yet. Press Refresh to probe "
                "(selection never blocks)."
            )
        profiles = str(status.get("profiles") or "").strip() or "—"
        return (
            f"{title}\n"
            f"Docker installed: {status.get('docker_installed')}\n"
            f"Docker running: {status.get('docker_running')}\n"
            f"Swarm: {status.get('swarm_status')} "
            f"(declared role: {status.get('swarm_role') or '—'})\n"
            f"Profiles: {profiles}\n"
            f"Domain: {status.get('domain') or '—'}\n"
            f"Virt user: {status.get('virt_user') or '—'}"
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
        self.btn_init_swarm.setVisible(tab == 1)
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


def create_page() -> StacksPage:
    return StacksPage()


Page = StacksPage
HomelabPage = StacksPage
