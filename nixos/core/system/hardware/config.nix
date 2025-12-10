{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.hardware or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/system/hardware/hardware-config.nix";
  symlinkPath = "/etc/nixos/configs/hardware-config.nix";
  configHelpers = import ../../management/system-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
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

