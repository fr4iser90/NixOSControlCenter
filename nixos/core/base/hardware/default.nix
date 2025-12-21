{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "hardware";
in {
  _module.metadata = {
    role = "internal";
    name = "hardware";
    description = "Hardware detection and configuration";
    category = "base";
    subcategory = "hardware";
    stability = "stable";
  };

  imports = [
    ./options.nix
    ./config.nix
    ./gpu
    ./cpu
    ./memory
  ];
}
