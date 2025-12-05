{ lib, ... }:

# Type definitions for configuration schema system
# These types help ensure type safety and provide documentation

rec {
  # Schema version type (e.g., "1.0", "2.0")
  Version = lib.types.str;
  
  # Schema definition type
  Schema = lib.types.submodule {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable description of this schema version";
      };
      
      requiredFields = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Fields that must be present in system-config.nix";
      };
      
      optionalFields = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Fields that may be present in system-config.nix";
      };
      
      hasConfigsDir = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this version uses configs/ directory";
      };
      
      hasConfigVersion = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this version requires configVersion field";
      };
      
      expectedConfigFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Expected config files in configs/ directory";
      };
      
      structure = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            maxSystemConfigLines = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Maximum lines allowed in system-config.nix";
            };
            
            forbiddenInSystemConfig = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Fields forbidden in system-config.nix";
            };
          };
        });
        default = null;
        description = "Structure requirements for this schema version";
      };
      
      detectionPatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Patterns to detect this schema version";
      };
    };
  };
  
  # Field mapping type (old path -> new path)
  FieldMapping = lib.types.attrsOf lib.types.str;
  
  # Structure definition type (recursive)
  Structure = lib.types.oneOf [
    lib.types.str  # Path in old config (e.g., "desktop.enable")
    (lib.types.attrsOf Structure)  # Nested structure
  ];
  
  # Field migration plan type
  FieldMigrationPlan = lib.types.submodule {
    options = {
      targetFile = lib.mkOption {
        type = lib.types.str;
        description = "Target file path (relative to configs/)";
      };
      
      structure = lib.mkOption {
        type = lib.types.attrs;
        description = "Structure definition for this field";
      };
      
      fieldMappings = lib.mkOption {
        type = lib.types.nullOr FieldMapping;
        default = null;
        description = "Field path mappings (old -> new)";
      };
      
      conversion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Conversion type (e.g., 'attrset-to-array')";
      };
    };
  };
  
  # Migration plan type
  MigrationPlan = lib.types.submodule {
    options = {
      fieldsToKeep = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Fields to keep in system-config.nix";
      };
      
      fieldsToMigrate = lib.mkOption {
        type = lib.types.attrsOf FieldMigrationPlan;
        default = {};
        description = "Fields to migrate to separate files";
      };
    };
  };
  
  # Migration plans type (fromVersion -> toVersion -> MigrationPlan)
  MigrationPlans = lib.types.attrsOf (lib.types.attrsOf MigrationPlan);
}

