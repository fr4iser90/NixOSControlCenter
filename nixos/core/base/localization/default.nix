{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "localization";
in {
  _module.metadata = {
    role = "core";
    name = "localization";
    description = "System localization and internationalization";
    category = "base";
    subcategory = "localization";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    ./config.nix
  ];
}

