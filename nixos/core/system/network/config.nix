{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./network-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.network.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "network";
      defaultConfig = defaultConfig;
    });
  # Network module implementation is handled in default.nix
}
