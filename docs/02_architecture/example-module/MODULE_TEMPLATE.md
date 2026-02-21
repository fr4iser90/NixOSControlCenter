# Module Template

This template defines the recommended structure for **all** NixOS Control Center modules in our unified architecture:

- **Core System modules** (`systemConfig.core.base.*`) - Core OS functionality (always enabled)
- **Core Management modules** (`systemConfig.core.management.*`) - System management tools (always enabled)
- **Core Infrastructure modules** (`systemConfig.core.management.system-manager.submodules.*`) - Core infrastructure (always enabled)
- **Optional Infrastructure modules** (`systemConfig.modules.infrastructure.*`) - Infrastructure modules (enable = false default)
- **Optional Security modules** (`systemConfig.modules.security.*`) - Security modules (enable = false default)
- **Optional Specialized modules** (`systemConfig.modules.specialized.*`) - Specialized modules (enable = false default)

## Architecture Overview

### **Unified Options Structure**
All module options are defined under `systemConfig`:

```nix
# Core modules (always enabled)
options.systemConfig.core.base.audio = { ... };
options.systemConfig.core.management.system-manager = { ... };

# Optional modules (user-enabled)
options.systemConfig.modules.infrastructure.homelab = { ... };
options.systemConfig.modules.security.ssh-client = { ... };
```

### **Automatic API Generation & Access**
Module APIs are automatically discoverable and accessible through the generic API system:

```nix
# Filesystem → API Mapping
core/base/audio/ → systemConfig.core.base.audio
modules/infrastructure/homelab/ → systemConfig.modules.infrastructure.homelab

# Generic Access (works everywhere)
ui = config.${getModuleApi "cli-formatter"};        # Runtime access
ui = getModuleApi "cli-formatter";                  # Direct access (build-time)
api = config.${getModuleApi "system-manager"};      # Any module API
```

#### **API Access Patterns**
- **Runtime Code**: `config.${getModuleApi "module-name"}` (config available)
- **Build-Time Code**: `getModuleApi "module-name"` (direct API import)
- **Automatic Context**: `getModuleApi` detects context and returns appropriate value
- **Consistent Syntax**: Same pattern works across all modules and contexts

### **Module Metadata**
All modules require `_module.metadata` for automatic discovery:

```nix
_module.metadata = {
  role = "core";           # "core" | "optional"
  name = "audio";          # Unique module identifier
  description = "Audio system configuration"; # Human-readable description
  category = "base";       # "core" | "base" | "security" | "infrastructure" | "specialized"
  subcategory = "audio";   # Specific subcategory within category
  stability = "stable";    # "stable" | "experimental" | "deprecated" | "beta" | "alpha"
  version = "1.0.0";       # SemVer: MAJOR.MINOR.PATCH
};
```

## Category Differences Explained

### **Core vs Optional Modules**

#### **Core Modules** (`systemConfig.core.*`)
- **Always enabled** (no enable option needed)
- **Critical system functionality**
- **Examples**: audio, packages, desktop, network
- **Located**: `nixos/core/*/`
- **Options**: `systemConfig.core.{domain}.{name}`

#### **Optional Modules** (`systemConfig.modules.*`)
- **User-enabled** (enable option required)
- **Optional functionality**
- **Examples**: homelab, vm, ssh-client
- **Located**: `nixos/modules/*/`
- **Options**: `systemConfig.modules.{domain}.{name}`

### **scripts/** vs **handlers/** vs **collectors/** vs **processors/**

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

## Directory Structure

