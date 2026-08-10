{ config, lib, pkgs, getModuleConfig, getCurrentModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Install / migrate wizard (PySide6 GUI + fzf; nix-shell bootstrap)";
    category = "management";
    subcategory = "install";
    stability = "stable";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    ./commands.nix
  ];
}
