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
#   7) static relative import paths exist + nix parse (all nixos/)
#   8) prebuild module fragments eval (import paths at apply-time)
#   9) GUI catalog invariants (enable or true, core domain+page, no tests in nixos/)
#  10) docs layout + kebab-case (module doc/, no loose root markdown)
#  11) store-status probes (df + profile gens — not flake path-info / list-generations)
#  12) module shape (template-config + ai/manifest + doc/usage.md)
#  13) AI pack contract (manifest + tools JSON)
#  14) module surfaces (commands ↔ doc/cli.md ↔ GUI page registration)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NCC HARD GATE — whole codebase (tests/gates/validate-ncc-nix)     ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── 1) Bash embedding: entire nixos/ ────────────────────────────────────────
echo ""
echo "== 1/14  bash-in-nix (all of nixos/) =="
if bash "$ROOT/tests/install-wizard/validate-bash-embedding.sh"; then
  pass "validate-bash-embedding.sh (nixos/)"
else
  fail "bash embedding issues under nixos/"
fi

# ── 2) Layer: no cross-module relative imports into foreign lib/ ─────────────
echo ""
echo "== 2/14  layer: no relative imports into other modules' lib/ =="
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
echo "== 3/14  module layer / modularity =="
if bash "$ROOT/tests/gates/validate-module-layer.sh"; then
  pass "validate-module-layer.sh"
else
  fail "module layer / modularity gate"
fi

# ── 4) Auto-detect migrations / version bumps ───────────────────────────────
echo ""
echo "== 4/14  module migrations auto-detect =="
if bash "$ROOT/tests/gates/validate-module-migrations.sh"; then
  pass "validate-module-migrations.sh"
else
  fail "missing migrations / version bumps for packaging-sensitive deletes"
fi

# ── 5) Install-wizard packaging ─────────────────────────────────────────────
echo ""
echo "== 5/14  install-wizard packaging gate =="
if bash "$ROOT/tests/install-wizard/validate-install-wizard-nix.sh"; then
  pass "validate-install-wizard-nix.sh"
else
  fail "install-wizard packaging / wizard layer gate"
fi

# ── 6) Wizard writes vs module options.nix ───────────────────────────────────
echo ""
echo "== 6/14  systemConfig writes vs options.nix (SSOT) =="
if bash "$ROOT/tests/gates/validate-systemconfig-writes.sh"; then
  pass "validate-systemconfig-writes.sh"
else
  fail "staged systemConfig violates module options.nix"
fi

# ── 7) Static relative import paths ──────────────────────────────────────────
echo ""
echo "== 7/14  nix import paths + parse (generic) =="
if bash "$ROOT/tests/gates/validate-nix-import-paths.sh"; then
  pass "validate-nix-import-paths.sh"
else
  fail "broken relative import paths under nixos/"
fi

# ── 8) Module fragment eval (prebuild + imported config.nix) ─────────────────
echo ""
echo "== 8/14  nix module eval (prebuild + config.nix imports) =="
if bash "$ROOT/tests/gates/validate-nix-module-eval.sh"; then
  pass "validate-nix-module-eval.sh"
else
  fail "prebuild / imported config.nix module eval failed"
fi

# ── 9) GUI catalog invariants ────────────────────────────────────────────────
echo ""
echo "== 9/14  GUI catalog invariants =="
if bash "$ROOT/tests/gates/validate-gui-catalog.sh"; then
  pass "validate-gui-catalog.sh"
else
  fail "GUI catalog / enable / test-leak invariants"
fi

# ── 10) Docs layout + kebab naming ───────────────────────────────────────────
echo ""
echo "== 10/14  docs layout + kebab-case =="
if bash "$ROOT/tests/gates/validate-docs-layout.sh"; then
  pass "validate-docs-layout.sh"
else
  fail "markdown outside doc/ or non-kebab names"
fi

# ── 11) Store-status probes ──────────────────────────────────────────────────
echo ""
echo "== 11/14  store-status probes =="
if bash "$ROOT/tests/gates/validate-store-status-probes.sh"; then
  pass "validate-store-status-probes.sh"
else
  fail "store-status probe contract broken"
fi

# ── 12) Uniform module skeleton ──────────────────────────────────────────────
echo ""
echo "== 12/14  module shape (template + ai + usage) =="
if bash "$ROOT/tests/gates/validate-module-shape.sh"; then
  pass "validate-module-shape.sh"
else
  fail "discovery modules missing template-config / ai/manifest / doc/usage.md"
fi

# ── 13) AI pack contract ─────────────────────────────────────────────────────
echo ""
echo "== 13/14  AI packs (manifest + tools) =="
if bash "$ROOT/tests/gates/validate-ai-packs.sh"; then
  pass "validate-ai-packs.sh"
else
  fail "AI pack manifest/tool contract broken"
fi

# ── 14) CLI / GUI / docs surfaces ────────────────────────────────────────────
echo ""
echo "== 14/14  module surfaces (CLI docs + GUI pages) =="
if bash "$ROOT/tests/gates/validate-module-surfaces.sh"; then
  pass "validate-module-surfaces.sh"
else
  fail "commands/doc/cli.md/GUI page surfaces inconsistent"
fi

echo ""
echo "=== NCC HARD GATE summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — do NOT claim Nix works; do NOT tell user to system-update."
  echo "Fix issues above, then re-run: bash tests/gates/validate-ncc-nix.sh"
  exit 1
fi
echo "OK — bash + layer + modularity + migrations + wizard + options + import paths + module eval + catalog + docs-layout + store-status + module-shape + ai-packs + surfaces green."
exit 0