```
├── core                          # Domain
│   ├── base                      # Category
│   │   ├── audio
│   │   ├── boot
│   │   ├── desktop
│   │   ├── hardware
│   │   ├── localization
│   │   ├── network
│   │   ├── packages
│   │   └── user
│   ├── default.nix
│   └── management                # Category
│       ├── module-manager        # Module
│       └── system-manager        # Module
├── custom                        # custom nix import except example_
│   ├── default.nix
│   ├── example_borg_backup.nix
│   ├── example_command_not_found.nix
│   ├── example_noisetorch.nix
│   └── README.md
├── flake.lock
├── flake.nix
└── modules                       # Optional Modules
    ├── default.nix
    ├── infrastructure            # Category
    │   ├── bootentry-manager     # Module name
    │   ├── homelab-manager       # Module name
    │   └── vm                    # Module name
    ├── security
    │   ├── ssh-client-manager    # Module name
    │   └── ssh-server-manager    # Module name
    ├── specialized
    │   ├── ai-workspace          # Module name
    │   └── hackathon             # Module name
    └── system
        └── lock-manager          # Module name

module-name/               # Module name
├── README.md              # Module documentation and usage guide
├── default.nix            # Main module (metadata + imports - REQUIRED pattern)
├── api/                   # Modulare APIs (für komplexe Module)
│   ├── feature-a.nix      # API für Feature A
│   ├── feature-b.nix      # API für Feature B
│   └── module.nix         # Modul-eigene APIs
├── api.nix                # Module API definition (for getModuleApi access)
├── options.nix            # All configuration options
├── types.nix              # Custom NixOS types (optional)
├── commands.nix           # Command-Center registration (optional)
├── systemd.nix            # Systemd services/timers (optional)
├── config.nix             # Module implementation (optional, split from default.nix if too large)
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
│   ├── validator-1.nix    # Validator implementation
├── formatters/            # Output formatting (optional)
│   ├── formatter-1.nix    # Formatter implementation
├── adapters/              # Interface translation (optional)
│   ├── adapter-1.nix      # Adapter implementation
├── parsers/               # Parsing logic (optional)
│   ├── parser-1.nix       # Parser implementation
├── serializers/           # Serialization logic (optional)
│   ├── serializer-1.nix   # Serializer implementation
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
├── submodules/            # Submodules implementations (semantic, optional)
│   ├── submodule-a/       # Submodule A implementation
│   │   ├── default.nix    # Submodule imports
│   │   ├── options.nix    # Submodule options
│   │   ├── config.nix     # Submodule implementation
│   │   ├── handlers/      # Submodule handlers
│   ├── submodule-b/       # Submodule B implementation
│   │   ├── default.nix    # Submodule imports
│   │   ├── options.nix    # Submodule options
│   │   └── config.nix     # Submodule implementation
│   └── complex-feature/   # Submodule C example
│       ├── default.nix    # Submodule imports
│       ├── options.nix    # Submodule options
│       ├── config.nix     # Submodule implementation
│       ├── lib/           # Submodule utilities
│       ├── scripts/       # Submodule scripts
├── components/            # Small utilities (separate from submodules)
│   ├── ui-helpers.nix     # Small utility functions
│   ├── validation.nix     # Helper functions
├── ui/                    # Multi-Interface UI Support (optional)
│   ├── cli/               # CLI-Interfaces (fzf, gum, etc.)
│   │   ├── fzf/           # fzf-basierte Menus (aus Scripts extrahiert!)
│   │   │   ├── menu.nix   # fzf Menu-Definition
│   │   │   ├── actions.nix # fzf Action-Handler
│   │   │   └── helpers.nix # fzf-spezifische Utilities
│   │   └── interactive/   # Andere CLI-Interfaces (gum, etc.)
│   │       └── ...
│   ├── tui/               # TUI Engine Integration
│   │   ├── menu.nix       # TUI Menu-Definition (verwendet tui-engine)
│   │   ├── actions.nix    # TUI Action-Handler
│   │   └── helpers.nix    # TUI-spezifische Utilities
│   ├── gui/               # GUI für verschiedene DEs (optional)
│   │   ├── plasma/        # KDE Plasma GUI
│   │   │   ├── main.qml   # QML Interface
│   │   │   └── components/# QML Components
│   │   ├── gnome/         # GNOME GUI
│   │   │   ├── main.py    # GTK4/Python Interface
│   │   │   └── widgets/   # GTK Widgets
│   │   ├── generic/       # Generic GUI (Qt/GTK)
│   │   │   └── ...
│   │   └── shared/        # Shared GUI Components
│   │       └── ...
│   └── web/               # Web-Interface (optional, wie nixify)
│       ├── api/           # REST API
│       │   ├── main.go    # Go API Server
│       │   ├── handlers/  # API Handlers
│       │   └── templates/ # HTML Templates
│       ├── frontend/      # Frontend (React/Vue/etc.)
│       │   └── ...
│       └── docker/        # Docker für Web-Service
│           ├── Dockerfile
│           └── docker-compose.yml
├── docker/                # Docker-Konfiguration (optional, aus Root verschoben)
│   ├── docker-compose.yml # Haupt-Compose
│   ├── docker-compose.traefik.yml # Traefik-spezifisch
│   └── Dockerfile         # Falls nötig
├── doc/                   # Detailed documentation (RECOMMENDED)
│   ├── README.md          # Main documentation (optional, if root README is sufficient)
│   ├── ARCHITECTURE.md    # Architecture details
│   ├── API.md             # API reference
│   ├── USAGE.md           # Usage guide
│   ├── SECURITY.md        # Security considerations
│   ├── ROADMAP.md         # Roadmap/plans
│   └── assets/            # Documentation assets (images, diagrams, etc.)
│       ├── architecture.png
│       └── workflow.svg
├── tests/                 # Module tests (optional)
│   └── default.nix        # Test suite
```

## File Descriptions

### `api.nix`
**Purpose**: Module API definition for `getModuleApi` access

**Responsibilities**:
- Define the public API that other modules can access
- Export functions, data structures, and utilities
- Enable build-time API access (when config is not available)
- Keep API stable and well-documented

