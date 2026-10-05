"""Doomscroll intervene actions: pause media, jump to browser desktop, overlay UI."""

from __future__ import annotations

import os
import shutil
import tempfile
import time
from typing import Any

from .preferences import (
    get_doomscroll_apps,
    get_doomscroll_block_input,
    get_doomscroll_follow_target,
    get_doomscroll_pause_media,
)


def pause_browser_media() -> bool:
    """MPRIS Pause on Playing Firefox instances."""
    from .focus import _firefox_mpris_tracks, _run

    paused = False
    for tr in _firefox_mpris_tracks():
        if (tr.get("status") or "") != "Playing":
            continue
        dest = tr.get("dest") or ""
        if not dest or not shutil.which("qdbus"):
            continue
        out = _run(
            [
                "qdbus",
                dest,
                "/org/mpris/MediaPlayer2",
                "org.mpris.MediaPlayer2.Player.Pause",
            ],
            timeout=3.0,
        )
        if out is not None:
            paused = True
    return paused


def _kwin_activate_browser(resource_hints: tuple[str, ...]) -> bool:
    """Plasma: one-shot KWin script → currentDesktop + activeWindow = matching app."""
    from .focus import _run

    if not shutil.which("qdbus"):
        return False
    hints_js = ",".join(f'"{h}"' for h in resource_hints)
    script = f"""
(function () {{
  var hints = [{hints_js}];
  var list = workspace.windowList ? workspace.windowList()
           : (workspace.clientList ? workspace.clientList() : []);
  for (var i = 0; i < list.length; i++) {{
    var w = list[i];
    var cls = String(w.resourceClass || w.resourceName || "").toLowerCase();
    var hit = false;
    for (var j = 0; j < hints.length; j++) {{
      if (cls.indexOf(hints[j]) >= 0) {{ hit = true; break; }}
    }}
    if (!hit) continue;
    try {{
      if (w.desktops && w.desktops.length)
        workspace.currentDesktop = w.desktops[0];
    }} catch (e1) {{}}
    try {{
      workspace.activeWindow = w;
    }} catch (e2) {{
      try {{ workspace.activeClient = w; }} catch (e3) {{}}
    }}
    break;
  }}
}})();
"""
    path = None
    try:
        fd, path = tempfile.mkstemp(prefix="ncc-focus-", suffix=".js")
        os.close(fd)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(script)
        plugin = f"ncc-focus-{os.getpid()}"
        sid = _run(
            [
                "qdbus",
                "org.kde.KWin",
                "/Scripting",
                "org.kde.kwin.Scripting.loadScript",
                path,
                plugin,
            ],
            timeout=3.0,
        )
        _run(
            ["qdbus", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.start"],
            timeout=3.0,
        )
        time.sleep(0.25)
        _run(
            [
                "qdbus",
                "org.kde.KWin",
                "/Scripting",
                "org.kde.kwin.Scripting.unloadScript",
                plugin,
            ],
            timeout=3.0,
        )
        return sid is not None
    except OSError:
        return False
    finally:
        if path:
            try:
                os.unlink(path)
            except OSError:
                pass


def _hyprland_activate_browser(resource_hints: tuple[str, ...]) -> bool:
    from .focus import _run

    if not shutil.which("hyprctl"):
        return False
    frag = resource_hints[0] if resource_hints else "firefox"
    raw = _run(
        ["hyprctl", "dispatch", "focuswindow", f"class:^({frag})"],
        timeout=2.0,
    )
    return raw is not None


def _resource_hints_for_apps() -> tuple[str, ...]:
    apps = get_doomscroll_apps()
    hints: list[str] = []
    for app in apps or ["firefox"]:
        if app == "firefox":
            hints.extend(("firefox", "navigator", "librewolf"))
        elif app == "chromium":
            hints.extend(("chromium", "chrome", "brave", "vivaldi"))
        elif app == "browsers":
            hints.extend(("firefox", "chromium", "chrome", "brave"))
        else:
            hints.append(app)
    seen: set[str] = set()
    out: list[str] = []
    for h in hints:
        if h not in seen:
            seen.add(h)
            out.append(h)
    return tuple(out) or ("firefox",)


def follow_target_desktop() -> bool:
    """Switch to the matched browser's virtual desktop / focus its window."""
    from .focus import detect_desktop

    hints = _resource_hints_for_apps()
    desktop = detect_desktop()
    if desktop in ("plasma-wayland", "plasma-x11"):
        return _kwin_activate_browser(hints)
    if desktop == "hyprland":
        return _hyprland_activate_browser(hints)
    return False


def apply_intervene_side_effects() -> dict[str, Any]:
    """Run configured non-UI actions (pause / follow). Call before showing dialog."""
    out: dict[str, Any] = {"paused": False, "followed": False}
    if get_doomscroll_pause_media():
        out["paused"] = pause_browser_media()
    if get_doomscroll_follow_target():
        out["followed"] = follow_target_desktop()
        if out["followed"]:
            time.sleep(0.2)
    return out


def present_interrupt_dialog(message: str, *, parent: Any = None) -> str:
    """
    Show interrupt UI. Returns 'snooze' | 'dismiss'.
    When block_input: fullscreen modal overlay (blocks browser interaction).
    Else: normal message box on the current desktop.
    """
    from PySide6.QtCore import Qt
    from PySide6.QtWidgets import (
        QDialog,
        QHBoxLayout,
        QLabel,
        QMessageBox,
        QPushButton,
        QVBoxLayout,
    )

    apply_intervene_side_effects()

    # Top-level (no parent) so the dialog maps on the desktop we just switched to,
    # not on whatever virtual desktop the Companion window lives on.
    dlg_parent = None

    if get_doomscroll_block_input():
        dlg = QDialog(dlg_parent)
        dlg.setWindowTitle("Doomscroll interrupt")
        dlg.setModal(True)
        dlg.setWindowFlags(
            Qt.WindowType.Window
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.FramelessWindowHint
        )
        dlg.setWindowState(Qt.WindowState.WindowFullScreen)
        lay = QVBoxLayout(dlg)
        lay.addStretch(1)
        title = QLabel("Focus check")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 28px; font-weight: 700;")
        body = QLabel(message)
        body.setWordWrap(True)
        body.setAlignment(Qt.AlignmentFlag.AlignCenter)
        body.setStyleSheet("font-size: 16px; max-width: 640px;")
        lay.addWidget(title)
        lay.addWidget(body)
        hint = QLabel(
            "Scroll/input to the browser underneath is blocked until you dismiss."
        )
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        hint.setStyleSheet("opacity: 0.75; margin-top: 12px;")
        lay.addWidget(hint)
        row = QHBoxLayout()
        row.addStretch(1)
        snooze_btn = QPushButton("Snooze 30 min")
        dismiss_btn = QPushButton("OK — I'm back")
        dismiss_btn.setDefault(True)
        row.addWidget(snooze_btn)
        row.addWidget(dismiss_btn)
        row.addStretch(1)
        lay.addLayout(row)
        lay.addStretch(1)
        result: dict[str, str] = {"choice": "dismiss"}

        def _snooze() -> None:
            result["choice"] = "snooze"
            dlg.accept()

        def _ok() -> None:
            result["choice"] = "dismiss"
            dlg.accept()

        snooze_btn.clicked.connect(_snooze)
        dismiss_btn.clicked.connect(_ok)
        dlg.exec()
        return result["choice"]

    QMessageBox.information(dlg_parent, "Doomscroll interrupt", message)
    snooze = QMessageBox.question(
        dlg_parent,
        "Snooze?",
        "Snooze doomscroll watchdog for 30 minutes?",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        QMessageBox.StandardButton.No,
    )
    if snooze == QMessageBox.StandardButton.Yes:
        return "snooze"
    return "dismiss"
