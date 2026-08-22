#!/usr/bin/env bash
# Catch bash ${VAR:-} / ${#…} in Nix '' strings (classic nix-build footgun).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"

FAIL=0

python3 - "$NIXOS" <<'PY' || FAIL=1
import re, sys, os
root = sys.argv[1]
# Bash-only patterns inside ${…} (not Nix toString/pkgs/lib/cfg)
bash_pat = re.compile(
    r"\$\{"
    r"(?:"
    r"[A-Za-z_][A-Za-z0-9_]*:-|"           # ${VAR:-default}
    r"#|"                                   # ${#arr}
    r"![A-Za-z_]|"                          # ${!var}
    r"selected_[A-Za-z0-9_]+|"              # install wizard arrays
    r"NCC_[A-Za-z0-9_]+|"                   # NCC env vars
    r"TMPDIR:-"
    r")"
)

issues = []
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith(".nix"):
            continue
        path = os.path.join(dirpath, name)
        text = open(path, encoding="utf-8", errors="replace").read()
        if "builtins.fromJSON" in text and "writeText" in text and "pkgs.writeText" in text:
            # Installer JSON blobs: skip whole file if only fromJSON writeText
            if text.count("pkgs.writeText") == text.count("builtins.fromJSON"):
                continue
        for m in re.finditer(
            r"pkgs\.(?:writeText|writeShellScriptBin)\s+[^'']*''(.*?)''",
            text,
            re.DOTALL,
        ):
            body = m.group(1)
            for i, line in enumerate(body.splitlines(), 1):
                if "''${" in line:
                    continue
                if bash_pat.search(line):
                    issues.append((path, i, line.strip()[:100]))

if issues:
    print("FAIL: bash-style ${ in Nix '' strings (use ''${ for shell):")
    for path, ln, content in issues[:30]:
        print(f"  {path}:{ln}: {content}")
    if len(issues) > 30:
        print(f"  … and {len(issues) - 30} more")
    sys.exit(1)
print(f"OK: checked inline '' bash blocks ({len(issues)} issues)")
PY

if [[ "$FAIL" -ne 0 ]]; then exit 1; fi
