"""Generation switch handling for NCC GUI.

After ``nixos-rebuild switch``:

* **Hard reload (re-exec)** only when the **GUI kit** (``ncc_gui/`` sources) or
  the Python env store path changes.
* **Soft refresh** when only catalog / domain pages / CLI wrappers move
  (e.g. module enable/disable) — keep the window + Activity; refresh nav/data.

``ncc`` and ``ncc-domain-gui-src`` change on almost every module toggle; those
must **not** force a hard restart.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import sys
from collections.abc import Callable, Sequence
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, Signal
from PySide6.QtWidgets import QApplication, QWidget

SYSTEM_LINK = Path("/run/current-system")
SW_BIN = SYSTEM_LINK / "sw" / "bin"
POLL_MS = 2000
RESTART_DELAY_MS = 900
RESUME_DOMAIN_ENV = "NCC_GUI_RESUME_DOMAIN"
ACTIVITY_DIR = Path.home() / ".cache" / "ncc" / "gui-activity"
ACTIVITY_MAX_CHARS = 120_000

_STORE_PATH_RE = re.compile(r"/nix/store/[a-z0-9]{32}-[^/\s\"']+")
_NCC_GUI_EXEC_RE = re.compile(
    r"exec\s+(/nix/store/[^/\s\"']+-ncc-gui)/bin/ncc-gui"
)
_PYTHONPATH_RE = re.compile(r'PYTHONPATH="(/nix/store/[^"${]+)')
_PYTHON_EXEC_RE = re.compile(r"exec\s+(/nix/store/[^/\s\"']+/bin/python[^\s\"']*)")
_CATALOG_RE = re.compile(r"(/nix/store/[^/\s\"\)]+-ncc-gui-catalog\.json)")


class GenerationBus(QObject):
    """soft_switched: new system generation, same GUI kit digest."""

    soft_switched = Signal()


_bus: GenerationBus | None = None


def generation_bus() -> GenerationBus:
    global _bus
    if _bus is None:
        _bus = GenerationBus()
    return _bus


def current_generation() -> str | None:
    try:
        if not SYSTEM_LINK.exists():
            return None
        return str(SYSTEM_LINK.resolve())
    except OSError:
        return None


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _ncc_gui_bin() -> Path | None:
    """Locate ``…/ncc-gui`` referenced by the active ``ncc`` wrapper."""
    ncc = SW_BIN / "ncc"
    text = _read_text(ncc)
    m = _NCC_GUI_EXEC_RE.search(text)
    if m:
        candidate = Path(m.group(1)) / "bin" / "ncc-gui"
        if candidate.is_file():
            return candidate
    # Fallbacks
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


def _kit_root_from_wrapper(wrapper: Path) -> Path | None:
    text = _read_text(wrapper)
    m = _PYTHONPATH_RE.search(text)
    if not m:
        return None
    root = Path(m.group(1))
    kit = root / "ncc_gui"
    return kit if kit.is_dir() else None


def _python_from_wrapper(wrapper: Path) -> str:
    text = _read_text(wrapper)
    m = _PYTHON_EXEC_RE.search(text)
    return m.group(1) if m else ""


def _hash_tree(root: Path) -> str:
    """Stable content digest of files under ``root`` (skip pycache)."""
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


def profile_gui_fingerprint() -> str:
    """Digest of GUI **kit** sources + Python env — not ``ncc`` / domain pages.

    Module enable/disable rebuilds catalog + ``ncc-domain-gui-src`` (pages), but
    the copied ``ncc_gui/`` kit and python env often stay byte-identical.
    """
    wrapper = _ncc_gui_bin()
    if wrapper is None:
        return ""
    kit = _kit_root_from_wrapper(wrapper)
    kit_digest = _hash_tree(kit) if kit is not None else ""
    py = _python_from_wrapper(wrapper)
    # Also hash running-process kit as fallback if wrapper unreadable mid-switch
    if not kit_digest:
        try:
            import ncc_gui as _ng

            kit_digest = _hash_tree(Path(_ng.__file__).resolve().parent)
        except Exception:
            pass
    return f"kit={kit_digest}\npython={py}"


def refresh_catalog_env() -> bool:
    """Point ``NCC_GUI_CATALOG`` at the JSON from the new system profile."""
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
    """Point ``sys.path`` / ``PYTHONPATH`` at the new ``ncc-domain-gui-src``.

    Kit digest may be unchanged while domain pages / catalog moved — soft
    refresh still needs the new src on ``sys.path`` for imports.
    """
    import sys

    wrapper = _ncc_gui_bin()
    if wrapper is None:
        return False
    text = _read_text(wrapper)
    m = _PYTHONPATH_RE.search(text)
    if not m:
        return False
    src = m.group(1)
    if not Path(src).is_dir():
        return False
    # Prefer new src first
    while src in sys.path:
        sys.path.remove(src)
    sys.path.insert(0, src)
    prev = os.environ.get("PYTHONPATH", "")
    parts = [p for p in prev.split(":") if p and p != src]
    os.environ["PYTHONPATH"] = src + ((":" + ":".join(parts)) if parts else "")
    return True


def resolve_ncc() -> str:
    """Prefer the active system profile so we pick up the post-switch binary."""
    for candidate in (
        "/run/current-system/sw/bin/ncc",
        shutil.which("ncc") or "",
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return "ncc"


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
    """Snapshot Activity from open DomainPages (before hard re-exec)."""
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
    """Replace this process with a fresh NCC GUI (does not return)."""
    if not argv:
        return
    persist_open_activity()
    program = argv[0]
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)
    try:
        os.execve(program, list(argv), env)
    except OSError as exc:
        print(f"ncc-gui: reload failed ({program}): {exc}", file=sys.stderr)


class GenerationWatcher(QObject):
    """Poll ``/run/current-system``; hard re-exec only when GUI kit digest moves."""

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
        self._timer = QTimer(self)
        self._timer.setInterval(POLL_MS)
        self._timer.timeout.connect(self._tick)
        if self._seen is not None:
            self._timer.start()

    def _tick(self) -> None:
        if self._restarting:
            return
        now = current_generation()
        if now is None:
            return
        if self._seen is None:
            self._seen = now
            self._gui_fp = profile_gui_fingerprint()
            return
        if now == self._seen:
            return
        self._seen = now
        new_fp = profile_gui_fingerprint()
        if new_fp and self._gui_fp and new_fp == self._gui_fp:
            refresh_catalog_env()
            refresh_runtime_paths()
            generation_bus().soft_switched.emit()
            return
        # Empty fingerprint mid-switch → wait for next poll
        if not new_fp:
            return
        self._gui_fp = new_fp
        self._schedule_hard_restart()

    def _schedule_hard_restart(self) -> None:
        self._restarting = True
        self._timer.stop()
        app = QApplication.instance()
        if app is not None:
            for w in app.topLevelWidgets():
                if isinstance(w, QWidget) and w.isVisible():
                    w.setWindowTitle(f"{w.windowTitle()} — reloading GUI…")
        QTimer.singleShot(RESTART_DELAY_MS, self._restart)

    def _restart(self) -> None:
        argv = self._relaunch() if callable(self._relaunch) else list(self._relaunch)
        reexec(argv)


def install_generation_watcher(
    *,
    relaunch_argv: Sequence[str] | Callable[[], Sequence[str]],
    parent: QObject | None = None,
) -> GenerationWatcher | None:
    """Start watching; no-op when not on NixOS (no ``/run/current-system``)."""
    if current_generation() is None:
        return None
    return GenerationWatcher(relaunch_argv=relaunch_argv, parent=parent)
