# Feature Module Template

This template defines the recommended structure for all NixOS Control Center feature modules.

## Directory Structure

```
feature-name/
├── README.md              # Feature documentation and usage guide
├── default.nix            # Main module (imports all sub-modules)
├── options.nix            # All configuration options
├── types.nix              # Custom NixOS types (optional)
├── commands.nix          # Command-Center registration
├── systemd.nix            # Systemd services/timers (optional)
├── config.nix             # Feature-specific configuration (optional)
├── lib/                   # Shared utility functions
│   ├── default.nix        # Library exports
│   ├── utils.nix          # General utilities
│   ├── validators.nix     # Validation functions
│   └── types.nix          # Internal type helpers (if needed)
├── scripts/               # Executable CLI commands (user entry points)
│   ├── main-command.nix   # Main command script
│   ├── sub-command-1.nix  # Sub-command 1
│   └── sub-command-2.nix  # Sub-command 2
├── handlers/              # Business logic orchestration (optional)
│   ├── handler-1.nix      # Handler implementation 1
│   └── handler-2.nix      # Handler implementation 2
├── collectors/            # Data collection modules (optional)
│   ├── collector-1.nix   # Collector implementation 1
│   └── collector-2.nix   # Collector implementation 2
├── processors/            # Data processing/transformation (optional)
│   ├── processor-1.nix   # Processor implementation 1
│   └── processor-2.nix   # Processor implementation 2
├── validators/            # Input validation (optional)
│   └── validator-1.nix   # Validator implementation
├── formatters/            # Output formatting (optional)
│   └── formatter-1.nix   # Formatter implementation
├── adapters/              # Interface translation (optional)
│   └── adapter-1.nix     # Adapter implementation
├── parsers/               # Parsing logic (optional)
│   └── parser-1.nix      # Parser implementation
├── serializers/           # Serialization logic (optional)
│   └── serializer-1.nix  # Serializer implementation
├── migrations/            # Feature option migrations (optional)
│   ├── v1.0-to-v1.1.nix  # Minor version migration
│   ├── v1.0-to-v2.0.nix  # Major version migration
│   └── v1.1-to-v2.0.nix  # Chain migration
├── builders/              # Build/construction logic (optional)
│   └── builder-1.nix     # Builder implementation
├── monitors/              # Monitoring logic (optional)
│   └── monitor-1.nix     # Monitor implementation
├── notifiers/             # Notification logic (optional)
│   └── notifier-1.nix    # Notifier implementation
├── providers/             # Provider implementations (semantic, optional)
│   ├── provider-a.nix     # Provider A implementation
│   └── provider-b.nix     # Provider B implementation
└── tests/                 # Module tests (optional)
    └── default.nix         # Test suite
```

## Category Differences Explained

### **scripts/** vs **handlers/** vs **processors/** vs **collectors/**

**Flow Example**: User runs command → Script → Handler → Collectors/Processors → Formatter

1. **`scripts/`** = **User Entry Point**
   - What: CLI commands that users execute
   - Does: Parse arguments, validate input, call handlers, format output
   - Example: `ncc-system-discovery` command script

2. **`handlers/`** = **Orchestration Layer**
   - What: Coordinate multiple operations to complete a workflow
   - Does: Calls collectors → processors → validators in sequence
   - Example: `discovery-handler.nix` orchestrates scanning workflow

3. **`collectors/`** = **Data Gathering**
   - What: Gather data from various sources
   - Does: Read from system, configs, files, APIs (no transformation)
   - Example: `package-collector.nix` reads installed packages

4. **`processors/`** = **Data Transformation**
   - What: Transform collected data
   - Does: Filter, map, aggregate, normalize, enrich data
   - Example: `package-processor.nix` filters and groups packages

5. **`validators/`** = **Input Checking**
   - What: Validate data correctness
   - Does: Check format, constraints, business rules
   - Example: `config-validator.nix` validates configuration

6. **`formatters/`** = **Output Formatting**
   - What: Format data for display
   - Does: Convert structured data to text/JSON/tables
   - Example: `table-formatter.nix` formats data as tables

### **When to Use Each**

| Need | Use | Example |
|------|-----|---------|
| User runs a command | `scripts/` | `ncc-backup create` |
| Coordinate multiple steps | `handlers/` | Orchestrate backup workflow |
| Read system info | `collectors/` | Read installed packages |
| Transform data | `processors/` | Filter and group packages |
| Check if valid | `validators/` | Validate backup config |
| Display results | `formatters/` | Format as table/JSON |

