#!/usr/bin/env bash
# HARD GATE — every static relative import under nixos/ must resolve to an existing file.
# Catches broken paths like components/lib/foo.nix vs components/system-checks/lib/foo.nix
# before commit (the class of error that passes packaging gates but fails nix build switch).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-nix-import-paths (static relative imports) ==="

REPORT=$(mktemp)
set +e
python3 - "$NIXOS" "$REPORT" <<'PY'
import re, sys
from pathlib import Path

root = Path(sys.argv[1])
report = Path(sys.argv[2])
skip_parts = {".git", "doc", "docs", "ai", "plans", "knowledge", ".cursor", "node_modules"}

IMPORT_PATH = re.compile(
    r'\bimport\s+(?:\(\s*)?(?:"(\.(?:/|\.)[^"]+\.nix)"|\'(\.(?:/|\.)[^\']+\.nix)\'|(\.(?:/|\.)[\w./-]+\.nix))'
)
IMPORTS_LIST = re.compile(r"^\s*(?P<p>(?:\./|\.\./)[\w./-]+\.nix)\s*,?\s*$")


def skip_file(rel: Path) -> bool:
    return any(p in skip_parts for p in rel.parts)


def in_repo(target: Path) -> bool:
    try:
        target.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def target_exists(base: Path, rel: str) -> bool:
    target = (base / rel).resolve()
    if not in_repo(target):
        return False
    if target.is_file():
        return True
    if target.is_dir() and (target / "default.nix").is_file():
        return True
    return False


def strip_nix_path(raw: str) -> str:
    return raw.strip().strip(")").strip(";")


issues: list[str] = []

for path in sorted(root.rglob("*.nix")):
    rel_file = path.relative_to(root)
    if skip_file(rel_file):
        continue
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        issues.append(f"{rel_file}: unreadable: {e}")
        continue

    in_imports = False
    seen: set[tuple[int, str]] = set()

    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0]
        if "${" in line:
            continue

        if re.search(r"\bimports\s*=\s*\[", line):
            in_imports = True
        if in_imports and "]" in line and "imports" not in line:
            in_imports = False

        candidates: list[str] = []
        for m in IMPORT_PATH.finditer(line):
            p = m.group(1) or m.group(2) or m.group(3)
            if p:
                candidates.append(strip_nix_path(p))

        if in_imports:
            lm = IMPORTS_LIST.match(line)
            if lm:
                candidates.append(lm.group("p"))

        for rel in candidates:
            if not rel.startswith("."):
                continue
            key = (lineno, rel)
            if key in seen:
                continue
            seen.add(key)
            if not target_exists(path.parent, rel):
                resolved = (path.parent / rel).resolve()
                issues.append(
                    f"{rel_file}:{lineno}: import {rel!r} -> missing ({resolved})"
                )

lines: list[str] = []
if issues:
    lines.append("MISSING_IMPORT_TARGETS:")
    lines.extend(f"  - {i}" for i in issues)
if not lines:
    lines.append("OK: all static relative import paths resolve")
report.write_text("\n".join(lines) + "\n", encoding="utf-8")
sys.exit(1 if issues else 0)
PY
RC=$?
set -e

if [[ -s "$REPORT" ]]; then
  sed 's/^/  /' "$REPORT"
fi
rm -f "$REPORT"

if [[ "$RC" -ne 0 ]]; then
  fail "broken relative import paths under nixos/"
else
  pass "static relative import paths resolve"
fi

echo "=== validate-nix-import-paths summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
