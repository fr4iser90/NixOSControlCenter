#/etc/nixos/modules/desktop/display/default.nix
{ config, lib, pkgs, ... }:
let
  env = import ../../../../env.nix;
  
  # Finde den Auto-Login Benutzer (wenn vorhanden)
  autoLoginUser = lib.findFirst 
    (user: env.users.${user}.autoLogin or false) 
    null 
    (builtins.attrNames env.users);
  
  # Gültige Display Manager als Set definieren
  validDisplayManagers = {
    sddm = true;
    gdm = true;
    lightdm = true;
  };

  # Import specific display manager configuration
  managerConfig = import ./${env.displayManager}.nix { 
    inherit config pkgs env; 
  };

  # Session handling
  sessionMap = {
    gnome = "gnome";
    plasma = "plasma";
    plasmax11 = "plasmax11";  # Neuer Name für X11   Alle noch angleichen für einfache verwendung
    plasma6 = "plasma";  # Für Wayland in Plasma 6
    plasmawayland = "plasmawayland";
    xfce = "xfce";
    i3 = "i3";
  };

  defaultSession = if builtins.hasAttr env.session sessionMap
                   then sessionMap.${env.session}
                   else "default";
in {
  imports = [ managerConfig ];

  # Common display manager settings
  services.displayManager = {
    defaultSession = defaultSession;
    autoLogin = lib.mkIf (autoLoginUser != null) {
      enable = true;
      user = autoLoginUser;
    };
  };

  assertions = [
    {
      assertion = builtins.hasAttr env.displayManager validDisplayManagers;
      message = "Invalid display manager: ${env.displayManager}";
    }
    {
      assertion = lib.count (user: env.users.${user}.autoLogin or false) 
                          (builtins.attrNames env.users) <= 1;
      message = "Only one user can be configured for auto-login";
    }
  ];
}