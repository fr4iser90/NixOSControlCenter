{ config, lib, pkgs, systemConfig, ... }:

let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
in
{
  config = lib.mkIf ((systemConfig.system.hardware.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "hardware";
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
    });
}

