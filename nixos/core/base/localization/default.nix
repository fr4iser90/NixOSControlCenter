{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.localization or {};
in {
  imports = [
    ./options.nix
    ./config.nix
  ];
}

