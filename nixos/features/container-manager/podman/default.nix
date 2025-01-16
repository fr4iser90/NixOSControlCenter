{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./container-manager.nix
    ./containers
  ];
  containerManager.enable = true;
}