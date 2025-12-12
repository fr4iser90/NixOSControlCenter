{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./user-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.user.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "user";
      defaultConfig = defaultConfig;
    });
  # User module implementation is handled in default.nix
}
