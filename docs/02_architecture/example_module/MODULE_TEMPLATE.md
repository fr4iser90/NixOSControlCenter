# Module Template

This template defines the recommended structure for **all** NixOS Control Center modules in our unified architecture:

- **Core System modules** (`systemConfig.core.system.*`) - Core OS functionality (enable = true default)
- **Core Management modules** (`systemConfig.core.management.*`) - System management tools (enable = true default)
- **Core Infrastructure modules** (`systemConfig.core.infrastructure.*`) - Core infrastructure (enable = true default)
- **Feature Infrastructure modules** (`systemConfig.features.infrastructure.*`) - Infrastructure features (enable = false default)
- **Feature Security modules** (`systemConfig.features.security.*`) - Security features (enable = false default)
- **Feature Specialized modules** (`systemConfig.features.specialized.*`) - Specialized features (enable = false default)

## Directory Structure

```
module-name/               # Module name
├── README.md              # Module documentation and usage guide
├── default.nix            # Main module (imports all sub-modules)
├── options.nix            # All configuration options
├── types.nix              # Custom NixOS types (optional)
├── commands.nix           # Command-Center registration (optional)
├── systemd.nix            # Systemd services/timers (optional)
├── config.nix             # Module implementation (optional, split from default.nix if too large)
├── module-name-config.nix # User config (symlinked to /etc/nixos/configs/)
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
│   ├── collector-1.nix    # Collector implementation 1
│   └── collector-2.nix    # Collector implementation 2
├── processors/            # Data processing/transformation (optional)
│   ├── processor-1.nix    # Processor implementation 1
│   └── processor-2.nix    # Processor implementation 2
├── validators/            # Input validation (optional)
│   └── validator-1.nix    # Validator implementation
├── formatters/            # Output formatting (optional)
│   └── formatter-1.nix    # Formatter implementation
├── adapters/              # Interface translation (optional)
│   └── adapter-1.nix      # Adapter implementation
├── parsers/               # Parsing logic (optional)
│   └── parser-1.nix       # Parser implementation
├── serializers/           # Serialization logic (optional)
│   └── serializer-1.nix   # Serializer implementation
├── migrations/            # Feature option migrations (optional)
│   ├── v1.0-to-v1.1.nix   # Minor version migration
│   ├── v1.0-to-v2.0.nix   # Major version migration
│   └── v1.1-to-v2.0.nix   # Chain migration
├── builders/              # Build/construction logic (optional)
│   └── builder-1.nix      # Builder implementation
├── monitors/              # Monitoring logic (optional)
│   └── monitor-1.nix      # Monitor implementation
├── notifiers/             # Notification logic (optional)
│   └── notifier-1.nix     # Notifier implementation
├── providers/             # Provider implementations (semantic, optional)
│   ├── provider-a.nix     # Provider A implementation
│   └── provider-b.nix     # Provider B implementation
└── tests/                 # Module tests (optional)
    └── default.nix        # Test suite
```

## Category Differences Explained

### **scripts/** vs **handlers/** vs **processors/** vs **collectors/**

**Flow Example**: User runs command → Script → Handler → Collectors/Processors → Formatter

1. **`scripts/`** = **User Entry Point**
   - What: CLI commands that users execute
   - Does: Parse arguments, validate input, call handlers, format output
   - Example: `ncc-lock` command script

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
- **Purpose**: Main module entry point - **ONLY imports and module structure**
- **Responsibilities**:
  - **ONLY**: Imports all sub-modules (options, types, commands, systemd, config.nix, etc.)
  - **ONLY**: Conditional imports based on `cfg.enable` or module state
  - **MUST NOT**: Contain any `config = { ... }` blocks with implementation logic
  - **MUST NOT**: Contain symlink management, assertions, or system configuration
  - **Rule**: If you need to write implementation logic → create `config.nix` and import it
