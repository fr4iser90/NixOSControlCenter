{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;
  cfg = getModuleConfig moduleName;
in {
  imports = if cfg.enable or false then [
    ./options.nix
    ./containers
    ./schemas
    ./llm
  ] else [];

  # Removed: Redundant enable setting (already defined in options.nix)
}
