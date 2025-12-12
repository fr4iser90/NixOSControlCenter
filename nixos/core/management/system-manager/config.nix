{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager or {};
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./system-manager-config.nix;
in
{
  config = lib.mkMerge [
    # Always import component commands (they'll be conditionally enabled)
    # (import ./components/config-migration/commands.nix)

    # Create config on activation (always runs)
    # Uses new external config system
    (configHelpers.createModuleConfig {
      moduleName = "system-manager";
      defaultConfig = defaultConfig;
    })
  ];
}