- **Pattern**: 
  ```nix
  { config, lib, pkgs, systemConfig, ... }:
  let
    cfg = systemConfig.module-name or {};
  in {
    imports = [
      ./options.nix  # Always import options first
    ] ++ (if (cfg.enable or false) then [
      ./sub-module-1
      ./sub-module-2
      ./config.nix  # Implementation logic goes here
    ] else [
      ./config.nix  # Import even if disabled (for symlink management)
    ]);
  }
  ```
- **Why**: Keeps `default.nix` clean and forces separation of concerns

### `options.nix`
- **Purpose**: Define all configuration options
- **Responsibilities**:
  - For **features**: All `options.features.<module-name>` definitions
  - For **core modules**: All `options.systemConfig.<module-name>` definitions
  - Default values and descriptions
  - Type definitions for options
  - **Versioning**: Define `_version` option for all modules (core and features)
- **Rule**: NO implementation logic, only option definitions
- **Required**: **ALL modules** (core and features) must have `options.nix` with versioning
- **Pattern**:
  ```nix
  # ALL modules use the SAME namespace pattern
  options.systemConfig.{top-level}.{domain}.module-name = {
    _version = lib.mkOption { ... };
    enable = lib.mkOption { ... };
    # ... other options
  };

  # Examples:
  # Core system module: options.systemConfig.core.system.audio
  # Core management module: options.systemConfig.core.management.logging
  # Core infrastructure module: options.systemConfig.core.infrastructure.cli-formatter
  # Feature module: options.systemConfig.features.infrastructure.homelab
  ```

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
- **Critical**: Should be inside `mkIf cfg.enable` block when module has enable option
- **Note**: Needed for any module that provides CLI commands

### `systemd.nix`
- **Purpose**: Systemd service and timer definitions
- **Responsibilities**:
  - Systemd services
  - Systemd timers
  - Systemd targets
  - Activation scripts
- **Optional**: Only needed if systemd integration is required

### `module-name-config.nix`
- **Purpose**: User-editable configuration file
- **Responsibilities**:
  - User options and choices (preferences, settings)
  - Configuration values that users can edit
  - Module-specific settings (not system-level logic)
- **Important**: This is **user configuration** - what users want to configure
- **Pattern**:
  ```nix
  {
    module-name = {
      enable = true;        # User choice: enable/disable this module
      theme = "dark";       # User preference: visual theme
      timeout = 30;         # User setting: operation timeout
    };
  }
  ```
- **Access**: Via `systemConfig.module-name` (or `systemConfig.features.module-name` for features)
- **Symlink**: Automatically symlinked to `/etc/nixos/configs/module-name-config.nix` for easy editing

### `config.nix`
- **Purpose**: Module implementation code (NixOS module configuration logic)
- **Responsibilities**:
  - **Symlink management**: Create/update symlinks to `module-name-config.nix` file
  - **Default config creation**: Create default user config if missing
  - **System configuration**: NixOS module config (services, environment, etc.)
  - **Assertions**: Validation of configuration values
  - **Integration**: Integration with other NixOS modules
- **When to use**:
  - **Always**: If module has `module-name-config.nix` → symlink management goes here
  - **Always**: If module has any system configuration → implementation goes here
  - **Rule**: If `default.nix` would contain `config = { ... }` → move it to `config.nix`
- **Important**: This is **system configuration code** (NOT user-editable)
- **Contains**:
  - Symlink management (`system.activationScripts`)
  - Default config creation
  - Implementation logic, system settings, NixOS module config
  - Assertions and validations
- **NOT for**: User options/choices - those go in `module-name-config.nix`
- **Pattern**:
  ```nix
  { config, lib, pkgs, systemConfig, ... }:
  let
    cfg = systemConfig.module-name or {};
    userConfigFile = ./module-name-config.nix;
    symlinkPath = "/etc/nixos/configs/module-name-config.nix";
  in
    lib.mkMerge [
      {
        # Symlink management (always runs)
        system.activationScripts.module-name-config-symlink = ''
          # Create default config if missing
          # Create/update symlink
        '';
      }
      (lib.mkIf (cfg.enable or false) {
        # Module implementation (only when enabled)
        # System configuration
        # Assertions
      })
    ];
  ```

