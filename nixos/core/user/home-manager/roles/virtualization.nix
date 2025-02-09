{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };

  # get UID and GID 
  userUID = let env = builtins.getEnv "UID"; in if env == "" then null else env;
  userGID = let env = builtins.getEnv "GID"; in if env == "" then null else env;
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
