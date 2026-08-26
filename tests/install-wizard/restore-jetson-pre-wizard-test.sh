#!/usr/bin/env bash
# Restore Jetson /etc/nixos to pre-NCC wizard state (no nixos-rebuild).
#
# Target layout after restore (matches user's pre-install ls):
#   configuration.nix  flake.nix  hardware-configuration.nix  systemd/
#   (flake.lock removed — nix will re-lock on next rebuild)
#
# Removes all NCC install artifacts: core/ modules/ custom/ systemConfig* secrets/
# Clears /tmp/ncc-update-src and /tmp/ncc-install-systemconfig on Target.
#
# Usage:
#   NCC_TARGET_SUDO_PASSWORD=… bash tests/install-wizard/restore-jetson-pre-wizard-test.sh
#   bash tests/install-wizard/restore-jetson-pre-wizard-test.sh fr4iser@192.168.178.41
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
FIXTURE="$DIR/fixtures/jetson-pre-ncc"
TARGET="${1:-${NCC_INSTALL_REMOTE_TARGET:-fr4iser@192.168.178.41}}"
PW="${NCC_TARGET_SUDO_PASSWORD:-}"

if [[ -z "$PW" ]]; then
  echo "Set NCC_TARGET_SUDO_PASSWORD for remote sudo" >&2
  exit 1
fi

if [[ ! -f "$FIXTURE/flake.nix" ]]; then
  echo "Missing fixture: $FIXTURE/flake.nix" >&2
  exit 1
fi

export PYTHONPATH="${PYTHONPATH:-}:$ROOT/nixos/core/management/gui-engine/python"
export NCC_RESTORE_TARGET="$TARGET"
export NCC_RESTORE_FLAKE_B64="$(base64 -w0 "$FIXTURE/flake.nix")"

python3 <<'PY'
import base64, os, sys
from ncc_gui.push_tree import _run_remote_sudo_bash

host = os.environ["NCC_RESTORE_TARGET"]
pw = os.environ["NCC_TARGET_SUDO_PASSWORD"]
flake_b64 = os.environ["NCC_RESTORE_FLAKE_B64"]
script = f"""
set -euo pipefail
NCC=/etc/nixos
if [ ! -d "$NCC" ]; then
  echo "No $NCC on target" >&2
  exit 1
fi
if [ ! -f "$NCC/configuration.nix" ]; then
  echo "WARN: no configuration.nix — keeping tree but restore may be incomplete" >&2
fi
if [ ! -f "$NCC/hardware-configuration.nix" ]; then
  echo "Missing hardware-configuration.nix" >&2
  exit 1
fi

echo "Removing NCC install artifacts..."
rm -rf "$NCC/core" "$NCC/modules" "$NCC/custom" "$NCC/systemConfig" "$NCC/secrets"
rm -f "$NCC/systemConfig.nix" "$NCC/system-config.nix"
rm -rf /tmp/ncc-update-src /tmp/ncc-install-systemconfig

echo "Restoring pre-NCC flake.nix..."
echo '{flake_b64}' | base64 -d > "$NCC/flake.nix"
rm -f "$NCC/flake.lock"

echo "Restored /etc/nixos:"
ls -1 "$NCC"
echo "--- unexpected (should be empty) ---"
for x in core modules custom systemConfig systemConfig.nix secrets flake.lock; do
  if [ -e "$NCC/$x" ]; then
    echo "STILL PRESENT: $x"
  fi
done
echo "--- flake.nix head ---"
head -5 "$NCC/flake.nix"
"""
ok, out = _run_remote_sudo_bash(host, script, sudo_password=pw)
print(out)
if not ok:
    sys.exit(1)

unexpected = [line for line in out.splitlines() if line.startswith("STILL PRESENT:")]
if unexpected:
    print("FAIL: restore incomplete")
    for line in unexpected:
        print(line)
    sys.exit(1)

print("OK: Jetson restored to pre-NCC layout — ready for GUI Install retest")
PY
