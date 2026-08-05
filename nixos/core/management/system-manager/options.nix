{ lib, pkgs, getCurrentModuleMetadata, ... }:

let
  # ALTE getCurrentModuleMetadata verwenden (repariert)
  metadata = getCurrentModuleMetadata ./.;  # ← Jetzt korrekt!
  configPath = metadata.configPath;

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

    # Release-Notify / Deprecation-Warnungen (Core)
    enableDeprecationWarnings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NixOS release warnings (gates channel-manager notify timer when enableNotify is true)";
    };

    # Legacy flag — update tools (update-channels / system update) are always registered
    enableUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Legacy option (unused). Channel/update tools are always available via ncc system update-channels / check-release";
    };

    # System Checks Component (converted from submodule)
    enableChecks = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Standardmäßig aktiviert
      description = "Enable system health checks component";
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

    # Channel / release awareness
    components.channelManager = {
      enableNotify = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Periodic systemd timer that notifies when a newer NixOS stable release is available (also requires enableDeprecationWarnings)";
      };
      checkInterval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd OnCalendar expression for ncc-release-check (e.g. weekly, daily, *-*-01 10:00:00)";
      };
    };
  };

  # API is now defined generically above via configPath
}
