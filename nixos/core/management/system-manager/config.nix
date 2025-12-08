{ config, lib, pkgs, systemConfig, ... }:
let
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/management/system-manager/user-configs/system-manager-config.nix";
  symlinkPath = "/etc/nixos/configs/system-manager-config.nix";
  configHelpers = config.core.management.system-manager.api.configHelpers;
  defaultConfig = ''
{
  features = {
    system-logger = true;
    system-checks = true;
    system-config-manager = false;
    system-discovery = false;
    ssh-client-manager = false;
    ssh-server-manager = false;
    bootentry-manager = false;
    homelab-manager = false;
    vm-manager = false;
    ai-workspace = false;
  };
}
'';
in
{
  config = {
    system.activationScripts.system-manager-config-symlink =
      configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
  };
}

