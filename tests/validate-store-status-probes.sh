#!/usr/bin/env bash
# HARD GATE — store-status probes must not use broken flake path-info on /nix/store
# and must count system profile generations (not nixos-rebuild --list-generations).
# GC preview must use nix-store --gc --print-dead (Nix 2.3x dropped it from collect-garbage).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/nixos/core/management/system-manager/scripts/ncc-store-gc.nix"
FAIL=0
pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-store-status-probes ==="

if [[ ! -f "$SRC" ]]; then
  fail "missing $SRC"
  exit 1
fi

if rg -q 'nix path-info -Sh "\$store_path"|nix path-info -Sh /nix/store|path-info -Sh "\$store_path"' "$SRC"; then
  fail "ncc-store-gc.nix still uses nix path-info on /nix/store (flakes → empty size)"
else
  pass "no nix path-info on whole /nix/store"
fi

if ! rg -q 'df -h "\$store_path"|df -h /nix/store' "$SRC"; then
  fail "store size must use df -h on /nix/store"
else
  pass "store size uses df"
fi

if rg -q 'nixos-rebuild --list-generations' "$SRC"; then
  fail "must not rely on nixos-rebuild --list-generations (broken on flake hosts)"
else
  pass "no nixos-rebuild --list-generations"
fi

if ! rg -q "system-\[0-9\]\*-link" "$SRC"; then
  fail "must count system-[0-9]*-link profile generations"
else
  pass "generations from system-*-link profiles"
fi

if rg -q 'nix-collect-garbage --print-dead' "$SRC"; then
  fail "nix-collect-garbage --print-dead is invalid on Nix 2.3x — use nix-store --gc --print-dead"
else
  pass "no nix-collect-garbage --print-dead"
fi

if ! rg -q 'nix-store --gc --print-dead' "$SRC"; then
  fail "must use nix-store --gc --print-dead for GC preview"
else
  pass "GC preview uses nix-store --gc --print-dead"
fi

if ! rg -q -- '--with-gc' "$SRC"; then
  fail "store-status must support --with-gc (GC is opt-in / slow)"
else
  pass "store-status has --with-gc"
fi

# Live probe sanity (this machine) — fast path only
prof=/nix/var/nix/profiles
if [[ -d "$prof" && -d /nix/store ]]; then
  gens=$(find "$prof" -maxdepth 1 -type l -name 'system-[0-9]*-link' 2>/dev/null | wc -l | tr -d ' ')
  size=$(df -h /nix/store 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 ")"}')
  if [[ -z "$size" ]]; then
    fail "df -h /nix/store produced empty size on this host"
  else
    pass "live df size: $size"
  fi
  if [[ -z "$gens" || "$gens" -lt 1 ]]; then
    fail "expected ≥1 system generation link, got [$gens]"
  else
    pass "live generations: $gens"
  fi
  # Prove collect-garbage rejects --print-dead on this Nix (documents why we switched)
  set +e
  out=$(nix-collect-garbage --print-dead 2>&1)
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "  NOTE: this Nix still accepts collect-garbage --print-dead (unusual)"
  elif printf '%s' "$out" | rg -q "unrecognised flag|unrecognized option|unknown flag"; then
    pass "live Nix rejects collect-garbage --print-dead (expected)"
  else
    echo "  NOTE: collect-garbage --print-dead rc=$rc (not success)"
  fi
else
  echo "  SKIP: no /nix/var/nix/profiles on this host"
fi

echo "=== summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED"
  exit 1
fi
echo "OK"
exit 0
