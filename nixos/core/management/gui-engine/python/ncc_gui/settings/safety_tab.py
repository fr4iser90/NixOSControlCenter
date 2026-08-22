"""Host safety policy — same Apply contract as CommitBar (write, then rebuild modal)."""

from __future__ import annotations

import json
import os
import subprocess
from typing import Any

from PySide6.QtCore import QProcess, QProcessEnvironment, QSettings, Qt
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QLabel,
    QProgressDialog,
    QVBoxLayout,
    QWidget,
)

from ncc_gui.commit_bar import offer_rebuild_after_apply
from ncc_gui.dialogs import confirm, error, info
from ncc_gui.remote import build_elevated_ncc_argv, can_elevate
from ncc_gui.settings.protocol import SettingsTabSpec
from ncc_gui.theme import APP_STYLE

_ORG = "NixOSControlCenter"
_APP = "ncc-gui"
_KEY_DANGER = "safety/dangerousIgnore"
_KEY_AUTO = "safety/autoBuild"

# Keep refs so GC does not kill async rebuild / progress UI.
_rebuild_proc: QProcess | None = None
_rebuild_progress: QProgressDialog | None = None


def load_host_policy() -> dict[str, Any]:
    raw = (os.environ.get("NCC_HOST_POLICY") or "").strip()
    if not raw:
        return {"dangerousIgnore": False, "autoBuild": False}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {"dangerousIgnore": False, "autoBuild": False}
    if not isinstance(data, dict):
        return {"dangerousIgnore": False, "autoBuild": False}
    return {
        "dangerousIgnore": bool(data.get("dangerousIgnore", False)),
        "autoBuild": bool(data.get("autoBuild", False)),
    }


def _qs() -> QSettings:
    return QSettings(_ORG, _APP)


def _cache_get(key: str, fallback: bool) -> bool:
    v = _qs().value(key, None)
    if v is None:
        return fallback
    if isinstance(v, bool):
        return v
    return bool(_qs().value(key, fallback, type=bool))


def _cache_set(key: str, value: bool) -> None:
    _qs().setValue(key, bool(value))
    _qs().sync()


def _cli_hint(d: bool, b: bool) -> str:
    return (
        "sudo NCC_ASSUME_YES=1 ncc system host-policy "
        f"--dangerous-ignore={'true' if d else 'false'} "
        f"--auto-build={'true' if b else 'false'}\n"
        "sudo ncc system build switch"
    )