### `lib/`
- **Purpose**: Shared utility functions
- **Structure**:
  - `default.nix`: Exports all library functions
  - `utils.nix`: General utility functions
  - `validators.nix`: Input validation functions
  - `types.nix`: Internal type helpers (if needed)
- **Best Practice**: Keep functions pure and reusable

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
- User Configs: `module-name-config.nix` (user settings)
- System Config: `config.nix` (implementation logic)
- Systemd in `systemd.nix` (service definitions)

### 2. **Command Registration**
- Always register commands in `commands.nix`
- Must be inside `mkIf cfg.enable` block
- Use descriptive names, categories, and help text
- Register all aliases

### 3. **Enable Check Pattern**

**All modules use the same pattern** (just different namespaces):

```nix
# System module example
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.module-name or {};
in
  lib.mkMerge [
    {
      # Symlink management (always runs)
      system.activationScripts.module-name-config-symlink = ''
        # Create symlink and default config
      '';
    }
    (lib.mkIf (cfg.enable or true) {  # Default true for system
      # Only module implementation here
      # System configuration
      # Assertions
    })
  ];

# Management module example
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.management.module-name or {};
in
  lib.mkMerge [
    {
      # Symlink management (always runs)
      system.activationScripts.module-name-config-symlink = ''
        # Create symlink and default config
      '';
    }
    (lib.mkIf (cfg.enable or true) {  # Default true for management
      # Only module implementation here
      # System configuration
      # Assertions
    })
  ];

# Feature module example
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.features.module-name or {};
in
  lib.mkMerge [
    {
      # Symlink management (always runs)
      system.activationScripts.module-name-config-symlink = ''
        # Create symlink and default config
      '';
    }
    (lib.mkIf (cfg.enable or false) {  # Default false for features
      # Only module implementation here
      # System configuration
      # Assertions
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
| `scanners/` | Feature is specifically about scanning | system-lock (scanning is core concept) |
| `services/` | Feature manages services | Only if service management is the core feature |
| `containers/` | Feature manages containers | Only if container management is the core feature |

**Decision Guide**:
1. **Ask**: "Could this logic apply to other features?" → If YES → use generic name
2. **Ask**: "Is this concept central to the feature's identity?" → If NO → use generic name
3. **Ask**: "Would renaming this to a generic term lose important meaning?" → If NO → use generic name

**Examples**:
- ✅ `system-lock/scanners/` → OK (scanning is the core concept)
- ❌ `system-lock/collectors/` → Better (generic data collection)
- ✅ `bootentry-manager/providers/` → OK (provider pattern is central)
- ❌ `vm-manager/handlers/` → Better (generic orchestration logic)
- ✅ `core/management/logging/reporting/collectors/` → OK (generic data collection)
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
- `scanners/` - Scanning logic (only if scanning is core feature, e.g., system-lock)
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
- `CHANGELOG.md` - Module change history (recommended)
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
- ✅ Bug fixes that don't change behavior (SHOULD increase: 1.0.0 → 1.0.1)
- ✅ Critical security fixes (MUST increase: 1.0.0 → 1.0.1)

**Note**: Patch versions typically don't require migration.

**When NOT to increase version**:
- ❌ Code refactorings (no user-visible changes)
- ❌ Documentation-only updates (unless breaking)
- ❌ Internal improvements (unless they fix bugs)
- ❌ Comments or formatting changes

### Versioning Implementation

#### **1. Define Version in `options.nix`**

**For Feature Modules**:
```nix
# options.nix
let
  moduleVersion = "1.0";  # Current module version
in {
  options.features.my-feature = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;  # Hidden from users
      description = "Module version";
    };
    
    # Actual options
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable my feature";
    };
  };
}
```

**For Core Modules**:
```nix
# options.nix
let
  moduleVersion = "1.0";  # Current module version
