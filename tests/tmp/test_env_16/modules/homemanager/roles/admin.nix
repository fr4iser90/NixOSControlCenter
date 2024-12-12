# src/nixos/modules/homemanager/roles/admin.nix
{ config, lib, pkgs, user, ... }:

let
  env = import ../../../env.nix;
  userConfig = env.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };
in {
  imports = [ shellInit ];

  home = {
    stateVersion = "24.05";
    username = user;
    homeDirectory = "/home/${user}";
  };

  home.sessionVariables = {
    SUDO_EDITOR = "vim";
  };
}