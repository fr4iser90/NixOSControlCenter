# modules/desktop/themes/color-schemes/gnome.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../../env.nix;
in {
  config = lib.mkIf env.darkMode {
    services.xserver.desktopManager.gnome = {
      extraGSettings = [
        {
          key = "org.gnome.desktop.interface";
          value = {
            color-scheme = "prefer-dark";
            gtk-theme = "Adwaita-dark";
          };
        }
      ];
    };
    
    environment.systemPackages = with pkgs; [
      gnome.adwaita-icon-theme
      gtk-engine-murrine
    ];
  };
}