### **Real-World Example**

```nix
# scripts/backup-create.nix - User entry point
# → Calls handler

# handlers/backup-handler.nix - Orchestration
# → Calls collectors/ to gather config
# → Calls validators/ to validate
# → Calls processors/ to prepare backup
# → Calls formatters/ to show progress

# collectors/config-collector.nix - Gather config
# → Reads backup configuration

# validators/config-validator.nix - Validate
# → Checks config correctness

# processors/backup-processor.nix - Prepare
# → Prepares backup plan

# formatters/progress-formatter.nix - Display
# → Shows progress to user
```

## File Descriptions

### `default.nix`
- **Purpose**: Main module entry point
- **Responsibilities**:
  - Imports all sub-modules (options, types, commands, systemd, etc.)
  - Maps `systemConfig.features.<feature-name>` to `config.features.<feature-name>.enable`
  - Defines `mkIf cfg.enable` block for feature implementation
- **Pattern**: Always use `mkMerge` to combine default config with enabled config

### `options.nix`
- **Purpose**: Define all configuration options
- **Responsibilities**:
  - All `options.features.<feature-name>` definitions
  - Default values and descriptions
  - Type definitions for options
- **Rule**: NO implementation logic, only option definitions

### `types.nix`
- **Purpose**: Custom NixOS types for the feature
- **Responsibilities**:
  - Reusable type definitions
  - Type validation logic
  - Complex nested types
- **Optional**: Only needed if custom types are required

### `commands.nix`
- **Purpose**: Command-Center command registration
- **Responsibilities**:
  - Create all executable scripts using `pkgs.writeShellScriptBin`
  - Register commands in `core.command-center.commands`
  - Define command metadata (name, description, category, help text)
- **Critical**: Must be inside `mkIf cfg.enable` block!

### `systemd.nix`
- **Purpose**: Systemd service and timer definitions
- **Responsibilities**:
  - Systemd services
  - Systemd timers
  - Systemd targets
  - Activation scripts
- **Optional**: Only needed if systemd integration is required

### `config.nix`
- **Purpose**: Feature-specific configuration logic
- **Responsibilities**:
  - Complex configuration transformations
  - Feature-specific system configuration
  - Integration with other NixOS modules
- **Optional**: Use when default.nix would become too large

### `lib/`
- **Purpose**: Shared utility functions
- **Structure**:
  - `default.nix`: Exports all library functions
  - `utils.nix`: General utility functions
  - `validators.nix`: Input validation functions
  - `types.nix`: Internal type helpers (if needed)
- **Best Practice**: Keep functions pure and reusable

### `scripts/`
- **Purpose**: Executable command scripts (CLI entry points)
- **Pattern**: One script per command, named after the command
- **Implementation**: Use `pkgs.writeShellScriptBin "command-name" ''...''`
- **Best Practice**: Keep scripts focused and single-purpose
- **Key Difference**: Scripts are the **user-facing entry points** - they parse arguments, call handlers/processors, and format output

### `handlers/`
- **Purpose**: Complex business logic handlers (orchestration layer)
- **Usage**: Called by scripts or other modules
- **Pattern**: One handler per logical operation/workflow
- **Optional**: Only create if logic is complex enough to warrant separation
- **Key Difference**: Handlers **orchestrate** multiple operations - they coordinate collectors, processors, validators, etc. to complete a business workflow

### `collectors/`
- **Purpose**: Data collection modules (gathering information)
- **Usage**: Called by handlers or scripts to gather data
- **Pattern**: One collector per data source or collection type
- **Optional**: Only needed if feature collects data from multiple sources
- **Key Difference**: Collectors **gather** data from system, configs, files, APIs, etc. - they don't process or transform, just collect

### `processors/`
- **Purpose**: Data processing and transformation logic
- **Usage**: Called by handlers to transform collected data
- **Pattern**: One processor per transformation type
- **Optional**: Only needed if data transformation is complex
- **Key Difference**: Processors **transform** data - they take input data and produce transformed output (filtering, mapping, aggregating, etc.)

### `validators/`
- **Purpose**: Input validation and verification logic
- **Usage**: Called by handlers, scripts, or processors to validate data
- **Pattern**: One validator per validation concern
- **Optional**: Only needed if validation logic is complex
- **Key Difference**: Validators **check** data - they verify correctness, format, constraints, etc. and return validation results

