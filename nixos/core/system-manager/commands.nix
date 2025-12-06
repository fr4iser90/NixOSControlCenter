{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.core.system-manager;
  versionChecker = import ./handlers/feature-version-check.nix { inherit config lib; };
  checkVersions = import ./scripts/check-versions.nix { inherit config lib pkgs; };
  updateFeatures = import ./scripts/update-features.nix { inherit config lib pkgs; };
  
  # Import handlers to get their scripts and commands
  systemUpdateHandler = import ./handlers/system-update.nix { inherit config lib pkgs systemConfig; };
  featureManagerHandler = import ./handlers/feature-manager.nix { inherit config lib pkgs systemConfig; };
  channelManagerHandler = import ./handlers/channel-manager.nix { inherit config lib pkgs systemConfig; };
  desktopManagerHandler = import ./handlers/desktop-manager.nix { inherit config lib pkgs systemConfig; };
  
  # Import config migration and validation
  configMigration = import ./config-migration.nix { inherit pkgs lib; };
  configValidator = import ./validators/config-validator.nix { inherit pkgs lib; };
in {
  config = {
    environment.systemPackages = 
      [ checkVersions.checkVersionsScript
        updateFeatures.updateFeaturesScript
        configMigration.migrateSystemConfig
        configValidator.validateSystemConfig
      ] ++
      (systemUpdateHandler.config.environment.systemPackages or []) ++
      (featureManagerHandler.config.environment.systemPackages or []) ++
      (channelManagerHandler.config.environment.systemPackages or []) ++
      (desktopManagerHandler.config.environment.systemPackages or []);
    
    core.command-center.commands = 
      (systemUpdateHandler.config.core.command-center.commands or []) ++
      (featureManagerHandler.config.core.command-center.commands or []) ++
      (channelManagerHandler.config.core.command-center.commands or []) ++
      (desktopManagerHandler.config.core.command-center.commands or []) ++
      [
        {
          name = "check-feature-versions";
          description = "Check feature versions and update status";
          category = "system";
          script = "${checkVersions.checkVersionsScript}/bin/ncc-check-feature-versions";
          arguments = [];
          dependencies = [ "nix" ];
          shortHelp = "check-feature-versions - Check feature versions";
          longHelp = ''
            Check the version status of all features:
            - Installed: Current version on the system
            - Available: Latest version in code (Git)
            - Stable: Stable version (if different from available)
            - Status: Update availability and migration support
          '';
        }
        {
          name = "update-features";
          description = "Update features with automatic migration support";
          category = "system";
          script = "${updateFeatures.updateFeaturesScript}/bin/ncc-update-features";
          arguments = [
            "--feature"
            "--dry-run"
            "--auto"
          ];
          dependencies = [ "nix" ];
          shortHelp = "update-features [--feature=name] [--dry-run] [--auto] - Update features";
          longHelp = ''
            Update features to their latest versions:
            - --feature=name: Update specific feature only
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
          script = "${configMigration.migrateSystemConfig}/bin/ncc-migrate-config";
          arguments = [];
          dependencies = [ "nix" ];
          shortHelp = "migrate-system-config - Migrate system-config.nix to modular structure";
          longHelp = ''
            Migrates the system configuration from monolithic to modular structure:
            
            Migration Process:
            - Creates backup of current system-config.nix
            - Extracts config sections to separate files in configs/:
              * features → configs/features-config.nix
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
      ];
  };
}