in {
  options.systemConfig.my-module = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;  # Hidden from users
      description = "Module version";
    };
    
    # Actual options
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable my module";
    };
  };
}
```

**Important**: **ALL modules** (core and features) must define `_version` in `options.nix`.

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
- [ ] **Create migration plan** in `migrations/vX-to-vY.nix` (if breaking changes)
- [ ] **Test migration** with old configs (if breaking changes)
- [ ] **Update CHANGELOG.md** with changes
- [ ] **Update documentation** (README.md)
- [ ] **Add migration script** if needed
- [ ] **Test backward compatibility** (if minor version)
- [ ] **Update examples** in documentation

### CHANGELOG.md

**Purpose**: Track all changes to the module (required for version tracking)

**Location**: `module-name/CHANGELOG.md`

**Format**: Follow [Keep a Changelog](https://keepachangelog.com/) format

**When to Update**:
- ✅ **Always** when version is increased
- ✅ **Always** when breaking changes are made
- ✅ **Always** when new features are added
- ✅ **Recommended** for bugfixes and improvements

**Example**:
```markdown
# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-12-15
### Breaking Changes
- Renamed `enable` → `enabled` option
- Changed `theme.dark` from `bool` to `enum ["light" "dark" "auto"]`
- Removed deprecated `oldOption` (use `newOption` instead)

### Migration Required
- Run migration: `v1.0-to-v2.0.nix`
- Update config: `enabled = true;` (was `enable = true;`)

## [1.1.0] - 2025-12-10
### Added
- New `keyboard.layout` option for keyboard configuration
- Support for additional display managers

### Changed
- Default theme changed from light to dark
- Improved error messages

## [1.0.1] - 2025-12-08
### Fixed
- Fixed symlink creation issue on first activation
- Fixed assertion error for invalid display server values