**Pattern**:
```nix
# api.nix
{ lib }:

let
  # Import internal components
  colors = import ./colors.nix;
  core = import ./core { inherit lib colors; config = {}; };
  components = import ./components { inherit lib colors; config = {}; };

in {
  # Public API exports
  inherit colors;
  inherit (core) text layout;
  inherit (components) lists tables progress boxes;

  # Utility functions
  formatMessage = msg: "[${colors.blue}INFO${colors.reset}] ${msg}";
}
```

### `default.nix`
**Purpose**: Main module entry point - ONLY imports and module structure

**Responsibilities**:
- ONLY: Imports all sub-modules (options, types, commands, systemd, config.nix, etc.)
- ONLY: Conditional imports based on `cfg.enable` or module state
- MUST NOT: Contain any `config = { ... }` blocks with implementation logic
- MUST NOT: Contain assertions, or system configuration
- Rule: If you need to write implementation logic → create `config.nix` and import it

**Pattern**:
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

with lib;

let
  # Calculate module name from directory (generic, not hardcoded)
  moduleName = baseNameOf ./. ;  # "my-module"
  # Get config using getModuleConfig (includes template-config.nix defaults)
  cfg = getModuleConfig moduleName;
  # Get module metadata (for passing to config.nix if needed)
  moduleConfig = getCurrentModuleMetadata ./.;
in {
  # Export moduleName via _module.args for sub-modules that need it
  _module.args = {
    moduleName = moduleName;
  };

  imports = [
    ./options.nix
    # Import commands.nix as function to pass moduleName (prevents infinite recursion)
    # WHY FUNCTION IMPORT? See explanation below!
    (import ./commands.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; moduleName = moduleName; })
  ] ++ lib.optionals (cfg.enable or false) [
    # Import sub-modules only when enabled
    ./sub-module-1
    ./sub-module-2
    ./config.nix  # Implementation logic goes here
  ];
}
```

### `options.nix`
**Purpose**: Define all configuration options

**Pattern (Works for both Core and Optional Modules)**:
```nix
# options.nix
{ lib, getCurrentModuleMetadata, ... }:

let
  moduleVersion = "1.0";
  # Get module metadata to determine configPath dynamically (generic, not hardcoded)
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  # Options must be under systemConfig prefix with dynamic configPath
  options.systemConfig.${configPath} = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option (for optional modules, core modules may omit this)
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable my module";
    };

    # Module-specific options
    # ...
  };
}
```

**Why dynamic configPath?**
- **Generic**: Works for any module without hardcoding paths
- **Automatic**: Discovery system determines the correct path
- **Consistent**: Same pattern works for core and optional modules

### `config.nix`
**Purpose**: Module implementation code (NixOS module configuration logic)

**Pattern**:
```nix
{ config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, configHelpers, ... }:

let
  # Get module metadata (generic, not hardcoded)
  moduleConfig = getCurrentModuleMetadata ./.;
  # Get config with defaults from options.nix and template-config.nix
  # This ensures template defaults are always available
  cfg = getModuleConfigFromPath moduleConfig.configPath;
  # Use the template file as default config
  # configHelpers is available via _module.args (no import needed!)
  defaultConfig = builtins.readFile ./template-config.nix;
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false) (
      (configHelpers.createModuleConfig {
        moduleName = "module-name";
        defaultConfig = defaultConfig;
      }) // {
        # Module implementation (only when enabled)
        # Use cfg for user settings (includes template defaults)
        # System configuration
        # Assertions
      }
    ))
  ];
}
```

**Important Notes**:
- **Return structure**: Must return `{ config = lib.mkMerge [...] }` (not just `lib.mkMerge`)
- **getModuleConfigFromPath**: Ensures defaults from `options.nix` and `template-config.nix` are merged
- **template-config.nix**: Automatically loaded as fallback if config file doesn't exist



## Best Practices

### 1. **Module Metadata**
Every module MUST have `_module.metadata` in `default.nix`:

```nix
_module.metadata = {
  role = "optional";     # "core" | "optional" | "required"
  name = "my-module";    # Unique identifier
  description = "...";   # Human-readable
  category = "infrastructure";  # UI grouping
  subcategory = "containers";   # Sub-grouping
  stability = "stable";  # "stable" | "experimental" | ...
  version = "1.0.0";     # SemVer
};
```

### 2. **Options Structure**
- Core modules: `options.systemConfig.core.{domain}.{name}`
- Optional modules: `options.systemConfig.modules.{domain}.{name}`
- Always include `_version` option

### 3. **API Generation & Access**
- **Automatic API Discovery**: Based on filesystem structure and `_module.metadata`
- **Generic API Access**: Use `getModuleApi "module-name"` for consistent API access
- **Runtime vs Build-Time**: Automatic context detection and API resolution

#### **Generic API Access Pattern**
```nix
# Works everywhere - automatically resolves at runtime or build-time
ui = config.${getModuleApi "cli-formatter"};
api = config.${getModuleApi "system-manager"};

