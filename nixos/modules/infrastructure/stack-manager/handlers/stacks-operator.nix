# Fleet tags + DNS env packages (NixOS module — config only).
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cfg = getModuleConfig "stack-manager";
  isSwarmMode = (cfg.swarm or null) != null;

  virtUsers = lib.filterAttrs
    (name: user: user.role == "virtualization")
    (getModuleConfig "user");
  adminUsers = lib.filterAttrs
    (name: user: user.role == "admin")
    (getModuleConfig "user");
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  hasAdminUsers = (lib.length (lib.attrNames adminUsers)) > 0;

  operatorScripts = import ./stacks-operator-scripts.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi;
  };
in {
  config = lib.mkIf ((cfg.enable or false) && (hasVirtUsers || hasAdminUsers)) {
    environment.systemPackages = [
      operatorScripts.stacksFleetTags
      operatorScripts.stacksDnsEnv
    ];
  };
}
