#!/usr/bin/env bash
# HARD GATE — module layer / modularity.
#
# Law:
#   - Cross-module rename/merge = <destination>/migrations/plan-*.nix (discovered)
#   - Central module-manager plans.nix = empty registry only (plans = [])
#   - Single-module cleanup = <that-module>/migrations/v*-to-v*.nix
#   - nixos/modules/* must not import other modules' trees
#   - Core orchestration may discover; must not list peer module script paths
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
MM_MIG="$NIXOS/core/management/module-manager/components/module-migration"
PLANS="$MM_MIG/plans.nix"
SYSTEM_UPDATE="$NIXOS/core/management/system-manager/handlers/system-update.nix"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-module-layer (HARD GATE) ==="

# ── 1) Central plans.nix must stay empty (no peer hardwires) ────────────────
echo "== 1) plans.nix empty registry =="
if [[ ! -f "$PLANS" ]]; then
  fail "missing $PLANS"
else
  if rg -q 'fromPaths\s*=|toPath\s*=|kind\s*=' "$PLANS"; then
    fail "plans.nix hardwires migrations — put plan-*.nix under destination module migrations/"
  else
    pass "plans.nix has no fromPaths/toPath/kind hardwires"
  fi
  if rg -q 'kind\s*=\s*"code-cleanup"' "$PLANS"; then
    fail "plans.nix has kind=code-cleanup — put removeRelativePaths in <module>/migrations/"
  fi
  if rg -q 'install-wizard' "$PLANS"; then
    fail "plans.nix hardwires install-wizard — layer violation (migration belongs in install-wizard/migrations/)"
  else
    pass "plans.nix does not mention install-wizard"
  fi
  if ! rg -q 'plans\s*=\s*\[\s*\]' "$PLANS"; then
    fail "plans.nix must be plans = [] (discovery owns rename/merge)"
  else
    pass "plans.nix is empty plans = []"
  fi
fi

# Runner must discover plan-*.nix
if rg -q 'migrations/plan-\*\.nix' "$MM_MIG/runner.nix"; then
  pass "runner discovers migrations/plan-*.nix"
else
  fail "runner.nix must discover */migrations/plan-*.nix"
fi

# gui-engine must not hardwire hyprland (catalog owned by hyprland module)
echo "== 1b) gui-engine no hyprland hardwire =="
GUI_ENG="$NIXOS/core/management/gui-engine"
if rg -q 'hyprlandRoot|NCC_HYPRLAND_CATALOG|hyprland/lib/mk-catalog' "$GUI_ENG" --glob '*.nix'; then
  fail "gui-engine hardwires hyprland catalog — keep NCC_HYPRLAND_CATALOG in hyprland/gui/"
elif rg -q '_CORE_CONDITIONAL|frozenset\(\{\"hyprland\"\}\)|\"hyprland\"' \
  "$GUI_ENG/python/ncc_gui/shell.py" 2>/dev/null; then
  fail "shell.py hardcodes hyprland — use catalog alwaysVisible from registerGuiDomain"
else
  pass "gui-engine has no hyprland hardwire"
fi

# gui-engine may only resolve plumbing peers. Domain content arrives through cli-registry
# (registerGuiPage / registerGuiEnv / registerGuiPython), so a new getModuleMetadata name here
# means someone re-coupled the engine to one module — ncc-assistant lived here until 2026-08.
echo "== 1c) gui-engine peer roots allow-list =="
ALLOWED_PEERS=$'cli-registry\npackages\nsystem-manager'
SEEN_PEERS=$(rg -o -N 'getModuleMetadata "[a-z0-9-]+"' "$GUI_ENG" --glob '*.nix' \
  | rg -o '"[a-z0-9-]+"' | tr -d '"' | sort -u || true)
BAD_PEERS=""
for peer in $SEEN_PEERS; do
  grep -qxF "$peer" <<<"$ALLOWED_PEERS" || BAD_PEERS="$BAD_PEERS $peer"
done
if [[ -n "$BAD_PEERS" ]]; then
  echo "    off-list:$BAD_PEERS"
  fail "gui-engine resolves a peer module it should discover — register it in cli-registry"
else
  pass "gui-engine resolves only plumbing peers"
