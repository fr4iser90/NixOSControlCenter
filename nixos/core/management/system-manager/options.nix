{ lib, pkgs, ... }:

let
  moduleName = baseNameOf ./. ;        # "system-manager"
  parentName = baseNameOf ../.;        # "management"
  grandparentName = baseNameOf ../../.; # "core"

  configPath = "${grandparentName}.${parentName}.${moduleName}";

  # Import helpers
  backupHelpersValue = import ./lib/backup-helpers.nix { inherit pkgs lib; };

  # API definition - always available (like cli-formatter.api)
  apiValue = backupHelpersValue;
in
{
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
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

    # API for other modules - always available
    api = lib.mkOption {
      type = lib.types.attrs;
      default = apiValue;
      internal = true;
      description = "System manager API for other modules (config helpers, backup helpers, etc.)";
    };

    # Config Migration Component
    components.configMigration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;  # Optional component, rarely needed after v0→v1 migration
        description = "Enable config migration tools (schema-based migration from v0 to v1)";
      };
    };
  };

  # API is now defined generically above via configPath
}
