#!/usr/bin/env python3
"""Run one GUI smoke script with the operator's desktop taken away from it.

The gate runs here because a GUI smoke script is started as its own interpreter, so the pytest
conftest boundary in tests/ncc-assistant/ never applies to it. Measured on the operator's
desktop before this runner existed: the gui gate connected to the live Wayland session — one
extra client on the compositor socket, 35 → 36 — because the gate only defaulted
``QT_QPA_PLATFORM`` with ``:-offscreen`` and the session already exported ``wayland;xcb``. The
pages construct, and a construct can reach the bus: ``ncc_assistant.focus`` probes KWin and the
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


def install_desktop_boundary() -> None:
    for name in SESSION_ENV_VARS:
        os.environ.pop(name, None)
    os.environ["QT_QPA_PLATFORM"] = "offscreen"

    real_which = shutil.which

    def which(cmd, *args, **kwargs):
        if os.path.basename(str(cmd)) in DESKTOP_BINARIES:
            return None
        return real_which(cmd, *args, **kwargs)

    shutil.which = which  # type: ignore[assignment]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: desktop_quiet_runner.py <script.py> [args...]", file=sys.stderr)
        return 2
    target = sys.argv[1]
    sys.argv = sys.argv[1:]
    install_desktop_boundary()
    runpy.run_path(target, run_name="__main__")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
