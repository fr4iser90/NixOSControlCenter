# src/nixos/modules/homemanager/roles/admin.nix
{ config, lib, pkgs, user, systemConfig, getModuleConfig, ... }:

let
  userCfg = getModuleConfig "user";
  userConfig = userCfg.${user};
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