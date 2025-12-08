{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.packages or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/packages/user-configs/packages-config.nix";
  symlinkPath = "/etc/nixos/configs/packages-config.nix";
  configHelpers = config.core.system-manager.api.configHelpers;
  defaultConfig = ''
{
  # Package modules directly
  packageModules = [];
}
'';
in
{
  config = {
    system.activationScripts.packages-config-symlink =
      configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
  };
}
