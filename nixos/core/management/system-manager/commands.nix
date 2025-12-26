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
      {
        name = "check-module-versions";
          description = "Check module versions for Core and Features and update status";
          category = "system";
          script = "${checkVersions.checkVersionsScript}/bin/ncc-check-module-versions";
          arguments = [];
          dependencies = [ "nix" ];
          shortHelp = "check-module-versions - Check module versions for Core and Features";
          longHelp = ''
            Check the version status of all modules (Core and Features):
            - Installed: Current version on the system
            - Available: Latest version in code (Git)
            - Stable: Stable version (if different from available)
            - Status: Update availability and migration support
            
            Shows both Core modules (systemConfig.*) and optional modules (modules.*).
          '';
        }
        {
          name = "update-modules";
          description = "Update modules with automatic migration support";
          category = "system";
          script = "${updateModules.updateModulesScript}/bin/ncc-update-modules";
          arguments = [
            "--module"
            "--dry-run"
            "--auto"
          ];
          dependencies = [ "nix" ];
          shortHelp = "update-modules [--module=name] [--dry-run] [--auto] - Update modules";
          longHelp = ''
            Update features to their latest versions:
            - --module=name: Update specific module only
            - --dry-run: Show what would be updated without making changes
            - --auto: Skip confirmation prompts
            
            Features with automatic migration will be updated automatically.
            Features without migration will show a warning.
          '';
        }
        {
          name = "migrate-system-config";
          description = "Migrate system-config.nix from monolithic to modular structure";
          category = "system";
          script = "${configMigration.migration.migrateSystemConfig}/bin/ncc-migrate-config";
          arguments = [];
          dependencies = [ "nix" ];
          shortHelp = "migrate-system-config - Migrate system-config.nix to modular structure";
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
            Run 'ncc validate-system-config' to check if migration is needed.
          '';
        }
        {
          name = "validate-system-config";
          description = "Validate system-config.nix structure and configuration";
          category = "system";
          script = "${configValidator.validateSystemConfig}/bin/ncc-validate-config";
          arguments = [];
          dependencies = [ "nix" ];
          shortHelp = "validate-system-config - Validate system-config.nix structure";
          longHelp = ''
            Validates the system configuration structure and checks:

            Validation Checks:
            - Nix syntax validity
            - Required critical values presence:
              * systemType, hostName, system.channel
              * system.bootloader, allowUnfree, users, timeZone
            - Modular structure check (configs/ directory)
            - Detects old monolithic structure

            Recommendations:
            - If old structure detected, run 'ncc migrate-system-config'
            - Ensures configuration follows best practices
            - Helps identify configuration issues before rebuild

            Exit codes:
            - 0: All checks passed
            - 1: Errors or warnings found
          '';
        }
        {
          name = "desktop-manager";
          description = "Enable or disable desktop environment";
          category = "system";
          script = "${enableDesktopScript}/bin/enable-desktop";
          arguments = [ "enable|disable" ];
          dependencies = [ "nix" ];
          shortHelp = "Enable or disable the desktop environment";
          longHelp = ''
            Allows enabling or disabling the desktop environment:
            - "enable" to activate the desktop
            - "disable" to deactivate the desktop
            Requires sudo privileges and triggers system rebuild.
          '';
        }
      ])
  ];
}