# Or direct API access (when config not available)
ui = getModuleApi "cli-formatter";  # Returns API directly
```

#### **How it Works**
- **Runtime**: `getModuleApi` returns config path (e.g. `"core.management.system-manager.submodules.cli-formatter.api"`)
- **Build-Time**: `getModuleApi` returns imported API directly (avoids config dependency)
- **Automatic**: No manual context detection needed - works in scripts, handlers, etc.

#### **API Definition**
Create `api.nix` in module root for build-time access:
```nix
# cli-formatter/api.nix
{ lib }:
let
  colors = import ./colors.nix;
  # ... API components
in {
  inherit colors;
  text = core.text;
  layout = core.layout;
  # ... exported API
}
```

#### **Module Discovery**
- Automatic based on `_module.metadata` in `default.nix`
- No manual registration needed
- APIs available via `getModuleApi "module-name"`

### 4. **Module Configuration System**
- **Central Functions**: All module access through standardized functions
- **Automatic Discovery**: Module metadata and paths automatically resolved
- **Consistent Access**: Same patterns work across all modules

#### **Core Functions (in `module-manager/lib/module-config.nix`)**

##### **`getModuleConfig` - Access Module Configuration**
```nix
getModuleConfig = moduleName:
  # Returns: Merged config with template-config.nix → options.nix defaults → user config
  # Automatically loads template-config.nix as fallback if config file doesn't exist
  # Example: getModuleConfig "chronicle" → { enable = false; mode = "automatic"; outputDir = "$HOME/.local/share/chronicle"; ... }

# Usage in modules:
let cfg = getModuleConfig "my-module"; in
  # Access user settings with automatic defaults:
  # - cfg.enable (from template-config.nix or user config)
  # - cfg.someOption (from template-config.nix or options.nix default or user config)
  # Template defaults are ALWAYS available, even if config file doesn't exist
```

**Merging Order**:
1. **template-config.nix** (base defaults, always loaded if exists)
2. **options.nix defaults** (from option definitions)
3. **user config file** (from `/etc/nixos/configs/`, overrides everything)

##### **`getModuleMetadata` - Access Module Metadata**
```nix
getModuleMetadata = moduleName:
  # Returns: Complete metadata attrset for module
  # Source: Module's _module.metadata + auto-generated paths from discovery
  # Example: getModuleMetadata "cli-formatter" → {
  #   # FROM MODULE (_module.metadata in default.nix):
  #   name = "cli-formatter";
  #   description = "CLI formatting utilities";
  #   category = "core";
  #   subcategory = "terminal";
  #   stability = "stable";
  #   version = "1.0.0";
  #   role = "core";
  #
  #   # FROM DISCOVERY (auto-generated):
  #   path = "core/management/system-manager/submodules/cli-formatter";  # Filesystem path
  #   configPath = "core.management.system-manager.submodules.cli-formatter";  # Path in systemConfig (from /etc/nixos/configs/)
  #   apiPath = "core.management.system-manager.submodules.cli-formatter";     # Base API path
  #   enablePath = "core.management.system-manager.submodules.cli-formatter.enable"; # Enable path (optional modules)
  # }
```

##### **`getCurrentModuleMetadata` - Current Module Metadata**
```nix
getCurrentModuleMetadata = modulePath:
  # Returns: Auto-generated metadata for module at given path
  # Used internally by modules to get their own paths
  # Contains: name, path, configPath, apiPath, enablePath (all auto-generated)
```

##### **`getModuleApi` - Generic API Access**
```nix
getModuleApi = moduleName:
  # Runtime: Returns API path string (e.g. "core.base.audio.api")
  # Build-Time: Returns imported API attrset directly
  # Automatic context detection using builtins.tryEval builtins.derivation

# Usage patterns:
ui = config.${getModuleApi "cli-formatter"};  # Runtime access
ui = getModuleApi "cli-formatter";            # Build-Time access
```

#### **Module Metadata Sources**

**Metadata comes from two sources:**

##### **1. Module-Defined (in `default.nix`)**
Every module must define `_module.metadata` in `default.nix`:
```nix
_module.metadata = {
  # Module identification (DEFINED BY MODULE)
  role = "optional";              # "core" | "optional" | "required"
  name = "my-module";             # Unique module identifier
  description = "Human readable description";

  # UI categorization (DEFINED BY MODULE)
  category = "infrastructure";    # "core" | "base" | "security" | "infrastructure" | "specialized"
  subcategory = "containers";     # Specific subcategory

  # Module lifecycle (DEFINED BY MODULE)
  stability = "stable";           # "stable" | "experimental" | "deprecated" | "beta" | "alpha"
  version = "1.0.0";              # Semantic versioning (MAJOR.MINOR.PATCH)
};
```

##### **2. Auto-Generated (by Discovery System)**
Based on module metadata + filesystem structure:
```nix
# These are AUTO-GENERATED by the discovery system:
{
  path = "infrastructure/containers/my-module";        # Filesystem path
  configPath = "modules.infrastructure.my-module";     # systemConfig path
  apiPath = "modules.infrastructure.my-module";        # API base path
  enablePath = "modules.infrastructure.my-module.enable"; # Enable option path
}
```

#### **Automatic Path Resolution**
Based on metadata, these paths are automatically generated:
- **Config Path**: `systemConfig.{category}.{subcategory}.{name}` (points to user config in `/etc/nixos/configs/`)
- **API Path**: `{configPath}.api` (for API access)
- **Enable Path**: `{configPath}.enable` (for optional modules)

**Example for cli-formatter:**
```nix
# Metadata
{
  role = "core";
  name = "cli-formatter";
  category = "core";
  subcategory = "management.system-manager.submodules";
}

