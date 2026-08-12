"""Push Host NCC tree to a remote Target and apply into /etc/nixos.

Does **not** rely on the Target's old ``ncc system update --source-dir``
(many older builds ignore that flag and use a default home path).
"""

from __future__ import annotations

import shlex
import subprocess
from pathlib import Path


_REMOTE_TMP = "/tmp/ncc-update-src"

# Apply staged tree → /etc/nixos (preserve user/system-specific leaves).
_APPLY_SH = r"""
set -euo pipefail
SRC="${NCC_STAGE:-/tmp/ncc-update-src}"
DST=/etc/nixos
if [ ! -d "$SRC" ] || [ ! -f "$SRC/flake.nix" ]; then
  echo "Staged tree missing flake.nix at $SRC" >&2
  exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root" >&2
  exit 1
fi
mkdir -p "$DST"
# Code / flake — refresh from staged Host tree
for item in core modules flake.nix; do
  if [ -e "$SRC/$item" ]; then
    echo "Applying $item..."
    if [ -d "$SRC/$item" ]; then
      mkdir -p "$DST/$item"
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$SRC/$item/" "$DST/$item/"
      else
        # No rsync on Target: replace tree (still preserves systemConfig outside)
        rm -rf "$DST/$item"
        cp -a "$SRC/$item" "$DST/$item"
      fi
    else
      cp -a "$SRC/$item" "$DST/$item"
    fi
  fi
done
# custom: only seed if missing
if [ -d "$SRC/custom" ] && [ ! -d "$DST/custom" ]; then
  echo "Seeding custom/..."
  cp -a "$SRC/custom" "$DST/custom"
fi
# NEVER touch: hardware-configuration.nix, flake.lock, systemConfig/, secrets/
echo "Preserved: hardware-configuration.nix flake.lock systemConfig/ secrets/ custom/(existing)"
echo "Apply done."
"""


def remote_staging_dir() -> str:
    return _REMOTE_TMP


def push_nixos_tree_to_target(
    local_nixos: str,
    target: str,
    *,
    timeout: float = 600,
) -> tuple[bool, str]:
    """Rsync ``local_nixos/`` → ``target:/tmp/ncc-update-src/``."""
    src = Path(local_nixos).expanduser()
    if not src.is_dir():
        return False, f"Local path not found:\n{src}"
    if not (src / "flake.nix").is_file():
        return False, f"No flake.nix in:\n{src}"
    host = (target or "").strip()
    if not host:
        return False, "No remote target"

    remote = _REMOTE_TMP
    prep = f"rm -rf -- {shlex.quote(remote)} && mkdir -p -- {shlex.quote(remote)}"
    try:
        mk = subprocess.run(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=8",
                host,
                prep,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)
    if mk.returncode != 0:
        err = (mk.stderr or mk.stdout or f"mkdir exit {mk.returncode}").strip()
        return False, err[:300]

    src_arg = str(src).rstrip("/") + "/"
    dest = f"{host}:{remote}/"
    try:
        proc = subprocess.run(
            [
                "rsync",
                "-az",
                "--delete",
                "--exclude",
                ".git",
                "--exclude",
                "result",
                "-e",
                "ssh -o BatchMode=yes -o ConnectTimeout=8",
                src_arg,
                dest,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return False, "rsync not found on this PC"
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or f"rsync exit {proc.returncode}").strip()
        return False, err[:400]
    return True, remote


def apply_staged_tree_on_target(
    target: str,
    *,
    staging: str | None = None,
    timeout: float = 120,
) -> tuple[bool, str]:
    """As root on Target: merge staged Host tree into ``/etc/nixos`` (preserve configs)."""
    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    stage = (staging or _REMOTE_TMP).strip()
    env_prefix = f"NCC_STAGE={shlex.quote(stage)} "
    # Pipe script on stdin; force root via sudo -n
    remote_cmd = f"{env_prefix}sudo -n bash -s"
    try:
        proc = subprocess.run(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=8",
                host,
                remote_cmd,
            ],
            input=_APPLY_SH,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)
    out = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if proc.returncode != 0:
        return False, (out or f"apply exit {proc.returncode}")[:500]
    return True, out or "ok"
