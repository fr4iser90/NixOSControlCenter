# Always-on operable baseline for every NCC machine (desktop, server, homelab).
# Not a packageModules set — imported unconditionally by the packages module.
#
# Goal: machine is inspectable and maintainable (fetch, edit, observe, JSON for NCC tools).
# Dev/IDE stacks belong in sets (e.g. system-dev, web-dev). Desktop apps → base/desktop.nix.

{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    coreutils
    curl
    wget
    nano
    htop
    jq
    unzip
  ];
}
