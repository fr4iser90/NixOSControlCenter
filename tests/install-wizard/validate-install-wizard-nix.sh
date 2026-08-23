#!/usr/bin/env bash
# HARD GATE — install-wizard Nix changes.
#
# Agents MUST get exit 0 before claiming wizard/packages wiring works.
# Partial checks (nix-instantiate --parse one file alone) are NOT validation.
#
# Catches:
#   - layer violation: install-wizard → relative import packages/lib
#   - stale data .nix in scripts/ walk (required args like meta/lib)
#   - deleted source files that sync-without--delete leaves on hosts (orphan)
#   - broken fromJSON / bash-in-nix embedding
#   - full scripts/default.nix packaging (same path as ncc system-update)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IW="$ROOT/nixos/core/management/install-wizard"
SCRIPTS="$IW/scripts"
PACKAGES="$ROOT/nixos/core/base/packages"
MM_LIB="$ROOT/nixos/core/management/module-manager/lib"
SYSTEM_UPDATE="$ROOT/nixos/core/management/system-manager/handlers/system-update.nix"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-install-wizard-nix (HARD GATE) ==="

# ── 1) Layer ────────────────────────────────────────────────────────────────
echo "== 1) layer: install-wizard must not import packages/lib =="
LAYER_HITS=$(rg -n --glob '*.nix' \
  'import[[:space:]]+[^;\n]*packages/lib|import[[:space:]]+\.\./(\.\./)*(base/)?packages/lib' \
  "$IW" 2>/dev/null || true)
if [[ -n "$LAYER_HITS" ]]; then
  echo "$LAYER_HITS" | sed 's/^/    /'
  fail "relative import of packages/lib from install-wizard (use getModuleApi \"packages\")"
else
  pass "no packages/lib relative imports under install-wizard"
fi

MM_MIGRATION="$ROOT/nixos/core/management/module-manager/components/module-migration"
PLANS_NIX="$MM_MIGRATION/plans.nix"
APPLY_MIG_NIX="$MM_MIGRATION/apply-migrations.nix"
IW_MIG="$IW/migrations/v1.0.0-to-v1.1.0.nix"
STALE_GEN_REL="ui/prompts/gen-features-from-metadata.nix"
STALE_GEN_ABS="$SCRIPTS/$STALE_GEN_REL"
echo "== 2) stale gen-features + module migration =="
if [[ -e "$STALE_GEN_ABS" ]]; then
  fail "scripts/$STALE_GEN_REL still exists in source (delete it)"
else
  pass "gen-features-from-metadata.nix absent from source"
fi
if [[ -f "$MM_MIGRATION/apply-code-cleanup-plans.nix" ]] || [[ -f "$MM_MIGRATION/apply-code-cleanup-plans.sh" ]]; then
  fail "legacy apply-code-cleanup-plans.* must die — use apply-migrations.nix + module migrations/"
fi
if rg -q 'install-wizard' "$PLANS_NIX" 2>/dev/null || rg -q 'code-cleanup' "$PLANS_NIX" 2>/dev/null; then
  fail "plans.nix must not hardwire install-wizard / code-cleanup (lives in install-wizard/migrations/)"
else
  pass "plans.nix has no install-wizard / code-cleanup hardwire"
fi
if [[ ! -f "$IW_MIG" ]]; then
  fail "missing install-wizard/migrations/v1.0.0-to-v1.1.0.nix"
elif ! rg -q 'gen-features-from-metadata\.nix' "$IW_MIG" || ! rg -q 'removeRelativePaths' "$IW_MIG"; then
  fail "install-wizard migration must removeRelativePaths gen-features-from-metadata.nix"
else
  pass "install-wizard owns migration v1.0.0→v1.1.0"
fi
if [[ ! -f "$APPLY_MIG_NIX" ]]; then
  fail "missing apply-migrations.nix"
elif ! rg -q 'writeShellScriptBin "ncc-apply-migrations"' "$APPLY_MIG_NIX"; then
  fail "apply-migrations.nix must define ncc-apply-migrations"
else
  pass "apply-migrations.nix (discovery, bash-in-nix)"
fi
if [[ ! -f "$SYSTEM_UPDATE" ]]; then
  fail "missing system-update.nix"
else
  if rg -q 'install-wizard/scripts' "$SYSTEM_UPDATE" 2>/dev/null; then
    fail "system-update.nix references install-wizard paths (layer violation)"
  else
    pass "system-update has no install-wizard-specific paths"
  fi
  if rg -q 'apply-migrations\.nix' "$SYSTEM_UPDATE" \
    && rg -q 'ncc-apply-migrations' "$SYSTEM_UPDATE"; then
    pass "system-update post-sync runs migration discovery"
  else
    fail "system-update must import apply-migrations.nix and run ncc-apply-migrations after sync"
  fi
  if rg -q 'rsync -a[qvx]* .*--delete.*"\$source_module/"' "$SYSTEM_UPDATE" 2>/dev/null; then
    pass "update_module_code rsync uses --delete"
  else
    fail "update_module_code must rsync with --delete"
  fi
