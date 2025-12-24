{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "localization";
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "System localization and internationalization";
    category = "base";
    subcategory = "localization";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    ./config.nix
  ];
}

