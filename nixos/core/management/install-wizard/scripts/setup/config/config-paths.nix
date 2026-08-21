# Installer paths — same body as runtime SSOT (system-manager/lib/config-facade.nix).
{ pkgs, getModuleMetadata, ... }:
let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeText "config-paths.sh" ''
#!/usr/bin/env bash
# Installer copy (SSOT: system-manager/lib/config-facade.nix)
${facade.pathsText}
''
