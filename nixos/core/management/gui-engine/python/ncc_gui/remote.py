"""Run `ncc` locally or on a remote host via SSH (same NCC modules, other systemConfig)."""

from __future__ import annotations

import os
import subprocess
from collections.abc import Sequence


def target_from_env() -> str | None:
    raw = (os.environ.get("NCC_TARGET_HOST") or "").strip()
    return raw or None


def build_ncc_argv(args: Sequence[str], *, target: str | None = None) -> list[str]:
    """Build argv for local `ncc …` or `ssh target -- ncc …`."""
    host = (target if target is not None else target_from_env()) or ""
    host = host.strip()
    if not host:
        return ["ncc", *args]
    # Non-interactive remote; caller can use -t for PTY when needed.
    return ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host, "--", "ncc", *args]


def run_ncc(
    *args: str,
    target: str | None = None,
    timeout: float | None = 120,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        build_ncc_argv(args, target=target),
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
