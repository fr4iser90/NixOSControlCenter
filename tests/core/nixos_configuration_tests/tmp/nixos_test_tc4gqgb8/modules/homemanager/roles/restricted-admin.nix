{ config, lib, pkgs, user, ... }:

let
  env = import ../../../env.nix;
  shellInitFile = ../shellInit/bashInit.nix;
  shellInitModule = import (builtins.toString shellInitFile) { inherit pkgs lib; };
in {
  imports = [ shellInitModule ];

  home = {
    stateVersion = "24.05";
    username = user;
    homeDirectory = lib.mkForce "/home/${user}";
  };
  
  # Eingeschränkte Admin-Berechtigungen
  home.sessionVariables = {
    SUDO_ASKPASS = "${pkgs.x11}/bin/ssh-askpass";  # Immer Passwort-Prompt
  };
  # Eingeschränkte Admin-Gruppen
  users.users.${user}.extraGroups = [
    "wheel"
    "networkmanager"
    "video"
    "audio"
  ];
}