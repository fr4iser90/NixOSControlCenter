# src/nixos/modules/homemanager/roles/admin.nix
{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.core.base.user.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };
in {
  imports = [ shellInit ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  home.sessionVariables = {
    SUDO_EDITOR = "vim";
  };
}