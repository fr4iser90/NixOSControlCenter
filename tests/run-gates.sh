#!/usr/bin/env bash
# Run all repo HARD GATEs before push/system-update.
# Agents and CI should get exit 0 from this script.
#
# Layout:
#   validate-ncc-nix.sh     — nixos/ (bash, layer, migrations, wizard packaging, options SSOT)
#   gui/validate-gui-python.sh — optional GUI smoke (fast; set SKIP_GUI=1 to skip)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

run() {
  local name="$1"
  shift
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  GATE: $name"
  echo "╚══════════════════════════════════════════════════════════╝"
  if "$@"; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name FAILED"
    FAIL=1
  fi
}

run "ncc-nix" bash "$ROOT/tests/validate-ncc-nix.sh"

if [[ "${SKIP_GUI:-}" != "1" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    run "gui-python" bash "$ROOT/tests/gui/validate-gui-python.sh"
  else
    echo "SKIP: gui-python (no python3)"
  fi
fi

echo ""
if [[ "$FAIL" -ne 0 ]]; then
  echo "GATES FAILED — fix issues above before commit/push/system-update."
  exit 1
fi
echo "All gates green."
exit 0
