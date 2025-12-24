{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.command-center or {};
in {
  _module.metadata = {
    role = "core";
    name = "cli-registry";
    description = "CLI command registration and management";
    category = "management";
    subcategory = "system-manager.submodules.cli-registry";
    stability = "stable";
    version = "1.0.0";
  };

  # imports must be at top level
  imports = [
    ./options.nix      # Always import options first
  ] ++ (if (cfg.enable or true) then [
    ./config.nix      # Implementation logic goes here
  ] else [
    ./config.nix      # Import even if disabled (for symlink management)
  ]);
}