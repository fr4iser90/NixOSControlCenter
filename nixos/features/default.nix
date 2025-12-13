{ config, lib, pkgs, systemConfig, ... }:

let
  # Use centralized discovery from module-manager
  moduleManagerLib = import ../core/management/module-manager/lib/default.nix {
    inherit config lib pkgs systemConfig;
  };

  # Get all discovered modules
  allDiscoveredModules = moduleManagerLib.allModules;

  # Read module configuration
  moduleManagerConfigPath = "/etc/nixos/configs/module-manager-config.nix";
  moduleManagerConfig = if builtins.pathExists moduleManagerConfigPath
    then import moduleManagerConfigPath
    else import ../core/management/module-manager/module-manager-config.nix;

  # Check if module is enabled
  getModuleEnabled = module:
    let
      configSection = moduleManagerConfig.${module.category} or {};
      moduleConfig = configSection.${module.name} or {};
    in
      moduleConfig.enable or (module.category == "core");

  # Special handling for homelab-manager auto-activation
  cfg = systemConfig.features or {};
  homelabSwarm = systemConfig.homelab.swarm or null;
  isSwarmManager = homelabSwarm != null && (homelabSwarm.role or null) == "manager";
  isSingleServer = homelabSwarm == null;
  shouldActivateHomelabManager = (cfg.homelab-manager.enable or false)
    || (isSingleServer && (systemConfig.homelab or null) != null)
    || isSwarmManager;

  # Override homelab-manager enable status
  getModuleEnabledWithHomelab = module:
    if module.category == "features" && module.name == "homelab-manager"
    then shouldActivateHomelabManager
    else getModuleEnabled module;

  # Filter to enabled modules and create import paths
  enabledModules = builtins.filter getModuleEnabledWithHomelab allDiscoveredModules;
  moduleImports = map (module:
    if module.category == "core"
    then ../core + "/${module.name}"
    else ./. + "/${module.name}"
  ) enabledModules;
in {
  imports = moduleImports;

  config = {
    # CLI formatter and command-center are Core modules, no enable needed

    # Nix experimental features
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}  
in {
  imports = featureModules;
  
  config = {
    # CLI formatter and command-center are Core modules, no enable needed
    
    # Nix experimental features
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
