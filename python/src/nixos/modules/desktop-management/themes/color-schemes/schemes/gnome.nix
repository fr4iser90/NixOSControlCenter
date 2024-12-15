{ config, lib, pkgs, ... }:

let
  env = import ../../../../env.nix;
in {
  config = lib.mkIf (env.desktop == "gnome") {
    services.xserver = {
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };

    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = if env.darkMode then "prefer-dark" else "default";
          gtk-theme = if env.darkMode then "Adwaita-dark" else "Adwaita";
        };
      };
    }];
    
    # Korrigierte Theme-Pakete
    environment.systemPackages = with pkgs; [
      adwaita-icon-theme  
      gtk-engine-murrine
    ];
  };
}