# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, ... }:
let
  # Import des spezifischen Theme Moduls
  themeModule = ./schemes + "/${systemConfig.system.desktop.environment}.nix";
in {
  imports = lib.optionals (systemConfig.system.desktop.enable or false) [ 
    themeModule 
  ];

  assertions = lib.optionals (systemConfig.system.desktop.enable or false) [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${systemConfig.system.desktop.environment} not found";
  }];
}