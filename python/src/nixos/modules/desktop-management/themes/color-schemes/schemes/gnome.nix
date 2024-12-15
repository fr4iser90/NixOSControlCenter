{ config, lib, pkgs, systemConfig, ... }:
{
  config = lib.mkIf (systemConfig.desktop == "gnome") {
    services.xserver = {
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };

    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = if systemConfig.darkMode then "prefer-dark" else "default";
          gtk-theme = if systemConfig.darkMode then "Adwaita-dark" else "Adwaita";
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