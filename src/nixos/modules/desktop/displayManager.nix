#/etc/modules/desktop/displayManager.nix

{ config, pkgs, ... }:
let
  env = import ../../env.nix;

  sessionMap = {
    gnome = "gnome";
    plasma = "plasma";
    plasmawayland = "plasmawayland";
    xfce = "xfce";
    i3 = "i3";
  };

  defaultSession = if builtins.hasAttr env.session sessionMap
                   then builtins.getAttr env.session sessionMap
                   else "default";
in
{
  # X11-spezifische Display-Manager-Einstellungen
  services.xserver.displayManager = {
    lightdm.enable = env.displayManager == "lightdm";
    gdm.enable = env.displayManager == "gdm";
  };

  # Allgemeine Display-Manager-Einstellungen
  services.displayManager = {
    sddm = {
      enable = env.displayManager == "sddm";
      wayland.enable = true;
    };
    defaultSession = defaultSession;
    autoLogin = {
      enable = env.autoLogin;
      user = env.mainUser;
    };
  };
}
