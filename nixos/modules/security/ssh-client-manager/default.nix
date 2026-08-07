{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
in {
  _module.args = {
    sshClientCfg = cfg;
  };

  # Unconditional imports — never gate on cfg.enable (that + _module.args = infinite recursion).
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
  ];

  environment.systemPackages = mkIf (cfg.enable or false) [
    pkgs.fzf
    pkgs.openssh
  ];
}
