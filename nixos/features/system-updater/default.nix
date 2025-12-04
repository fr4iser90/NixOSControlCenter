{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./update.nix
    ./feature-manager.nix
    ./homelab-utils.nix
    ./channel-manager.nix
    ./config-migration.nix
    ./config-validator.nix
  ];
}