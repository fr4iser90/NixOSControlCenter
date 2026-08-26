#!/usr/bin/env bash
# Verify remote sudo argv for nixos-rebuild (Jetson-safe: --version only, no switch).
#
# Without password: proves old sudo -p '' bug (prompt = nixos-rebuild).
# With password: runs fixed argv via push_tree._run_remote_sudo_argv.
#
# Usage:
#   bash tests/install-wizard/test-remote-sudo-rebuild-cmd.sh fr4iser@192.168.178.41
#   NCC_TARGET_SUDO_PASSWORD=… bash tests/install-wizard/test-remote-sudo-rebuild-cmd.sh …
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
TARGET="${1:-${NCC_INSTALL_REMOTE_TARGET:-fr4iser@192.168.178.41}}"
GUI_PY="$ROOT/nixos/core/management/gui-engine/python"

export PYTHONPATH="$GUI_PY${PYTHONPATH:+:$PYTHONPATH}"

echo "== unit: sudo argv (no network) =="
python3 -m pytest "$ROOT/tests/gui/test_push_tree_sudo_argv.py" -q

echo ""
echo "== remote: $TARGET (password in env: $([ -n "${NCC_TARGET_SUDO_PASSWORD:-}" ] && echo yes || echo no)) =="

python3 <<PY
import os
import subprocess
import sys

host = "$TARGET"
flake = "/etc/nixos#jetson-orin"

def ssh_sudo(tail, stdin="\n"):
    argv = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host, "--"] + tail
    p = subprocess.run(argv, input=stdin, capture_output=True, text=True, timeout=30)
    return p.returncode, (p.stdout + p.stderr).strip()[:400]

# Old bug: empty -p loses nixos-rebuild as command → prompt shows "nixos-rebuild"
rc, out = ssh_sudo(["sudo", "-S", "-p", "", "nixos-rebuild", "switch", "--flake", flake])
if "nixos-rebuild" in out and "password for" not in out.split("\n")[0]:
    print("OK: old -p '' bug reproduced (sudo prompt is nixos-rebuild, not user)")
else:
    print("WARN: old argv output unexpected:", repr(out[:200]))

rc2, out2 = ssh_sudo(["sudo", "-S", "nixos-rebuild", "--version"])
if "password for" in out2 or "[sudo]" in out2:
    print("OK: fixed argv asks normal sudo password (not nixos-rebuild prompt)")
else:
    print("WARN: fixed argv output:", repr(out2[:200]))

pw = (os.environ.get("NCC_TARGET_SUDO_PASSWORD") or "").strip()
if not pw:
    print("SKIP: set NCC_TARGET_SUDO_PASSWORD to run sudo -S true on Target")
    sys.exit(0)

sys.path.insert(0, "$GUI_PY")
from ncc_gui.push_tree import _run_remote_sudo_argv

ok, detail = _run_remote_sudo_argv(host, ["true"], sudo_password=pw)
if not ok:
    print("FAIL: sudo -S true via fixed argv:", detail[:300])
    sys.exit(1)
if "switch: command not found" in detail.lower():
    print("FAIL: switch parsed as separate command (argv bug still present)")
    sys.exit(1)
print("OK: sudo -S true on Target via fixed argv")
PY
