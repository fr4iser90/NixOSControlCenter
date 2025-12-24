{ config, lib, pkgs, systemConfig, corePathsLib, ... }:
let
  cfg = systemConfig.management.system-manager or {};
  # Import config-migration module to get the commands
  configMigrationModule = import ./. { inherit pkgs lib config; };
  checkScript = configMigrationModule.check.configCheck;
in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.components.configMigration.enable or false)
      (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
    {
      name = "config-check";
      script = "${checkScript}";
      description = "Validate and migrate NixOS configuration (v0→v1)";
      category = "system";
      help = "ncc config-check: Validates current NixOS configuration and automatically migrates from v0 to v1 if needed.";
    }
    {
      name = "config-detect-version";
      script = "${configMigrationModule.detection.detectConfigVersion}";
      description = "Detect NixOS configuration version";
      category = "system";
      help = "ncc config-detect-version: Detects the current NixOS configuration version (v0 or v1).";
    }
    {
      name = "config-migrate";
      script = "${configMigrationModule.migration.migrateSystemConfig}";
      description = "Migrate NixOS configuration (v0→v1)";
      category = "system";
      help = "ncc config-migrate: Migrates NixOS configuration from v0 (monolithic) to v1 (modular) format.";
    }
    {
      name = "config-validate";
      script = "${configMigrationModule.validator.validateSystemConfig}";
      description = "Validate NixOS configuration structure";
      category = "system";
      help = "ncc config-validate: Validates the structure and required fields of the current NixOS configuration.";
    }
    ]))
  ];
}