### `formatters/`
- **Purpose**: Output formatting modules
- **Usage**: Called by scripts to format output for display
- **Pattern**: One formatter per output format (text, json, table, etc.)
- **Optional**: Only needed if multiple output formats are supported
- **Key Difference**: Formatters **format** output - they take structured data and produce formatted strings for display

### `adapters/`
- **Purpose**: Adapter pattern implementations (interface translation)
- **Usage**: Translate between different interfaces/formats
- **Pattern**: One adapter per interface variant
- **Optional**: Only needed when interfacing with multiple external systems
- **Key Difference**: Adapters **translate** between different interfaces - they convert one API/format to another

### `parsers/`
- **Purpose**: Parsing logic (string/file parsing)
- **Usage**: Called by collectors or handlers to parse structured data
- **Pattern**: One parser per format (JSON, YAML, XML, etc.)
- **Optional**: Only needed if parsing logic is complex
- **Key Difference**: Parsers **parse** structured text/data formats into structured objects

### `serializers/`
- **Purpose**: Serialization/deserialization logic
- **Usage**: Convert between structured objects and serialized formats
- **Pattern**: One serializer per format
- **Optional**: Only needed if serialization is complex
- **Key Difference**: Serializers **convert** between objects and serialized formats (JSON, YAML, binary, etc.)

### `migrations/`
- **Purpose**: Feature option migration logic (feature-specific)
- **Usage**: Migrate feature options between versions when breaking changes occur
- **Pattern**: One migration file per version transition (`vX-to-vY.nix`)
- **Optional**: Only needed if feature options change in breaking ways
- **Key Difference**: Migrations **transform** feature options from old format to new format
- **Note**: This is for **feature option migrations**, not system config migrations (those are handled centrally in `nixos/core/config/`)

### `providers/`
- **Purpose**: Multiple implementation providers (e.g., different backends)
- **Usage**: Select provider based on configuration
- **Pattern**: One provider per implementation variant
- **Optional**: Only needed for features with multiple backends
- **Note**: This is a **semantic** name - use only when provider concept is central to the feature

### `tests/`
- **Purpose**: Module tests and validation
- **Usage**: Test module functionality and edge cases
- **Pattern**: Use NixOS testing framework
- **Optional**: Recommended for complex features

## Best Practices

### 1. **Separation of Concerns**

**Layer Architecture** (from user to system):
1. **`scripts/`** - User-facing CLI entry points (parse args, call handlers, format output)
2. **`handlers/`** - Business logic orchestration (coordinate collectors, processors, validators)
3. **`collectors/`** - Data gathering (read from system, configs, files, APIs)
4. **`processors/`** - Data transformation (filter, map, aggregate, transform)
5. **`validators/`** - Input validation (check correctness, format, constraints)
6. **`formatters/`** - Output formatting (format data for display)
7. **`adapters/`** - Interface translation (convert between APIs/formats)
8. **`parsers/`** - Parsing logic (parse structured text/data)
9. **`serializers/`** - Serialization (convert objects to/from formats)
10. **`lib/`** - Shared utilities (pure functions, reusable helpers)

**File Organization**:
- Options in `options.nix` (no implementation)
- Types in `types.nix` (reusable type definitions)
- Scripts in `scripts/` (one per command)
- Handlers in `handlers/` (orchestration logic)
- Collectors in `collectors/` (data gathering)
- Processors in `processors/` (data transformation)
- Systemd in `systemd.nix` (service definitions)

### 2. **Command Registration**
- Always register commands in `commands.nix`
- Must be inside `mkIf cfg.enable` block
- Use descriptive names, categories, and help text
- Register all aliases

### 3. **Enable Check Pattern**
```nix
config = mkMerge [
  {
    features.feature-name.enable = mkDefault (systemConfig.features.feature-name or false);
  }
  (mkIf cfg.enable {
    # All feature implementation here
  })
];
```

### 4. **Script Creation Pattern**
```nix
# In commands.nix, inside mkIf cfg.enable
let
  myScript = pkgs.writeShellScriptBin "ncc-my-command" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    # Script content
  '';
in {
  core.command-center.commands = [
    {
      name = "my-command";
      script = "${myScript}/bin/ncc-my-command";
      # ... other command metadata
    }
  ];
}
```

### 5. **Avoid `let` Block Issues**
- **CRITICAL**: Don't create scripts in outer `let` block if they use `cfg` options
- Scripts using `cfg` must be created inside `mkIf cfg.enable` block
- Only use outer `let` for things that don't depend on `cfg`

