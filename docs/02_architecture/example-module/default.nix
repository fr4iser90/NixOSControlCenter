{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

with lib;

let
  # Calculate module name from directory (generic, not hardcoded)
  moduleName = baseNameOf ./. ;  # "example-module"
  # Get config using getModuleConfig (includes template-config.nix defaults)
  cfg = getModuleConfig moduleName;
  # Get module metadata (for passing to config.nix if needed)
  moduleConfig = getCurrentModuleMetadata ./.;
in {
  # Export moduleName via _module.args for sub-modules that need it
  _module.args = {
    moduleName = moduleName;
  };

  imports = [
    ./options.nix
    # Import commands.nix as function to pass moduleName (prevents infinite recursion)
    (import ./commands.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; moduleName = moduleName; })
  ] ++ lib.optionals (cfg.enable or false) [
    # Import sub-modules only when enabled
    # ./sub-module-1
    # ./sub-module-2
    ./config.nix
  ];
}

