#!/usr/bin/env bash
# HARD GATE — discovery modules share a uniform skeleton.
#
# A module = directory under nixos/core|modules with default.nix + options.nix
# (same rule as module-manager discovery).
#
# Required per module:
#   - template-config.nix
#   - ai/manifest.nix
#   - doc/usage.md
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-module-shape (HARD GATE) ==="

if python3 - "$NIXOS" <<'PY'
import sys
from pathlib import Path

nixos = Path(sys.argv[1])
errors: list[str] = []

REQUIRED = (
    "template-config.nix",
    "ai/manifest.nix",
    "doc/usage.md",
)


def discover_modules(root: Path) -> list[Path]:
    mods: list[Path] = []
    for base in (root / "core", root / "modules"):
        if not base.is_dir():
            continue
        for default in base.rglob("default.nix"):
            d = default.parent
            if (d / "options.nix").is_file():
                mods.append(d)
    return sorted(mods)


mods = discover_modules(nixos)
if not mods:
    print("FAIL: no discovery modules found")
    sys.exit(1)

for mod in mods:
    rel = mod.relative_to(nixos)
    for req in REQUIRED:
        if not (mod / req).is_file():
            errors.append(f"{rel}: missing {req}")

if errors:
    print("ISSUES:")
    for e in errors:
        print(f"  - {e}")
    print(f"checked {len(mods)} modules; {len(errors)} issue(s)")
    sys.exit(1)

print(f"OK: {len(mods)} discovery modules have template-config + ai/manifest + doc/usage.md")
sys.exit(0)
PY
then
  pass "discovery module skeleton"
else
  fail "module skeleton incomplete"
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — uniform module shape broken."
  exit 1
fi
echo "OK — module shape green."
exit 0
