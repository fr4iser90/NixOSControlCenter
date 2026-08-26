"""Push Host NCC tree to a remote Target and apply into /etc/nixos.

Does **not** rely on the Target's old ``ncc system update --source-dir``
(many older builds ignore that flag and use a default home path).
"""

from __future__ import annotations

import shlex
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path


# SSOT step order matches system-manager/components/system-checks/lib/preflight-remote.nix
_REMOTE_INSTALL_CHECK_STEPS: list[tuple[str, dict[str, str]]] = [
    ("prebuild-check-users", {"NCC_REMOTE_NONINTERACTIVE": "1"}),
    ("prebuild-check-platform", {"NCC_PREFLIGHT_MODE": "compare", "NCC_REMOTE_NONINTERACTIVE": "1"}),
    ("prebuild-check-cpu", {"NCC_PREFLIGHT_MODE": "compare", "NCC_REMOTE_NONINTERACTIVE": "1"}),
    ("prebuild-check-gpu", {"NCC_PREFLIGHT_MODE": "compare", "NCC_REMOTE_NONINTERACTIVE": "1"}),
    ("prebuild-check-memory", {"NCC_PREFLIGHT_MODE": "compare", "NCC_REMOTE_NONINTERACTIVE": "1"}),
]

_REMOTE_INSTALL_POST_SH = r"""
set -euo pipefail
NIXOS_DIR="${NIXOS_DIR:-/etc/nixos}"
FLAKE_ATTR="${NCC_FLAKE_ATTR:-nixos}"
live="/tmp/ncc-live-flake-backup.nix"
incoming="$NIXOS_DIR/flake.nix"
merged="/tmp/ncc-flake-merged.nix"
if [ -f "$live" ] && [ -f "$incoming" ] && [ -n "${NCC_FLAKE_MERGE_CMD:-}" ]; then
  eval "$NCC_FLAKE_MERGE_CMD" || echo "WARN flake-extras merge failed (continuing)"
fi
flake_ref="$NIXOS_DIR#$FLAKE_ATTR"
HOME=/root exec nixos-rebuild switch --flake "$flake_ref"
"""


_REMOTE_TMP = "/tmp/ncc-update-src"
_REMOTE_SC_TMP = "/tmp/ncc-install-systemconfig"

# Merge staged systemConfig (under /tmp) into /etc/nixos as root.
_SYNC_SC_SH = r"""
set -euo pipefail
SRC="${NCC_SC_STAGE:-/tmp/ncc-install-systemconfig}"
DST=/etc/nixos
if [ "$(id -u)" -ne 0 ]; then
  echo "Must run as root" >&2
  exit 1
fi
for name in systemConfig systemConfig.nix system-config.nix; do
  if [ -d "$SRC/$name" ]; then
    echo "Applying $name..."
    mkdir -p "$DST/$name"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$SRC/$name/" "$DST/$name/"
    else
      rm -rf "$DST/$name"
      cp -a "$SRC/$name" "$DST/$name"
    fi
  elif [ -f "$SRC/$name" ]; then
    echo "Applying $name..."
    cp -a "$SRC/$name" "$DST/$name"
  fi
done
rm -rf "$SRC"
echo "systemConfig apply done."
"""
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
# Preserve live flake for remote install gate (flake-extras merge)
if [ -f "$DST/flake.nix" ]; then
  cp -a "$DST/flake.nix" /tmp/ncc-live-flake-backup.nix
  echo "Backed up live flake.nix → /tmp/ncc-live-flake-backup.nix"
