{ lib, pkgs, ... }:

let
  moduleVersion = "1.0";
  
  # Import helpers
  backupHelpersValue = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # Pass backupHelpers to configHelpers so it can use it
  configHelpersValue = import ./lib/config-helpers.nix { inherit pkgs lib; backupHelpers = backupHelpersValue; };
  
  # API definition - always available (like cli-formatter.api)
  apiValue = {
    configHelpers = configHelpersValue;
    backupHelpers = backupHelpersValue;
  };
in
{
  options.core.system-manager = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "System manager module version";
    };
    # Version-Info ist immer verfügbar (Core)
    enableVersionChecker = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Immer an
      description = "Enable version checking (always available in Core)";
    };
    
    # Deprecation-Warnungen sind immer verfügbar (Core)
    enableDeprecationWarnings = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Immer an
      description = "Enable deprecation warnings (e.g., NixOS version deprecation)";
    };
    
    # Update-Funktionalität ist optional
    enableUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;  # Optional
      description = "Enable automatic updates (optional)";
    };
    
    # Auto-build nach Updates
    auto-build = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically build after updates";
    };
    
    # API for other modules
    api = lib.mkOption {
      type = lib.types.attrs;
      default = apiValue;
      description = "System manager API for other modules (config helpers, etc.)";
    };
  };
}

