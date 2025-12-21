{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = config.systemConfig.core.system.packages;
in {
  # Packages configuration is handled in default.nix (core module, always enabled)
  # This file creates symlinks and handles config file management
  system.activationScripts.createPackagesConfig = ''
    mkdir -p /etc/nixos/configs
    ln -sf ${./packages-config.nix} /etc/nixos/configs/packages-config.nix
  '';
}