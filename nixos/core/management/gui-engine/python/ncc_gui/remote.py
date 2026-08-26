"""Run `ncc` locally or on a remote host via SSH (same NCC modules, other systemConfig)."""

from __future__ import annotations

import os
import subprocess
from collections.abc import Sequence


def target_from_env() -> str | None:
    """Connected fleet target from the GUI session env only.

    Persistence (``~/.config/ncc/active-target``) is a reconnect candidate
    until the user clears Target / chooses This machine / Disconnect —
    then the file is removed so the next start stays local.
    Connect must set ``NCC_TARGET_HOST`` before remote ``ncc`` runs.
    """
    raw = (os.environ.get("NCC_TARGET_HOST") or "").strip()
    return raw or None


def can_elevate(*, target: str | None = None, timeout: float = 8) -> bool:
    """True when elevated ``ncc`` can run without an interactive password.

    Local: already root, or ``sudo -n true``.
    Remote: ``ssh host -- sudo -n true`` (NOPASSWD on the Target).
    """
    host = (target if target is not None else target_from_env()) or ""
    host = host.strip()
    if host:
        try:
            proc = subprocess.run(
                [
                    "ssh",
                    "-o",
                    "BatchMode=yes",
                    "-o",
                    "ConnectTimeout=8",
                    host,
                    "--",
                    "sudo",
                    "-n",
                    "true",
                ],
                check=False,
                capture_output=True,
                timeout=timeout,
            )
            return proc.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    if os.geteuid() == 0:
        return True
    try:
        return (
            subprocess.run(
                ["sudo", "-n", "true"],
                check=False,
                capture_output=True,
                timeout=timeout,
            ).returncode
            == 0
        )
    except (OSError, subprocess.TimeoutExpired):
        return False


def build_ncc_argv(args: Sequence[str], *, target: str | None = None) -> list[str]:
    """Build argv for local ``ncc …`` or ``ssh target -- ncc …``."""
    host = (target if target is not None else target_from_env()) or ""
    host = host.strip()
    if not host:
        return ["ncc", *args]
    return [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=8",
        host,
        "--",
        "ncc",
        *args,
    ]


def build_elevated_ncc_argv(
    args: Sequence[str],
    *,
    target: str | None = None,
    noninteractive: bool = False,
) -> tuple[str, list[str]]:
    """Return ``(program, argv)`` for elevated ``ncc``.

    Local: prefer passwordless sudo, then pkexec, then interactive sudo
    (unless ``noninteractive=True`` — GUI must never block on a password prompt).
    Remote: ``ssh host -- sudo -n ncc …`` (requires NOPASSWD on the target).
    """
    import shutil

    host = (target if target is not None else target_from_env()) or ""
    host = host.strip()
    ncc = shutil.which("ncc") or "ncc"
    argv_tail = list(args)

    if host:
        return (
            "ssh",
            [
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=8",
                host,
                "--",
                "sudo",
                "-n",
                "ncc",
                *argv_tail,
            ],
        )

    if os.geteuid() == 0:
        return ncc, argv_tail
    if shutil.which("sudo") and subprocess.run(
        ["sudo", "-n", "true"],
        check=False,
        capture_output=True,
    ).returncode == 0:
        # Preserve assume-yes / nested chrome through sudo
        return (
            "sudo",
            [
                "-n",
                "--preserve-env=NCC_ASSUME_YES,NCC_CLI_NESTED,NCC_QUIET_SWITCH,"
                "NCC_INSTALL_SELECTION,NCC_GUI_ANSWERS_FILE,NCC_INSTALL_REPO,"
                "NCC_INSTALL_HOST_BLUEPRINT_ONLY,NCC_INSTALL_SKIP_COLLECT,"
                "NCC_INSTALL_SKIP_DEPLOY,NCC_DEPLOY_SKIP_REBUILD,NCC_REMOTE_NONINTERACTIVE,"
                "NCC_PREFLIGHT_MODE,SYSTEM_CONFIG_DIR",
                ncc,
                *argv_tail,
            ],
        )
    if shutil.which("pkexec"):
        return "pkexec", [ncc, *argv_tail]
    if noninteractive:
        raise PermissionError(
            "Need passwordless sudo (sudo -n) for GUI Apply. "
            "Or run the same command in a terminal."
        )
    if shutil.which("sudo"):
        return "sudo", [ncc, *argv_tail]
    raise PermissionError("Need sudo or pkexec for elevated ncc")


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
