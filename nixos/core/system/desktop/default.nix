{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.desktop or {};
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or false) then [ 
    ./display-managers
    ./display-servers
    ./environments
    ./themes
    ./config.nix
  ] else [
    ./config.nix
  ]);
}