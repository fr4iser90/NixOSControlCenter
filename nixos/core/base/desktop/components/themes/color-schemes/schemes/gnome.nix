{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  desktopCfg = getModuleConfig "desktop";
  themeCfg = desktopCfg.theme;
  isDark = themeCfg.dark or false;
in {
    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = if isDark then "prefer-dark" else "default";
          gtk-theme = if isDark then "Adwaita-dark" else "Adwaita";
        };
      };
    }];
    
    # Korrigierte Theme-Pakete
    environment.systemPackages = with pkgs; [
      adwaita-icon-theme
      gtk-engine-murrine
    ];
}