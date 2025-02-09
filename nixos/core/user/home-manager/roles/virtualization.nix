{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };

  # get UID and GID 
  userUID = builtins.getEnv "UID" or null;
  userGID = builtins.getEnv "GID" or null;
in
{
  imports = [ shellInit ];

  home = {
    stateVersion = systemConfig.system.version;
    username = user;
    homeDirectory = "/home/${user}";
    sessionVariables = {
      DOMAIN = systemConfig.domain;
      EMAIL = systemConfig.email;
      UID = userUID;
      GID = userGID;
    };
  };
}
