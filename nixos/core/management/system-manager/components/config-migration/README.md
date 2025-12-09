# NixOS Configuration Management System

A fully schema-based system for managing, validating, and migrating NixOS configurations.

## Overview

This system enables:
- **Automatic Migration** of old configurations to new versions
- **Schema-based Validation** of configuration structure
- **Automatic Version Detection** through pattern matching
- **Modular Configuration** (v1.0+): `system-config.nix` + `configs/*.nix`
- **Chain Migration**: Automatic migration across multiple versions (e.g., v0 → v1.0 → v1.5)

## Architecture

```
config/
├── config-schema.nix           # Schema Discovery & Migration Paths
├── config-detection.nix        # Version Detection via Patterns
├── config-migration.nix        # Migration Engine (jq-based)
├── config-validator.nix        # Validation Engine
├── config-check.nix            # Main Command (validate + migrate)
├── utils.nix                   # Helper Functions (Discovery, Chain-Finding)
├── types.nix                   # Type Definitions
├── default.nix                 # Public API
└── config-schema/
    ├── v0.nix                  # Schema v0 (monolithic, ohne configVersion)
    ├── v1.nix                  # Schema v1.0 (modular, mit configVersion = "1.0")
    └── migrations/
        └── v0-to-v1.nix        # Migration Plan v0 → v1.0
```

## File Explanations

### `config-schema.nix`
**Purpose**: Central schema management and auto-discovery

**Functions**:
- Automatically discovers all schema files (`v*.nix`) in the `config-schema/` directory
- Automatically discovers all migration plans (`v*-to-v*.nix`) in the `migrations/` directory
- Automatically generates migration paths (direct paths)
- Automatically calculates `minSupportedVersion`
- Provides helper functions: `getSchema`, `isVersionSupported`, `canMigrate`, `findMigrationChain`

**API**:
```nix
{
  schemas = { "1.0" = {...}; "2.0" = {...}; };
  migrationPlans = { "1.0" = { "2.0" = {...}; }; };
  migrationPaths = { "1.0" = "2.0"; };
  currentVersion = "1.0";
  minSupportedVersion = "1.0";
}
```

### `config-detection.nix`
**Purpose**: Automatic version detection of `system-config.nix`

**Functions**:
- First checks for explicit `configVersion` field
- If not present: Pattern-based detection
  - Reads `system-config.nix` as text
  - Checks `detectionPatterns` from all schemas
  - Selects version with most matches
- Fallback: Checks for `configs/` directory (v1.0+) or uses `minSupportedVersion`

**Example**:
```bash
ncc-detect-version
# Output: "1.0" or "2.0"
```

**Pattern Example** (v0):
```nix
detectionPatterns = [
  "packageModules = {"     # v0 had packageModules as Attrset
  "system.version"         # v0 had system.version
  "hardware.memory"        # v0 had hardware.memory (not ram!)
];
```

### `config-migration.nix`
**Purpose**: Migration engine for automatic configuration migration

**Functions**:
- **Direct Migration**: v0 → v1.0 (single step)
- **Chain Migration**: v0 → v1.0 → v1.5 (multiple steps)
- **Schema-based**: Uses `fieldsToKeep` and `fieldsToMigrate` from migration plans
- **Recursive Formatting**: Converts JSON → Nix syntax with arbitrary nesting depth
- **Atomic Operations**: Uses temporary files, only overwrites on success
- **Backup**: Automatically creates backups before migration

**Migration Process**:
1. Detects current version via `ncc-detect-version`
2. Finds migration path (direct or chain)
3. Creates backup
4. Extracts `fieldsToKeep` → creates minimal `system-config.nix`
5. Migrates `fieldsToMigrate` → creates `configs/*.nix` files
6. Only overwrites `system-config.nix` if all steps succeed

**Example**:
```bash
sudo ncc-migrate-config
# Automatically migrates from v0 to v1.0
```

**Recursive Formatting** (jq-based):
- Converts JSON objects to Nix attribute sets
- Handles booleans (`true`/`false`), numbers, strings, arrays, nested objects
- Correct indentation for arbitrary nesting depth

### `config-validator.nix`
**Purpose**: Validation of configuration structure

**Functions**:
- Checks Nix syntax
- Detects version via `ncc-detect-version`
- Validates `requiredFields` for detected version
- Checks structure requirements (`maxSystemConfigLines`, `forbiddenInSystemConfig`)
- Validates `configs/*.nix` files (for v1.0+)
- Outputs detailed error and warning messages

**Example**:
```bash
ncc-validate-config
# Output: ✓ All checks passed! or detailed error list
```

