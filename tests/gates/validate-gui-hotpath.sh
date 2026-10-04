#!/usr/bin/env bash
# HARD GATE — domain GUI must not live-eval nixpkgs/catalogs (stack-overflow class).
#
# Catches:
#   - import <nixpkgs> in ui/gui/**/*.py
#   - mk-catalog-json referenced from ui/gui (must use NCC_*_CATALOG env)
#   - modules with lib/mk-catalog-json.nix (except packages) missing registerGuiEnv
#   - hyprland catalog Nix parses + rice-catalog loads (no fetchurl bake in gate)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-gui-hotpath (HARD GATE) ==="

# ── 1) No live nixpkgs / catalog builders in domain pages ────────────────────
BAD=$(
  rg -n --glob '**/ui/gui/**/*.py' \
    -e 'import <nixpkgs>' \
    -e 'mk-catalog-json' \
    "$NIXOS" 2>/dev/null || true
)
if [[ -n "${BAD}" ]]; then
  echo "$BAD" | sed 's/^/    /'
  fail "ui/gui must not import <nixpkgs> or reference mk-catalog-json (use NCC_*_CATALOG)"
else
  pass "no live nixpkgs/catalog builders in ui/gui"
fi

# ── 2) Non-packages mk-catalog-json modules must registerGuiEnv ──────────────
if python3 - "$NIXOS" <<'PY'
import sys
from pathlib import Path

nixos = Path(sys.argv[1])
errors: list[str] = []

for mk in sorted(nixos.rglob("lib/mk-catalog-json.nix")):
    mod = mk.parent.parent
    if not (mod / "default.nix").is_file() or not (mod / "options.nix").is_file():
        continue
    name = mod.name
    if name == "packages":
        continue
    text = ""
    for n in ("commands.nix", "gui/default.nix", "config.nix"):
        p = mod / n
        if p.is_file():
            text += p.read_text(encoding="utf-8", errors="replace")
    if "registerGuiEnv" not in text:
        errors.append(
            f"{mod.relative_to(nixos)}: has lib/mk-catalog-json.nix but no registerGuiEnv "
            f"(root ncc-gui will not export NCC_*_CATALOG)"
        )

if errors:
    print("ISSUES:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print("OK: catalog modules registerGuiEnv (or packages via gui-engine)")
sys.exit(0)
PY
then
  pass "registerGuiEnv for non-packages catalogs"
else
  fail "missing registerGuiEnv for catalog modules"
fi

# ── 3) Hyprland catalog Nix integrity (parse + rice-catalog attrset) ─────────
echo "== hyprland catalog Nix =="
HYPR_MK="$NIXOS/core/base/hyprland/lib/mk-catalog-json.nix"
HYPR_CAT="$NIXOS/core/base/hyprland/lib/rice-catalog.nix"
if [[ ! -f "$HYPR_MK" || ! -f "$HYPR_CAT" ]]; then
  fail "missing hyprland catalog nix files"
elif ! nix-instantiate --parse "$HYPR_MK" >/dev/null 2>&1; then
  fail "mk-catalog-json.nix does not parse"
elif ! nix-instantiate --parse "$HYPR_CAT" >/dev/null 2>&1; then
  fail "rice-catalog.nix does not parse"
else
  # HoF only (pkgs=null) — no GitHub fetch / fetchurl thumbnails in the gate.
  if nix-instantiate --eval --strict -E "
    let cat = import $HYPR_CAT { pkgs = null; };
    in builtins.length (builtins.attrNames cat) > 0
  " 2>/tmp/ncc-hypr-cat.err | grep -q true; then
    pass "hyprland rice-catalog (HoF) loads non-empty"
  else
    sed 's/^/    /' /tmp/ncc-hypr-cat.err | tail -30
    fail "hyprland rice-catalog.nix failed to eval"
  fi
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — GUI hot-path / catalog bake broken."
  exit 1
fi
echo "OK — GUI hot-path green."
exit 0
