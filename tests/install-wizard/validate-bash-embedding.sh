#!/usr/bin/env bash
# Catch bash ${VAR} / ${VAR:-} in Nix '' strings (classic nix-build footgun).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"

FAIL=0

python3 - "$NIXOS" <<'PY' || FAIL=1
import re, sys, os
root = sys.argv[1]

VAR = r"[A-Za-z_][A-Za-z0-9_]*"

bash_op = re.compile(
    r"\$\{"
    r"(?:"
    r"[A-Za-z_][A-Za-z0-9_]*:-|"
    r"#|"
    r"![A-Za-z_]|"
    r"selected_[A-Za-z0-9_]+|"
    r"NCC_[A-Za-z0-9_]+|"
    r"TMPDIR:-"
    r")"
)

# Self-assign with suffix — gc_freed="${gc_freed}G"
bash_suffix = re.compile(rf"=\s*\"\$\{{({VAR})\}}(?=[A-Za-z0-9_])")

# ui.messages "…${var}…" — Nix eval eats ${var}; use $var in message text
ui_bash = re.compile(rf"messages\.\w+\s+\"[^\"]*\$\{{({VAR})\}}")


def check_line(path, i, line, issues):
    if "''${" in line:
        return
    if bash_op.search(line):
        issues.append((path, i, line.strip()[:100], "bash ${var:-} / ${#…}"))
        return
    if bash_suffix.search(line):
        issues.append((path, i, line.strip()[:100], "bash ''${var}… (suffix after })"))
        return
    if ui_bash.search(line):
        issues.append((path, i, line.strip()[:100], "ui message: use $var not ${var}"))


issues = []
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith(".nix"):
            continue
        path = os.path.join(dirpath, name)
        text = open(path, encoding="utf-8", errors="replace").read()
        if "builtins.fromJSON" in text and "writeText" in text and "pkgs.writeText" in text:
            if text.count("pkgs.writeText") == text.count("builtins.fromJSON"):
                continue
        for m in re.finditer(
            r"pkgs\.(?:writeText|writeShellScriptBin)\s+[^'']*''(.*?)''",
            text,
            re.DOTALL,
        ):
            body = m.group(1)
            for i, line in enumerate(body.splitlines(), 1):
                check_line(path, i, line, issues)

if issues:
    print("FAIL: bash-style ${ in Nix '' strings (use ''${ for shell, or $var in ui.messages):")
    for path, ln, content, hint in issues[:40]:
        print(f"  {path}:{ln}: [{hint}] {content}")
    if len(issues) > 40:
        print(f"  … and {len(issues) - 40} more")
    sys.exit(1)
print(f"OK: checked inline '' bash blocks ({len(issues)} issues)")
PY

if [[ "$FAIL" -ne 0 ]]; then exit 1; fi
