{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  isSwarmMode = (cfg.swarm or null) != null;

  virtUsers = filterAttrs
    (name: user: user.role == "virtualization")
    (getModuleConfig "user");
  adminUsers = filterAttrs
    (name: user: user.role == "admin")
    (getModuleConfig "user");

  hasVirtUsers = (length (attrNames virtUsers)) > 0;
  hasAdminUsers = (length (attrNames adminUsers)) > 0;

  hasDockerUser = if isSwarmMode then hasVirtUsers
    else (hasVirtUsers || hasAdminUsers);

  virtUser = if hasVirtUsers then (head (attrNames virtUsers))
    else if (hasAdminUsers && !isSwarmMode) then (head (attrNames adminUsers))
    else null;

  stacksUtils = import ./lib/stacks-utils.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
in {
  _module.args = {
    isSwarmMode = isSwarmMode;
  };

  imports = [
    ./options.nix
    ./commands.nix
  ] ++ optionals (cfg.enable or false) [
    ./config.nix
    ./handlers/stacks-fetch.nix
    ./handlers/stacks-create.nix
  ];

  environment.systemPackages = mkIf (cfg.enable or false) (
    stacksUtils.config.environment.systemPackages or []
  );

  warnings = optional ((cfg.enable or false) && isSwarmMode && !hasVirtUsers) ''
    stack-manager: swarm is set but no user with role "virtualization" exists.
    Swarm mode requires a virtualization user (e.g. docker@).
  '';
}
