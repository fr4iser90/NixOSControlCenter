{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "system-manager";
  # Use the template file as default config
  defaultConfig = builtins.readFile ./system-manager-config.nix;

  # Parse the default config to extract modules
  parsedConfig = import ./system-manager-config.nix;
  enabledModules = parsedConfig.modules or {};

  # Import module discovery to get moduleConfig
  discovery = import ../module-manager/lib/discovery.nix { inherit lib; };
  discoveredModules = discovery.discoverAllModules;
  automaticModuleConfigs = lib.listToAttrs (
    map (module: {
      name = module.name;
      value = {
        inherit (module) configPath enablePath apiPath;
        name = module.name;
        category = module.category;
        path = module.path;
      };
    }) discoveredModules
  );
in
{
  config = lib.mkMerge [
    # Always import component commands (they'll be conditionally enabled)
    # (import ./components/config-migration/commands.nix)

  ];
}