# Generated paths (point to /etc/nixos/configs/ structure)
configPath = "core.management.system-manager.submodules.cli-formatter"
apiPath = "core.management.system-manager.submodules.cli-formatter.api"
enablePath = "core.management.system-manager.submodules.cli-formatter.enable"
```

### 4. **Enable Pattern**
- Optional modules: Check `cfg.enable`
- Core modules: Always active (no enable check needed)
- Use `mkIf (cfg.enable or false)` for optional modules

## File Descriptions

### `default.nix`
- **Purpose**: Main module entry point - **ONLY imports and module structure**
- **Responsibilities**:
  - **ONLY**: Imports all sub-modules (options, types, commands, systemd, config.nix, etc.)
  - **ONLY**: Conditional imports based on `cfg.enable` or module state
  - **MUST NOT**: Contain any `config = { ... }` blocks with implementation logic
  - **MUST NOT**: Contain assertions, or system configuration
  - **Rule**: If you need to write implementation logic → create `config.nix` and import it
- **Pattern**:
  ```nix
  { config, lib, pkgs, systemConfig, ... }:
  let
    # Module metadata (REQUIRED - define directly here)
    metadata = {
      role = "optional";              # "optional" | "core" | "required"
      name = "my-module";             # Unique module identifier
      description = "My awesome module"; # Human-readable description
      category = "infrastructure";    # "core" | "base" | "security" | "infrastructure" | "specialized"
      subcategory = "containers";     # Specific subcategory within category
      stability = "stable";           # "stable" | "experimental" | "deprecated" | "beta" | "alpha"
      version = "1.0.0";             # SemVer: MAJOR.MINOR.PATCH
    };
  in {
    # REQUIRED: Export metadata for discovery system
    _module.metadata = metadata;

    # Module imports
    imports = [
      ./options.nix  # Always import options first
    ] ++ (if (cfg.enable or false) then [
      ./sub-module-1
      ./sub-module-2
      ./config.nix  # Implementation logic goes here
    ]);
  }
  ```
- **Why**: Keeps `default.nix` clean and forces separation of concerns

### `options.nix`
- **Purpose**: Define all configuration options
- **Responsibilities**:
  - **ALL modules**: `options.systemConfig.{category}.{module-name}` definitions
  - Default values and descriptions
  - Type definitions for options
  - **Versioning**: Define `_version` option for all modules (core and optional)
- **Rule**: NO implementation logic, only option definitions
- **Required**: **ALL modules** (core and optional) must have `options.nix` with versioning
- **Pattern**:
  ```nix
  # ALL modules use the SAME namespace pattern
  options.systemConfig.infrastructure.homelab = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option (for optional modules)
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable homelab module";
    };

    # Module-specific options
    swarm = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["manager" "worker"]);
      default = null;
      description = "Swarm mode configuration";
    };
  };
  ```

### `config.nix`
- **Purpose**: Module implementation code (NixOS module configuration logic)
- **Responsibilities**:
  - **Config Management**: Use framework for automatic config file creation
  - **System configuration**: NixOS module config (services, environment, etc.)
  - **Assertions**: Validation of configuration values
  - **Integration**: Integration with other NixOS modules
- **When to use**:
  - **Always**: If module has any system configuration → implementation goes here
  - **Rule**: If `default.nix` would contain `config = { ... }` → move it to `config.nix`
- **Pattern**:
  ```nix
  { config, lib, pkgs, systemConfig, getModuleConfigFromPath, getCurrentModuleMetadata, configHelpers, ... }:
  let
    # Get module metadata (generic, not hardcoded)
    moduleConfig = getCurrentModuleMetadata ./.;
    # Get config with defaults from options.nix and template-config.nix
    cfg = getModuleConfigFromPath moduleConfig.configPath;
    # Use the template file as default config
    # configHelpers is available via _module.args (no import needed!)
    defaultConfig = builtins.readFile ./template-config.nix;
  in
  {
    config = lib.mkMerge [
      (lib.mkIf (cfg.enable or false) (
        (configHelpers.createModuleConfig {
          moduleName = "homelab";
          defaultConfig = defaultConfig;
        }) // {
          # Module implementation (only when enabled)
          # Use cfg for user settings (includes template defaults)
          # System configuration goes here
          # environment.systemPackages, services, etc.
        }
      ))
    ];
  }
  ```

### `template-config.nix`
- **Purpose**: Default configuration template (automatically loaded as fallback)
- **Responsibilities**:
  - Provide sensible default values for all module options
  - Automatically loaded by `getModuleConfig` if config file doesn't exist
  - Used as base for merging with `options.nix` defaults and user config
- **Critical Rules**:
  - **MUST be FLAT**: No nesting like `modules.example-module = { ... }`
  - The file path determines nesting automatically via `config-loader.nix`
  - Contains only the module's direct options
- **Pattern**:
```nix
# template-config.nix
# IMPORTANT: This must be FLAT - no nesting!
# The file path automatically determines the nesting structure
{
  enable = false;
  option1 = "default-value";
  option2 = 42;
  nested = {
    option = false;
  };
}
```

**How it works**:
1. **Automatic Loading**: `getModuleConfig` automatically loads `template-config.nix` if it exists
2. **Fallback Chain**: `template-config.nix` → `options.nix` defaults → user config file
3. **Merging**: All three sources are merged: `templateDefaults` → `configValue` (with options defaults) → `systemConfigValue` (user config)
4. **File Path Nesting**: `config-loader.nix` automatically nests based on file path:
   - `/etc/nixos/configs/modules/infrastructure/homelab/config.nix` → `systemConfig.modules.infrastructure.homelab`
   - So `template-config.nix` should be flat: `{ enable = false; ... }`

**Example**:
```nix
# ✅ CORRECT (flat)
{
  enable = false;
  mode = "automatic";
  outputDir = "$HOME/.local/share/chronicle";
}