### 6. **Documentation**
- Every feature should have a `README.md`
- Document all options in `options.nix` with descriptions
- Include usage examples
- Document dependencies and requirements

### 7. **Consistency**
- Use same structure across all features
- Follow naming conventions
- Use consistent option patterns
- Maintain consistent code style

### 8. **Directory Naming: Generic vs Semantic**

**CRITICAL RULE**: Always prefer **generic names** unless the concept is central to the feature's identity.

#### **Generic Names** (use these in 95% of cases):

| Directory | Purpose | When to Use |
|-----------|---------|-------------|
| `scripts/` | Executable CLI commands | User-facing command entry points |
| `handlers/` | Business logic orchestration | Complex workflows coordinating multiple operations |
| `collectors/` | Data gathering | Collecting info from system, configs, files, APIs |
| `processors/` | Data transformation | Filtering, mapping, aggregating, transforming data |
| `validators/` | Input validation | Checking correctness, format, constraints |
| `formatters/` | Output formatting | Formatting data for display (text, JSON, tables) |
| `adapters/` | Interface translation | Converting between different APIs/formats |
| `parsers/` | Parsing structured data | Parsing JSON, YAML, XML, config files, etc. |
| `serializers/` | Serialization logic | Converting objects to/from serialized formats |
| `migrations/` | Configuration migration | Migrating config between versions |
| `builders/` | Build/construction logic | Building objects, configs, or artifacts |
| `monitors/` | Monitoring logic | Monitoring system state, health, metrics |
| `notifiers/` | Notification logic | Sending notifications, alerts, messages |

#### **Semantic Names** (use ONLY when concept is central to feature):

| Directory | When to Use | Example |
|-----------|-------------|---------|
| `providers/` | Multiple backend implementations | bootentry-manager (grub, systemd-boot, refind) |
| `drivers/` | Multiple driver implementations | vm-manager (qemu, kvm drivers) |
| `scanners/` | Feature is specifically about scanning | system-discovery (scanning is core concept) |
| `services/` | Feature manages services | Only if service management is the core feature |
| `containers/` | Feature manages containers | Only if container management is the core feature |

**Decision Guide**:
1. **Ask**: "Could this logic apply to other features?" → If YES → use generic name
2. **Ask**: "Is this concept central to the feature's identity?" → If NO → use generic name
3. **Ask**: "Would renaming this to a generic term lose important meaning?" → If NO → use generic name

**Examples**:
- ✅ `system-discovery/scanners/` → OK (scanning is the core concept)
- ❌ `system-discovery/collectors/` → Better (generic data collection)
- ✅ `bootentry-manager/providers/` → OK (provider pattern is central)
- ❌ `vm-manager/handlers/` → Better (generic orchestration logic)
- ✅ `system-logger/collectors/` → OK (generic data collection)
- ❌ `ai-workspace/services/` → Consider `handlers/` or `processors/` instead

**Rule of Thumb**: 
- Generic = reusable across features (handlers, processors, collectors, validators, formatters)
- Semantic = specific to feature domain (scanners, providers, drivers - only when central to identity)

## Complete Directory Reference

### Core Directories (always available):
- `scripts/` - Executable CLI commands
- `handlers/` - Business logic orchestration
- `lib/` - Shared utility functions
- `tests/` - Module tests

### Generic Directories (use as needed):
- `collectors/` - Data gathering from system/configs/files/APIs
- `processors/` - Data transformation and processing
- `validators/` - Input validation and verification
- `formatters/` - Output formatting (text, JSON, tables, etc.)
- `adapters/` - Interface translation between different APIs/formats
- `parsers/` - Parsing structured data (JSON, YAML, XML, configs)
- `serializers/` - Serialization/deserialization logic
- `migrations/` - Configuration migration between versions
- `builders/` - Build/construction logic for objects/configs/artifacts
- `monitors/` - Monitoring system state, health, metrics
- `notifiers/` - Notification and alert logic

### Semantic Directories (use ONLY when concept is central):
- `providers/` - Multiple backend implementations (e.g., bootentry-manager)
- `drivers/` - Multiple driver implementations (e.g., vm-manager)
- `scanners/` - Scanning logic (only if scanning is core feature, e.g., system-discovery)
- `services/` - Service management (only if service management is core feature)
- `containers/` - Container management (only if container management is core feature)

### File-Level Modules (at feature root):
- `default.nix` - Main module entry point
- `options.nix` - Configuration options
- `types.nix` - Custom NixOS types
- `commands.nix` - Command registration
- `systemd.nix` - Systemd services/timers
- `config.nix` - Feature-specific configuration

