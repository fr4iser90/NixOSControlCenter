{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Discovery: Modulname aus Dateisystem ableiten
  moduleName = baseNameOf ./. ;  # ← desktop aus core/base/desktop/
  cfg = getModuleConfig moduleName;

  # DEBUG: cfg Wert anzeigen
  debugCfg = cfg;  # Für spätere Verwendung
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Desktop environment configuration and management";
    category = "base";
    subcategory = "desktop";
    version = "1.0.0";
  };


  imports = if cfg.enable or false then [
    ./options.nix
    ./components/display-managers
    ./components/display-servers
    ./components/environments
    ./components/themes
    (import ./config.nix { inherit config lib systemConfig getModuleConfig moduleName; })
  ] else [];
}