class _SafetyPage(QWidget):
    """Cache toggles; Settings OK → write (like CommitBar Apply), then rebuild offer."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet(APP_STYLE)
        policy = load_host_policy()
        self._live_danger = bool(policy["dangerousIgnore"])
        self._live_build = bool(policy["autoBuild"])

        lay = QVBoxLayout(self)
        lay.setContentsMargins(8, 8, 8, 8)

        tip = QLabel(
            "These options control confirmation prompts and automatic rebuilds "
            "on this machine. Changes are remembered when you toggle them. "
            "Press OK to save them to the system configuration. "
            "You will then be asked whether to rebuild so they take effect."
        )
        tip.setObjectName("nccPageSubtitle")
        tip.setWordWrap(True)
        lay.addWidget(tip)

        live = QLabel(
            "Currently active on this system: "
            f"skip danger prompts = {'yes' if self._live_danger else 'no'}, "
            f"auto rebuild after update = {'yes' if self._live_build else 'no'}"
        )
        live.setObjectName("nccPageSubtitle")
        live.setWordWrap(True)
        lay.addWidget(live)

        self.dangerous = QCheckBox("Skip “are you sure?” prompts for risky commands")
        self.dangerous.setChecked(_cache_get(_KEY_DANGER, self._live_danger))
        self.dangerous.setToolTip(
            "When on, commands that normally ask for confirmation continue without asking. "
            "Useful for automation; less safe for everyday use."
        )
        self.dangerous.toggled.connect(
            lambda on: _cache_set(_KEY_DANGER, bool(on))
        )
        lay.addWidget(self.dangerous)

        self.auto_build = QCheckBox("After a system update, rebuild and switch automatically")
        self.auto_build.setChecked(_cache_get(_KEY_AUTO, self._live_build))
        self.auto_build.setToolTip(
            "When on, a successful system update continues into rebuild and switch "
            "without asking again."
        )
        self.auto_build.toggled.connect(
            lambda on: _cache_set(_KEY_AUTO, bool(on))
        )
        lay.addWidget(self.auto_build)

        warn = QLabel(
            "These settings reduce safety checks. "
            "Saving needs administrator rights. "
            "They only become active after a rebuild."
        )
        warn.setObjectName("nccPageSubtitle")
        warn.setWordWrap(True)
        lay.addWidget(warn)
        lay.addStretch(1)

    def collect(self) -> dict:
        d = bool(self.dangerous.isChecked())
        b = bool(self.auto_build.isChecked())
        _cache_set(_KEY_DANGER, d)
        _cache_set(_KEY_AUTO, b)
        return {
            "dangerousIgnore": d,
            "autoBuild": b,
            "changed": d != self._live_danger or b != self._live_build,
        }


def _start_rebuild_async(parent: QWidget | None) -> None:
    """Non-blocking rebuild with a visible progress dialog."""
    global _rebuild_proc, _rebuild_progress
    args = ["system", "build", "switch"]
    try:
        prog, argv = build_elevated_ncc_argv(args, noninteractive=True)
    except PermissionError as exc:
        error(
            parent,
            "Could not rebuild",
            f"{exc}\n\nTry again from a terminal: sudo ncc system build switch",
        )
        return

    progress = QProgressDialog(
        "Rebuilding the system…\nThis can take a few minutes.",
        None,
        0,
        0,
        parent,
    )
    progress.setWindowTitle("Rebuild")
    progress.setWindowModality(Qt.WindowModality.ApplicationModal)
    progress.setMinimumDuration(0)
    progress.setCancelButton(None)
    progress.setRange(0, 0)
    progress.show()
    _rebuild_progress = progress

    env = QProcessEnvironment.systemEnvironment()
    env.insert("NCC_ASSUME_YES", "1")
    env.insert("NCC_CLI_NESTED", "1")
    proc = QProcess(QApplication.instance())
    proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
    proc.setProcessEnvironment(env)

    def _done(code: int, _status: object) -> None:
        global _rebuild_proc, _rebuild_progress
        if _rebuild_progress is not None:
            _rebuild_progress.close()
            _rebuild_progress = None
        _rebuild_proc = None
        if code == 0:
            info(
                parent,
                "Rebuild finished",
                "Your safety settings are now active. "
                "Close and re-open Control Center to refresh the display.",
            )
        else:
            out = bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
            error(
                parent,
                "Rebuild failed",
                (out or f"Something went wrong (exit {code}).")[:1500],
            )

    proc.finished.connect(_done)
    _rebuild_proc = proc
    proc.start(prog, list(argv))
    if not proc.waitForStarted(5000):
        if _rebuild_progress is not None:
            _rebuild_progress.close()
            _rebuild_progress = None
        _rebuild_proc = None
        error(
            parent,
            "Could not start rebuild",
            "The rebuild could not be started. Try again, or run it from a terminal.",
        )


def _apply(data: dict) -> None:
    """Write config, then offer rebuild (plain UI copy)."""
    d = bool(data.get("dangerousIgnore"))
    b = bool(data.get("autoBuild"))
    _cache_set(_KEY_DANGER, d)
    _cache_set(_KEY_AUTO, b)
    if not data.get("changed"):
        return

    parent = QApplication.activeWindow()
    skip = "on" if d else "off"
    auto = "on" if b else "off"
    if not confirm(
        parent,
        "Save safety settings?",
        "Save these settings to the system configuration?\n\n"
        f"• Skip risky-command prompts: {skip}\n"
        f"• Auto rebuild after update: {auto}\n\n"
        "They will not take effect until you rebuild the system. "
        "You can choose that in the next step.",
    ):
        return

    if not can_elevate():
        error(
            parent,
            "Administrator rights needed",
            "Saving these settings needs administrator rights "
            "(passwordless sudo on this machine).\n\n"
            "You can also run this in a terminal:\n\n"
            + _cli_hint(d, b),
        )
        return

    write_args = [
        "system",
        "host-policy",
        f"--dangerous-ignore={'true' if d else 'false'}",
        f"--auto-build={'true' if b else 'false'}",
    ]
    try:
        prog, argv = build_elevated_ncc_argv(write_args, noninteractive=True)
        env = os.environ.copy()
        env["NCC_ASSUME_YES"] = "1"
        # Write only — must stay short; never --rebuild here (that froze the UI).
        proc = subprocess.run(
            [prog, *argv],
            check=False,
            capture_output=True,
            text=True,
            timeout=90,
            env=env,
        )
    except PermissionError as exc:
        error(
            parent,
            "Could not save",
            f"{exc}\n\nYou can save from a terminal instead:\n\n{_cli_hint(d, b)}",
        )
        return
    except subprocess.TimeoutExpired:
        error(
            parent,
            "Saving took too long",
            "The configuration could not be written in time.\n\n"
            "Try again, or run this in a terminal:\n\n"
            + _cli_hint(d, b),
        )
        return
    except OSError as exc:
        error(parent, "Could not save", str(exc))
        return

    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
        if "Unknown" in err or "host-policy" in err.lower():
            err = (
                "This Control Center build does not include the save command yet.\n\n"
                "Update the system from your NCC repo first, then try again.\n\n"
                "Or save from a terminal:\n\n"
                + _cli_hint(d, b)
            )
        error(parent, "Could not save", err[:2000])
        return

    # No extra “saved” popup — the rebuild dialog already explains that.
    if offer_rebuild_after_apply(
        parent,
        f"Skip risky prompts: {skip}. Auto rebuild after update: {auto}.",
    ):
        _start_rebuild_async(parent)
    else:
        info(
            parent,
            "Settings saved",
            "Saved. Rebuild later when you want them to take effect "
            "(System page → rebuild, or: sudo ncc system build switch).",
        )


def safety_settings_tab() -> SettingsTabSpec:
    return SettingsTabSpec(
        id="safety",
        title="Safety",
        build=lambda parent: _SafetyPage(parent),
        collect=lambda w: w.collect() if isinstance(w, _SafetyPage) else {},
        apply=_apply,
        order=15,
        subtitle="Confirmations and automatic rebuild",
    )
