{ pkgs, lib, ... }:

let
  # Import once to avoid circular dependencies
  schemaModule = import ./config-schema.nix { inherit lib; };
  detectionModule = import ./config-detection.nix { inherit pkgs lib; };
  migrationModule = import ./config-migration.nix { inherit pkgs lib; };
  validatorModule = import ./config-validator.nix { inherit pkgs lib; };
  checkModule = import ./config-check.nix { inherit pkgs lib; };
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

