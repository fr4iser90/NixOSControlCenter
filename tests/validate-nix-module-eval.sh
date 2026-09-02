#!/usr/bin/env bash
# HARD GATE — eval Nix module fragments that only fail at apply-time (let/import bindings).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-nix-module-eval (prebuild + imported config.nix) ==="

OUT=$(mktemp)
ERR=$(mktemp)
set +e
nix-instantiate --eval --strict --json \
  --arg pkgs 'import <nixpkgs> {}' \
  --argstr nixosRoot "$NIXOS" \
  "$ROOT/tests/lib/eval-prebuild-modules.nix" >"$OUT" 2>"$ERR"
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  fail "eval-prebuild-modules.nix failed"
  sed 's/^/    /' "$ERR"
  rm -f "$OUT" "$ERR"
  exit 1
fi

if jq -e '.ok != true' "$OUT" >/dev/null 2>&1; then
  fail "prebuild check modules have broken imports"
  jq -r '.errors[]?' "$OUT" | sed 's/^/    /'
  FAIL=1
else
  count="$(jq -r '.checked | length' "$OUT")"
  pass "prebuild/checks modules eval ($count files)"
fi
rm -f "$OUT" "$ERR"

# config.nix values loaded via (import ./config.nix …) into imports=
OUT=$(mktemp)
ERR=$(mktemp)
set +e
nix-instantiate --eval --strict --json \
  --arg pkgs 'import <nixpkgs> {}' \
  --argstr nixosRoot "$NIXOS" \
  "$ROOT/tests/lib/eval-imported-config-modules.nix" >"$OUT" 2>"$ERR"
RC=$?
set -e
if [[ "$RC" -ne 0 ]]; then
  fail "eval-imported-config-modules.nix failed"
  sed 's/^/    /' "$ERR"
  rm -f "$OUT" "$ERR"
  exit 1
fi

if jq -e '.ok != true' "$OUT" >/dev/null 2>&1; then
  fail "imported config.nix not valid as NixOS modules"
  jq -r '.errors[]?' "$OUT" | sed 's/^/    /'
  FAIL=1
else
  count="$(jq -r '.checked | length' "$OUT")"
  pass "imported config.nix modules eval ($count files)"
fi
rm -f "$OUT" "$ERR"

echo "=== validate-nix-module-eval summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
