"""Generation switch handling for NCC GUIs (event-driven, no polling).

After ``nixos-rebuild switch`` / activation:

* ``/run/current-system`` moves (SSOT) and activation atomically updates
  ``/run/ncc/generation`` → ``QFileSystemWatcher`` (+ focus fallback) fires.
* **Hard re-exec** when GUI app digests changed **or** this process still
  loads ``ncc_gui`` / ``ncc_assistant`` from an old store path.
* **Soft refresh** only when generation moved, digests match, and modules
  are already the new paths (catalog / domain pages / module toggles).

Installed once from ``ensure_app`` — every NCC Qt process gets it.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import sys
from collections.abc import Callable, Sequence
from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QObject, Qt, QTimer, Signal
from PySide6.QtWidgets import QApplication, QWidget

SYSTEM_LINK = Path("/run/current-system")
SW_BIN = SYSTEM_LINK / "sw" / "bin"
NOTIFY_DIR = Path("/run/ncc")
NOTIFY_FILE = NOTIFY_DIR / "generation"
DEBOUNCE_MS = 500
RESTART_DELAY_MS = 900
RESUME_DOMAIN_ENV = "NCC_GUI_RESUME_DOMAIN"
ACTIVITY_DIR = Path.home() / ".cache" / "ncc" / "gui-activity"
ACTIVITY_MAX_CHARS = 120_000

_STORE_PATH_RE = re.compile(r"/nix/store/[a-z0-9]{32}-[^/\s\"'${]+")
_NCC_GUI_EXEC_RE = re.compile(
    r"exec\s+(/nix/store/[^/\s\"']+-ncc-gui)/bin/ncc-gui"
)
_PYTHONPATH_RE = re.compile(r'(?:export\s+)?PYTHONPATH="([^"]+)"')
_PYTHON_EXEC_RE = re.compile(r"exec\s+(/nix/store/[^/\s\"']+/bin/python[^\s\"']*)")
_CATALOG_RE = re.compile(r"(/nix/store/[^/\s\"\)]+-ncc-gui-catalog\.json)")
_ASSISTANT_ROOT_RE = re.compile(r'export\s+NCC_ASSISTANT_ROOT="([^"]+)"')
_DOMAIN_TOOLS_RE = re.compile(
    r'export\s+NCC_ASSISTANT_DOMAIN_TOOLS_FILE="([^"]+)"'
)

# Domain page dumps / catalogs change on module toggles → soft only.
_SOFT_ONLY_MARKERS = (
    "ncc-domain-gui-src",
    "ncc-gui-catalog",
    "ncc-domain-ai-tools",
)


class GenerationBus(QObject):
    """soft_switched: new system generation, same GUI app digests."""

    soft_switched = Signal()


_bus: GenerationBus | None = None
_watcher: GenerationWatcher | None = None
_relaunch_override: Callable[[], Sequence[str]] | Sequence[str] | None = None


def _debug(msg: str) -> None:
    if os.environ.get("NCC_GUI_RELOAD_DEBUG", "").strip() in ("1", "true", "yes"):
        print(f"ncc-gui reload: {msg}", file=sys.stderr)


def generation_bus() -> GenerationBus:
    global _bus
    if _bus is None:
        _bus = GenerationBus()
    return _bus


def current_generation() -> str | None:
    """Active system profile path — ``/run/current-system`` is SSOT.

    ``/run/ncc/generation`` is only a notify trigger (may lag briefly).
    """
    try:
        if SYSTEM_LINK.exists() or SYSTEM_LINK.is_symlink():
            return str(SYSTEM_LINK.resolve())
        if NOTIFY_FILE.is_file():
            text = NOTIFY_FILE.read_text(encoding="utf-8").strip()
            if text:
                return text
        return None
    except OSError:
        return None


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _clean_store_path(raw: str) -> Path | None:
    """Strip bash ``${…}`` expansions glued into wrapper PYTHONPATH values."""
    part = raw.strip()
    if not part:
        return None
    if "${" in part:
        part = part.split("${", 1)[0]
    part = part.rstrip(":").strip()
    m = _STORE_PATH_RE.match(part)
    if m:
        part = m.group(0)
    if not part.startswith("/nix/store/"):
        return None
    path = Path(part)
    if path.exists():
        return path
    return None


def _ncc_gui_bin() -> Path | None:
    ncc = SW_BIN / "ncc"
    text = _read_text(ncc)
    m = _NCC_GUI_EXEC_RE.search(text)
    if m:
        candidate = Path(m.group(1)) / "bin" / "ncc-gui"
        if candidate.is_file():
            return candidate
    for name in ("ncc-gui",):
        p = SW_BIN / name
        if p.is_file():
            return p
    for m in _STORE_PATH_RE.finditer(text):
        if m.group(0).endswith("-ncc-gui"):
            candidate = Path(m.group(0)) / "bin" / "ncc-gui"
            if candidate.is_file():
                return candidate
    return None


def _python_from_wrapper(wrapper: Path) -> str:
    text = _read_text(wrapper)
    m = _PYTHON_EXEC_RE.search(text)
    return m.group(1) if m else ""


def _hash_tree(root: Path) -> str:
    h = hashlib.sha256()
    if not root.is_dir():
        return ""
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts or path.suffix == ".pyc":
            continue
        rel = path.relative_to(root).as_posix().encode()
        h.update(rel)
        h.update(b"\0")
        try:
            h.update(path.read_bytes())
        except OSError:
            continue
        h.update(b"\0")
    return h.hexdigest()


def _soft_only_path(path: Path) -> bool:
    s = str(path)
    return any(m in s for m in _SOFT_ONLY_MARKERS)


def _iter_gui_wrappers() -> list[Path]:
    """All NCC GUI entrypoints on the active profile (generic discovery)."""
    if not SW_BIN.is_dir():
        return []
    out: list[Path] = []
    for p in sorted(SW_BIN.iterdir()):
        if not p.is_file() and not p.is_symlink():
            continue
        name = p.name
        if name in ("ncc-gui", "ncc-assistant", "ncc-domain-gui"):
            out.append(p)
        elif name.startswith("ncc-") and name.endswith("-gui"):
            out.append(p)
    return out


def _payload_digests_from_root(root: Path) -> list[str]:
    """Hash known GUI packages under a PYTHONPATH / app root (skip soft-only)."""
    if _soft_only_path(root):
        lines: list[str] = []
        for pkg in ("ncc_gui", "ncc_assistant"):
            d = root / pkg
            if d.is_dir():
                lines.append(f"{pkg}@{root.name}={_hash_tree(d)}")
        return lines
    lines = []
    for pkg in ("ncc_gui", "ncc_assistant"):
        d = root / pkg
        if d.is_dir():
            lines.append(f"{pkg}@{root.name}={_hash_tree(d)}")
    if lines:
        return lines
    if root.is_dir():
        return [f"tree@{root.name}={_hash_tree(root)}"]
    return []


def _roots_from_wrapper(wrapper: Path) -> list[Path]:
    text = _read_text(wrapper)
    roots: list[Path] = []
    m = _ASSISTANT_ROOT_RE.search(text)
    if m:
        cleaned = _clean_store_path(m.group(1))
        if cleaned is not None:
            roots.append(cleaned)
    for m in _PYTHONPATH_RE.finditer(text):
        for part in m.group(1).split(":"):
            cleaned = _clean_store_path(part)
            if cleaned is not None:
                roots.append(cleaned)
    seen: set[str] = set()
    out: list[Path] = []
    for r in roots:
        key = str(r)
        if key in seen:
            continue
        seen.add(key)
        out.append(r)
    return out


def profile_gui_fingerprint() -> str:
    """Digest of **all** GUI app payloads on the active system (not catalogs)."""
    lines: list[str] = []
    pythons: list[str] = []
    for wrapper in _iter_gui_wrappers():
        py = _python_from_wrapper(wrapper)
        if py:
            pythons.append(f"python@{wrapper.name}={py}")
        for root in _roots_from_wrapper(wrapper):
            lines.extend(_payload_digests_from_root(root))
        text = _read_text(wrapper)
        tm = _DOMAIN_TOOLS_RE.search(text)
        if tm:
            lines.append(f"domain_tools@{wrapper.name}={tm.group(1)}")

    if not lines:
        for mod_name in ("ncc_gui", "ncc_assistant"):
            try:
                mod = __import__(mod_name)
                root = Path(mod.__file__).resolve().parent  # type: ignore[arg-type]
                lines.append(f"{mod_name}@runtime={_hash_tree(root)}")
            except Exception:
                pass

    lines.extend(sorted(set(pythons)))
    return "\n".join(sorted(set(lines)))


def profile_gui_package_dirs() -> set[str]:
    """Absolute package dirs (``…/ncc_gui``, ``…/ncc_assistant``) on the profile."""
    out: set[str] = set()
    for wrapper in _iter_gui_wrappers():
        for root in _roots_from_wrapper(wrapper):
            for pkg in ("ncc_gui", "ncc_assistant"):
                d = root / pkg
                if d.is_dir():
                    try:
                        out.add(str(d.resolve()))
                    except OSError:
                        out.add(str(d))
    return out


def process_gui_stale() -> bool:
    """True if this process still imports GUI code from an old store path."""
    advertised = profile_gui_package_dirs()
    if not advertised:
        return False
    for name in ("ncc_gui", "ncc_assistant"):
        mod = sys.modules.get(name)
        if mod is None:
            continue
        f = getattr(mod, "__file__", None)
        if not f:
            continue
        try:
            here = str(Path(f).resolve().parent)
        except OSError:
            continue
        if here not in advertised:
            _debug(f"stale {name}: loaded={here} not in profile")
            return True
    return False


def refresh_catalog_env() -> bool:
    text = _read_text(SW_BIN / "ncc")
    m = _CATALOG_RE.search(text)
    if not m:
        return False
    path = Path(m.group(1))
    try:
        os.environ["NCC_GUI_CATALOG"] = path.read_text(encoding="utf-8")
    except OSError:
        return False
    return True


def refresh_runtime_paths() -> bool:
    wrapper = _ncc_gui_bin()
    if wrapper is None:
        return False
    text = _read_text(wrapper)
    m = _PYTHONPATH_RE.search(text)
    if not m:
        return False
    cleaned = _clean_store_path(m.group(1).split(":")[0])
    if cleaned is None or not cleaned.is_dir():
        return False
    src = str(cleaned)
    while src in sys.path:
        sys.path.remove(src)
    sys.path.insert(0, src)
    prev = os.environ.get("PYTHONPATH", "")
    parts = [p for p in prev.split(":") if p and p != src]
    os.environ["PYTHONPATH"] = src + ((":" + ":".join(parts)) if parts else "")
    return True


def resolve_ncc() -> str:
    for candidate in (
        "/run/current-system/sw/bin/ncc",
        shutil.which("ncc") or "",
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return "ncc"


def resolve_executable(name: str) -> str:
    for candidate in (
        f"/run/current-system/sw/bin/{name}",
        shutil.which(name) or "",
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return name


def pop_resume_domain() -> str | None:
    val = os.environ.pop(RESUME_DOMAIN_ENV, "").strip()
    return val or None


def root_relaunch_argv(*, domain_id: str | None = None) -> list[str]:
    argv = [resolve_ncc(), "gui"]
    if domain_id:
        os.environ[RESUME_DOMAIN_ENV] = domain_id
    return argv


def domain_relaunch_argv(domain_id: str) -> list[str]:
    return [resolve_ncc(), domain_id, "--gui"]


def default_relaunch_argv() -> list[str]:
    """Re-exec whatever started this process (works for any NCC GUI)."""
    argv = list(sys.argv)
    if not argv:
        return [resolve_ncc(), "gui"]
    prog = argv[0]
    base = Path(prog).name
    if base.startswith("ncc"):
        resolved = resolve_executable(base)
        argv = [resolved, *argv[1:]]
    return argv


def set_relaunch_argv(
    relaunch: Callable[[], Sequence[str]] | Sequence[str],
) -> None:
    """Optional override (e.g. root shell resumes current domain)."""
    global _relaunch_override
    _relaunch_override = relaunch
    if _watcher is not None:
        _watcher._relaunch = relaunch


def activity_path(key: str) -> Path:
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in key.strip()) or "page"
    return ACTIVITY_DIR / f"{safe}.txt"


def load_activity(key: str) -> str:
    if not key:
        return ""
    try:
        text = activity_path(key).read_text(encoding="utf-8")
    except OSError:
        return ""
    return text[-ACTIVITY_MAX_CHARS:] if len(text) > ACTIVITY_MAX_CHARS else text


def save_activity(key: str, text: str) -> None:
    if not key:
        return
    body = text[-ACTIVITY_MAX_CHARS:] if len(text) > ACTIVITY_MAX_CHARS else text
    try:
        ACTIVITY_DIR.mkdir(parents=True, exist_ok=True)
        activity_path(key).write_text(body, encoding="utf-8")
    except OSError:
        pass


def persist_open_activity() -> None:
    app = QApplication.instance()
    if app is None:
        return
    for w in app.allWidgets():
        key = getattr(w, "_activity_key", None)
        log = getattr(w, "log", None)
        if not key or log is None:
            continue
        try:
            save_activity(str(key), log.toPlainText())
        except Exception:
            pass


def reexec(argv: Sequence[str]) -> None:
    if not argv:
        return
    persist_open_activity()
    program = argv[0]
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)
    _debug(f"execve {argv}")
    try:
        os.execve(program, list(argv), env)
    except OSError as exc:
        print(f"ncc-gui: reload failed ({program}): {exc}", file=sys.stderr)


class GenerationWatcher(QObject):
    """Watch ``/run/current-system`` + ``/run/ncc/generation``; focus fallback."""

    def __init__(
        self,
        *,
        relaunch_argv: Sequence[str] | Callable[[], Sequence[str]],
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._relaunch = relaunch_argv
        self._seen = current_generation()
        self._gui_fp = profile_gui_fingerprint()
        self._restarting = False
        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(DEBOUNCE_MS)
        self._debounce.timeout.connect(self._evaluate)

        self._fs = QFileSystemWatcher(self)
        self._fs.fileChanged.connect(self._on_fs_event)
        self._fs.directoryChanged.connect(self._on_fs_event)
        self._arm_watches()

        app = QApplication.instance()
        if app is not None:
            app.applicationStateChanged.connect(self._on_app_state)

        _debug(f"armed seen={self._seen} fp_lines={len(self._gui_fp.splitlines())}")

    def _arm_watches(self) -> None:
        want: list[str] = ["/run"]
        if NOTIFY_DIR.is_dir():
            want.append(str(NOTIFY_DIR))
        if NOTIFY_FILE.is_file():
            want.append(str(NOTIFY_FILE))
        if SYSTEM_LINK.exists() or SYSTEM_LINK.is_symlink():
            want.append(str(SYSTEM_LINK))
        # Parent of the symlink (often /run) already listed; also watch sw/bin
        if SW_BIN.is_dir():
            want.append(str(SW_BIN))
        have = set(self._fs.files()) | set(self._fs.directories())
        for p in want:
            if p not in have:
                ok = self._fs.addPath(p)
                if not ok:
                    _debug(f"addPath failed: {p}")

    def _on_fs_event(self, path: str = "") -> None:
        if self._restarting:
            return
        _debug(f"fs event: {path}")
        # Watches drop on replace/rename — re-arm immediately
        self._arm_watches()
        self._debounce.start()

    def _on_app_state(self, state: Qt.ApplicationState) -> None:
        if self._restarting:
            return
        if state == Qt.ApplicationState.ApplicationActive:
            _debug("app active → evaluate")
            self._debounce.start()

    def _evaluate(self) -> None:
        if self._restarting:
            return
        self._arm_watches()
        now = current_generation()
        if now is None:
            return
        if self._seen is None:
            self._seen = now
            self._gui_fp = profile_gui_fingerprint()
            return
        if now == self._seen:
            # Same generation string — still catch stale modules if profile
            # wrappers were updated in place (unusual) or we missed an event.
            if process_gui_stale():
                _debug("same gen but process stale → hard restart")
                self._gui_fp = profile_gui_fingerprint()
                self._schedule_hard_restart()
            return

        _debug(f"generation {self._seen} → {now}")
        self._seen = now
        new_fp = profile_gui_fingerprint()
        stale = process_gui_stale()
        same_fp = bool(new_fp and self._gui_fp and new_fp == self._gui_fp)
        _debug(f"same_fp={same_fp} stale={stale}")

        if same_fp and not stale:
            refresh_catalog_env()
            refresh_runtime_paths()
            generation_bus().soft_switched.emit()
            return
        if not new_fp and not stale:
            # Mid-switch; wait for next FS event / focus
            _debug("empty fingerprint, waiting")
            return
        self._gui_fp = new_fp or self._gui_fp
        self._schedule_hard_restart()

    def _schedule_hard_restart(self) -> None:
        self._restarting = True
        app = QApplication.instance()
        if app is not None:
            for w in app.topLevelWidgets():
                if isinstance(w, QWidget) and w.isVisible():
                    w.setWindowTitle(f"{w.windowTitle()} — reloading GUI…")
        QTimer.singleShot(RESTART_DELAY_MS, self._restart)

    def _restart(self) -> None:
        relaunch = _relaunch_override if _relaunch_override is not None else self._relaunch
        argv = relaunch() if callable(relaunch) else list(relaunch)
        reexec(argv)


def install_generation_watcher(
    *,
    relaunch_argv: Sequence[str] | Callable[[], Sequence[str]] | None = None,
    parent: QObject | None = None,
) -> GenerationWatcher | None:
    """Start watching once per process. No-op off NixOS."""
    global _watcher
    if _watcher is not None:
        if relaunch_argv is not None:
            set_relaunch_argv(relaunch_argv)
        return _watcher
    if current_generation() is None and not SYSTEM_LINK.exists():
        return None
    _watcher = GenerationWatcher(
        relaunch_argv=relaunch_argv or default_relaunch_argv,
        parent=parent,
    )
    return _watcher
