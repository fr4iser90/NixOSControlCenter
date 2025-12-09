{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.command-center or {};
in {
  # imports must be at top level
  imports = [
    ./options.nix      # Always import options first
  ] ++ (if (cfg.enable or true) then [
    ./config.nix      # Implementation logic goes here
  ] else [
    ./config.nix      # Import even if disabled (for symlink management)
  ]);
}