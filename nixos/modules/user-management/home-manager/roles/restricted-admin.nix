{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };
in {
  imports = [ shellInit ];

  home = {
    stateVersion = "24.05";
    username = user;
    homeDirectory = lib.mkForce "/home/${user}";
  };
  
  # Eingeschränkte Admin-Berechtigungen
  home.sessionVariables = {
    SUDO_ASKPASS = "${pkgs.ksshaskpass}/bin/ksshaskpass";
  };
}