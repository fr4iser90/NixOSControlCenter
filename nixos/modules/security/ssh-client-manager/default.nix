{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;
  cfg = getModuleConfig moduleName;
in {
  _module.args = {
    sshClientCfg = cfg;
  };

  imports = [
    ./options.nix
  ] ++ optionals (cfg.enable or false) [
    ./config.nix
    (import ./commands.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; moduleName = moduleName; })
  ];

  # Removed: Redundant enable setting (already defined in options.nix)
  
  environment.systemPackages = mkIf (cfg.enable or false) [
    pkgs.fzf
    pkgs.openssh
  ];
}