fi

# The decoupled channel itself: a module hands over its own store root and the engine only
# makes it importable. Peer code is NEVER copied — the store is read-only and a peer that
# ships its own ncc_gui would collide with the engine's. Pinned because reverting to a
# package list, or back to copying, would otherwise be silent.
if ! rg -q 'registerGuiPython' "$NIXOS/core/management/cli-registry/api.nix"; then
  fail "cli-registry lost registerGuiPython — pages would ship without their Python"
elif rg -q 'cp[^\n]*p\.root' "$GUI_ENG/domain-gui.nix"; then
  fail "domain-gui.nix copies a peer payload again — it stays read-only in the store, on PYTHONPATH"
elif ! rg -q 'payloadRoots = lib\.unique \(map \(p: p\.root\) payloads\);' "$GUI_ENG/domain-gui.nix"; then
  fail "domain-gui.nix must build the payload PYTHONPATH from every registered root"
elif ! rg -q '\[ "\$\{src\}" \] \+\+ payloadRoots' "$GUI_ENG/domain-gui.nix"; then
  fail "engine root must come FIRST on PYTHONPATH — a peer copying ncc_gui must not shadow it"
elif ! rg -q 'PYTHONPATH="\$\{shared\.pythonPath\}' "$GUI_ENG/root-gui.nix"; then
  fail "root-gui.nix must reuse the composed PYTHONPATH or ncc-gui loses the page's Python"
elif rg -q 'GUI_PACKAGES' "$GUI_ENG/python/ncc_gui/reload.py"; then
  fail "reload.py lists GUI packages again — it must find them by __init__.py"
elif ! rg -q '\(d / "__init__\.py"\)\.is_file\(\)' "$GUI_ENG/python/ncc_gui/reload.py"; then
  fail "reload.py must discover staged packages via __init__.py (data/ stays undigested)"
else
  pass "GUI Python payload is discovered end to end"
fi

# ── 1d) staged Python keeps an importable directory name ─────────────────────
echo "== 1d) staged Python dirs keep importable names =="
# A path literal IS /nix/store/<hash>-<dir>. `cp -r ${./window} DEST/` into a directory that
# already exists keeps the SOURCE basename, so the package lands as <hash>-window and nobody
# can import it. Each package copied into a staging dir must name its destination.
#
# Tokenised, not regex-matched: destinations are `$out/…`, so a pattern anchored on a literal
# `/` after the whitespace never fires and the gate stays green while the build ships
# unimportable names (measured: the original regex scored 0 hits on the real breakage).
STAGE_HITS=$(mktemp)
set +e
python3 - "$NIXOS" "$STAGE_HITS" <<'PY'
import os, re, sys

root, out = sys.argv[1], sys.argv[2]
LITERAL = re.compile(r"^\$\{[^}]+\}$")
CP_R = re.compile(r"\bcp\s+-[A-Za-z]*r")
issues = []
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith(".nix"):
            continue
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, os.path.dirname(root))
        text = open(path, encoding="utf-8", errors="replace").read()
        for i, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#") or not CP_R.search(stripped):
                continue
            tokens = stripped.split()
            if len(tokens) < 3:
                continue
            dest = tokens[-1]
            literals = [t for t in tokens[1:-1] if LITERAL.match(t)]
            if not literals:
                continue
            where = f"{rel}:{i}: {' '.join(literals)} -> {dest}"
            if len(literals) >= 2:
                issues.append(where + "   (several sources: cp keeps every store basename)")
            elif dest.endswith("/"):
                issues.append(where + "   (destination is a directory: cp keeps the store basename)")
open(out, "w", encoding="utf-8").write("\n".join(issues))
sys.exit(1 if issues else 0)
PY
STAGE_RC=$?
set -e
if [[ "$STAGE_RC" -ne 0 ]]; then
  sed 's/^/    /' "$STAGE_HITS"
  fail "a package would be staged under its store hash — spell out every destination or import fails at runtime"
else
  pass "no path literal is staged where its store basename would become the package name"
fi
rm -f "$STAGE_HITS"


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
echo "OK — plans.nix empty; plan-*.nix + v*-to-v*.nix discovered; modules modular."
exit 0
