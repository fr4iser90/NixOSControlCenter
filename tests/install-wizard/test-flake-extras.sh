#!/usr/bin/env bash
# Smoke: host-only flake inputs are detected vs NCC flake (no /etc/nixos access).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NCC_FLAKE="$ROOT/nixos/flake.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Host with short nixpkgs + home-manager (NCC aliases) plus real extras
cat >"$TMP/host-flake.nix" <<'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    jetpack.url = "github:fr4iser90/jetpack-nixos/master";
    jetpack.inputs.nixpkgs.follows = "nixpkgs";
    my-private.url = "git+ssh://git@example.com/org/private.git";
  };
  outputs = { self, nixpkgs, home-manager, jetpack, my-private, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        jetpack.nixosModules.default
      ];
    };
  };
}
EOF

# Inline same alias rules as flake-extras.nix (keep in sync)
python3 - "$TMP/host-flake.nix" "$NCC_FLAKE" <<'PY'
import re, sys
from pathlib import Path

SKIP = {"url", "flake", "type", "follows", "inputs"}
ALIASES = {
    "nixpkgs": {"nixpkgs-stable", "nixpkgs-unstable"},
    "home-manager": {"home-manager-stable", "home-manager-unstable"},
}

def extract(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    lines = []
    for line in text.splitlines():
        if "#" in line:
            line = line[: line.index("#")]
        lines.append(line)
    text = "\n".join(lines)
    m = re.search(r"\binputs\s*=\s*\{", text)
    if not m:
        return []
    i = m.end() - 1
    depth = 0
    end = None
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                end = j
                break
    body = text[i + 1 : end]
    names = []
    for m in re.finditer(r"(?m)^[ \t]*([A-Za-z_][A-Za-z0-9_-]*)\s*(?:\.url\s*=|\s*=)", body):
        n = m.group(1)
        if n not in SKIP and n not in names:
            names.append(n)
    return names

def host_only(live, incoming):
    in_set = set(incoming)
    out = []
    for n in live:
        if n in in_set:
            continue
        aliases = ALIASES.get(n)
        if aliases and (in_set & aliases):
            continue
        out.append(n)
    return sorted(set(out))

live = extract(sys.argv[1])
incoming = extract(sys.argv[2])
extras = host_only(live, incoming)
print("host inputs:", " ".join(live))
print("ncc inputs: ", " ".join(sorted(incoming)))
print("extras:     ", " ".join(extras) if extras else "(none)")

assert "jetpack" in extras, extras
assert "my-private" in extras, extras
assert "nixpkgs" not in extras, "nixpkgs must be skipped (NCC aliases)"
assert "home-manager" not in extras, "home-manager must be skipped (NCC aliases)"
print("OK: aliases skipped; real extras kept")
PY
