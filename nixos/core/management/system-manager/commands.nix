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

  backupHelpersForMigration = config.${configPath}.api.backupHelpers or (import ./lib/backup-helpers.nix { inherit pkgs lib; });
  configMigration = import ./components/config-migration/default.nix { inherit config pkgs lib systemConfig getModuleApi configPath; backupHelpers = backupHelpersForMigration; };
  configValidator = import ./validators/config-validator.nix { inherit pkgs lib; };
in {
  config = lib.mkMerge [
    {
      environment.systemPackages =
        [ checkVersions.checkVersionsScript
          updateModules.updateModulesScript
          configMigration.migration.migrateSystemConfig
          configValidator.validateSystemConfig
          enableDesktopScript
          updateDesktopConfig
        ] ++ lib.optionals (cfg.components.configMigration.enable or false) [
          configMigration.check.configCheck
          configMigration.validator.validateSystemConfig
        ];
    }
    (cliRegistry.registerCommandsFor "system-manager" [
      # System Domain Manager (TUI launcher)
      {
        name = "system";
        domain = "system";
        type = "manager";
        description = "System lifecycle management";
        category = "system";
        script = "${prebuildCheckScript}/bin/build";
        shortHelp = "system - System management (TUI)";
        longHelp = ''
          System management provides commands for system lifecycle.
          
          Usage:
            ncc system                    - System TUI
            ncc system build              - Build configuration
            ncc system update             - Update from repository
            ncc system check-versions     - Check module versions
            ncc system update-modules     - Update modules
            ncc system migrate-config     - Migrate configuration
            ncc system validate-config    - Validate configuration
            ncc system report             - Generate system report
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
        description = "Migrate system-config.nix from monolithic to modular structure";
        category = "system";
        script = "${configMigration.migration.migrateSystemConfig}/bin/ncc-migrate-config";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "migrate-config - Migrate system-config.nix";
        longHelp = ''
          Migrates the system configuration from monolithic to modular structure:

          Migration Process:
          - Creates backup of current system-config.nix
          - Extracts config sections to separate files in configs/:
            * modules → configs/module-manager-config.nix
            * desktop → configs/desktop-config.nix
            * hardware → configs/hardware-config.nix
            * network → configs/network-config.nix
            * logging → configs/logging-config.nix
          - Keeps only critical values in system-config.nix
          - Preserves all existing configuration values

          This migration is safe and creates backups automatically.
        '';
      }
      # Subcommand: validate-config
      {
        name = "validate-config";
        domain = "system";
        parent = "system";
        description = "Validate system-config.nix structure and configuration";
        category = "system";
        script = "${configValidator.validateSystemConfig}/bin/ncc-validate-config";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "validate-config - Validate system-config.nix";
        longHelp = ''
          Validates the system configuration structure and checks:

          Validation Checks:
          - Nix syntax validity
          - Required critical values presence:
            * systemType, hostName, system.channel
            * system.bootloader, allowUnfree, users, timeZone
          - Modular structure check (configs/ directory)
          - Detects old monolithic structure

          Exit codes:
          - 0: All checks passed
          - 1: Errors or warnings found
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
            --auto-build         Automatically build and switch after update
            --verbose, -v        Show verbose output during update
            --force-migration    Force migration even if versions match
            --force-update       Force update even if versions match
            --cleanup            Remove modules that no longer exist in source

          Examples:
            # Interactive update (default)
            ncc system-update

            # Fully automated local update with rebuild
            ncc system-update --yes --local --auto-build

            # Local update without rebuild
            ncc system-update -y --local

            # Remote update with auto-confirm
            ncc system-update --auto --remote --auto-build

            # Channel update
            ncc system-update --yes --channels

          Note: This command requires root privileges. The script will check for root and prompt for sudo if needed.
        '';
        requiresSudo = true;
      }
    ])
  ];
}