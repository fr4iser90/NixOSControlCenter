{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.management.system-manager or {};
  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; backupHelpers = backupHelpers; };
  apiValue = configHelpers // backupHelpers;
in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Handlers
    ./handlers/system-update.nix
    ./handlers/channel-manager.nix
    ./handlers/desktop-manager.nix
    # Note: feature-manager and module-version-check moved to module-management/module-manager
    # Note: config-validator.nix and config-migration.nix are not modules,
    # they're imported in commands.nix to get their scripts
  ];

  config = {
    # System-Manager ist Core - immer geladen
    # Version-Info und Deprecation-Warnungen sind immer verfügbar
    # Updates sind optional (enableUpdates = false by default)
    
    core.management.system-manager.api = apiValue;
  };
}
