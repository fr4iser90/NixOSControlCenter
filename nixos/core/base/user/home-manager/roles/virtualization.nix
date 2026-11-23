{ config, lib, pkgs, user, systemConfig, getModuleConfig, ... }:

let
  userCfg = getModuleConfig "user";
  userConfig = userCfg.${user};
  locCfg = getModuleConfig "localization";
  # Nested layout: email/domain under localization (legacy: systemConfig.domain/email).
  hostDomain = locCfg.domain or systemConfig.domain or "";
  hostEmail = locCfg.email or systemConfig.email or "";
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };

in
{
  imports = [ shellInit ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    sessionVariables = {
      DOMAIN = hostDomain;
      EMAIL = hostEmail;
    };
  };
}
