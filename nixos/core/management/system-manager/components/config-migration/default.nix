{ pkgs, lib, config ? null, systemConfig ? null, ... }:

let
  # Import cli-formatter directly (config/ is a library, not a NixOS module, so it can't access config.core.cli-formatter.api)
  colors = import ../../../../infrastructure/cli-formatter/colors.nix;
  core = import ../../../../infrastructure/cli-formatter/core { inherit lib colors; config = {}; };
  status = import ../../../../infrastructure/cli-formatter/status { inherit lib colors; config = {}; };
  
  # Build formatter API (same structure as cli-formatter/default.nix apiValue)
  formatter = {
    inherit colors;
    inherit (core) text layout;
    inherit (status) messages badges;
  };
  
  # Use API if available (when called from NixOS module), otherwise import directly
  backupHelpers = if config != null && config ? core && config.core ? management && config.core.management ? system-manager && config.core.management.system-manager ? api
    then config.core.management.system-manager.api.backupHelpers
    else import ../../lib/backup-helpers.nix { inherit pkgs lib; };
  
  # Import once to avoid circular dependencies
  schemaModule = import ./schema.nix { inherit lib; };
  detectionModule = import ./detection.nix { inherit pkgs lib; };
  migrationModule = import ./migration.nix { inherit pkgs lib formatter backupHelpers; };
  validatorModule = import ./validator.nix { inherit pkgs lib formatter; };
  checkModule = import ./check.nix { inherit config pkgs lib formatter backupHelpers systemConfig; };
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
  
  # Main command (validates + migrates)
  check = checkModule;
  
  # Convenience: Direct access to main command
  configCheck = checkModule.configCheck;
}
