# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, ... }:
let
  # Import des spezifischen Theme Moduls
  themeModule = ./schemes + "/${systemConfig.desktop.environment}.nix";
in {
  imports = lib.mkIf systemConfig.desktop.enable [ themeModule ];

  assertions = lib.mkIf systemConfig.desktop.enable [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${systemConfig.desktop.environment} not found";
  }];
}