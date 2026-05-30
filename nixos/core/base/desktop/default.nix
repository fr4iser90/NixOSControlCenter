{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

let
  # Discovery: Modulname aus Dateisystem ableiten
  moduleName = baseNameOf ./. ;  # ← desktop aus core/base/desktop/
  cfg = getModuleConfig moduleName;
  desktopEnabled = cfg.enable or true;
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
    (import ./config.nix { inherit lib getModuleConfig moduleName; })
    (import ./commands.nix { inherit config lib pkgs getModuleApi getModuleConfig moduleName getCurrentModuleMetadata; })
  ] ++ lib.optionals desktopEnabled [
    ./components/display-managers
    ./components/display-servers
    ./components/environments
    ./components/themes
  ];
}