**Validation Checks**:
- ✓ Nix syntax is valid
- ✓ Version detected
- ✓ All `requiredFields` present
- ✓ Structure requirements met (for v1.0: max 30 lines in `system-config.nix`)
- ✓ No `forbiddenInSystemConfig` fields in `system-config.nix`
- ✓ All `configs/*.nix` files have valid syntax

### `config-check.nix`
**Purpose**: Main command - combines validation + migration

**Functions**:
1. Validates configuration
2. If errors: Attempts automatic migration
3. Re-validates after migration

**Example**:
```bash
ncc-config-check
# Automatically performs migration if needed
```

**Usage**:
- Automatically called by `ncc system-update`
- Can be run manually: `sudo ncc-config-check`

### `utils.nix`
**Purpose**: Helper functions for schema discovery and migration chain finding

**Functions**:
- `extractVersion`: Extracts version from filename (`v0.nix` → `"0"`, `v1.nix` → `"1.0"`)
- `parseMigrationFilename`: Parses migration filenames (`v0-to-v1.nix` → `{ from = "0"; to = "1.0"; }`)
- `discoverSchemas`: Automatically discovers all schema files
- `discoverMigrations`: Automatically discovers all migration plans
- `generateMigrationPaths`: Generates direct migration paths
- `findMigrationChain`: Finds migration chain via BFS (e.g., v0 → v1.0 → v1.5)
- `canMigrateChain`: Checks if migration chain exists

**Example** (Chain-Finding):
```nix
findMigrationChain migrationPlans "1.0" "2.0"
# If v0 → v1.0 → v1.5 exists: ["0", "1.0", "1.5"]
# If only v0 → v1.0 exists: ["0", "1.0"]
# If no path: null
```

### `types.nix`
**Purpose**: Type definitions for type safety and documentation

**Types**:
- `Version`: Schema version (e.g., `"1.0"`, `"2.0"`)
- `Schema`: Schema definition with all options
- `FieldMapping`: Field mappings (old path → new path)
- `Structure`: Recursive structure definition
- `FieldMigrationPlan`: Plan for single field
- `MigrationPlan`: Complete migration plan (`fieldsToKeep` + `fieldsToMigrate`)

### `default.nix`
**Purpose**: Public API - exports all modules

**API**:
```nix
{
  schema = schemaModule;           # Schema System
  detection = detectionModule;      # Version Detection
  migration = migrationModule;     # Migration Engine
  validator = validatorModule;      # Validation Engine
  check = checkModule;             # Main Command
  configCheck = checkModule.configCheck;  # Convenience
}
```

**Usage**:
```nix
configModule = import ./core/infrastructure/config { inherit pkgs lib; };
# Then: configModule.configCheck, configModule.migration.migrateSystemConfig, etc.
```

## Schema Definitions

### Schema Structure (`config-schema/v*.nix`)

Each schema defines:
```nix
{
  description = "Description";
  requiredFields = [ "field1" "field2" ];
  optionalFields = [ "field3" ];
  hasConfigsDir = true/false;
  hasConfigVersion = true/false;
  expectedConfigFiles = [ "desktop-config.nix" ];
  structure = {
    maxSystemConfigLines = 30;
    forbiddenInSystemConfig = [ "desktop" "hardware" ];
  };
  detectionPatterns = [ "pattern1" "pattern2" ];
}
```

### Migration Plan (`config-schema/migrations/v*-to-v*.nix`)

Each migration plan defines:
```nix
{
  fieldsToKeep = [ "systemType" "hostName" ];  # Stay in system-config.nix
  fieldsToMigrate = {
    "desktop" = {
      targetFile = "configs/desktop-config.nix";
      structure = {
        desktop = {
          enable = "desktop.enable";  # Path in old config
          environment = "desktop.environment";
        };
      };
      fieldMappings = {  # Optional: Field renamings
        "hardware.memory.sizeGB" = "hardware.ram.sizeGB";
      };
      conversion = "attrset-to-array";  # Optional: Special conversion
    };
  };
}
```

## Version Differences

### v0 (Monolithic)
- **Structure**: Everything in `system-config.nix`
- **No** `configVersion` field
- **No** `configs/` directory
- **Detection**: Pattern matching (`packageModules = {`, `system.version`, `hardware.memory`)

### v1.0 (Modular)
- **Structure**: Minimal `system-config.nix` + `configs/*.nix` files
- **Must** have `configVersion = "1.0";`
- **Must** have `configs/` directory
- **Detection**: Explicit `configVersion` field or `configs/` directory

## Migration Example

### Before (v0):
```nix
{
  systemType = "desktop";
  hostName = "Gaming";
  system = { channel = "stable"; bootloader = "systemd-boot"; };
  allowUnfree = true;
  users = { fr4iser = { role = "admin"; defaultShell = "zsh"; }; };
  timeZone = "Europe/Berlin";
  desktop = { enable = true; environment = "plasma"; };
  hardware = { cpu = "intel"; gpu = "amd"; };
}
```