# ❌ WRONG (nested - will cause double nesting!)
{
  modules.specialized.chronicle = {
    enable = false;
    mode = "automatic";
  };
}
```

### `commands.nix`
- **Purpose**: Command-Center command registration
- **Responsibilities**:
  - Create all executable scripts using `pkgs.writeShellScriptBin`
  - Register commands via CLI Registry API: `cliRegistry.registerCommandsFor`
  - Define command metadata (name, description, category, help text)
- **Critical**: 
  - Commands must be wrapped in `{ config = lib.mkMerge [...] }` (not just `lib.mkMerge`)
  - `moduleName` is passed as parameter from `default.nix` (prevents infinite recursion)
  - Use `getModuleConfig moduleName` to get config (includes template defaults)
- **Pattern**:
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  # Get config using getModuleConfig (includes template-config.nix defaults)
  cfg = getModuleConfig moduleName;
  # Get CLI registry API
  cliRegistry = getModuleApi "cli-registry";
  
  # Create script with safe defaults for build-time
  myScript = pkgs.writeShellScriptBin "ncc-my-command" ''
    #!/usr/bin/env bash
    # Command implementation
    echo "Hello from my module!"
    echo "Module: ${moduleName}"
    echo "Enabled: ${toString (cfg.enable or false)}"
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerCommandsFor "my-module" [
      {
        name = "my-command";
        script = "${myScript}/bin/ncc-my-command";
        description = "My awesome command";
        category = "specialized";
        arguments = ["arg1" "arg2"];
        shortHelp = "my-command - Short description";
        longHelp = ''
          Detailed help text here
          
          Usage: ncc my-command [options]
          
          Options:
            arg1    First argument
            arg2    Second argument
        '';
      }
    ])
  ];
}
```

### UI-Architektur (Multi-Interface Support)

Module können mehrere UI-Formen unterstützen:
- **CLI**: fzf-basierte Menus (aus Scripts extrahiert)
- **TUI**: Bubble Tea-basierte Interfaces (via tui-engine)
- **GUI**: Desktop-Environment-spezifische GUIs (Plasma, GNOME, etc.)
- **Web**: Optionaler Web-Service mit REST API

**Wichtig:**
- **fzf aus Scripts extrahieren**: Scripts enthalten nur reine Commands, UI-Logik in `ui/cli/fzf/`
- **TUI via Engine**: Nutze `tui-engine` API für Bubble Tea Interfaces
- **GUI optional**: Nur wenn Modul GUI benötigt
- **Web optional**: Nur wenn Modul Web-Service benötigt (wie nixify)
- **Docker einsortieren**: `docker/` oder `ui/web/docker/` statt Root

#### `ui/cli/fzf/` - fzf-basierte CLI-Menus

**Purpose**: fzf-Menus aus Scripts extrahiert (Scripts bleiben clean)

