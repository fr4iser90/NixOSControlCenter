#!/usr/bin/env bash
# Smoke: host-only flake inputs are detected vs NCC flake (no /etc/nixos access).
# Generic only — no vendor/Jetson names. Jetson/jetpack: tests/hardware/jetson/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NCC_FLAKE="$ROOT/nixos/flake.nix"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Host with short nixpkgs + home-manager (NCC aliases) plus generic real extras
cat >"$TMP/host-flake.nix" <<'EOF'
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    acme-hw.url = "github:example/acme-hw/main";
    acme-hw.inputs.nixpkgs.follows = "nixpkgs";
    my-private.url = "git+ssh://git@example.com/org/private.git";
  };
  outputs = { self, nixpkgs, home-manager, acme-hw, my-private, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        acme-hw.nixosModules.default
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
DROP = {"ncc"}

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
        if n in DROP:
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

assert "acme-hw" in extras, extras
assert "my-private" in extras, extras
assert "nixpkgs" not in extras, "nixpkgs must be skipped (NCC aliases)"
assert "home-manager" not in extras, "home-manager must be skipped (NCC aliases)"
assert "ncc" not in extras, "product self-name ncc must be dropped"
assert "ncc" not in incoming, "stock flake must not ship an ncc input"
print("OK: aliases skipped; real extras kept; no ncc input/dummy")
PY

# Stray self-import on live must not become a host-only extra vs stock flake
cat >"$TMP/host-with-ncc.nix" <<'EOF'
{
  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    ncc.url = "github:example/NixOSControlCenter?dir=nixos";
  };
  outputs = { self, nixpkgs-stable, ncc, ... }: { };
}
EOF
python3 - "$TMP/host-with-ncc.nix" "$NCC_FLAKE" <<'PY'
import re, sys
from pathlib import Path
SKIP = {"url", "flake", "type", "follows", "inputs"}
ALIASES = {
    "nixpkgs": {"nixpkgs-stable", "nixpkgs-unstable"},
    "home-manager": {"home-manager-stable", "home-manager-unstable"},
}
DROP = {"ncc"}
def extract(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    lines = [line[: line.index("#")] if "#" in line else line for line in text.splitlines()]
    text = "\n".join(lines)
    m = re.search(r"\binputs\s*=\s*\{", text)
    i = m.end() - 1
    depth = 0
    end = None
    for j in range(i, len(text)):
        if text[j] == "{": depth += 1
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
        if n in in_set or n in DROP: continue
        aliases = ALIASES.get(n)
        if aliases and (in_set & aliases): continue
        out.append(n)
    return sorted(set(out))
extras = host_only(extract(sys.argv[1]), extract(sys.argv[2]))
assert extras == [], extras
print("OK: stray live inputs.ncc is dropped (not a host-only extra)")
PY

# Comments mentioning ncc.nixosModules must not become module refs
python3 - <<'PY'
import importlib.util, tempfile, textwrap
from pathlib import Path

# Load helpers by reading the nix writeText is hard; inline strip + regex like flake-extras
import re
DROP = {"ncc"}
def strip_line_comments(text: str) -> str:
    return "\n".join(line[: line.index("#")] if "#" in line else line for line in text.splitlines())
def extract_nixos_module_refs(text: str):
    text = strip_line_comments(text)
    refs = []
    for m in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_-]*)\.nixosModules(?:\.default)?\b", text):
        n = m.group(1)
        if n in DROP: continue
        if n not in refs: refs.append(n)
    return refs
sample = textwrap.dedent('''
  # modules = [ inputs.ncc.nixosModules.ncc-assistant ];
  modules = [ home-manager.nixosModules.home-manager ];
''')
refs = extract_nixos_module_refs(sample)
assert refs == ["home-manager"], refs
print("OK: comment ncc.nixosModules ignored; home-manager kept")
PY
