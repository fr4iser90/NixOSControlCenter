{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "hardware";
in {
  _module.metadata = {
    role = "core";
    name = "hardware";
    description = "Hardware detection and configuration";
    category = "base";
    subcategory = "hardware";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    ./config.nix
    ./gpu
    ./cpu
    ./memory
  ];
}
