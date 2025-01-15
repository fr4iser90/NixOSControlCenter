# homelab-manager/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./homelab-fetch.nix
    ./homelab-create.nix
#    ./homelab-update.nix
#    ./homelab-delete.nix
#    ./homelab-list.nix
  ];
}