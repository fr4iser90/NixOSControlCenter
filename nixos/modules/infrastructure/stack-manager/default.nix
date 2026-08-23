{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  isSwarmMode = (cfg.swarm or null) != null;

  virtUsers = filterAttrs
    (name: user: user.role == "virtualization")
    (getModuleConfig "user");
  hasVirtUsers = (length (attrNames virtUsers)) > 0;

  stacksUtils = import ./lib/stacks-utils.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
in {
  # Unconditional imports — never gate imports on cfg/config (_module.args / infinite recursion).
  # Handlers wrap packages in mkIf; config seeding is module-manager's job (not legacy configHelpers).
  imports = [
    ./options.nix
    ./commands.nix
    ./handlers/stacks-fetch.nix
    ./handlers/stacks-create.nix
    ./handlers/stacks-catalog.nix
    ./handlers/stacks-operator.nix
  ];

  environment.systemPackages = mkIf (cfg.enable or false) (
    stacksUtils.config.environment.systemPackages or []
  );

  warnings = optional ((cfg.enable or false) && isSwarmMode && !hasVirtUsers) ''
    stack-manager: swarm is set but no user with role "virtualization" exists.
    Swarm mode requires a virtualization user (e.g. docker@).
  '';
}
