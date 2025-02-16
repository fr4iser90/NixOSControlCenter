{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./update.nix
    ./feature-manager.nix
    ./homelab-utils.nix
  ];
}