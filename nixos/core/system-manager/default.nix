{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.core.system-manager;
  # API definition - always available
  configHelpers = import ./lib/config-helpers.nix { inherit pkgs lib; };
  apiValue = {
    configHelpers = configHelpers;
  };
in {
  imports = [
    ./options.nix
    ./commands.nix
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