fi
if rg -q 'gen-features-from-metadata\.nix' "$SCRIPTS/default.nix" 2>/dev/null; then
  pass "install-wizard packaging lists removed generator in isDataNix (bootstrap until migration runs)"
else
  fail "scripts/default.nix must isDataNix gen-features-from-metadata.nix until hosts are cleaned"
fi

# ── 3) Bash embedding ───────────────────────────────────────────────────────
echo "== 3) bash embedding =="
if bash "$ROOT/tests/install-wizard/validate-bash-embedding.sh"; then
  pass "validate-bash-embedding.sh"
else
  fail "validate-bash-embedding.sh"
fi

# ── 4) export-options ───────────────────────────────────────────────────────
echo "== 4) export-options parse + build =="
EXPORT="$SCRIPTS/ui/gui/export-options.nix"
if [[ ! -f "$EXPORT" ]]; then
  fail "missing $EXPORT"
else
  if nix-instantiate --parse "$EXPORT" >/dev/null 2>&1; then
    pass "export-options.nix parses"
  else
    fail "export-options.nix does not parse"
  fi
  if nix-build --no-out-link -E "
    let pkgs = import <nixpkgs> {};
    in import $EXPORT { inherit pkgs; }
  " >/dev/null 2>/tmp/ncc-export-build.err; then
    pass "export-options.nix builds"
  else
    fail "export-options.nix build failed"
    sed -n '1,25p' /tmp/ncc-export-build.err | sed 's/^/    /'
  fi
fi

# ── 5) packages API ─────────────────────────────────────────────────────────
echo "== 5) packages API installerFeaturesBash =="
if nix-instantiate --eval --strict -E "
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    api = import $PACKAGES/api.nix {
      inherit lib;
      metadata = {};
      getModuleMetadata = _: null;
      getModuleApi = _: null;
    };
    bash = api.installerFeaturesBash;
  in
  assert api ? installerFeaturesBash;
  assert builtins.isString bash;
  assert builtins.match \".*ALL_FEATURES=\\\\(.*\" bash != null;
  assert builtins.match \".*\\\"docker-rootless\\\".*\" bash == null;
  \"ok\"
" >/dev/null 2>/tmp/ncc-pkg-api.err; then
  pass "packages.installerFeaturesBash (docker-rootless not listed)"
else
  fail "packages API / installerFeaturesBash"
  sed -n '1,30p' /tmp/ncc-pkg-api.err | sed 's/^/    /'
fi

# Shared Nix snippet: real discovery getModuleApi (same family as flake specialArgs)
read -r -d '' NIX_HELPERS <<'NIX' || true
pkgs = import <nixpkgs> {};
lib = pkgs.lib;
helpers = import __MM_LIB__/module-config.nix {
  inherit lib;
  systemConfig = {};
};
inherit (helpers) getModuleApi getModuleMetadata;
NIX
NIX_HELPERS="${NIX_HELPERS//__MM_LIB__/$MM_LIB}"

# ── 6) FULL script tree packaging ───────────────────────────────────────────
echo "== 6) full install-wizard scripts packaging =="
PKG_ERR=$(mktemp)
if nix-build --no-out-link -E "
  let
    $NIX_HELPERS
  in
  (import $SCRIPTS {
    inherit pkgs getModuleApi getModuleMetadata;
  }).scriptTree
" >/dev/null 2>"$PKG_ERR"; then
  pass "scripts/default.nix scriptTree builds"
else
  fail "scripts packaging failed (this is what ncc system-update hits)"
  sed -n '1,50p' "$PKG_ERR" | sed 's/^/    /'
fi
rm -f "$PKG_ERR"

# ── 7) Prove callScript rejects unknown leaked data .nix ────────────────────
echo "== 7) prove packaging rejects leaked { lib, meta } helper .nix =="
PROBE_REL="ui/prompts/.gate-probe-leaked-meta.nix"
PROBE="$SCRIPTS/$PROBE_REL"

# ── summary ─────────────────────────────────────────────────────────────────
echo "=== summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "HARD GATE FAILED — do NOT claim wizard/Nix changes work; do NOT tell user to system-update."
  exit 1
fi
echo "HARD GATE OK — install-wizard packaging + layer checks green."
exit 0