## [1.0.0] - 2025-12-07
### Added
- Initial release
- Desktop environment support (plasma, gnome, xfce)
- Display server configuration (wayland, x11, hybrid)
- Theme configuration
- Keyboard layout support
```

**Important Notes**:
- **Version MUST be increased** when:
  - Breaking changes (Major: 1.0 → 2.0)
  - New features/options (Minor: 1.0 → 1.1)
  - Bugfixes (Patch: 1.0.0 → 1.0.1)
- **Version does NOT need to increase** for:
  - Code refactorings (no user-visible changes)
  - Documentation-only updates
  - Internal improvements (unless they fix bugs)
- **Client Update Detection**:
  - `ncc system-update` copies all files regardless of version (simple file copy)
  - `ncc check-module-versions` compares `_version` in config vs. code
  - Smart Update (coming soon) will use version comparison for selective updates

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

## Module Types

### Core Modules (`nixos/core/{domain}/{module-name}/`)
- **Purpose**: System-level functionality (always available)
- **Domains**:
  - `system/` - Core OS functionality (`systemConfig.core.system.*`)
  - `management/` - System management tools (`systemConfig.core.management.*`)
  - `infrastructure/` - Core infrastructure (`systemConfig.core.infrastructure.*`)
- **Examples**: `desktop/`, `hardware/`, `network/`, `user/`, `audio/`, `logging/`, `checks/`, `cli-formatter/`
- **Config Location**: `nixos/core/{domain}/{module-name}/{module-name}-config.nix`
- **Config Access**: Via `systemConfig.core.{domain}.{module-name}` in flake.nix
- **Enable Pattern**: Usually always enabled, but can be conditionally configured
- **Options**: Must define `options.systemConfig.core.{domain}.{module-name}` in `options.nix`
- **Versioning**: Must include `_version` option in `options.nix`
- **Required Files**: `default.nix`, `options.nix`, `config.nix` (if has implementation), `{module-name}-config.nix`

### Feature Modules (`nixos/features/{domain}/{module-name}/`)
- **Purpose**: Optional features that can be enabled/disabled
- **Domains**:
  - `infrastructure/` - Infrastructure features (`systemConfig.features.infrastructure.*`)
  - `security/` - Security features (`systemConfig.features.security.*`)
  - `specialized/` - Specialized features (`systemConfig.features.specialized.*`)
- **Examples**: `homelab/`, `vm/`, `ssh-client/`, `lock/`, `ai-workspace/`
- **Config Location**: `nixos/features/{domain}/{module-name}/{module-name}-config.nix`
- **Config Access**: Via `systemConfig.features.{domain}.{module-name}` in flake.nix
- **Enable Pattern**: Must check `cfg.enable` before implementation
- **Options**: Must define `options.systemConfig.features.{domain}.{module-name}` in `options.nix`
- **Versioning**: Must include `_version` option in `options.nix`
- **Required Files**: `default.nix`, `options.nix`, `config.nix` (if has implementation), `{module-name}-config.nix`

## Config File Management Strategy

### Overview
Each module manages its own config files, keeping them co-located with the module code. Config files are symlinked to `/etc/nixos/configs/` for centralized editing.

### Key Distinction

**Two Types of Configuration:**

1. **`config.nix`** (System Config - NOT user-editable)
   - Implementation code
   - System-level configuration
   - NixOS module logic
   - **Location**: `module-name/config.nix`
   - **Purpose**: How the module works internally

2. **`module-name-config.nix`** (User Config - user-editable)
   - User options and choices
   - Preferences and settings
   - **Location**: `module-name/module-name-config.nix`
   - **Symlink**: `/etc/nixos/configs/module-name-config.nix` → points to module config file
   - **Purpose**: What the user wants to configure

### Structure
```
nixos/
├── core/
│   ├── system/
│   │   ├── desktop/
│   │   │   ├── desktop-config.nix  # User-editable config
│   │   │   └── default.nix
│   │   └── hardware/
│   │       ├── hardware-config.nix
│   │       └── default.nix
│   ├── management/
│   │   ├── logging/
│   │   │   ├── logging-config.nix
│   │   │   └── default.nix
│   │   ├── checks/
│   │   │   ├── checks-config.nix
│   │   │   └── default.nix
│   │   └── module-manager/
│   │       ├── module-manager-config.nix
│   │       └── default.nix
│   └── infrastructure/
│       ├── cli-formatter/
│       │   ├── cli-formatter-config.nix
│       │   └── default.nix
│       └── command-center/
│           ├── command-center-config.nix
│           └── default.nix
├── features/
│   ├── infrastructure/
│   │   ├── homelab/
│   │   │   ├── homelab-config.nix
│   │   │   └── default.nix
│   │   └── vm/
│   │       ├── vm-config.nix
│   │       └── default.nix
│   ├── security/
│   │   ├── ssh-client/
│   │   │   ├── ssh-client-config.nix
│   │   │   └── default.nix
│   │   └── lock/
│   │       ├── lock-config.nix
│   │       └── default.nix
│   └── specialized/
│       ├── ai-workspace/
│       │   ├── ai-workspace-config.nix
│       │   └── default.nix
│       └── hackathon/
│           ├── hackathon-config.nix
│           └── default.nix
└── configs/  # Symlinks to module configs (for easy editing)
    ├── desktop-config.nix -> ../core/system/desktop/desktop-config.nix
    ├── hardware-config.nix -> ../core/system/hardware/hardware-config.nix
    ├── logging-config.nix -> ../core/management/logging/logging-config.nix
    ├── checks-config.nix -> ../core/management/checks/checks-config.nix
    ├── cli-formatter-config.nix -> ../core/infrastructure/cli-formatter/cli-formatter-config.nix
    ├── command-center-config.nix -> ../core/management/command-center/command-center-config.nix
    ├── homelab-config.nix -> ../features/infrastructure/homelab/homelab-config.nix
    ├── vm-config.nix -> ../features/infrastructure/vm/vm-config.nix
    ├── ssh-client-config.nix -> ../features/security/ssh-client/ssh-client-config.nix
    ├── lock-config.nix -> ../features/security/lock/lock-config.nix
    ├── ai-workspace-config.nix -> ../features/specialized/ai-workspace/ai-workspace-config.nix
    └── hackathon-config.nix -> ../features/specialized/hackathon/hackathon-config.nix
