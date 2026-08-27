#!/usr/bin/env bash
# HARD GATE — GUI catalog / commands.nix invariants + no tests under nixos/
#
# Catches:
#   - cfg.enable or true / enableChecks or true (Nix: false or true → always true)
#   - test_*.py under nixos/ (would deploy into /etc/nixos)
#   - Core domains missing registerGuiDomain / registerGuiPage
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-gui-catalog (HARD GATE) ==="

# ── 1) No unit tests inside nixos/ (product tree) ────────────────────────────
LEAK=$(find "$NIXOS" -type f \( -name 'test_*.py' -o -name '*_test.py' \) 2>/dev/null | head -50 || true)
if [[ -n "${LEAK}" ]]; then
  echo "$LEAK" | sed 's/^/    /'
  fail "Python tests under nixos/ — move to tests/ (they deploy with the tree)"
else
  pass "no test_*.py under nixos/"
fi

# ── 2) Ban enable or true footguns in commands.nix ───────────────────────────
OR_TRUE=$(
  grep -RInE \
    --include='commands.nix' \
    'enable[[:space:]]+or[[:space:]]+true|enableChecks[[:space:]]+or[[:space:]]+true|mkIf[[:space:]]*\([^)]*or[[:space:]]+true' \
    "$NIXOS" 2>/dev/null || true
)
if [[ -n "${OR_TRUE}" ]]; then
  echo "$OR_TRUE" | sed 's/^/    /'
  fail "enable/or true in commands.nix (use != false or or false)"
else
  pass "no enable or true in commands.nix"
fi

# ── 3) Core domains must register domain + page ──────────────────────────────
# shellcheck disable=SC2016
python3 - "$NIXOS" <<'PY' || FAIL=1
import re, sys
from pathlib import Path

nixos = Path(sys.argv[1])
# Catalog short ids that are Core (config manager — always present).
CORE = {
    "desktop",
    "hardware",
    "network",
    "user",
    "packages",
    "system",
    "modules",
    "install",
}

domain_re = re.compile(
    r'registerGuiDomain\s+"([^"]+)"\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}',
    re.DOTALL,
)
page_re = re.compile(r'registerGuiPage\s+"([^"]+)"')

found_domain: set[str] = set()
found_page: set[str] = set()
group_of: dict[str, str] = {}

for path in nixos.rglob("commands.nix"):
    text = path.read_text(encoding="utf-8", errors="replace")
    for m in page_re.finditer(text):
        found_page.add(m.group(1))
    for m in domain_re.finditer(text):
        did = m.group(1)
        body = m.group(2)
        found_domain.add(did)
        gm = re.search(r'group\s*=\s*"(core|features)"', body)
        if gm:
            group_of[did] = gm.group(1)

missing_d = sorted(CORE - found_domain)
missing_p = sorted(CORE - found_page)
wrong_group = sorted(
    d for d in CORE if group_of.get(d) and group_of[d] != "core"
)

ok = True
if missing_d:
    print(f"  FAIL: core domains missing registerGuiDomain: {missing_d}")
    ok = False
if missing_p:
    print(f"  FAIL: core domains missing registerGuiPage: {missing_p}")
    ok = False
if wrong_group:
    print(f"  FAIL: core domains not group=core: {wrong_group}")
    ok = False
if ok:
    print("  PASS: core domains register domain+page with group=core")
sys.exit(0 if ok else 1)
PY

# ── 4) Packages/network/user/desktop: domain registration not solely inside mkIf enable ──
# Heuristic: file must contain registerGuiDomain outside a wrapping `config = lib.mkIf (cfg.enable`
python3 - "$NIXOS" <<'PY' || FAIL=1
import re, sys
from pathlib import Path

nixos = Path(sys.argv[1])
# These must keep domain+page when "disabled" (config manager).
CHECK = ("desktop", "network", "user", "packages", "hardware")
issues = []
for path in nixos.rglob("commands.nix"):
    text = path.read_text(encoding="utf-8", errors="replace")
    for did in CHECK:
        if f'registerGuiDomain "{did}"' not in text:
            continue
        # Bad pattern: entire config = mkIf (cfg.enable …) ( mkMerge [ registerGuiDomain
        if re.search(
            rf'config\s*=\s*lib\.mkIf\s*\([^)]*enable[^)]*\)\s*\(?\s*lib\.mkMerge\s*\[\s*\(cliRegistry\.registerGuiDomain\s+"{did}"',
            text,
            re.DOTALL,
        ):
            issues.append(f"{path.relative_to(nixos)}: {did} domain wrapped in config=mkIf enable")
if issues:
    for i in issues:
        print(f"  FAIL: {i}")
    sys.exit(1)
print("  PASS: checked core domains not wrapped in config=mkIf enable")
sys.exit(0)
PY

echo "=== validate-gui-catalog summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — catalog / enable / test-leak invariants."
  exit 1
fi
echo "OK — catalog invariants green."
exit 0
