#!/usr/bin/env bash
# Run all repo HARD GATEs before push/system-update.
# Agents and CI should get exit 0 from this script.
#
# Layout:
#   validate-ncc-nix.sh          — nixos/ integrity + GUI catalog invariants
#   gui/validate-gui-python.sh   — GUI Python (required; set SKIP_GUI=1 only in emergencies)
#
# Strategy: tests/TESTING.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Self-heal: wire Git pre-commit like deepseek-harness postinstall (idempotent).
if [[ -f "$ROOT/scripts/install-git-hooks.sh" ]]; then
  bash "$ROOT/scripts/install-git-hooks.sh" >/dev/null 2>&1 || true
fi

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
    echo "FAIL: gui-python required but no python3"
    FAIL=1
  fi
else
  echo "WARN: SKIP_GUI=1 — GUI gate skipped (not for normal commits)"
fi

echo ""
if [[ "$FAIL" -ne 0 ]]; then
  echo "GATES FAILED — fix issues above before commit/push/system-update."
  echo "See tests/TESTING.md"
  exit 1
fi
echo "All gates green."
exit 0