**Pattern**:
```nix
# ui/cli/fzf/menu.nix
{ lib, pkgs, cfg, ... }:

let
  # fzf Menu-Definition
  menuItems = [
    { name = "Connect"; action = "connect"; }
    { name = "List"; action = "list"; }
    { name = "Add"; action = "add"; }
  ];
  
  fzfMenu = pkgs.writeShellScriptBin "ncc-example-fzf" ''
    #!/usr/bin/env bash
    # fzf Menu Implementation
    SELECTION=$(printf '%s\n' "${lib.concatMapStringsSep "\n" (item: item.name) menuItems}" | ${pkgs.fzf}/bin/fzf)
    # Handle selection...
  '';
in
  fzfMenu
```

#### `ui/tui/` - TUI Engine Integration

**Purpose**: Bubble Tea-basierte TUI via tui-engine

**Pattern**:
```nix
# ui/tui/menu.nix
{ lib, pkgs, getModuleApi, cfg, ... }:

let
  tuiEngine = getModuleApi "tui-engine";
  
  # TUI Menu-Definition (verwendet tui-engine Templates)
  tui = tuiEngine.templates."5panel".createTUI
    "📦 Example Module"
    [ "📋 List" "🔍 Search" "⚙️ Settings" "❌ Quit" ]
    actions.getList
    actions.getSearch
    actions.getDetails
    actions.getActions;
in
  tui
```

#### `ui/gui/` - Desktop GUI (optional)

**Purpose**: DE-spezifische GUIs (Plasma, GNOME, etc.)

**Pattern**:
```nix
# ui/gui/plasma/main.qml (QML für Plasma)
import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    title: "Example Module"
    // GUI Implementation
}
```

#### `ui/web/` - Web-Interface (optional, wie nixify)

**Purpose**: Web-Service mit REST API

**Structure**:
```
ui/web/
├── api/              # REST API Backend
│   ├── main.go       # Go API Server
│   ├── handlers/     # API Handlers
│   └── templates/    # HTML Templates
├── frontend/         # Frontend (optional)
└── docker/           # Docker für Web-Service
    ├── Dockerfile
    └── docker-compose.yml
```

**Pattern**:
```nix
# config.nix - Web-Service Integration
{ config, lib, pkgs, buildGoApplication, gomod2nix, ... }:

let
  webService = buildGoApplication {
    pname = "example-web-service";
    version = "1.0.0";
    src = ./ui/web/api;
    go = pkgs.go;
    modules = ./ui/web/api/gomod2nix.toml;
  };
in
{
  systemd.services.example-web-service = {
    enable = true;
    serviceConfig.ExecStart = "${webService}/bin/example-web-service";
  };
}
```

#### `docker/` - Docker-Konfiguration

**Purpose**: Docker-Compose und Dockerfiles (aus Root verschoben)

**Structure**:
```
docker/
├── docker-compose.yml          # Haupt-Compose
├── docker-compose.traefik.yml  # Traefik-spezifisch
└── Dockerfile                  # Falls nötig
```

**Wichtig**: Docker-Compose nicht im Modul-Root, sondern in `docker/` oder `ui/web/docker/` (wenn nur für Web-Service)

**Why function import (Lambda)?**

Das ist ein wichtiges Konzept! Hier die Erklärung:

**Problem ohne Funktion-Import:**
```nix
# ❌ PROBLEM: Infinite Recursion!
imports = [
  ./commands.nix  # commands.nix braucht moduleName
];
# _module.args wird NACH imports evaluiert!
# → commands.nix wird evaluiert BEVOR moduleName verfügbar ist
# → Infinite Recursion Error!
```

**Lösung mit Funktion-Import:**
```nix
# ✅ LÖSUNG: Funktion-Import mit expliziten Parametern
imports = [
  (import ./commands.nix { 
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi; 
    moduleName = moduleName;  # ← Explizit übergeben, sofort verfügbar!
  })
];
# moduleName ist JETZT verfügbar (aus let-Block oben)
# → commands.nix bekommt moduleName direkt als Parameter
# → Keine Infinite Recursion!
```

**Wie funktioniert `(import ./file.nix { ... })`?**
- `import ./file.nix` ist eine Funktion, die Parameter erwartet
- `{ ... }` sind die Argumente, die an die Funktion übergeben werden
- Das Ergebnis ist ein NixOS-Modul (Attribut-Set)
- **Vorteil**: Parameter sind sofort verfügbar, nicht erst nach `_module.args` Evaluation

**Zusammenfassung:**
- **Normaler Import**: `./commands.nix` → Module wird direkt evaluiert, `_module.args` noch nicht verfügbar
- **Funktion-Import**: `(import ./commands.nix { ... })` → Module bekommt Parameter direkt, keine Wartezeit auf `_module.args`
- **Warum nötig**: Verhindert Infinite Recursion bei `moduleName` Zugriff

