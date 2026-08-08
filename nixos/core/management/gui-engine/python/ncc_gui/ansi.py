"""Strip ANSI / VT junk for non-interactive Activity logs.

Interactive SSH/shells must use ``ncc_gui.pty_terminal.PtyTerminal`` (pyte),
not this stripper — stripping leaves broken prompts and loses colors.
"""

from __future__ import annotations

import re

# CSI (incl. private ? / >), OSC, DCS, charset, and single-char ESC sequences (e.g. ESC=)
_ANSI_RE = re.compile(
    r"""
    \x1b\[[0-9;?]*[ -/]*[@-~]      # CSI
  | \x1b\][^\x07\x1b]*(?:\x07|\x1b\\)  # OSC
  | \x1b[PX^_][^\x1b]*\x1b\\       # DCS/PM/APC (ST-terminated)
  | \x1b[()][0-9A-Za-z]            # charset designate
  | \x1b[=>NODME78c]               # single-char ESC (DECKPAM, keypad, …)
  | \x1b.                          # leftover ESC+byte
    """,
    re.VERBOSE,
)


def strip_ansi(text: str) -> str:
    s = _ANSI_RE.sub("", text)
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    # Bel / backspace leftovers
    s = s.replace("\x07", "").replace("\x08", "")
    return s
