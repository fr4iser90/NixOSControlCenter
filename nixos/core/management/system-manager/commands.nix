{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;        # "system-manager"
  parentName = baseNameOf ../.;        # "management"
  grandparentName = baseNameOf ../../.; # "core"
  configPath = "${grandparentName}.${parentName}.${moduleName}";

  # Core modules use config.* (chicken-egg problem with systemConfig)
  cfg = config.${configPath};

  # For components: provide configPath for consistent access
  # This allows components to use systemConfig.${configPath} instead of hardcoded paths
  versionChecker = import ./handlers/module-version-check.nix { inherit config lib; };
  checkVersions = import ./scripts/check-versions.nix { inherit config lib pkgs getModuleApi; };
  updateModules = import ./scripts/update-modules.nix { inherit config lib pkgs getModuleApi; };
  
  # Scripts are imported below (template-compliant)

  # Import scripts (template-compliant)
  enableDesktopScript = import ./scripts/enable-desktop.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  updateDesktopConfig = import ./scripts/update-desktop-config.nix { inherit config lib pkgs systemConfig; };
  
  # Import config migration and validation
  # CLI APIs - elegant registration
  formatter = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  systemTui = (import ./ui/tui/domain.nix { inherit config lib pkgs getModuleApi; }).tuiScript;

  # System Checks Scripts (converted from component)
  postbuildCheckScript = import ./components/system-checks/scripts/postbuild-checks.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  prebuildCheckScript = import ./components/system-checks/scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

  # System Logging Scripts (converted from component)
  systemReportScript = import ./components/system-logging/scripts/system-report.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

  # System Update Handler (converted from component)
  systemUpdateHandler = import ./handlers/system-update.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi cliRegistry;
  };
  systemUpdateMainScript = systemUpdateHandler.systemUpdateMainScript;
  # Handler returns real NixOS options (activationScripts, extra systemPackages) merged
  # with `// { inherit systemUpdateMainScript; }`. Previously only the script path was
  # used for CLI registration — the rest was dropped, so no activation scripts ever ran.
  systemUpdateNixosConfig = lib.removeAttrs systemUpdateHandler [ "systemUpdateMainScript" ];

  backupHelpersForMigration = config.${configPath}.api.backupHelpers or (import ./lib/backup-helpers.nix { inherit pkgs lib; });
  configMigration = import ./components/config-migration/default.nix { inherit config pkgs lib systemConfig getModuleApi configPath; backupHelpers = backupHelpersForMigration; };
  configValidator = import ./validators/config-validator.nix { inherit pkgs lib; };