## Best Practices

### 1. **Enable Check Pattern**
**All optional modules use the same pattern:**

```nix
# default.nix
imports = [
  ./options.nix
] ++ (if (cfg.enable or false) then [
  ./config.nix
  ./commands.nix
]);

# config.nix
lib.mkIf (cfg.enable or false) {
  # Implementation here
};
```

### 2. **Module Metadata**
**Always define metadata in default.nix:**

```nix
{ config, lib, ... }:
let
  metadata = {
    role = "optional";
    name = "homelab";
    description = "Homelab environment management";
    category = "infrastructure";
    subcategory = "containers";
    stability = "stable";
    version = "1.0.0";
  };
in {
  _module.metadata = metadata;
  # ... rest of module
};
```

### 3. **Separation of Concerns**
- `default.nix`: Structure and imports only
- `options.nix`: Configuration options only
- `config.nix`: Implementation logic only
- `commands.nix`: CLI commands only

### 4. **Versioning**
- **Major**: Breaking changes (renamed options, changed types)
- **Minor**: New features (new options, new commands)
- **Patch**: Bug fixes (no user-visible changes)

## Example Usage

### Optional Module Example
See `nixos/modules/infrastructure/homelab-manager/` for a complete optional module example.

### Core Module Example
See `nixos/core/base/packages/` for a complete core module example.

## Versioning & Migration

### Versioning Rules
- **Major**: Breaking changes (1.0 → 2.0)
- **Minor**: New features (1.0 → 1.1)
- **Patch**: Bug fixes (1.0.0 → 1.0.1)

### Migration Pattern
```nix
# migrations/v1.0-to-v2.0.nix
{
  fromVersion = "1.0";
  toVersion = "2.0";
  optionRenamings = {
    "oldOption" = "newOption";
  };
}
```

## Documentation Structure

### README.md (Root)
**Purpose**: Module overview, Quick Start, Navigation
**Location**: `module-name/README.md`
**Required**: Yes (for all modules)
**Content**:
- Module description and purpose
- Quick Start guide
- Basic usage examples
- Links to detailed documentation in `doc/`
- Key features overview

**Template**: See `docs/02_architecture/example-module/doc/README_TEMPLATE.md`

### CHANGELOG.md (Root)
**Format**: Keep a Changelog
**Location**: `module-name/CHANGELOG.md` (Root, NOT in doc/)
**Required**: Recommended (for all version changes)
**Why Root**: Standard location, easily accessible, many tools expect it here

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
- Run migration: `migrations/v1.0-to-v2.0.nix`
- Update config: `enabled = true;` (was `enable = true;`)

## [1.1.0] - 2025-12-10
### Added
- New `timeout` option for operation timeouts
- Support for additional container runtimes

### Changed
- Default timeout increased from 30 to 60 seconds
- Improved error messages

## [1.0.1] - 2025-12-08
### Fixed
- Fixed config file creation issue on first activation
- Fixed assertion error for invalid configuration values

## [1.0.0] - 2025-12-07
### Added
- Initial release
- Core functionality for homelab management
- Docker Swarm support
- Container management
- Network configuration
```

### doc/ Directory (Detailed Documentation)
**Purpose**: Detailed documentation for complex modules
**Location**: `module-name/doc/`
**Required**: Recommended (for modules with extensive documentation)
**Structure**:
- `README.md` - Main documentation (optional, if root README is sufficient)
- `ARCHITECTURE.md` - Architecture details, component descriptions
- `API.md` - API reference, function signatures, examples
- `USAGE.md` - Detailed usage guide, examples, best practices
- `SECURITY.md` - Security considerations, threat model
- `ROADMAP.md` - Development roadmap, planned features
- `assets/` - Images, diagrams, screenshots

**Web-Service Support**: The nixify web-service automatically discovers and displays:
- All `.md`, `.txt`, `.rst` files from `doc/`
- `CHANGELOG.md` from root (standard location)
- Assets from `doc/assets/`
- Special file names get nice titles (README, SECURITY, ROADMAP, CHANGELOG, API, USAGE)

**Example Structure**:
```
module-name/
├── README.md              # Overview, Quick Start
├── CHANGELOG.md           # Version history (Root - standard location)
├── doc/
│   ├── ARCHITECTURE.md    # Architecture details
│   ├── API.md             # API reference
│   ├── USAGE.md           # Usage guide
│   ├── SECURITY.md        # Security info
│   ├── ROADMAP.md         # Roadmap
│   └── assets/
│       └── diagram.png
```

**Templates**: See `docs/02_architecture/example-module/doc/` for templates:
- `README_TEMPLATE.md` - README template
- `ARCHITECTURE_TEMPLATE.md` - Architecture documentation template
- `API_TEMPLATE.md` - API reference template
- `USAGE_TEMPLATE.md` - Usage guide template
