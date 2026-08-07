#!/usr/bin/env bash
# Fail if modules bypass flake specialArgs via (import ./commands.nix { … })
# or use getModuleMetadata without declaring it in the header.
# getModuleNixConfig is banned — see validate-no-hardcoded-paths.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
NIXOS="${ROOT}/nixos"
FAIL=0

echo "=== NCC: validate module path-imports + helper args ==="

# 1) Ban explicit function-call imports of commands/schedules (skips specialArgs)
while IFS= read -r -d '' file; do
  if rg -n -e '\(import\s+\./(commands|schedules)\.nix\s*\{' "$file" >/tmp/ncc-import-hits.txt 2>/dev/null; then
    echo "FAIL [use path import ./commands.nix — not (import ./commands.nix {…})]: $file"
    cat /tmp/ncc-import-hits.txt
    echo
    FAIL=1
  fi
done < <(find "$NIXOS/core" "$NIXOS/modules" -type f -name 'default.nix' -print0)

# 2+3) Helper used in body must appear in top-level function args
check_helper_in_header() {
  local helper="$1"
  local file
  while IFS= read -r -d '' file; do
    case "$file" in
      */doc/*|*/plans/*|*/knowledge/*|*/module-config.nix|*/module-manager/lib/*) continue ;;
      */api.nix) continue ;; # APIs document helpers; callers pass them
    esac
    if ! rg -q "\b${helper}\b" "$file"; then
      continue
    fi
    # Must be real usage (call or inherit), not only a comment
    if ! rg -q "^[^#]*\b${helper}\b" "$file"; then
      continue
    fi
    missing="$(HELPER="$helper" python3 - "$file" <<'PY'
import os, re, sys
helper = os.environ["HELPER"]
path = sys.argv[1]
body = open(path).read()
# real use: call, inherit, or binding — not only in a string/comment
if not re.search(rf'(?<![\w]){re.escape(helper)}(?![\w])', body):
    sys.exit(0)
# strip line comments for header check
text = body.splitlines()
i = 0
while i < len(text) and (not text[i].strip() or text[i].lstrip().startswith("#")):
    i += 1
if i >= len(text) or not text[i].strip().startswith("{"):
    sys.exit(0)
buf = []
for j in range(i, min(i + 50, len(text))):
    buf.append(text[j])
    if "}:" in text[j]:
        break
header = "\n".join(buf)
if not re.search(r"\}\s*:", header):
    sys.exit(0)
hc = re.sub(r"#.*", "", header)
# package.nix / plain lets that take the helper as attrset arg
if helper not in hc:
    # allow files that only mention helper inside nested lambdas after first }:
    # still flag — nested still needs outer pass-through for modules
    print(path)
PY
)"
    if [[ -n "${missing:-}" ]]; then
      echo "FAIL [uses ${helper} but missing from function args]: $missing"
      FAIL=1
    fi
  done < <(find "$NIXOS/core" "$NIXOS/modules" -type f -name '*.nix' -print0)
}

check_helper_in_header getModuleMetadata

# 4) flake.nix specialArgs must export the two public helpers
if ! rg -q 'getModuleConfig' "$NIXOS/flake.nix"; then
  echo "FAIL: flake.nix missing getModuleConfig in specialArgs wiring"
  FAIL=1
fi
if ! rg -q 'getModuleApi' "$NIXOS/flake.nix"; then
  echo "FAIL: flake.nix missing getModuleApi in specialArgs wiring"
  FAIL=1
fi
if rg -q 'getModuleNixConfig' "$NIXOS/flake.nix"; then
  echo "FAIL: flake.nix still exports banned getModuleNixConfig"
  FAIL=1
fi
if ! rg -q 'specialArgs' "$NIXOS/flake.nix"; then
  echo "FAIL: flake.nix missing specialArgs"
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "=== FAILED ==="
  echo "Prefer: imports = [ ./commands.nix ];  # injects flake specialArgs"
  echo "Never:  (import ./commands.nix { inherit … })  # drops helpers"
  echo "Helpers: getModuleConfig + getModuleApi only"
  exit 1
fi

echo "=== OK: module imports + helper args ==="
exit 0
