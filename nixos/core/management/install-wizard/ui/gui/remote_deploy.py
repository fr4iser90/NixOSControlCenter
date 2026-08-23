"""Remote install deploy — same Host→Target chain as System → Update."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path


def run_install_wizard() -> tuple[int, str, str, str]:
    """Run PySide6 wizard locally; return (code, selection, answers_file, log)."""
    ncc = shutil.which("ncc") or "ncc"
    try:
        proc = subprocess.run(
            [ncc, "install", "wizard"],
            check=False,
            capture_output=True,
            text=True,
            timeout=3600,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", "", str(e)
    log = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if proc.returncode != 0:
        return proc.returncode, "", "", log
    selection = ""
    for line in reversed((proc.stdout or "").splitlines()):
        line = line.strip()
        if line and not line.startswith("NCC_GUI_ANSWERS_FILE="):
            selection = line
            break
    answers = ""
    for line in (proc.stderr or "").splitlines():
        if line.startswith("NCC_GUI_ANSWERS_FILE="):
            answers = line.split("=", 1)[1].strip()
            break
    if not selection:
        return 1, "", answers, log or "Wizard returned no selection."
    return 0, selection, answers, log


def flake_hostname(staging_etc: Path) -> str:
    """Read hostName from staged systemConfig for ``--flake /etc/nixos#NAME``."""
    candidates = (
        staging_etc / "systemConfig" / "core" / "management" / "system-manager" / "config.nix",
        staging_etc / "systemConfig.nix",
        staging_etc / "system-config.nix",
    )
    pat = re.compile(r'hostName\s*=\s*"([^"]+)"')
    for path in candidates:
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        m = pat.search(text)
        if m:
            return m.group(1)
    return "nixos"


def _run_install_apply(
    env: dict[str, str],
    on_log: Callable[[str], None] | None = None,
) -> tuple[int, str]:
    ncc = shutil.which("ncc") or "ncc"
    if on_log is not None:
        on_log(f"• running: {ncc} install apply\n")
    try:
        proc = subprocess.Popen(
            [ncc, "install", "apply"],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except OSError as e:
        return 1, str(e)
    lines: list[str] = []
    if proc.stdout is not None:
        for line in proc.stdout:
            lines.append(line)
            if on_log is not None:
                on_log(line)
    rc = proc.wait()
    out = "".join(lines).strip()
    if rc != 0 and "install apply" in out.lower() and "unknown" in out.lower():
        return rc, (
            f"{ncc} install apply failed — run ncc system-update on this PC first.\n\n{out}"
        )
    return rc, out


def stage_install_config(
    *,
    selection: str,
    answers_file: str,
    nixos_source: str,
    staging_etc: Path,
    dry_run: bool = False,
) -> tuple[bool, str]:
    """Generate systemConfig under *staging_etc* — never touches local ``/etc/nixos``."""
    staging_etc.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(
        {
            "NCC_INSTALL_SELECTION": selection,
            "NCC_INSTALL_REPO": nixos_source,
            "NIXOS_CONFIG_DIR": nixos_source,
            "SYSTEM_CONFIG_DIR": str(staging_etc),
            "NCC_INSTALL_SKIP_DEPLOY": "1",
            "NCC_INSTALL_SKIP_COLLECT": "1",
            "NCC_DEPLOY_SKIP_REBUILD": "1",
        }
    )
    if answers_file:
        env["NCC_GUI_ANSWERS_FILE"] = answers_file
    if dry_run:
        env["NCC_DRY_RUN"] = "1"
    rc, out = _run_install_apply(env, on_log=None)
    if rc != 0:
        return False, out or f"install apply exit {rc}"
    if dry_run:
        return True, out
    if not (staging_etc / "systemConfig").is_dir() and not (
        staging_etc / "systemConfig.nix"
    ).is_file():
        return False, (
            f"install apply produced no systemConfig under:\n{staging_etc}\n\n{out}"
        )
    return True, out


def make_staging_dir() -> Path:
    return Path(tempfile.mkdtemp(prefix="ncc-install-staging-")) / "etc-nixos"


def execute_remote_deploy(
    *,
    target: str,
    selection: str,
    answers_file: str,
    nixos_source: str,
    on_log: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Full Host→Target install chain (blocking — run off the UI thread)."""
    from ncc_gui.push_tree import (
        apply_staged_tree_on_target,
        push_nixos_tree_to_target,
        remote_nixos_rebuild_switch,
        remote_staging_dir,
        sync_system_config_to_target,
    )

    def log(msg: str) -> None:
        if on_log is not None:
            on_log(msg)

    staging = make_staging_dir()
    log("• stage systemConfig on this PC (not local /etc/nixos)\n")
    env = os.environ.copy()
    env.update(
        {
            "NCC_INSTALL_SELECTION": selection,
            "NCC_INSTALL_REPO": nixos_source,
            "NIXOS_CONFIG_DIR": nixos_source,
            "SYSTEM_CONFIG_DIR": str(staging),
            "NCC_INSTALL_SKIP_DEPLOY": "1",
            "NCC_INSTALL_SKIP_COLLECT": "1",
            "NCC_DEPLOY_SKIP_REBUILD": "1",
        }
    )
    if answers_file:
        env["NCC_GUI_ANSWERS_FILE"] = answers_file
    rc, detail = _run_install_apply(env, on_log=log)
    if rc != 0:
        return False, detail
    if not (staging / "systemConfig").is_dir() and not (staging / "systemConfig.nix").is_file():
        return False, (
            f"install apply produced no systemConfig under:\n{staging}\n\n{detail}"
        )

    flake_attr = flake_hostname(staging)
    log(f"• rsync {nixos_source} → {target}:{remote_staging_dir()}\n")
    pushed, push_detail = push_nixos_tree_to_target(nixos_source, target)
    if not pushed:
        return False, f"Failed to copy tree to Target:\n{push_detail}"
    log(f"• staged at {push_detail}\n")

    log("• apply staged tree → /etc/nixos (preserve hardware)\n")
    applied, apply_out = apply_staged_tree_on_target(target, staging=push_detail)
    log(apply_out + "\n")
    if not applied:
        return False, f"Failed to apply tree on Target:\n{apply_out}"

    log("• sync generated systemConfig → Target /etc/nixos\n")
    synced, sync_out = sync_system_config_to_target(str(staging), target)
    log(sync_out + "\n")
    if not synced:
        return False, f"Failed to copy systemConfig:\n{sync_out}"

    log(f"• nixos-rebuild switch --flake /etc/nixos#{flake_attr}\n")
    rebuilt, rebuild_out = remote_nixos_rebuild_switch(target, flake_attr)
    log(rebuild_out[-2000:] + "\n")
    if not rebuilt:
        return False, f"Rebuild failed:\n{rebuild_out[-1500:]}"
    return True, flake_attr
