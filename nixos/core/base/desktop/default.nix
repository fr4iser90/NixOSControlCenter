{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

let
  # Discovery: Modulname aus Dateisystem ableiten
  moduleName = baseNameOf ./. ;  # ← desktop aus core/base/desktop/
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Desktop environment configuration and management";
    category = "base";
    subcategory = "desktop";
    version = "1.0.0";
  };


  imports = [
    ./options.nix
    ./components/display-managers
    ./components/display-servers
    ./components/environments
    ./components/themes
    (import ./config.nix { inherit lib systemConfig; })
    (import ./commands.nix { inherit config lib pkgs getModuleApi moduleName systemConfig getCurrentModuleMetadata; })
  ];
}