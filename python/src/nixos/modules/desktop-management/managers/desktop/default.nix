# modules/desktop/managers/desktop/default.nix
{ config, lib, pkgs, ... }:
let
  env = import ../../../../env.nix;
  
  # Import des spezifischen Desktop Manager Moduls
  desktopManagerModule = ./managers + "/${env.desktop}.nix";
in {
  imports = [ desktopManagerModule ];

  assertions = [{
    assertion = builtins.pathExists desktopManagerModule;
    message = "Desktop environment ${env.desktop} not found";
  }];
}