{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };

in
{
  imports = [ shellInit ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    sessionVariables = {
      DOMAIN = systemConfig.domain;
      EMAIL = systemConfig.email;
    };
  };
}
