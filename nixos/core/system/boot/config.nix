{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
in
{
  config = lib.mkIf ((systemConfig.system.boot.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "boot";
      defaultConfig = ''
{
  # Boot System Configuration
  # This is a core module that dynamically loads bootloader implementations
  # No user configuration needed - bootloader is selected via systemConfig.system.bootloader

  boot = {
    # Bootloader selection is handled centrally in system-config.nix
    # Available options: "systemd-boot", "grub", "refind"
  };
}
'';
    });
  # Boot module implementation is handled in default.nix
}
