#!/usr/bin/env bash
# Check flake exports: nixosModules.ncc-runtime, feature modules, lib.mkNccSpecialArgs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

echo "=== NCC: flake nixosModules exports ==="

if ! command -v nix >/dev/null 2>&1; then
  echo "SKIP: nix not on PATH"
  exit 0
fi

names="$(
  nix eval --impure --json "path:${NIXOS}#nixosModules" \
    --apply 'm: builtins.attrNames m' 2>/dev/null \
    || nix eval --json "${NIXOS}#nixosModules" --apply 'm: builtins.attrNames m'
)"

need=(ncc-runtime default ncc-assistant lock-manager)
for n in "${need[@]}"; do
  if echo "$names" | grep -q "\"$n\""; then
    echo "  OK nixosModules.$n"
  else
    echo "  FAIL missing nixosModules.$n (got: $names)"
    FAIL=1
  fi
done

# lib.mkNccSpecialArgs must exist and return getModuleConfig
has_fn="$(
  nix eval --impure --json "path:${NIXOS}#lib" \
    --apply 'l: builtins.hasAttr "mkNccSpecialArgs" l' 2>/dev/null \
    || nix eval --json "${NIXOS}#lib" --apply 'l: builtins.hasAttr "mkNccSpecialArgs" l'
)"
if [[ "$has_fn" == "true" ]]; then
  echo "  OK lib.mkNccSpecialArgs"
else
  echo "  FAIL lib.mkNccSpecialArgs missing"
  FAIL=1
fi

# Smoke: specialArgs helper builds and exposes getModuleConfig for ncc-assistant enable leaf
ok_cfg="$(
  nix eval --impure --expr "
    let
      flake = builtins.getFlake \"path:${NIXOS}\";
      pkgs = import flake.inputs.nixpkgs-stable { system = \"x86_64-linux\"; };
      args = flake.lib.mkNccSpecialArgs {
        inherit (pkgs) lib;
        systemConfig = {
          modules.specialized.ncc-assistant.enable = true;
        };
      };
      cfg = args.getModuleConfig \"ncc-assistant\";
    in cfg.enable
  " 2>/dev/null || echo false
)"
if [[ "$ok_cfg" == "true" ]]; then
  echo "  OK mkNccSpecialArgs getModuleConfig ncc-assistant.enable"
else
  echo "  FAIL mkNccSpecialArgs smoke (enable=$ok_cfg)"
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAIL flake-exports"
  exit 1
fi
echo "OK flake-exports"
exit 0
