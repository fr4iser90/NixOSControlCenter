{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

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
    ./commands.nix
    ./config.nix
    ./handlers/ssh-client-handler.nix
    ./scripts/ssh-client-manager.nix
    ./lib/ssh-key-utils.nix
    ./lib/ssh-server-utils.nix
  ];

  # Removed: Redundant enable setting (already defined in options.nix)
  
  environment.systemPackages = mkIf (cfg.enable or false) [
    pkgs.fzf
    pkgs.openssh
  ];
}
