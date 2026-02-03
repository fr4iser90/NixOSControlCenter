{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;

  cfg = getModuleConfig moduleName;
  
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or false) then [
    ./commands.nix
    ./config.nix
  ] else []);

  # Removed: Redundant enable setting (already defined in options.nix)
}
