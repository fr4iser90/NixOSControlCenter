{ config, lib, pkgs, user, systemConfig, ... }:

let
  shellInitFile = ../shellInit/bashInit.nix;  # Gäste bekommen bash
  shellInitModule = import (builtins.toString shellInitFile) { inherit pkgs lib; };
in {
  imports = [ shellInitModule ];

  home = {
    username = user;
    homeDirectory = lib.mkForce "/home/${user}";
  };

  # Eingeschränkte Berechtigungen
  home.sessionVariables = {
    PATH = lib.mkForce "$HOME/.local/bin:/usr/bin:/bin";  # Eingeschränkter PATH
    # DOCKER_HOST = "unix:///run/user/$userid/docker.sock";
  };
}