#!/usr/bin/env bash
# Smoke: host-only flake inputs are detected vs NCC flake (no /etc/nixos access).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NCC_FLAKE="$ROOT/nixos/flake.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/host-flake.nix" <<'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    jetpack.url = "github:fr4iser90/jetpack-nixos/master";
    jetpack.inputs.nixpkgs.follows = "nixpkgs";
    my-private.url = "git+ssh://git@example.com/org/private.git";
  };
  outputs = { self, nixpkgs, jetpack, my-private, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix jetpack.nixosModules.default ];
    };
  };
}
EOF

extract_inputs() {
  python3 - "$1" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
lines = []
for line in text.splitlines():
    if "#" in line:
        line = line[: line.index("#")]
    lines.append(line)
text = "\n".join(lines)
m = re.search(r"\binputs\s*=\s*\{", text)
if not m:
    sys.exit(0)
i = m.end() - 1
depth = 0
end = None
for j in range(i, len(text)):
    c = text[j]
    if c == "{":
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0:
            end = j
            break
if end is None:
    sys.exit(0)
body = text[i + 1 : end]
names = set()
for m in re.finditer(
    r"(?m)^[ \t]*([A-Za-z_][A-Za-z0-9_-]*)\s*(?:\.url\s*=|\s*=)",
    body,
):
    name = m.group(1)
    if name in ("url", "flake", "type", "follows", "inputs"):
        continue
    names.add(name)
for n in sorted(names):
    print(n)
PY
}

mapfile -t HOST < <(extract_inputs "$TMP/host-flake.nix")
mapfile -t NCC < <(extract_inputs "$NCC_FLAKE")

declare -A NCC_SET=()
for n in "${NCC[@]}"; do NCC_SET["$n"]=1; done

EXTRAS=()
for n in "${HOST[@]}"; do
  [[ -z "${NCC_SET[$n]:-}" ]] && EXTRAS+=("$n")
done

echo "host inputs: ${HOST[*]}"
echo "ncc inputs:  ${NCC[*]}"
echo "extras:      ${EXTRAS[*]}"

printf '%s\n' "${EXTRAS[@]}" | grep -qx jetpack
printf '%s\n' "${EXTRAS[@]}" | grep -qx my-private
# nixpkgs may or may not be extra depending on NCC naming (nixpkgs-stable)
echo "OK: generic host-only input detection"