### Additional Files (as needed):
- `ARCHITECTURE.md` - Detailed architecture documentation
- `CHANGELOG.md` - Feature change history
- `.env.example` - Example environment configuration
- `schema.json` - JSON schema for configuration validation

## Versioning & Migration Strategy

### Overview

**Two-Level Versioning System**:
1. **System Config Migration** (central): Managed by `nixos/core/config/` for `system-config.nix` structure changes
2. **Feature Option Migration** (decentralized): Each feature manages its own option migrations

**Key Principle**: Each feature is responsible for its own versioning and migration.

### When to Version

#### **Major Version (X.0)** - Breaking Changes
Version when:
- ✅ Option names change (e.g., `enable` → `enabled`)
- ✅ Option types change (e.g., `bool` → `enum ["on" "off"]`)
- ✅ Option structure changes (e.g., flat → nested)
- ✅ Required options are removed
- ✅ Default behavior changes significantly
- ✅ Backward compatibility is broken

**Example**:
```nix
# v1.0
options.features.my-feature.enable = mkOption { type = types.bool; };

# v2.0 - BREAKING: Option renamed
options.features.my-feature.enabled = mkOption { type = types.bool; };
```

#### **Minor Version (0.X)** - New Features (Backward Compatible)
Version when:
- ✅ New optional options are added
- ✅ New functionality is added
- ✅ Default values change (but old configs still work)
- ✅ New commands are added
- ✅ Enhancements that don't break existing configs

**Example**:
```nix
# v1.0
options.features.my-feature.enable = mkOption { type = types.bool; };

# v1.1 - NEW: Optional option added (backward compatible)
options.features.my-feature.enable = mkOption { type = types.bool; };
options.features.my-feature.timeout = mkOption { type = types.int; default = 30; };
```

#### **Patch Version (0.0.X)** - Bug Fixes
Version when:
- ✅ Bug fixes that don't change behavior
- ✅ Documentation updates
- ✅ Internal refactoring
- ✅ Performance improvements

**Note**: Patch versions typically don't require migration.

### Versioning Implementation

#### **1. Define Version in `options.nix`**

```nix
# options.nix
let
  featureVersion = "1.0";  # Current feature version
in {
  options.features.my-feature = {
    # Version metadata (optional but recommended)
    _version = mkOption {
      type = types.str;
      default = featureVersion;
      internal = true;  # Hidden from users
      description = "Feature version";
    };
    
    # Actual options
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable my feature";
    };
  };
}
```

#### **2. Create Migration Directory Structure**

```
feature-name/
├── migrations/
│   ├── v1.0-to-v1.1.nix    # Minor version migration
│   ├── v1.0-to-v2.0.nix    # Major version migration
│   └── v1.1-to-v2.0.nix    # Chain migration
```

#### **3. Migration Plan Structure**

```nix
# migrations/v1.0-to-v2.0.nix
{ lib, ... }:

{
  # Source and target versions
  fromVersion = "1.0";
  toVersion = "2.0";
  
  # Option renamings (old → new)
  optionRenamings = {
    "features.my-feature.enable" = "features.my-feature.enabled";
  };
  
  # Option removals (will be removed, user must update manually)
  optionsRemoved = [
    "features.my-feature.oldOption"
  ];
  
  # Option additions (new options with defaults)
  optionsAdded = {
    "features.my-feature.newOption" = {
      type = "int";
      default = 30;
      description = "New option";
    };
  };
  
  # Type conversions (if needed)
  typeConversions = {
    "features.my-feature.someOption" = {
      from = "bool";
      to = "enum";
      converter = "bool-to-enum";  # Custom converter function
    };
  };
  
  # Migration script (optional, for complex migrations)
  migrationScript = ''
    # Custom migration logic if needed
    # Called after automatic option renamings
  '';
}
```

### Migration Execution

#### **Automatic Migration Pattern**

```nix
# default.nix
let
  cfg = config.features.my-feature;
  currentVersion = "2.0";
  detectedVersion = cfg._version or "1.0";
  
  # Check if migration needed
  needsMigration = detectedVersion != currentVersion;
  
  # Load migration plans
  migrationsDir = ./migrations;
  migrationPlans = lib.mapAttrs (name: _: import (migrationsDir + "/${name}")) 
    (lib.filterAttrs (name: _: lib.hasSuffix ".nix" name) 
      (builtins.readDir migrationsDir));
in {
  config = mkIf cfg.enable {
    # Auto-migration on activation
    system.activationScripts.my-feature-migration = mkIf needsMigration {
      text = ''
        ${pkgs.writeShellScript "migrate-my-feature" ''
          # Migration logic here
          # 1. Detect current version
          # 2. Find migration path
          # 3. Apply migrations step-by-step
          # 4. Update version
        ''}/bin/migrate-my-feature
      '';
    };
  };
}
```

