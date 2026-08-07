# Shared helpers for hardware prebuild checks (layout-aware)
# Bash comes from config-facade.nix → nix store (no .sh under nixos/)
{ pkgs, lib, systemConfig, getModuleConfig }:

let
  layout = (getModuleConfig "system-manager").layout or "monolith";
  facade = import ./config-facade.nix { inherit pkgs; };
in
{
  inherit layout;

  preamble = facade.sourcePreamble {
    nixosRoot = "/etc/nixos";
    inherit layout;
  };

  readHardware = ''
    ncc_read_module_config "core/base/hardware"
  '';

  writeHardware = ''
    ncc_write_module_config "core/base/hardware" "$1"
  '';
}
