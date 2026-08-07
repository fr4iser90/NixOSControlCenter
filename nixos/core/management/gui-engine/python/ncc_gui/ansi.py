"""Strip ANSI / CLI-formatter escape sequences for Qt log widgets."""

from __future__ import annotations

import re

# CSI sequences (colors, bold, …) + OSC junk if any
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def strip_ansi(text: str) -> str:
    return _ANSI_RE.sub("", text)
