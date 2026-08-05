{ config, lib, pkgs, systemConfig, configPath ? "management.system-manager", ... }:
let
  cfg = systemConfig.${configPath};
  # Import config-migration module to get the commands
  configMigrationModule = import ./. { inherit pkgs lib config; };
  checkScript = configMigrationModule.check.configCheck;
in {
  config = lib.mkMerge [
    (lib.mkIf (cfg.components.configMigration.enable or false)
      cliRegistry.registerCommandsFor "config-migration" [
    {
      name = "config-check";
      script = "${checkScript}";
      description = "Validate and migrate NixOS configuration (schema versions)";
      category = "system";
      help = "ncc config-check: Validates config (monolith or split) and migrates schema if needed.";
    }
    {
      name = "config-detect-version";
      script = "${configMigrationModule.detection.detectConfigVersion}";
      description = "Detect NixOS configuration schema version";
      category = "system";
      help = "ncc config-detect-version: Detects schema version (v0/v1/v2) from systemConfig.nix or split leaves.";
    }
    {
      name = "config-migrate";
      script = "${configMigrationModule.migration.migrateSystemConfig}";
      description = "Migrate NixOS configuration schema version";
      category = "system";
      help = "ncc config-migrate: Migrates schema versions (v0→v1→v2). For layout use config-layout.";
    }
    {
      name = "config-validate";
      script = "${configMigrationModule.validator.validateSystemConfig}";
      description = "Validate NixOS configuration (monolith or split)";
      category = "system";
      help = "ncc config-validate: Validates active layout SSOT via config-facade.";
    }
    {
      name = "config-layout";
      script = "${configMigrationModule.configLayout}/bin/ncc-config-layout";
      description = "Detect or convert systemConfig layout (monolith ↔ split)";
      category = "system";
      help = ''
        ncc system config-layout detect
        ncc system config-layout convert --to monolith|split [--force]
      '';
    }
    ]))
  ];
}
