{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager.submodules.system-checks or {};
in {
  # imports must be at top level
  imports = [
    ./options.nix  # Always import options first
    ./commands.nix # Command registration (always needed)
  ] ++ (if (cfg.enable or true) then [
    ./config.nix  # Implementation logic goes here
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ]);
}