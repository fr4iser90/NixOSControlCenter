#!/usr/bin/env bash
# HARD GATE — CLI / GUI / docs surfaces stay consistent per module.
#
# Rules:
#   1) Every commands.nix has sibling doc/cli.md with Status line
#   2) No legacy root CLI.md / cli.md next to commands.nix (use doc/cli.md)
#   3) Module-root ui/gui/page.py ⇒ commands.nix registers registerGuiPage
#   4) registerGuiPage "<id>" <path> ⇒ <path>/page.py exists
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-module-surfaces (HARD GATE) ==="

if python3 - "$NIXOS" <<'PY'
import re
import sys
from pathlib import Path

nixos = Path(sys.argv[1])
errors: list[str] = []

STATUS_RE = re.compile(
    r"\*\*Status:\*\*\s*`(todo|partial|compliant)`"
)
PAGE_REG_RE = re.compile(
    r'registerGuiPage\s+"([^"]+)"\s+(\.\.?/[\w./+-]+)'
)


def module_root_for(path: Path):
    cur = path if path.is_dir() else path.parent
    while True:
        if (cur / "default.nix").is_file() and (cur / "options.nix").is_file():
            return cur
        if cur == nixos:
            return None
        parent = cur.parent
        if parent == cur:
            return None
        cur = parent


commands_files = sorted(nixos.rglob("commands.nix"))
cli_ok = 0

for cmd in commands_files:
    d = cmd.parent
    rel = d.relative_to(nixos)
    for legacy in ("CLI.md", "cli.md"):
        if (d / legacy).is_file():
            errors.append(f"{rel}: move {legacy} → doc/cli.md (no root CLI docs)")

    cli_doc = d / "doc" / "cli.md"
    if not cli_doc.is_file():
        errors.append(f"{rel}: commands.nix without doc/cli.md")
    elif not STATUS_RE.search(cli_doc.read_text(encoding="utf-8", errors="replace")):
        errors.append(
            f"{rel}: doc/cli.md missing **Status:** `todo|partial|compliant`"
        )
    else:
        cli_ok += 1

for page in sorted(nixos.rglob("ui/gui/page.py")):
    mod = module_root_for(page)
    if mod is None:
        continue
    if page.parent != mod / "ui" / "gui":
        continue
    commands = mod / "commands.nix"
    rel = mod.relative_to(nixos)
    if not commands.is_file():
        errors.append(f"{rel}: ui/gui/page.py but no commands.nix")
        continue
    text = commands.read_text(encoding="utf-8", errors="replace")
    if "registerGuiPage" not in text:
        errors.append(f"{rel}: ui/gui/page.py without registerGuiPage in commands.nix")

for cmd in commands_files:
    text = cmd.read_text(encoding="utf-8", errors="replace")
    base = cmd.parent
    for m in PAGE_REG_RE.finditer(text):
        domain_id, raw_path = m.group(1), m.group(2)
        target = (base / raw_path).resolve()
        page_py = target / "page.py"
        rel = cmd.relative_to(nixos)
        if not page_py.is_file():
            errors.append(
                f"{rel}: registerGuiPage \"{domain_id}\" {raw_path} → missing page.py"
            )

if errors:
    print("ISSUES:")
    for e in errors:
        print(f"  - {e}")
    print(f"commands.nix files={len(commands_files)}; cli docs ok={cli_ok}; issues={len(errors)}")
    sys.exit(1)

print(
    f"OK: {len(commands_files)} commands.nix ↔ doc/cli.md; "
    f"GUI page registration paths consistent"
)
sys.exit(0)
PY
then
  pass "CLI ↔ docs ↔ GUI surfaces"
else
  fail "CLI/GUI/docs surface mismatch"
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — module surfaces not uniform."
  exit 1
fi
echo "OK — module surfaces green."
exit 0
