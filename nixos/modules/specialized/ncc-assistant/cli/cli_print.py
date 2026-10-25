"""Plain-text status lines for Python CLI (COPY-aligned; no ANSI)."""

from __future__ import annotations

import sys


def print_info(msg: str) -> None:
    print(f"info: {msg}")


def print_ok(msg: str) -> None:
    print(f"ok: {msg}")


def print_err(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
