{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./boot-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.boot.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "boot";
      defaultConfig = defaultConfig;
    });
  # Boot module implementation is handled in default.nix
}
