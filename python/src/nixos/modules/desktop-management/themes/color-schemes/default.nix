# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, ... }:
let
  # Import des spezifischen Theme Moduls
  themeModule = ./schemes + "/${systemConfig.desktop}.nix";
in {
  imports = [ themeModule ];

  assertions = [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${systemConfig.desktop} not found";
  }];
}