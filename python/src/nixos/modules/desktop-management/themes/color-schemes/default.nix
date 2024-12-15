# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, ... }:
let
  env = import ../../../../env.nix;
  
  # Import des spezifischen Theme Moduls
  themeModule = ./schemes + "/${env.desktop}.nix";
in {
  imports = [ themeModule ];

  assertions = [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${env.desktop} not found";
  }];
}