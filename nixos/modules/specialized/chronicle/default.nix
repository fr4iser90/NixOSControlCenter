{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;  # "chronicle"
  cfg = getModuleConfig moduleName;
in
{
  _module.args = {
    chronicleCfg = cfg;
    moduleName = moduleName;
  };

  imports = [
    ./options.nix
    (import ./commands.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; moduleName = moduleName; })
  ] ++ (if (cfg.enable or false) then [
    ./config.nix
    ./systemd.nix
    ./privacy
    ./compliance
    ./security
    ./ai
    ./collaboration
    ./visualization
    ./plugins
    ./enterprise
    ./mobile
    ./platforms
    ./integrations
  ] else []);
}
