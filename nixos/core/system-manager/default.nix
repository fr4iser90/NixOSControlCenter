{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.core.system-manager;
  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; backupHelpers = backupHelpers; };
  apiValue = {
    configHelpers = configHelpers;
    backupHelpers = backupHelpers;
  };
in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Handlers
    ./handlers/system-update.nix
    ./handlers/feature-manager.nix
    ./handlers/channel-manager.nix
    ./handlers/desktop-manager.nix
    # Note: config-validator.nix and config-migration.nix are not modules,
    # they're imported in commands.nix to get their scripts
  ];

  config = {
    # System-Manager ist Core - immer geladen
    # Version-Info und Deprecation-Warnungen sind immer verfügbar
    # Updates sind optional (enableUpdates = false by default)
    
    core.system-manager.api = apiValue;
  };
}