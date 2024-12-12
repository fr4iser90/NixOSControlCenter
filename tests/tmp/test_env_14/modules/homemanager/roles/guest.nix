{ config, lib, pkgs, user, ... }:

let
  env = import ../../../env.nix;
  shellInitFile = ../shellInit/bashInit.nix;  # Gäste bekommen bash
  shellInitModule = import (builtins.toString shellInitFile) { inherit pkgs lib; };
in {
  imports = [ shellInitModule ];

  home = {
    stateVersion = "24.05";
    username = user;
    homeDirectory = lib.mkForce "/home/${user}";
  };

  # Eingeschränkte Berechtigungen
  home.sessionVariables = {
    PATH = lib.mkForce "$HOME/.local/bin:/usr/bin:/bin";  # Eingeschränkter PATH
  };

}