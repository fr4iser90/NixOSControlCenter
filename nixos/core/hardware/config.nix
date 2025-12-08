{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.hardware or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/hardware/user-configs/hardware-config.nix";
  symlinkPath = "/etc/nixos/configs/hardware-config.nix";
  configHelpers = config.core.system-manager.api.configHelpers;
  defaultConfig = ''
{
  hardware = {
    cpu = "intel";
    gpu = "amd";
    ram = {
      sizeGB = null;
    };
  };
}
'';
in
{
  config = {
    system.activationScripts.hardware-config-symlink =
      configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
  };
}

