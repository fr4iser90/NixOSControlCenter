{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.desktop or {};
in {
  imports = [
    ./options.nix
    ./display-managers
    ./display-servers
    ./environments
    ./themes
    ./config.nix
  ];
}