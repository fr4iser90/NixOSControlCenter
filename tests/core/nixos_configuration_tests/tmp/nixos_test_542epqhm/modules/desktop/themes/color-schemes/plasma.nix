# modules/desktop/themes/color-schemes/plasma.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../../env.nix;
in {
  config = lib.mkIf env.darkMode {
    services.displayManager.sddm.theme = "breeze-dark";
    environment.variables = {
      KDE_GLOBAL_THEME = "Breeze Dark";
      # Additional KDE-specific theme variables
      KDEGLOBALS = "breeze-dark";
      KDE_SESSION_VERSION = "5";
    };
    
    environment.systemPackages = with pkgs; [
      breeze-icons
      breeze-gtk
      breeze-qt5
    ];
  };
}