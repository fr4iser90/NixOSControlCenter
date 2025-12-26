# NixOS Control Center - Component-Based Implementation

## **REGEL NUMMER 1: NO HARDCODED PATHS!**
- Niemals hardcoded Pfade wie `"core.management.ncc"` schreiben
- Immer dynamisch aus `getCurrentModuleMetadata` oder Pfad-Struktur ableiten
- Pfade müssen für alle Module funktionieren, nicht nur für NCC

## Architecture Overview

NixOS Control Center is a core module that provides CLI management functionality through reusable components.

## Structure

```
core/management/nixos-control-center/
├── default.nix          # Main module definition
├── options.nix          # Configuration options
├── config.nix           # Implementation
├── commands.nix         # CLI commands
├── api/                 # API definitions
│   ├── cli-formatter.nix    # UI formatting API
│   ├── cli-registry.nix     # Command registry API
│   └── nixos-control-center.nix  # Core APIs
├── api.nix              # Main API orchestrator
└── components/          # Pure implementation components
    ├── cli-formatter/   # UI formatting logic
    └── cli-registry/    # Command registration logic
```

## Implementation Steps

### 1. Create Main Module
- Add nixos-control-center to core/default.nix
- Create default.nix, options.nix, config.nix, commands.nix, api.nix

### 2. Move Components
- Move cli-formatter from system-manager/components/ to nixos-control-center/components/
- Move cli-registry from system-manager/components/ to nixos-control-center/components/

### 3. Clean Components - Detailed Migration

#### Remove Module Files:
- ❌ `components/cli-formatter/default.nix` - Module entry point (delete)
- ❌ `components/cli-formatter/options.nix` - User options (move to main module)
- ❌ `components/cli-formatter/api.nix` - Public API (move to api/ directory)

#### Preserve Implementation:
- ✅ `components/cli-formatter/config.nix` - API setup logic (move to handlers/)
- ✅ `components/cli-formatter/colors.nix` - Utility functions (keep)
- ✅ `components/cli-formatter/core/` - Core formatting logic (keep)
- ✅ `components/cli-formatter/components/` - Sub-components (keep)
- ✅ `components/cli-formatter/interactive/` - Interactive features (keep)
- ✅ `components/cli-formatter/status/` - Status displays (keep)

#### Migration Details:

**Options Migration:**
```nix
# FROM: components/cli-formatter/options.nix
options.${configPath} = {
  enable = mkOption { ... };
  config = mkOption { ... };
  components = mkOption { ... };
};

# TO: nixos-control-center/options.nix
options.systemConfig.core.management.nixos-control-center = {
  cli-formatter = {
    enable = mkOption { ... };  # Moved from component
    config = mkOption { ... };  # Moved from component
    components = mkOption { ... };  # Moved from component
  };
};
```

**API Migration:**
```nix
# FROM: components/cli-formatter/api.nix
{
  colors = ...;
  text = ...;
  tables = ...;
  # ...
}

# TO: api/cli-formatter.nix
{
  colors = ...;
  text = ...;
  tables = ...;
  # ...
}
```

**Config Migration:**
```nix
# FROM: components/cli-formatter/config.nix
{
  ${configPath}.api = apiValue;
}

# TO: components/cli-formatter/handlers/api-handler.nix
{ config, lib, ... }:
let
  # API setup logic moved here
  apiValue = { ... };
in {
  # Main module sets API
  nixos-control-center.cli-formatter.api = apiValue;
}
```

### 4. Setup API Orchestration - Detailed

**api.nix Structure:**
```nix
# nixos-control-center/api.nix
{
  # Backward compatibility - delegate component APIs
  cli-formatter = import ./api/cli-formatter.nix { inherit lib; };
  cli-registry = import ./api/cli-registry.nix { inherit lib; };

  # New structured access
  format = import ./api/cli-formatter.nix { inherit lib; };
  registry = import ./api/cli-registry.nix { inherit lib; };
  center = import ./api/nixos-control-center.nix { inherit lib; };
}
```

**Handler Integration:**
```nix
# nixos-control-center/default.nix
imports = [
  ./options.nix
  ./config.nix
  # Component handlers
  ./components/cli-formatter/handlers/api-handler.nix
  ./components/cli-registry/handlers/registry-handler.nix
];
```

### 5. Clean system-manager
- Remove component imports from system-manager/default.nix

## API Pattern

```nix
# api.nix orchestrates all APIs
{
  # Backward compatibility
  cli-formatter = import ./api/cli-formatter.nix;
  cli-registry = import ./api/cli-registry.nix;

  # New structured APIs
  format = import ./api/cli-formatter.nix;
  registry = import ./api/cli-registry.nix;
  center = import ./api/nixos-control-center.nix;
}
```

## Success Criteria

- Components are pure implementation (no module files)
- getModuleApi("cli-formatter") works through delegation
- Discovery shows ~15 modules instead of 241+
- Template compliant structure
- Backward compatibility maintained

## Component API Orchestration

The main module orchestrates component APIs through delegation:

```nix
# nixos-control-center/api.nix - Main API
{
  # Delegate component APIs under their original names
  cli-formatter = import ./api/cli-formatter.nix { inherit lib; };
  cli-registry = import ./api/cli-registry.nix { inherit lib; };

  # New structured APIs
  format = import ./api/cli-formatter.nix { inherit lib; };
  registry = import ./api/cli-registry.nix { inherit lib; };
  center = import ./api/nixos-control-center.nix { inherit lib; };
}
```

### API Structure
```
nixos-control-center/
├── api/                    # API definitions by theme
│   ├── cli-formatter.nix   # UI formatting APIs
│   ├── cli-registry.nix    # Command registry APIs
│   └── nixos-control-center.nix  # Core control center APIs
├── api.nix                # Main API orchestrator
└── components/            # Pure implementation
    ├── cli-formatter/     # No default.nix/options.nix!
    └── cli-registry/      # No default.nix/options.nix!
```

### Benefits
- **Backward compatibility**: `getModuleApi("cli-formatter")` continues working
- **Clean architecture**: Components are pure implementation (template compliant)
- **Centralized orchestration**: Main module controls all APIs
- **Scalable**: New APIs added as separate files
- **No hardcoding**: Clean delegation pattern

### Discovery Solution
Components have no module files (default.nix, options.nix) so are not counted as separate modules by discovery, solving the 241+ module problem.
