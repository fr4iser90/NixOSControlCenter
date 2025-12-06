{ pkgs, lib, ... }:

let
  # Import cli-formatter directly (config/ is a library, not a NixOS module, so it can't access config.core.cli-formatter.api)
  colors = import ../cli-formatter/colors.nix;
  core = import ../cli-formatter/core { inherit lib colors; config = {}; };
  status = import ../cli-formatter/status { inherit lib colors; config = {}; };
  
  # Build formatter API (same structure as cli-formatter/default.nix apiValue)
  formatter = {
    inherit colors;
    inherit (core) text layout;
    inherit (status) messages badges;
  };
  
  # Import once to avoid circular dependencies
  schemaModule = import ./config-schema.nix { inherit lib; };
  detectionModule = import ./config-detection.nix { inherit pkgs lib; };
  migrationModule = import ./config-migration.nix { inherit pkgs lib formatter; };
  validatorModule = import ./config-validator.nix { inherit pkgs lib formatter; };
  checkModule = import ./config-check.nix { inherit pkgs lib formatter; };
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

