#!/usr/bin/env python3
"""Run one GUI smoke script with the operator's desktop taken away from it.

The gate runs here because a GUI smoke script is started as its own interpreter, so the pytest
conftest boundary in tests/ncc-assistant/ never applies to it. Measured on the operator's
desktop before this runner existed: the gui gate connected to the live Wayland session — one
extra client on the compositor socket, 35 → 36 — because the gate only defaulted
``QT_QPA_PLATFORM`` with ``:-offscreen`` and the session already exported ``wayland;xcb``. The
pages construct, and a construct can reach the bus: ``plugins.doomscroll.watchdog`` probes KWin and the
MPRIS players on the session bus just to decide what to render.

Two removals, not two warnings:

* ``QT_QPA_PLATFORM=offscreen`` unconditionally — a session value may not outvote the gate.
* The desktop tools stop resolving (``shutil.which``), and the session bus address, the runtime
  dir it falls back to, and both display sockets leave the environment. Without them there is
  no KWin to query and no player to pause, so a page that reaches for the session finds nothing
  instead of moving the operator's windows.

A smoke script that genuinely needs a tool stubs it itself, exactly as the assistant tests do.
"""

from __future__ import annotations

import os
import runpy
import shutil
import sys

#: Same capability list as tests/ncc-assistant/conftest.py — one boundary, two entry points.
DESKTOP_BINARIES = frozenset(
    {
        "notify-send",
        "qdbus",
        "dbus-send",
        "hyprctl",
        "swaymsg",
        "kdotool",
        "wtype",
        "xdotool",
        "ydotool",
    }
)

#: Everything a process uses to find *this* graphical session.
SESSION_ENV_VARS = (
    "DBUS_SESSION_BUS_ADDRESS",
    "XDG_RUNTIME_DIR",
    "WAYLAND_DISPLAY",
    "DISPLAY",
    "XAUTHORITY",
    "HYPRLAND_INSTANCE_SIGNATURE",
    "SWAYSOCK",
)


#: The model gateway is part of the operator's session too. A ChatPage probes ``{endpoint}/models``
#: the moment it opens, with the operator's own key, and ``Settings.from_env`` defaults it to
#: localhost:11434 — so every GUI smoke dialled a real gateway and left a QThread in flight. An
#: unreadable port answers in microseconds, which is what makes the teardown below deterministic
#: instead of racing the interpreter on ~1 run in 100.
MODEL_ENDPOINT_ENV = "NCC_ASSISTANT_ENDPOINT"
UNREACHABLE_ENDPOINT = "http://127.0.0.1:1/v1"

#: Every QThread this process started. PySide destroys a running QThread at interpreter exit and
#: Qt makes that fatal ("QThread: Destroyed while thread is still running"), which is how a smoke
#: prints OK and aborts anyway — after its own assertions, so nothing in the output explains it.
STARTED_THREADS: list = []


def _track_thread_starts() -> None:
    try:
        from PySide6.QtCore import QThread
    except ImportError:
        return

    real_start = QThread.start

    def start(self, *args, **kwargs):
        STARTED_THREADS.append(self)
        return real_start(self, *args, **kwargs)

    QThread.start = start  # type: ignore[assignment]


def drain_qthreads(timeout_ms: int = 5000) -> list[str]:
    """Stop and wait for every worker the script started; name the ones that would not stop.

    Waiting is the whole point. A worker that outlives its script is not merely untidy — Qt aborts
    the process when it is destroyed mid-run, so the run dies after printing its result. A
    straggler is reported by name rather than waited away in silence.
    """
    stragglers: list[str] = []
    for thread in list(STARTED_THREADS):
        try:
            if not thread.isRunning():
                continue
            thread.requestInterruption()
            thread.quit()
            if not thread.wait(timeout_ms):
                stragglers.append(type(thread).__name__)
        except RuntimeError:
            continue  # Qt already destroyed it — nothing here can destroy it wrongly
    return stragglers


def install_desktop_boundary() -> None:
    for name in SESSION_ENV_VARS:
        os.environ.pop(name, None)
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    os.environ[MODEL_ENDPOINT_ENV] = UNREACHABLE_ENDPOINT
    # The smokes import the assistant packages straight out of the module tree, and package.nix
    # stages that tree verbatim — bytecode written here would change the store path of the shipped
    # package. validate-gui-python.sh exports this, but the runner is also invoked bare, and .gitignore
    # hides __pycache__ from git while `ncc system-update --local` copies it by path anyway.
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    sys.dont_write_bytecode = True

    real_which = shutil.which

    def which(cmd, *args, **kwargs):
        if os.path.basename(str(cmd)) in DESKTOP_BINARIES:
            return None
        return real_which(cmd, *args, **kwargs)

    shutil.which = which  # type: ignore[assignment]
    _track_thread_starts()


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: desktop_quiet_runner.py <script.py> [args...]", file=sys.stderr)
        return 2
    target = sys.argv[1]
    sys.argv = sys.argv[1:]
    install_desktop_boundary()
    try:
        runpy.run_path(target, run_name="__main__")
    finally:
        stuck = drain_qthreads()
        if stuck:
            print(
                f"desktop_quiet_runner: {', '.join(stuck)} still running at exit — the script "
                "started a worker it never stopped",
                file=sys.stderr,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
