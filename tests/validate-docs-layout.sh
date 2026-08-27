#!/usr/bin/env bash
# HARD GATE — ONE docs home per module: <module>/doc/ (+ kebab-case).
# Root may only have README.md / CHANGELOG.md. No ai/docs/, no root cli.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-docs-layout (HARD GATE) ==="

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
nixos = root / "nixos"
docs = root / "docs"
errors: list[str] = []

ALLOWED_ROOT_NAMES = {"README.md", "CHANGELOG.md"}
# Product text that is not the module doc tree
ALLOWED_PATH_MARKERS = (
    "/doc/",
    "/prompts/",       # runtime prompts (not human docs)
    "/knowledge/",     # built/packaged knowledge if present in tree
)

KEBAB_OR_VER = re.compile(
    r"^([a-z0-9]+([.-][a-z0-9]+)*|v[0-9]+(\.[0-9]+)*(-[a-z0-9]+)*)\.md$"
)


def is_allowed_nixos_md(path: Path) -> bool:
    rel = "/" + str(path.relative_to(nixos)).replace("\\", "/")
    name = path.name
    if name in ALLOWED_ROOT_NAMES:
        return True
    if any(m in rel for m in ALLOWED_PATH_MARKERS):
        return True
    return False


def check_kebab(path: Path, *, under: str) -> None:
    name = path.name
    if name in ("README.md", "CHANGELOG.md"):
        return
    if not KEBAB_OR_VER.match(name):
        errors.append(f"{under}: non-kebab filename: {path.relative_to(root)}")


# Forbidden legacy paths
for bad in nixos.rglob("ai/docs"):
    if bad.is_dir() and any(bad.glob("*.md")):
        errors.append(f"nixos: remove ai/docs — use doc/ai-*.md instead ({bad.relative_to(root)})")

for md in sorted(nixos.rglob("*.md")):
    if not is_allowed_nixos_md(md):
        errors.append(
            f"nixos: markdown only under doc/ (or prompts/knowledge), "
            f"or README/CHANGELOG at root — found {md.relative_to(root)}"
        )
    check_kebab(md, under="nixos")

if docs.is_dir():
    for md in sorted(docs.rglob("*.md")):
        check_kebab(md, under="docs")

if errors:
    print("ISSUES:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print(
    f"OK: one docs home (doc/) + kebab "
    f"({sum(1 for _ in nixos.rglob('*.md'))} nixos md files)"
)
sys.exit(0)
PY
rc=$?
if [[ $rc -eq 0 ]]; then
  pass "markdown only under doc/ + kebab-case"
else
  fail "docs layout / naming violations (see ISSUES)"
fi

echo "=== validate-docs-layout summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — see docs/developing/docs-conventions.md"
  exit 1
fi
echo "OK — docs layout + kebab naming green."
exit 0
