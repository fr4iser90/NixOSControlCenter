{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.hardware or {};
in {
  imports = [
    ./options.nix
    ./config.nix
    ./gpu
    ./cpu
    ./memory
  ];
}
