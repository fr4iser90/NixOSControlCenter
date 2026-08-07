{ pkgs, lib, config, systemConfig, getModuleApi, getModuleMetadata, backupHelpers, configPath, ... }:

let
  # Formatter wird direkt aus NCC geholt - GENAUSO WIE ALLE ANDEREN MODULE!
  formatterApi = getModuleApi "cli-formatter";
  
  # backupHelpers wird jetzt als Parameter übergeben
  
  # Import once to avoid circular dependencies
  schemaModule = import ./schema.nix { inherit lib; };
  detectionModule = import ./detection.nix { inherit pkgs lib; };
  migrationModule = import ./migration.nix { inherit pkgs lib getModuleApi backupHelpers; };
  validatorModule = import ./validator.nix { inherit pkgs lib getModuleApi; };
  legacyCleanupModule = import ./legacy-cleanup.nix { inherit pkgs lib getModuleApi backupHelpers; };
  checkModule = import ./check.nix { inherit config pkgs lib getModuleApi backupHelpers systemConfig configPath; };
  layoutModule = import ./layout.nix { inherit pkgs lib getModuleApi getModuleMetadata; };
in

{
  # Main export for config management system
  # Provides clean API for all config-related functionality
  
  # Schema system (auto-discovery, version management)
  schema = schemaModule;
  
  # Version detection (uses detectionPatterns from schemas)
  detection = detectionModule;
  
  # Migration engine (fully generic, schema-driven)
  migration = migrationModule;
  
  # Validation engine (fully generic, schema-driven)
  validator = validatorModule;

  # Legacy path cleanup (configs/ → systemConfig/)
  legacyCleanup = legacyCleanupModule;
  
  # Main command (validates + migrates)
  check = checkModule;

  # Layout detect/convert (monolith ↔ split)
  layout = layoutModule;
  
  # Convenience: Direct access to main command
  configCheck = checkModule.configCheck;
  cleanupLegacyConfigs = legacyCleanupModule.cleanupLegacyConfigs;
  configLayout = layoutModule.configLayout;
}
