{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./update.nix
    ./feature-manager.nix
    ./homelab-utils.nix
    ./channel-manager.nix
    # config-migration.nix and config-validator.nix are imported directly in update.nix, not as modules
  ];
}