in {
  config = lib.mkMerge [
    systemUpdateNixosConfig
    {
      environment.systemPackages =
        [ checkVersions.checkVersionsScript
          updateModules.updateModulesScript
          configMigration.migration.migrateSystemConfig
          configMigration.configLayout
          configValidator.validateSystemConfig
          enableDesktopScript
          updateDesktopConfig
        ] ++ lib.optionals (cfg.components.configMigration.enable or false) [
          configMigration.check.configCheck
          configMigration.validator.validateSystemConfig
        ];
    }
    (cliRegistry.registerCommandsFor "system-manager" [
      # Domain TUI launcher
      {
        name = "system";
        domain = "system";
        description = "System management TUI";
        category = "system";
        script = "${systemTui}/bin/ncc-system-tui";
        arguments = [];
        type = "manager";
        shortHelp = "system - System Manager (TUI)";
        longHelp = ''
          Interactive system manager TUI.
        '';
      }
      # Subcommand: check-versions
      {
        name = "check-versions";
        domain = "system";
        parent = "system";
        description = "Check module versions for Core and Features and update status";
        category = "system";
        script = "${checkVersions.checkVersionsScript}/bin/ncc-check-module-versions";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "check-versions - Check module versions";
          longHelp = ''
            Check the version status of all modules (Core and Features):
            - Installed: Current version on the system
            - Available: Latest version in code (Git)
            - Stable: Stable version (if different from available)
            - Status: Update availability and migration support
            
            Shows both Core modules (systemConfig.*) and optional modules (modules.*).
          '';
        }
      # Subcommand: update-modules
      {
        name = "update-modules";
        domain = "system";
        parent = "system";
        description = "Update modules with automatic migration support";
        category = "system";
        script = "${updateModules.updateModulesScript}/bin/ncc-update-modules";
        arguments = [
          "--module"
          "--dry-run"
          "--auto"
        ];
        dependencies = [ "nix" ];
        shortHelp = "update-modules - Update modules";
        longHelp = ''
          Update features to their latest versions:
          - --module=name: Update specific module only
          - --dry-run: Show what would be updated without making changes
          - --auto: Skip confirmation prompts
          
          Features with automatic migration will be updated automatically.
          Features without migration will show a warning.
        '';
      }
      # Subcommand: migrate-config
      {
        name = "migrate-config";
        domain = "system";
        parent = "system";
        description = "Migrate configuration schema version (v0→v2)";
        category = "system";
        script = "${configMigration.migration.migrateSystemConfig}/bin/ncc-migrate-config";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "migrate-config - Migrate config schema version (v0→v2)";
        longHelp = ''
          Migrates system configuration across schema versions (v0 → v1 → v2).

          v2 layouts (after migration):
            monolith  /etc/nixos/systemConfig.nix   (default)
            split     /etc/nixos/systemConfig/**/config.nix

          For layout switches use:
            ncc system config-layout convert --to monolith|split

          Creates backups under /var/backup/nixos/ automatically.
        '';
      }
      # Subcommand: migrate (Kurzform für v0→v1 Migration)
      {
        name = "migrate";
        domain = "system";
        parent = "system";
        description = "Migrate configuration schema version (alias for migrate-config)";
        category = "system";
        script = "${configMigration.migration.migrateSystemConfig}/bin/ncc-migrate-config";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "migrate - Alias for migrate-config (schema versions)";
        longHelp = ''
          Shortcut for ncc system migrate-config.
          Migrates schema versions (v0→v1→v2). For monolith↔split use config-layout.
        '';
      }
      # Subcommand: config-layout (v2 dual layout)
      {
        name = "config-layout";
        domain = "system";
        parent = "system";
        description = "Detect or convert systemConfig layout (monolith ↔ split)";
        category = "system";
        script = "${configMigration.configLayout}/bin/ncc-config-layout";
        arguments = [ "detect" "convert" "--to" "--force" ];
        dependencies = [ "nix" "jq" ];
        requiresSudo = true;
        shortHelp = "config-layout - Detect/convert monolith ↔ split";
        longHelp = ''
          Dual-layout management for systemConfig (schema v2):

            ncc system config-layout detect
            ncc system config-layout convert --to monolith
            ncc system config-layout convert --to split [--force]

          Layouts:
            monolith  /etc/nixos/systemConfig.nix (nested attrset, default)
            split     /etc/nixos/systemConfig/**/config.nix

          Convert backs up under /var/backup/nixos/, then keeps only the target layout.
          Also available as: ncc-config-layout
        '';
      }
      # Subcommand: validate-config
      {
        name = "validate-config";
        domain = "system";
        parent = "system";
        description = "Validate systemConfig (monolith or split)";
        category = "system";
        script = "${configValidator.validateSystemConfig}/bin/ncc-validate-config";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "validate-config - Validate systemConfig (monolith|split)";
        longHelp = ''
          Validates the active layout SSOT (via config-facade):

            monolith  /etc/nixos/systemConfig.nix
            split     /etc/nixos/systemConfig/**/config.nix

          Checks:
          - Config present and Nix syntax
          - Detected schema version vs current
          - Required fields (e.g. configVersion)
          - No leftover legacy /etc/nixos/configs/

          Exit codes:
          - 0: All checks passed
          - 1: Errors or warnings found

          Tip: ncc system config-layout detect
        '';
      }
      ])
    # System Checks Commands (enabled by default in core, but configurable)
    (lib.mkIf (cfg.enableChecks or true)
      (cliRegistry.registerCommandsFor "system-checks" [
        # Subcommand: build
        {
          name = "build";
          domain = "system";
          parent = "system";
          description = "Build and activate NixOS configuration with safety checks";
          category = "system";
          script = "${prebuildCheckScript}/bin/build";
          arguments = ["switch" "boot" "test" "build"];
          dependencies = [ "nix" ];
          shortHelp = "build - Build with preflight checks";
          longHelp = ''
            Build and activate NixOS configuration with preflight safety checks

            Commands:
              switch    Build and activate configuration
              boot      Build boot configuration
              test      Test configuration
              build     Build only

            Options:
              --force   Skip safety checks
          '';
        }
      ]))
    # System Logging Commands (converted from component - always enabled in core)
    (cliRegistry.registerCommandsFor "system-logging" [
      # Subcommand: report
      {
        name = "report";
        domain = "system";
        parent = "system";
        script = "${systemReportScript.script}/bin/ncc-log-system-report";
        category = "system";
        description = "Generate system report with configured collectors";
        shortHelp = "report - Generate system report";
        longHelp = ''
          Generate a comprehensive system report using configured collectors.

          Examples:
            ncc system report                    # Generate default report
            ncc system report --level debug      # Generate debug report
            ncc system report --list-collectors  # List available collectors
            ncc system report --enable profile   # Enable specific collector
        '';
      }
    ])
    # System Update Commands (converted from component - always enabled in core)
    (cliRegistry.registerCommandsFor "system-update" [
      # Subcommand: update
      {
        name = "update";
        domain = "system";
        parent = "system";
        script = "${systemUpdateMainScript}/bin/ncc-system-update-main";
        category = "system";
        description = "Update NixOS configuration from repository";
        shortHelp = "update - Update NixOS configuration";
        longHelp = ''
          Update NixOS configuration from repository with automatic migration support.

          Options:
            --yes, -y, --auto    Skip all confirmation prompts (dangerous warning, build prompt)
            --local              Automatically select local directory update (option 2)
            --remote             Automatically select remote repository update (option 1)
            --channels           Automatically select channel update (option 3)
            --with-channels      After config update, auto-include channel bump if newer pin exists
            --auto-build         Automatically build and switch after update
            --verbose, -v        Show verbose output during update
            --force-migration    Force migration even if versions match
            --force-update       Force update even if versions match
            --cleanup            Remove modules that no longer exist in source

          Examples:
            # Interactive update (default)
            # After config copy: prompts y/n if a newer nixos-YY.MM pin is available
            ncc system-update

            # Fully automated local update with rebuild
            ncc system-update --yes --local --auto-build

            # Local update + channel bump (when available) + rebuild
            ncc system-update --yes --local --with-channels --auto-build

            # Local update without rebuild
            ncc system-update -y --local

            # Remote update with auto-confirm
            ncc system-update --auto --remote --auto-build

            # Channel update only
            ncc system-update --yes --channels

          Note: This command requires root privileges. The script will check for root and prompt for sudo if needed.
        '';
        requiresSudo = true;
      }
    ])
  ];
}