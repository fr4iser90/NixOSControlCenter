{ config, lib, pkgs, user, systemConfig, getModuleConfig, ... }:

let
  userCfg = getModuleConfig "user";
  userConfig = userCfg.${user};
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