### Migration Best Practices

#### **1. Always Provide Migration Paths**
- ✅ Create migration for every major version change
- ✅ Support chain migrations (v1.0 → v1.1 → v2.0)
- ✅ Never skip versions in migration chain

#### **2. Backward Compatibility**
- ✅ Prefer deprecation warnings over breaking changes
- ✅ Support old option names with warnings (if possible)
- ✅ Provide clear migration instructions

#### **3. Migration Safety**
- ✅ Always create backups before migration
- ✅ Use atomic operations (temp files, only commit on success)
- ✅ Validate migrated config after migration
- ✅ Provide rollback mechanism

#### **4. Documentation**
- ✅ Document breaking changes in `CHANGELOG.md`
- ✅ Provide migration examples
- ✅ Document version history

### Version Detection

#### **Pattern 1: Explicit Version Field**
```nix
# User's config
features.my-feature = {
  _version = "1.0";  # Explicit version
  enable = true;
};
```

#### **Pattern 2: Option Presence Detection**
```nix
# Detect version by checking which options exist
detectedVersion = 
  if cfg.newOption != null then "2.0"
  else if cfg.enable != null then "1.0"
  else "1.0";
```

#### **Pattern 3: Config File Patterns**
```nix
# Check for version-specific patterns in config files
detectionPatterns = {
  "1.0" = [ "enable = " ];
  "2.0" = [ "enabled = " "timeout = " ];
};
```

### Migration Examples

#### **Example 1: Simple Option Rename**

```nix
# v1.0
options.features.backup.enable = mkOption { type = types.bool; };

# v2.0 - Renamed
options.features.backup.enabled = mkOption { type = types.bool; };

# migrations/v1.0-to-v2.0.nix
{
  optionRenamings = {
    "features.backup.enable" = "features.backup.enabled";
  };
}
```

#### **Example 2: Option Type Change**

```nix
# v1.0
options.features.backup.mode = mkOption { 
  type = types.bool;  # true/false
  default = false;
};

# v2.0 - Changed to enum
options.features.backup.mode = mkOption {
  type = types.enum [ "full" "incremental" "disabled" ];
  default = "disabled";
};

# migrations/v1.0-to-v2.0.nix
{
  typeConversions = {
    "features.backup.mode" = {
      from = "bool";
      to = "enum";
      converter = ''
        if [ "$OLD_VALUE" = "true" ]; then
          echo "full"
        else
          echo "disabled"
        fi
      '';
    };
  };
}
```

#### **Example 3: Structure Change**

```nix
# v1.0 - Flat structure
options.features.backup.enable = mkOption { type = types.bool; };
options.features.backup.path = mkOption { type = types.str; };

# v2.0 - Nested structure
options.features.backup.config = {
  enable = mkOption { type = types.bool; };
  path = mkOption { type = types.str; };
};

# migrations/v1.0-to-v2.0.nix
{
  structureMappings = {
    "features.backup.enable" = "features.backup.config.enable";
    "features.backup.path" = "features.backup.config.path";
  };
}
```

### Versioning Checklist

When releasing a new version:

- [ ] **Determine version type** (major/minor/patch)
- [ ] **Update version** in `options.nix`
- [ ] **Create migration plan** in `migrations/vX-to-vY.nix`
- [ ] **Test migration** with old configs
- [ ] **Update documentation** (README.md, CHANGELOG.md)
- [ ] **Add migration script** if needed
- [ ] **Test backward compatibility** (if minor version)
- [ ] **Update examples** in documentation

### Integration with System Config Migration

**Important**: Feature migrations are **independent** of system config migrations.

- System config migration (`nixos/core/config/`) manages `system-config.nix` structure
- Feature migrations manage feature-specific options
- Both can run independently or together

**Example Flow**:
```bash
# System config migration (central)
sudo ncc-migrate-config  # Migrates system-config.nix structure

# Feature migrations (automatic on activation)
sudo nixos-rebuild switch  # Each feature migrates its own options
```

## Example Usage

See existing features like `system-discovery/` or `ssh-client-manager/` for complete examples.

