{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../../management/system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
in
{
  config = lib.mkIf ((systemConfig.system.packages.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "packages";
      defaultConfig = ''
{
  # Package modules directly
  packageModules = [];
}
'';
    });
}
