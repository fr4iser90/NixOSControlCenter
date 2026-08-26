#!/usr/bin/env bash
# HARD GATE — entire NCC Nix tree (not install-wizard only).
#
# Agents MUST get exit 0 before claiming ANY nixos/ change works or telling
# the user to ncc system-update. Wizard-only checks are necessary but not sufficient.
#
# Covers:
#   1) bash-in-nix footguns across nixos/
#   2) cross-module layer violations (relative imports into other modules' lib/)
#   3) module modularity (plans vs <module>/migrations/; no peer hardwires)
#   4) auto-detect missing migrations / version bumps (packaging-sensitive deletes)
#   5) install-wizard packaging + packages catalog (system-update path)
#   6) staged systemConfig vs module options.nix (wizard write SSOT)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NCC HARD GATE — whole codebase (tests/validate-ncc-nix)     ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── 1) Bash embedding: entire nixos/ ────────────────────────────────────────
echo ""
echo "== 1/6  bash-in-nix (all of nixos/) =="
if bash "$ROOT/tests/install-wizard/validate-bash-embedding.sh"; then
  pass "validate-bash-embedding.sh (nixos/)"
else
  fail "bash embedding issues under nixos/"
fi

# ── 2) Layer: no cross-module relative imports into foreign lib/ ─────────────
echo ""
echo "== 2/6  layer: no relative imports into other modules' lib/ =="
LAYER_OUT=$(mktemp)
set +e
python3 - "$NIXOS" "$LAYER_OUT" <<'PY'
import os, re, sys
root = sys.argv[1]
out = sys.argv[2]
pat_packages_lib = re.compile(
    r"""import\s+(?:[^;\n]*packages/lib/|\.\./(?:\.\./)*(?:base/)?packages/lib/)"""
)
issues = []
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
            if "import" not in line:
                continue
            if rel.startswith("core/base/packages/") and "packages/lib/" in line:
                continue
            if pat_packages_lib.search(line):
                issues.append(
                    f"{rel}:{i}: packages/lib import — use getModuleApi \"packages\": "
                    f"{line.strip()[:120]}"
                )
open(out, "w", encoding="utf-8").write("\n".join(issues))
sys.exit(1 if issues else 0)
PY
LAYER_RC=$?
set -e
if [[ "$LAYER_RC" -ne 0 ]]; then
  if [[ -s "$LAYER_OUT" ]]; then
    sed 's/^/    /' "$LAYER_OUT"
  else
    echo "    (layer scanner exited $LAYER_RC with empty report)"
  fi
  fail "cross-module packages/lib imports found"
else
  pass "no foreign packages/lib relative imports"
fi
rm -f "$LAYER_OUT"

# ── 3) Module modularity ────────────────────────────────────────────────────
echo ""
echo "== 3/6  module layer / modularity =="
if bash "$ROOT/tests/validate-module-layer.sh"; then
  pass "validate-module-layer.sh"
else
  fail "module layer / modularity gate"
fi

# ── 4) Auto-detect migrations / version bumps ───────────────────────────────
echo ""
echo "== 4/6  module migrations auto-detect =="
if bash "$ROOT/tests/validate-module-migrations.sh"; then
  pass "validate-module-migrations.sh"
else
  fail "missing migrations / version bumps for packaging-sensitive deletes"
fi

# ── 5) Install-wizard packaging ─────────────────────────────────────────────
echo ""
echo "== 5/6  install-wizard packaging gate =="
if bash "$ROOT/tests/install-wizard/validate-install-wizard-nix.sh"; then
  pass "validate-install-wizard-nix.sh"
else
  fail "install-wizard packaging / wizard layer gate"
fi

# ── 6) Wizard writes vs module options.nix ───────────────────────────────────
echo ""
echo "== 6/6  systemConfig writes vs options.nix (SSOT) =="
if bash "$ROOT/tests/validate-systemconfig-writes.sh"; then
  pass "validate-systemconfig-writes.sh"
else
  fail "staged systemConfig violates module options.nix"
fi

echo ""
echo "=== NCC HARD GATE summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — do NOT claim Nix works; do NOT tell user to system-update."
  echo "Fix issues above, then re-run: bash tests/validate-ncc-nix.sh"
  exit 1
fi
echo "OK — bash + layer + modularity + migrations + wizard packaging + options SSOT green."
exit 0
