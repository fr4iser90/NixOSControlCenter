"""Remote install deploy — same Host→Target chain as System → Update."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
from collections.abc import Callable
from pathlib import Path

# Host staging: blueprint only — never collect Host hardware into systemConfig.
_HOST_STAGING_ENV = {
    "NCC_INSTALL_HOST_BLUEPRINT_ONLY": "1",
    "NCC_INSTALL_SKIP_DEPLOY": "1",
    "NCC_DEPLOY_SKIP_REBUILD": "1",
}


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
            **_HOST_STAGING_ENV,
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
    sudo_password: str | None = None,
    on_log: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Full Host→Target install chain (blocking — run off the UI thread)."""
    from ncc_gui.push_tree import (
        apply_staged_tree_on_target,
        push_nixos_tree_to_target,
        remote_staging_dir,
        remote_target_install_gate,
        sync_system_config_to_target,
    )

    def log(msg: str) -> None:
        if on_log is not None:
            on_log(msg)

    staging = make_staging_dir()
    log("• [Host] stage systemConfig from blueprint (no Host hardware collect)\n")
    env = os.environ.copy()
    env.update(
        {
            "NCC_INSTALL_SELECTION": selection,
            "NCC_INSTALL_REPO": nixos_source,
            "NIXOS_CONFIG_DIR": nixos_source,
            "SYSTEM_CONFIG_DIR": str(staging),
            **_HOST_STAGING_ENV,
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

    log("• apply staged tree → /etc/nixos (preserve hardware, backup live flake)\n")
    applied, apply_out = apply_staged_tree_on_target(
        target, staging=push_detail, sudo_password=sudo_password
    )
    log(apply_out + "\n")
    if not applied:
        return False, f"Failed to apply tree on Target:\n{apply_out}"

    log("• sync generated systemConfig → Target /etc/nixos\n")
    synced, sync_out = sync_system_config_to_target(
        str(staging), target, sudo_password=sudo_password
    )
    log(sync_out + "\n")
    if not synced:
        return False, f"Failed to copy systemConfig:\n{sync_out}"

    log(
        "• remote install gate on Target "
        "(passwords + preflight + migrate + rebuild)\n"
    )
    gated, gate_out = remote_target_install_gate(
        target,
        flake_attr,
        sudo_password=sudo_password,
        on_line=log,
    )
    if not gated:
        return False, f"Remote install gate failed:\n{gate_out[-8000:]}"
    log("• remote install gate finished OK\n")
    return True, flake_attr


def dry_run_remote_deploy(
    *,
    target: str,
    selection: str,
    nixos_source: str,
    answers_file: str = "",
    sudo_password: str | None = None,
    on_log: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Validate install deploy chain — no writes to Target ``/etc/nixos``."""
    from ncc_gui.push_tree import (
        probe_remote_target,
        push_nixos_tree_to_target,
        remote_staging_dir,
        sync_system_config_to_target,
    )
    from .remote_preflight import run_remote_systemconfig_preflight

    def log(msg: str) -> None:
        if on_log is not None:
            on_log(msg)

    log("=== remote install dry-run (no Target /etc/nixos writes) ===\n")

    staging = make_staging_dir()
    log("• [1/7] stage systemConfig on Host (blueprint only)\n")
    ok, detail = stage_install_config(
        selection=selection,
        answers_file=answers_file,
        nixos_source=nixos_source,
        staging_etc=staging,
        dry_run=False,
    )
    log(detail[-3000:] + "\n")
    if not ok:
        return False, f"stage failed:\n{detail}"
    if not (staging / "systemConfig").is_dir() and not (staging / "systemConfig.nix").is_file():
        return False, f"no systemConfig under {staging}"

    flake_attr = flake_hostname(staging)
    log(f"• flake attr would be: /etc/nixos#{flake_attr}\n")

    log(f"• [2/7] probe Target {target}\n")
    probed, probe_out = probe_remote_target(target, sudo_password=sudo_password)
    log(probe_out + "\n")
    if not probed:
        return False, f"Target probe failed:\n{probe_out}"

    log(f"• [3/7] rsync dry-run {nixos_source} → {target}:{remote_staging_dir()}\n")
    pushed, push_detail = push_nixos_tree_to_target(
        nixos_source, target, dry_run=True
    )
    log(push_detail[:4000] + "\n")
    if not pushed:
        return False, f"rsync dry-run failed:\n{push_detail}"

    log("• [4/7] systemConfig sync dry-run (rsync -n → /tmp, then sudo merge)\n")
    synced, sync_out = sync_system_config_to_target(
        str(staging), target, dry_run=True, sudo_password=sudo_password
    )
    log(sync_out + "\n")
    if not synced:
        return False, f"systemConfig dry-run failed:\n{sync_out}"

    log("• [5/7] remote preflight: Host staging vs live Target (dry-run)\n")
    pf = run_remote_systemconfig_preflight(
        target=target,
        staging_etc=staging,
        sudo_password=sudo_password,
    )
    log(pf.report + "\n")
    if not pf.ok:
        return False, f"remote preflight failed:\n{pf.report}"

    log("• [6/7] remote install gate (would pipe system-manager prebuild-check-*)\n")
    log(
        "  steps: prebuild-check-users → platform/cpu/gpu/memory (compare) "
        "→ migrate-config → flake-extras → nixos-rebuild\n"
    )
    log("  SSOT: system-manager prebuild-check-* (Host PATH → SSH bash -s)\n")

    log("• [7/7] skipped: apply staged tree + gate execution (dry-run)\n")
    log(
        "DRY-RUN OK — rerun without dry-run via GUI Install or "
        "execute_remote_deploy after fixes.\n"
    )
    return True, flake_attr
