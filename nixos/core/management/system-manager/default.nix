{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.management.system-manager or {};
  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  apiValue = configHelpers // backupHelpers;
in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Handlers
    ./handlers/system-update.nix
    ./handlers/channel-manager.nix
  ];

  config = {
    # System-Manager ist Core - immer geladen
    # Version-Info und Deprecation-Warnungen sind immer verfügbar
    # Updates sind optional (enableUpdates = false by default)
    
    core.management.system-manager.api = apiValue;
  };
}
