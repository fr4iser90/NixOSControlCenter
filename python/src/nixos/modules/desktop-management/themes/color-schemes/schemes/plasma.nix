# modules/desktop/themes/color-schemes/plasma.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../../../env.nix;
in {
  config = lib.mkIf env.darkMode {
    services.displayManager.sddm.theme = "breeze";
    environment.variables = {
      KDE_GLOBAL_THEME = "Breeze";
      KDEGLOBALS = "Breeze";
      KDE_SESSION_VERSION = "6"; 
    };
    
    environment.systemPackages = with pkgs.kdePackages; [
      breeze-icons
      breeze-gtk
      breeze
    ];
  };
}