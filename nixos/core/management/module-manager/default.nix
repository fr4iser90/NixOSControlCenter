{ config, lib, pkgs, systemConfig, ... }:

{
  # Module-manager is always active (Core module, no enable option)
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix  # ✅ Commands in commands.nix per MODULE_TEMPLATE
  ];
}

