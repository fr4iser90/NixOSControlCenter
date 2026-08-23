#!/usr/bin/env bash
# HARD GATE — module layer / modularity.
#
# Law:
#   - Central module-manager plans.nix = cross-module rename/merge ONLY
#   - Single-module cleanup = <that-module>/migrations/v*-to-v*.nix
#   - nixos/modules/* must not import other modules' trees
#   - Core orchestration may discover; must not list peer module script paths
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
MM_MIG="$NIXOS/core/management/module-manager/components/module-migration"
PLANS="$MM_MIG/plans.nix"
SYSTEM_UPDATE="$NIXOS/core/management/system-manager/handlers/system-update.nix"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-module-layer (HARD GATE) ==="

# ── 1) Central plans: no code-cleanup / no install-wizard paths ─────────────
echo "== 1) plans.nix cross-module only =="
if [[ ! -f "$PLANS" ]]; then
  fail "missing $PLANS"
else
  if rg -q 'kind\s*=\s*"code-cleanup"' "$PLANS"; then
    fail "plans.nix has kind=code-cleanup — put removeRelativePaths in <module>/migrations/"
  else
    pass "plans.nix has no code-cleanup (module migrations/ own that)"
  fi
  if rg -q 'install-wizard' "$PLANS"; then
    fail "plans.nix hardwires install-wizard — layer violation (migration belongs in install-wizard/migrations/)"
  else
    pass "plans.nix does not mention install-wizard"
  fi
fi

# ── 2) module-manager must not hardwire install-wizard script paths ─────────
echo "== 2) module-manager no install-wizard script paths =="
HITS=$(rg -n 'install-wizard/scripts' "$MM_MIG" --glob '*.nix' 2>/dev/null || true)
if [[ -n "$HITS" ]]; then
  echo "$HITS" | sed 's/^/    /'
  fail "module-migration hardwires install-wizard/scripts (use discovery of migrations/)"
else
  pass "module-migration has no install-wizard/scripts paths"
fi

# ── 3) system-update: discovery helper only, no module script paths ─────────
echo "== 3) system-update generic discovery =="
if [[ ! -f "$SYSTEM_UPDATE" ]]; then
  fail "missing system-update.nix"
else
  if rg -q 'install-wizard/scripts' "$SYSTEM_UPDATE"; then
    fail "system-update hardwires install-wizard/scripts"
  else
    pass "system-update has no install-wizard/scripts"
  fi
  if rg -q 'apply-migrations\.nix' "$SYSTEM_UPDATE" \
    && rg -q 'ncc-apply-migrations' "$SYSTEM_UPDATE"; then
    pass "system-update runs ncc-apply-migrations (discovery)"
  else
    fail "system-update must import apply-migrations.nix and run ncc-apply-migrations post-sync"
  fi
  if rg -q 'apply-code-cleanup|ncc-apply-code-cleanup' "$SYSTEM_UPDATE"; then
    fail "system-update still references old apply-code-cleanup naming"
  else
    pass "no legacy apply-code-cleanup references"
  fi
fi

# ── 4) Helper naming + no repo .sh ──────────────────────────────────────────
echo "== 4) apply-migrations.nix (bash-in-nix) =="
HELPER="$MM_MIG/apply-migrations.nix"
if find "$MM_MIG" -maxdepth 1 -name '*.sh' -print -quit | grep -q .; then
  fail "repo .sh under module-migration forbidden"
fi
if [[ -f "$MM_MIG/apply-code-cleanup-plans.nix" ]] || [[ -f "$MM_MIG/apply-code-cleanup-plans.sh" ]]; then
  fail "legacy apply-code-cleanup-plans.* must be removed — use apply-migrations.nix"
fi
if [[ ! -f "$HELPER" ]]; then
  fail "missing apply-migrations.nix"
elif ! rg -q 'writeShellScriptBin "ncc-apply-migrations"' "$HELPER"; then
  fail "apply-migrations.nix must define writeShellScriptBin ncc-apply-migrations"
elif ! rg -q 'migrations/v\*-to-v\*\.nix' "$HELPER"; then
  fail "helper must discover */migrations/v*-to-v*.nix"
else
  pass "apply-migrations.nix present (bash-in-nix discovery)"
fi

# ── 5) Optional modules must not import peer trees ──────────────────────────
echo "== 5) nixos/modules: no cross-module imports =="
# Ban import of other modules' trees. Attr keys / generated path strings are OK.
MOD_HITS=$(mktemp)
set +e
python3 - "$NIXOS/modules" "$MOD_HITS" <<'PY'
import os, re, sys
root = sys.argv[1]
out = sys.argv[2]
issues = []
rel_import = re.compile(r"""import\s+\.\./(\.\./)+(modules|core)/""")
abs_import = re.compile(
    r"""import\s+(?:[^;\n]*?)/(?:modules|core)/(?:management|base|infrastructure|security|specialized|system)/"""
)
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith(".nix"):
            continue
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            s = line.strip()
            if s.startswith("#") or "import" not in line:
                continue
            if rel_import.search(line) or abs_import.search(line):
                issues.append(f"modules/{rel}:{i}: cross-module import: {s[:110]}")
open(out, "w", encoding="utf-8").write("\n".join(issues))
sys.exit(1 if issues else 0)
PY
MOD_RC=$?
set -e
if [[ "$MOD_RC" -ne 0 ]]; then
  if [[ -s "$MOD_HITS" ]]; then
    sed 's/^/    /' "$MOD_HITS" | head -40
  fi
  fail "optional modules import peer trees — use getModuleApi / getModuleConfig only"
else
  pass "nixos/modules has no cross-module imports"
fi
rm -f "$MOD_HITS"

# ── 6) install-wizard owns its migration ────────────────────────────────────
echo "== 6) install-wizard module migration =="
IW_MIG="$NIXOS/core/management/install-wizard/migrations/v1.0.0-to-v1.1.0.nix"
if [[ ! -f "$IW_MIG" ]]; then
  fail "missing install-wizard/migrations/v1.0.0-to-v1.1.0.nix"
elif ! rg -q 'gen-features-from-metadata\.nix' "$IW_MIG" \
  || ! rg -q 'removeRelativePaths' "$IW_MIG"; then
  fail "install-wizard migration must list removeRelativePaths (incl. gen-features-from-metadata.nix)"
else
  pass "install-wizard/migrations/v1.0.0-to-v1.1.0.nix owns stale path cleanup"
fi

echo "=== module-layer summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — fix layer violations before claiming modularity."
  exit 1
fi
echo "OK — central plans cross-module only; module migrations discovered; modules modular."
exit 0
