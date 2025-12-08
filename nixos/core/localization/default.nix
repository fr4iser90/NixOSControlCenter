{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.localization or {};
in {
  imports = [
    ./options.nix
    ./config.nix
  ];
}

