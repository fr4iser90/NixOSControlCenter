#!/usr/bin/env bash
# HARD GATE — manager CLI verbs stay wired end-to-end.
#
# Catches: Python argparse adds `ncc ai focus` but commands.nix `arguments =`
# whitelist omits it → dispatcher prints Unknown command 'ai focus'.
#
# Rules (ncc-assistant):
#   1) Every top-level argparse subcommand is listed in commands.nix arguments
#   2) Every commands.nix argument maps to a top-level argparse subcommand
#   3) Every argparse subcommand has a main() dispatcher branch
#      (gui may fall through to default GUI)
#   4) longHelp should mention each verb (soft warn → hard if missing from help
#      when also missing from arguments — already covered by 1)
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-cli-manager-args (HARD GATE) ==="

python3 - "$NIXOS" <<'PY'
from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

nixos = Path(sys.argv[1])
errors: list[str] = []
warns: list[str] = []

# --- ncc-assistant: argparse ↔ commands.nix arguments ---

cli_py = (
    nixos
    / "modules/specialized/ncc-assistant/python/ncc_assistant/cli.py"
)
commands_nix = nixos / "modules/specialized/ncc-assistant/commands.nix"

if not cli_py.is_file():
    errors.append("ncc-assistant: missing python/ncc_assistant/cli.py")
elif not commands_nix.is_file():
    errors.append("ncc-assistant: missing commands.nix")
else:
    tree = ast.parse(cli_py.read_text(encoding="utf-8"), filename=str(cli_py))

    def const_str(node: ast.AST) -> str | None:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        return None

    # Top-level subparsers dest="command" → name of variable (usually `sub`)
    top_sub_names: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        tgt = node.targets[0]
        if not isinstance(tgt, ast.Name):
            continue
        val = node.value
        if not isinstance(val, ast.Call):
            continue
        func = val.func
        if not (
            isinstance(func, ast.Attribute) and func.attr == "add_subparsers"
        ):
            continue
        # dest="command" marks the manager root
        for kw in val.keywords:
            if kw.arg == "dest" and const_str(kw.value) == "command":
                top_sub_names.add(tgt.id)

    argparse_cmds: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if not (isinstance(func, ast.Attribute) and func.attr == "add_parser"):
            continue
        if not isinstance(func.value, ast.Name) or func.value.id not in top_sub_names:
            continue
        if not node.args:
            continue
        name = const_str(node.args[0])
        if name:
            argparse_cmds.add(name)

    # Dispatcher branches: command == "x" / command in ("a","b")
    handled: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Compare):
            continue
        left = node.left
        if not (isinstance(left, ast.Name) and left.id == "command"):
            continue
        for op, comparator in zip(node.ops, node.comparators):
            if isinstance(op, ast.Eq):
                s = const_str(comparator)
                if s:
                    handled.add(s)
            elif isinstance(op, (ast.In, ast.NotIn)) and isinstance(
                comparator, (ast.Tuple, ast.List)
            ):
                for elt in comparator.elts:
                    s = const_str(elt)
                    if s:
                        handled.add(s)

    # gui is default fall-through when command is None/"gui"
    handled.add("gui")

    text = commands_nix.read_text(encoding="utf-8")
    # Prefer the ai manager registration block
    args_match = re.search(
        r"arguments\s*=\s*\[(.*?)\]\s*;",
        text,
        re.DOTALL,
    )
    nix_args: set[str] = set()
    if not args_match:
        errors.append(
            "ncc-assistant/commands.nix: no arguments = [ … ] on ai manager"
        )
    else:
        nix_args = set(re.findall(r'"([a-z0-9-]+)"', args_match.group(1)))

    missing_in_nix = sorted(argparse_cmds - nix_args)
    extra_in_nix = sorted(nix_args - argparse_cmds)
    missing_handler = sorted(argparse_cmds - handled)

    if missing_in_nix:
        errors.append(
            "ncc-assistant: argparse subcommands missing from commands.nix "
            f"arguments (ncc will reject them): {', '.join(missing_in_nix)}"
        )
    if extra_in_nix:
        errors.append(
            "ncc-assistant: commands.nix arguments not defined in cli.py "
            f"top-level argparse: {', '.join(extra_in_nix)}"
        )
    if missing_handler:
        errors.append(
            "ncc-assistant: argparse subcommands without main() dispatcher "
            f"branch (if command == …): {', '.join(missing_handler)}"
        )

    # longHelp should mention each verb at least once (soft → hard for gaps)
    help_blob = text.lower()
    help_missing = sorted(
        a for a in argparse_cmds if f"ncc ai {a}" not in help_blob and a not in ("gui",)
    )
    # gui is default `ncc ai` — OK if not listed as `ncc ai gui` only once
    if "ncc ai gui" not in help_blob and "gui" in argparse_cmds:
        # still ok if "Graphical window" documented
        pass
    if help_missing:
        warns.append(
            "ncc-assistant longHelp may omit verbs (document in longHelp): "
            + ", ".join(help_missing)
        )

    if not errors:
        print(
            f"  OK: ncc-assistant argparse↔arguments synced "
            f"({len(argparse_cmds)} verbs)"
        )

# --- Generic: any manager with arguments= must not list empty/dupe junk ---
for cmd_path in sorted(nixos.rglob("commands.nix")):
    text = cmd_path.read_text(encoding="utf-8", errors="replace")
    rel = cmd_path.relative_to(nixos)
    for m in re.finditer(r"arguments\s*=\s*\[(.*?)\]\s*;", text, re.DOTALL):
        block = m.group(1)
        args = re.findall(r'"([^"]+)"', block)
        if not args:
            continue
        # Flag args are OK (-n etc.) — skip strings starting with -
        verbs = [a for a in args if not a.startswith("-")]
        # duplicates
        seen: set[str] = set()
        dups = []
        for a in verbs:
            if a in seen:
                dups.append(a)
            seen.add(a)
        if dups:
            errors.append(f"{rel}: duplicate arguments verbs: {', '.join(sorted(set(dups)))}")

if warns:
    for w in warns:
        print(f"  WARN: {w}")

if errors:
    for e in errors:
        print(f"  ERROR: {e}")
    print(
        "\n  Fix: add the verb to commands.nix arguments = [ … ] "
        "(and longHelp), and ensure cli.py main() handles it."
    )
    sys.exit(1)

print("OK — CLI manager arguments ↔ argparse / dispatcher green.")
sys.exit(0)
PY
RC=$?

if [[ "$RC" -ne 0 ]]; then
  fail "CLI manager arguments out of sync with argparse/dispatcher"
else
  pass "CLI manager args synced (ncc-assistant + arguments hygiene)"
fi

echo "=== validate-cli-manager-args summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — fix commands.nix arguments / cli.py wiring before system-update."
  exit 1
fi
echo "OK — CLI manager args gate green."
exit 0
