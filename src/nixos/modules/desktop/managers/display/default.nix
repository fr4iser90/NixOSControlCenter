# modules/desktop/managers/display/default.nix
{ config, lib, pkgs, ... }:
let
  env = import ../../../../env.nix;
  
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
    autoLogin = {
      enable = env.autoLogin;
      user = env.mainUser;
    };
  };

  assertions = [
    {
      assertion = builtins.hasAttr env.displayManager validDisplayManagers;
      message = "Invalid display manager: ${env.displayManager}";
    }
  ];
}