# Installer facade — same body as runtime SSOT (system-manager/lib/config-facade.nix).
# Do not duplicate bash here; regenerate by evaluating this file.
{ pkgs, getModuleMetadata, ... }:
let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeText "config-facade.sh" ''
#!/usr/bin/env bash
# Installer copy of config facade (SSOT: system-manager/lib/config-facade.nix → store)
${facade.facadeText}

# Resolve serialize helper for installer / live tree when SERIALIZE_NIX unset
if [[ -z "''${SERIALIZE_NIX:-}" ]]; then
  for candidate in \
    "''${NIXOS_CONFIG_DIR:-}/core/management/system-manager/lib/serialize-json-to-nix.nix" \
    "''${NIXOS_ROOT:-/etc/nixos}/core/management/system-manager/lib/serialize-json-to-nix.nix" \
    "/etc/nixos/core/management/system-manager/lib/serialize-json-to-nix.nix"; do
    if [[ -f "$candidate" ]]; then SERIALIZE_NIX="$candidate"; break; fi
  done
fi
''
