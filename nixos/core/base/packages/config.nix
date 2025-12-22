{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "packages";
in {
  # Packages configuration is handled in default.nix (core module, always enabled)
  # This file creates symlinks and handles config file management
  system.activationScripts.createPackagesConfig = ''
    mkdir -p /etc/nixos/configs
    ln -sf ${./packages-config.nix} /etc/nixos/configs/packages-config.nix
  '';
}