{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

# Import utility functions from lib/
let
  libUtils = import ../lib/default.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

in {
  # 🎯 HANDLER: Only Business Logic - NO Commands!
  # Commands belong in commands.nix per MODULE_TEMPLATE!
  # All utility functions are now in lib/default.nix

  # Re-export functions for commands.nix
  inherit (libUtils)
    allModules
    getModuleStatus
    updateModuleConfig
    formatModuleList
    enableModule
    disableModule;
}
