{ config, lib, pkgs, systemConfig, ... }:

let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./hardware-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.hardware.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "hardware";
      defaultConfig = defaultConfig;
    });
}

