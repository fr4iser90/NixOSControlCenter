# modules/desktop/themes/color-schemes/plasma.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  config = lib.mkIf systemConfig.darkMode {
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