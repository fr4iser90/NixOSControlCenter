{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./packages-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.packages.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "packages";
      defaultConfig = defaultConfig;
    });
}
