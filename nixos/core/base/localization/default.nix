{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "localization";
in {
  _module.metadata = {
    role = "internal";
    name = "localization";
    description = "System localization and internationalization";
    category = "base";
    subcategory = "localization";
    stability = "stable";
  };

  imports = [
    ./options.nix
    ./config.nix
  ];
}