```

### Benefits
1. **Modularity**: Each module is self-contained with its own configs
2. **Maintainability**: Config changes are co-located with module code
3. **Easy Editing**: Symlinks provide centralized access in `/etc/nixos/configs/`
4. **Version Control**: Configs are versioned with their modules
5. **Migration**: Module migrations can update their own configs

### Symlink Management
Symlinks are created automatically during module activation:
- On `nixos-rebuild switch`, modules create symlinks to their configs
- Symlinks point from `/etc/nixos/configs/` to module config directories
- If config file doesn't exist, module creates a default one

### Implementation Pattern

#### `default.nix` (ONLY imports)
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  # For core modules: systemConfig.core.{domain}.{module-name}
  cfg = systemConfig.core.infrastructure.cli-formatter or {};

  # For feature modules: systemConfig.features.{domain}.{module-name}
  # cfg = systemConfig.features.infrastructure.homelab or {};
in {
  # imports must be at top level
  imports = if (cfg.enable or false) then [
    ./sub-module-1
    ./sub-module-2
    ./config.nix  # Implementation logic
  ] else [
    ./config.nix  # Import even if disabled (for symlink management)
  ];
}
```

#### `config.nix` (ALL implementation)
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  # For core modules: systemConfig.core.{domain}.{module-name}
  cfg = systemConfig.core.infrastructure.cli-formatter or {};

  # For feature modules: systemConfig.features.{domain}.{module-name}
  # cfg = systemConfig.features.infrastructure.homelab or {};

  userConfigFile = ./module-name-config.nix;
  symlinkPath = "/etc/nixos/configs/module-name-config.nix";
in
  lib.mkMerge [
    {
      # Symlink management (always runs, even if disabled)
      system.activationScripts.module-name-config-symlink = ''
        mkdir -p "$(dirname "${symlinkPath}")"

        # Create default config if it doesn't exist
        if [ ! -f "${toString userConfigFile}" ]; then
          mkdir -p "$(dirname "${toString userConfigFile}")"
          cat > "${toString userConfigFile}" <<'EOF'
{
  module-name = {
    enable = false;
    # ... default values
  };
}
EOF
        fi
        
        # Create/Update symlink
        if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
          CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
          EXPECTED_TARGET=$(readlink -f "${toString userConfigFile}" 2>/dev/null || echo "")
          
          if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
            if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
              cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
            fi
            ln -sfn "${toString userConfigFile}" "${symlinkPath}"
          fi
        else
          ln -sfn "${toString userConfigFile}" "${symlinkPath}"
        fi
      '';
    }
    (lib.mkIf (cfg.enable or false) {
      # Module implementation (only when enabled)
      # System configuration
      # Assertions
      # ...
    })
  ];
```

#### Key Rules:
1. **`default.nix`**: ONLY imports, NO `config = { ... }` blocks
2. **`config.nix`**: ALL implementation logic, symlink management, system config
3. **Automatic**: If you need to write `config = { ... }` → create `config.nix` and import it
4. **Separation**: Clear separation between structure (default.nix) and implementation (config.nix)

## Example Usage

### Core System Module Example
See `nixos/core/system/desktop/` for a complete core system module example.

### Core Management Module Example
See `nixos/core/management/logging/` for a complete core management module example.

### Core Infrastructure Module Example
See `nixos/core/infrastructure/cli-formatter/` for a complete core infrastructure module example.

### Feature Module Example
See existing features like `features/security/ssh-client/` or `features/infrastructure/homelab/` for complete feature module examples.