### After (v1.0):

**`system-config.nix`**:
```nix
{
  configVersion = "1.0";
  systemType = "desktop";
  hostName = "Gaming";
  system = { channel = "stable"; bootloader = "systemd-boot"; };
  allowUnfree = true;
  users = { fr4iser = { role = "admin"; defaultShell = "zsh"; }; };
  timeZone = "Europe/Berlin";
}
```

**`configs/desktop-config.nix`**:
```nix
{
  desktop = {
    enable = true;
    environment = "plasma";
  };
}
```

**`configs/hardware-config.nix`**:
```nix
{
  hardware = {
    cpu = "intel";
    gpu = "amd";
  };
}
```

## Usage

### Automatic (via `ncc system-update`)
```bash
sudo ncc system-update
# Automatically runs ncc-config-check (validates + migrates if needed)
```

### Manual
```bash
# Validate only
ncc-validate-config

# Migrate only
sudo ncc-migrate-config

# Validate + Migrate
sudo ncc-config-check

# Detect version
ncc-detect-version
```

## Extension (Adding New Version)

### 1. Create Schema File
```bash
# nixos/core/config/config-schema/v3.nix
{
  description = "v3.0 Description";
  requiredFields = [ "configVersion" "systemType" ... ];
  hasConfigsDir = true;
  hasConfigVersion = true;
  detectionPatterns = [ "v3.0-specific pattern" ];
  structure = {
    maxSystemConfigLines = 25;
    forbiddenInSystemConfig = [ ... ];
  };
}
```

### 2. Create Migration Plan
```bash
# nixos/core/config/config-schema/migrations/v2-to-v3.nix
{
  fieldsToKeep = [ "systemType" "hostName" ... ];
  fieldsToMigrate = {
    "newField" = {
      targetFile = "configs/new-field-config.nix";
      structure = { ... };
    };
  };
}
```

### 3. Update `currentVersion`
```nix
# config-schema.nix
currentVersion = "3.0";
```

**That's it!** The system automatically discovers everything.

## Technical Details

### Why JSON?
- `nix-instantiate --eval --json` converts Nix → JSON
- `jq` can easily process JSON (paths, extraction, transformation)
- Recursive formatting: JSON → Nix syntax via `jq` with `formatNixValue` function

### Why jq?
- Powerful JSON processing
- Recursive functions possible (`formatNixValue`)
- Simple path extraction (`.hardware.cpu`)
- Transformations (Attrset → Array, field renamings)

### Atomic Operations
- Migration first writes to temporary file (`mktemp`)
- Only overwrites `system-config.nix` if all steps succeed
- On error: Original file remains unchanged
- Automatic backups before each migration

### Chain Migration
- If direct migration doesn't exist (e.g., v0 → v1.0 missing)
- Automatically finds chain (e.g., v0 → v1.0 → v1.5)
- Performs migration step-by-step
- Each step creates backup

## Best Practices

1. **Always check backups**: Backup is automatically created before migration
2. **Schema-based**: Add new versions only through schema files
3. **Pattern-based**: `detectionPatterns` should be unique
4. **Modular**: v1.0+ should have minimal `system-config.nix`
5. **Validation**: Always run `ncc-config-check` before `nixos-rebuild`

## Troubleshooting

### Migration overwrites config with empty content
- **Cause**: `fieldsToKeep` contains no fields that exist in old config
- **Solution**: Check `fieldsToKeep` in migration plan, ensure fields exist

### Version is incorrectly detected
- **Cause**: `detectionPatterns` are not unique or missing
- **Solution**: Add unique patterns to schema

### Migration fails with jq error
- **Cause**: `formatNixValue` function has syntax error
- **Solution**: Check jq syntax in `config-migration.nix` (lines 226-240, 389-403)

### Chain migration finds no path
- **Cause**: No migration plans for all steps available
- **Solution**: Create missing migration plans (e.g., `v1.0-to-v1.5.nix`, `v1.5-to-v2.0.nix`)

## Summary

This system enables:
- ✅ **Automatic Migration** of old configs to new versions
- ✅ **Schema-based Validation** of structure
- ✅ **Automatic Version Detection** via patterns
- ✅ **Modular Configuration** (v1.0+)
- ✅ **Chain Migration** across multiple versions
- ✅ **Atomic Operations** (no data loss)
- ✅ **Recursive Formatting** (arbitrary nesting depth)
- ✅ **Auto-Discovery** (no manual registration needed)

**Adding new versions**: Simply create schema + migration plan, the rest happens automatically!
