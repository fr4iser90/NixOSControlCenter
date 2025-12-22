# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  # Import des spezifischen Theme Moduls
  desktopCfg = getModuleConfig "desktop";
  themeModule = ./schemes + "/${desktopCfg.environment}.nix";
in {
  imports = lib.optionals (desktopCfg.enable or false) [
    themeModule
  ];

  assertions = lib.optionals (desktopCfg.enable or false) [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${desktopCfg.environment} not found";
  }];
}