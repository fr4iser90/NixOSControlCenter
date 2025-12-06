{ pkgs, lib, ... }:

let
  # Import terminal-ui directly (same as terminal-ui/default.nix does)
  colors = import ../../features/terminal-ui/colors.nix;
  core = import ../../features/terminal-ui/core { inherit lib colors; config = {}; };
  status = import ../../features/terminal-ui/status { inherit lib colors; config = {}; };
  
  # Build UI API (same structure as terminal-ui/default.nix apiValue)
  ui = {
    inherit colors;
    inherit (core) text layout;
    inherit (status) messages badges;
  };
  
  # Import once to avoid circular dependencies
  schemaModule = import ./config-schema.nix { inherit lib; };
  detectionModule = import ./config-detection.nix { inherit pkgs lib; };
  migrationModule = import ./config-migration.nix { inherit pkgs lib ui; };
  validatorModule = import ./config-validator.nix { inherit pkgs lib ui; };
  checkModule = import ./config-check.nix { inherit pkgs lib ui; };
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