fi
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
# NEVER touch: hardware-configuration.nix, flake.lock, systemConfig/, secrets/, custom/
echo "Preserved: hardware-configuration.nix flake.lock systemConfig/ secrets/ custom/"
echo "Apply done."
"""


def _ssh_rsync_e() -> str:
    return "ssh -o BatchMode=yes -o ConnectTimeout=8"


def _run_ssh(
    host: str,
    remote_argv: list[str],
    *,
    input_text: str | None = None,
    timeout: float = 120,
) -> tuple[int, str]:
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
                *remote_argv,
            ],
            input=input_text,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)
    out = ((proc.stdout or "") + (proc.stderr or "")).strip()
    return proc.returncode, out


def _run_remote_sudo_bash(
    host: str,
    script: str,
    *,
    env_prefix: str = "",
    sudo_password: str | None = None,
    timeout: float = 120,
) -> tuple[bool, str]:
    """Run *script* on Target as root (`sudo -n` or `sudo -S` with password)."""
    if sudo_password:
        remote_cmd = f"{env_prefix}sudo -S bash -s"
        stdin = f"{sudo_password}\n{script}"
    else:
        remote_cmd = f"{env_prefix}sudo -n bash -s"
        stdin = script
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
            input=stdin,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)
    out = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if proc.returncode != 0:
        return False, (out or f"remote sudo exit {proc.returncode}")[:800]
    return True, out or "ok"


def _run_remote_sudo_argv(
    host: str,
    cmd: list[str],
    *,
    sudo_password: str | None = None,
    timeout: float = 7200,
    on_line: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Run argv under remote sudo. Streams combined stdout/stderr when *on_line* set."""
    if sudo_password:
        argv = [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=8",
            host,
            "--",
            "sudo",
            "-S",
            *cmd,
        ]
        stdin = f"{sudo_password}\n"
    else:
        argv = [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=8",
            host,
            "--",
            "sudo",
            "-n",
            *cmd,
        ]
        stdin = None
    try:
        if on_line is None:
            proc = subprocess.run(
                argv,
                input=stdin,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            out = ((proc.stdout or "") + (proc.stderr or "")).strip()
            if proc.returncode != 0:
                # Last chunk — flake.lock noise is at the start of long rebuilds
                return False, (out or f"exit {proc.returncode}")[-8000:]
            return True, out or "ok"

        proc = subprocess.Popen(
            argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert proc.stdin is not None and proc.stdout is not None
        if stdin is not None:
            proc.stdin.write(stdin)
            proc.stdin.flush()
        proc.stdin.close()
        chunks: list[str] = []
        try:
            for line in proc.stdout:
                chunks.append(line)
                on_line(line)
        except Exception:
            proc.kill()
            raise
        rc = proc.wait(timeout=timeout)
        out = "".join(chunks).strip()
        if rc != 0:
            return False, (out or f"exit {rc}")[-8000:]
        return True, out or "ok"
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)


_RSYNC_PUSH_EXCLUDES = (
    ".git",
    "result",
    # Host-only / Target-preserved (see apply script — never overwrite on Target)
    "secrets",
    "systemConfig",
    "systemConfig.nix",
    "system-config.nix",
    "hardware-configuration.nix",
    "flake.lock",
    "custom",
)


def remote_staging_dir() -> str:
    return _REMOTE_TMP


def push_nixos_tree_to_target(
    local_nixos: str,
    target: str,
    *,
    timeout: float = 600,
    dry_run: bool = False,
) -> tuple[bool, str]:
    """Rsync ``local_nixos/`` → ``target:/tmp/ncc-update-src/`` (``dry_run``: rsync -n only)."""
    src = Path(local_nixos).expanduser()
    if not src.is_dir():
        return False, f"Local path not found:\n{src}"
    if not (src / "flake.nix").is_file():
        return False, f"No flake.nix in:\n{src}"
    host = (target or "").strip()
    if not host:
        return False, "No remote target"

    remote = _REMOTE_TMP
    if not dry_run:
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
    rsync_args = [
        "rsync",
        "-az",
    ]
    if dry_run:
        rsync_args.extend(["-n", "--itemize-changes"])
    else:
        rsync_args.append("--delete")
    for pat in _RSYNC_PUSH_EXCLUDES:
        rsync_args.extend(["--exclude", pat])
    rsync_args.extend(["-e", _ssh_rsync_e(), src_arg, dest])
    try:
        proc = subprocess.run(
            rsync_args,
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
        return False, err[:800]
    out = ((proc.stdout or "") + (proc.stderr or "")).strip()
    if dry_run:
        return True, out or "rsync dry-run: no changes listed (trees may already match)"
    return True, remote


def apply_staged_tree_on_target(
    target: str,
    *,
    staging: str | None = None,
    sudo_password: str | None = None,
    timeout: float = 120,
) -> tuple[bool, str]:
    """As root on Target: merge staged Host tree into ``/etc/nixos`` (preserve configs)."""
    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    stage = (staging or _REMOTE_TMP).strip()
    env_prefix = f"NCC_STAGE={shlex.quote(stage)} "
    return _run_remote_sudo_bash(
        host,
        _APPLY_SH,
        env_prefix=env_prefix,
        sudo_password=sudo_password,
        timeout=timeout,
    )


def probe_remote_target(
    target: str,
    *,
    sudo_password: str | None = None,
    timeout: float = 30,
) -> tuple[bool, str]:
    """SSH reachability, sudo (NOPASSWD or password), Target /etc/nixos snapshot."""
    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    script = r"""
set -euo pipefail
echo "=== probe $(hostname) ==="
if sudo -n true 2>/dev/null; then
  echo "sudo-n: OK"
else
  echo "sudo-n: no"
fi
echo "--- /etc/nixos ---"
ls -1 /etc/nixos 2>/dev/null || echo "(missing)"
for p in core modules systemConfig systemConfig.nix; do
  if [ -e "/etc/nixos/$p" ]; then echo "has: $p"; else echo "missing: $p"; fi
done
if [ -d /tmp/ncc-update-src ]; then
  echo "--- /tmp/ncc-update-src ---"
  ls -1 /tmp/ncc-update-src 2>/dev/null | head -20
else
  echo "staging /tmp/ncc-update-src: absent"
fi
"""
    if sudo_password:
        root_script = (
            "set -euo pipefail\n"
            "echo 'sudo-password: OK'\n"
            + script
        )
        return _run_remote_sudo_bash(
            host,
            root_script,
            sudo_password=sudo_password,
            timeout=timeout,
        )
    check_script = (
        "set -euo pipefail\n"
        "if sudo -n true 2>/dev/null; then echo 'sudo-n: OK'; else echo 'sudo-n: FAIL'; exit 2; fi\n"
    )
    stdin = f"{check_script}{script}"
    rc, out = _run_ssh(host, ["bash", "-s"], input_text=stdin, timeout=timeout)
    if rc != 0:
        return False, out or f"probe exit {rc}"
    return True, out


def sync_system_config_to_target(
    local_staging_etc: str,
    target: str,
    *,
    timeout: float = 300,
    dry_run: bool = False,
    sudo_password: str | None = None,
) -> tuple[bool, str]:
    """Copy generated systemConfig from PC staging → Target ``/etc/nixos`` (via /tmp + sudo)."""
    src = Path(local_staging_etc).expanduser()
    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    if not src.is_dir():
        return False, f"Staging path not found:\n{src}"

    found = False
    for name in ("systemConfig", "systemConfig.nix", "system-config.nix"):
        if (src / name).exists():
            found = True
            break
    if not found:
        return False, f"No systemConfig output under:\n{src}"

    remote_tmp = _REMOTE_SC_TMP
    rc, out = _run_ssh(host, ["mkdir", "-p", remote_tmp], timeout=60)
    if rc != 0:
        return False, out or f"mkdir staging exit {rc}"
    if not dry_run:
        rc, out = _run_ssh(host, ["rm", "-rf", remote_tmp], timeout=60)
        if rc != 0:
            return False, out or f"rm staging exit {rc}"
        rc, out = _run_ssh(host, ["mkdir", "-p", remote_tmp], timeout=60)
        if rc != 0:
            return False, out or f"mkdir staging exit {rc}"

    lines: list[str] = []
    for name in ("systemConfig", "systemConfig.nix", "system-config.nix"):
        item = src / name
        if not item.exists():
            continue
        lines.append(f"Staging {name} → Target {remote_tmp}/...")
        if item.is_dir():
            src_arg = f"{item}/"
            dest_arg = f"{host}:{remote_tmp}/"
        else:
            src_arg = str(item)
            dest_arg = f"{host}:{remote_tmp}/{name}"
        rsync_args = ["rsync", "-a"]
        if dry_run:
            rsync_args.extend(["-n", "--itemize-changes"])
        rsync_args.extend(["-e", _ssh_rsync_e(), src_arg, dest_arg])
        try:
            proc = subprocess.run(
                rsync_args,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as e:
            return False, str(e)
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or f"exit {proc.returncode}").strip()
            return False, err[:500]
        if dry_run and proc.stdout:
            lines.append(proc.stdout.strip()[:2000])

    if dry_run:
        lines.append("dry-run: would sudo-merge staged systemConfig → /etc/nixos")
        return True, "\n".join(lines)

    env_prefix = f"NCC_SC_STAGE={shlex.quote(remote_tmp)} "
    ok, apply_out = _run_remote_sudo_bash(
        host,
        _SYNC_SC_SH,
        env_prefix=env_prefix,
        sudo_password=sudo_password,
        timeout=timeout,
    )
    if not ok:
        return False, apply_out
    lines.append(apply_out)
    return True, "\n".join(lines)


def _env_prefix(extra: dict[str, str] | None = None) -> str:
    env = {"NCC_PREFLIGHT_VERBOSE": "0", **(extra or {})}
    return "".join(f"{k}={shlex.quote(v)} " for k, v in env.items())


def _host_ncc_script_body(cmd: str) -> str | None:
    """Read prebuild/check script from Host PATH (system-manager SSOT)."""
    bin_path = shutil.which(cmd)
    if not bin_path:
        return None
    try:
        return Path(bin_path).read_text(encoding="utf-8")
    except OSError:
        return None


def run_remote_prebuild_checks(
    target: str,
    *,
    sudo_password: str | None = None,
    timeout: float = 300,
    on_line: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Pipe system-manager prebuild-check-* scripts to Target (compare + users)."""
    host = (target or "").strip()
    if not host:
        return False, "No remote target"
    chunks: list[str] = []
    for cmd, env in _REMOTE_INSTALL_CHECK_STEPS:
        body = _host_ncc_script_body(cmd)
        if not body:
            return (
                False,
                f"{cmd} not on Host PATH — run ncc system-update on this PC first",
            )
        prefix = _env_prefix(env)
        if on_line is not None:
            ok, out = _run_remote_sudo_bash_streaming(
                host,
                body,
                env_prefix=prefix,
                sudo_password=sudo_password,
                timeout=timeout,
                on_line=on_line,
            )
        else:
            ok, out = _run_remote_sudo_bash(
                host,
                body,
                env_prefix=prefix,
                sudo_password=sudo_password,
                timeout=timeout,
            )
        chunks.append(out)
        if not ok:
            return False, f"{cmd} failed:\n{out[-4000:]}"
    return True, "\n".join(chunks)


def remote_target_install_gate(
    target: str,
    flake_attr: str,
    *,
    sudo_password: str | None = None,
    timeout: float = 7200,
    on_line: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Run system-manager prebuild checks on Target, then migrate + rebuild."""
    host = (target or "").strip()
    attr = (flake_attr or "nixos").strip()
    if not host:
        return False, "No remote target"

    ok, detail = run_remote_prebuild_checks(
        host,
        sudo_password=sudo_password,
        timeout=min(timeout, 600),
        on_line=on_line,
    )
    if not ok:
        return False, detail

    mig = _host_ncc_script_body("ncc-migrate-config")
    if mig:
        if on_line is not None:
            mig_ok, mig_out = _run_remote_sudo_bash_streaming(
                host,
                mig,
                sudo_password=sudo_password,
                timeout=300,
                on_line=on_line,
            )
        else:
            mig_ok, mig_out = _run_remote_sudo_bash(
                host, mig, sudo_password=sudo_password, timeout=300
            )
        if not mig_ok and on_line is not None:
            on_line(f"WARN migrate-config: {mig_out[-500:]}\n")

    merge_cmd = ""
    check_bin = shutil.which("ncc-check-flake-extras")
    merge_bin = shutil.which("ncc-merge-flake-extras")
    if check_bin and merge_bin:
        merge_cmd = (
            f"set +e; {shlex.quote(check_bin)} --live /tmp/ncc-live-flake-backup.nix "
            f"--incoming /etc/nixos/flake.nix --json >/dev/null 2>&1; rc=$?; set -e; "
            f"if [ $rc -eq 2 ]; then {shlex.quote(merge_bin)} --live /tmp/ncc-live-flake-backup.nix "
            f"--incoming /etc/nixos/flake.nix --out /tmp/ncc-flake-merged.nix "
            f"&& cp -a /tmp/ncc-flake-merged.nix /etc/nixos/flake.nix; fi"
        )

    post_env = {
        "NCC_FLAKE_ATTR": attr,
        "NCC_REMOTE_NONINTERACTIVE": "1",
        **({"NCC_FLAKE_MERGE_CMD": merge_cmd} if merge_cmd else {}),
    }
    post_prefix = _env_prefix(post_env)
    if on_line is not None:
        return _run_remote_sudo_bash_streaming(
            host,
            _REMOTE_INSTALL_POST_SH,
            env_prefix=post_prefix,
            sudo_password=sudo_password,
            timeout=timeout,
            on_line=on_line,
        )
    return _run_remote_sudo_bash(
        host,
        _REMOTE_INSTALL_POST_SH,
        env_prefix=post_prefix,
        sudo_password=sudo_password,
        timeout=timeout,
    )


def _run_remote_sudo_bash_streaming(
    host: str,
    script: str,
    *,
    env_prefix: str = "",
    sudo_password: str | None = None,
    timeout: float = 7200,
    on_line: Callable[[str], None],
) -> tuple[bool, str]:
    """Like ``_run_remote_sudo_bash`` but stream stdout to *on_line*."""
    if sudo_password:
        remote_cmd = f"{env_prefix}sudo -S bash -s"
        stdin = f"{sudo_password}\n{script}"
    else:
        remote_cmd = f"{env_prefix}sudo -n bash -s"
        stdin = script
    try:
        proc = subprocess.Popen(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=8",
                host,
                remote_cmd,
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except OSError as e:
        return False, str(e)
    assert proc.stdin is not None and proc.stdout is not None
    proc.stdin.write(stdin)
    proc.stdin.close()
    chunks: list[str] = []
    try:
        for line in proc.stdout:
            chunks.append(line)
            on_line(line)
    except Exception:
        proc.kill()
        raise
    rc = proc.wait(timeout=timeout)
    out = "".join(chunks).strip()
    if rc != 0:
        return False, (out or f"remote gate exit {rc}")[-8000:]
    return True, out or "ok"


def remote_nixos_rebuild_switch(
    target: str,
    flake_attr: str,
    *,
    sudo_password: str | None = None,
    timeout: float = 7200,
    on_line: Callable[[str], None] | None = None,
) -> tuple[bool, str]:
    """Run remote install gate (secrets + preflight + rebuild) on Target."""
    return remote_target_install_gate(
        target,
        flake_attr,
        sudo_password=sudo_password,
        timeout=timeout,
        on_line=on_line,
    )
