{ config, lib, pkgs, getCurrentModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Shared Qt/PySide6 GUI engine for NixOS Control Center";
    category = "management";
    subcategory = "gui-engine";
    stability = "stable";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    ./config.nix
  ];
}
