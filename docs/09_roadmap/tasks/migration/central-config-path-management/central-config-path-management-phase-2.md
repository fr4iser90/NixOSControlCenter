# Central Config Path Management - Phase 2: Module Discovery Refactor

## 🎯 Phase Overview

**Duration**: 3 days
**Focus**: Update all modules to use centralized path management
**Goal**: Remove hardcoded config paths and implement metadata-driven discovery

## 📋 Objectives

- [ ] Remove hardcoded configFile from all modules
- [ ] Add metadata to all system modules (scope, mutability, dimensions)
- [ ] Update module discovery to use centralized path resolution
- [ ] Implement dimension-based config resolution
- [ ] Add backward compatibility for existing configs

## 🔧 Implementation Steps

### Day 1: Update Core Module Metadata

#### 2.1 Update System Modules with Metadata
**Files to modify**: All `default.nix` files in `nixos/core/system/`

For each module (audio, boot, desktop, hardware, localization, network), update:

```nix
# Example: nixos/core/system/audio/default.nix
{
  config,
  lib,
  systemConfig,
  ...
}:

let
  # Use centralized config resolution
  configResolver = import ../../../../management/module-manager/lib/config-resolver.nix {
    inherit lib config;
  };

  # Module metadata (NEW)
  metadata = {
    name = "audio";
    scope = "system";              # system | shared | user
    mutability = "overlay";        # exclusive | overlay
    dimensions = [];               # [] for system scope
    description = "Audio system configuration";
    version = "1.0";
    mutable = true;
  };

  # Get resolved config paths
  resolvedConfig = configResolver.loadMergedConfig metadata {
    user = null;  # System scope has no user dimension
    hostname = config.networking.hostName or null;
    environment = null;
  };

in {
  # Module metadata for discovery system
  _module.metadata = metadata;

  # Configuration (using resolved config)
  config = lib.mkMerge [
    resolvedConfig
    # Module-specific defaults
    {
      hardware.pulseaudio.enable = lib.mkDefault true;
      # ... rest of module config
    }
  ];
}
```

#### 2.2 Update Shared Modules
**File**: `nixos/core/system/packages/default.nix`

```nix
# packages module (shared scope)
{
  config,
  lib,
  systemConfig,
  ...
}:

let
  configResolver = import ../../../../management/module-manager/lib/config-resolver.nix {
    inherit lib config;
  };

  metadata = {
    name = "packages";
    scope = "shared";             # Can be system + user specific
    mutability = "overlay";       # User can override
    dimensions = ["user"];        # Supports user dimension
    description = "System and user package management";
    version = "1.0";
    mutable = true;
  };

  # Load system config
  systemConfigResolved = configResolver.loadMergedConfig metadata {
    user = null;
    hostname = config.networking.hostName or null;
    environment = null;
  };

  # Load user-specific config (if user active)
  userConfigResolved = if config.core.management.module-manager.managedUsers != []
    then configResolver.loadMergedConfig metadata {
      user = lib.head config.core.management.module-manager.managedUsers;
      hostname = config.networking.hostName or null;
      environment = null;
    }
    else {};

in {
  _module.metadata = metadata;

  config = lib.mkMerge [
    systemConfigResolved
    userConfigResolved
    # Default system packages
    {
      environment.systemPackages = lib.mkDefault [
        # ... default packages
      ];
    }
  ];
}
```

### Day 2: Update Module Discovery Logic

#### 2.3 Refactor Discovery to Use Metadata
**File**: `nixos/core/management/module-manager/lib/discovery.nix`

```nix
# Updated discovery logic with metadata support
{
  lib,
  ...
}:

let
  flakeRoot = ../../../..;

  # Import config resolver
  configResolver = import ./config-resolver.nix { inherit lib; };

  # Discover modules with metadata
  discoverModulesRecursively = rootDir: rootCategory: let
    scanDir = dir: relativeCategory: let
      contents = builtins.readDir dir;
    in lib.flatten (
      lib.mapAttrsToList (name: type:
        if type == "directory" then
          let
            subDir = "${dir}/${name}";
            hasDefault = builtins.pathExists "${subDir}/default.nix";
            hasOptions = builtins.pathExists "${subDir}/options.nix";
            currentCategory = if relativeCategory == "" then name else "${relativeCategory}.${name}";
          in if hasDefault && hasOptions then
            let
              # Load module to extract metadata
              modulePath = "${subDir}/default.nix";
              moduleConfig = import modulePath {
                config = {};  # Minimal config for metadata extraction
                lib = lib;
                systemConfig = {};
                # ... other minimal args
              };

              # Extract metadata from module
              metadata = moduleConfig._module.metadata or {
                name = name;
                scope = "system";  # Default fallback
                mutability = "overlay";
                dimensions = [];
                description = "${rootCategory} ${currentCategory} module";
                version = "1.0";
                mutable = true;
              };

              # Resolve config paths using centralized resolver
              configResolution = configResolver.resolveConfigPaths metadata {
                user = null;  # Will be resolved at runtime
                hostname = null;
                environment = null;
              };

            in [{
              name = metadata.name;
              domain = rootCategory;
              category = "${rootCategory}.${currentCategory}";
              path = subDir;
              configPath = lib.head configResolution.paths;  # Primary path
              configPaths = configResolution.paths;          # All possible paths (NEW)
              enablePath = "${rootCategory}.${currentCategory}.enable";
              apiPath = "${rootCategory}.${currentCategory}";
              metadata = metadata;                            # Full metadata (NEW)
              description = metadata.description;
              dependencies = [];
              version = metadata.version;
              defaultEnabled = rootCategory == "core";
            }]
            ++ scanDir subDir currentCategory
          else
            scanDir subDir currentCategory
        else []
      ) contents
    );
  in scanDir rootDir "";

  # ... rest of discovery functions remain similar but use metadata
```

### Day 3: Implement Runtime Config Resolution

#### 2.4 Add Runtime Config Loading
**File**: `nixos/core/management/module-manager/lib/default.nix`

```nix
# Enhanced library exports
{
  config,
  lib,
  pkgs,
  systemConfig,
  ...
}:

let
  discovery = import ./discovery.nix { inherit lib; };
  configResolver = import ./config-resolver.nix { inherit lib config; };
  moduleMetadata = import ./module-metadata.nix { inherit lib; };

  # Runtime config resolution for modules
  resolveModuleConfig = module: dimensions:
    let
      metadata = module.metadata or module;  # Backward compatibility
    in
      configResolver.loadMergedConfig metadata dimensions;

  # Get all modules with resolved configs
  allModulesWithConfigs = dimensions:
    let
      modules = discovery.discoverAllModules;
    in
      map (module: module // {
        resolvedConfig = resolveModuleConfig module dimensions;
      }) modules;

in {
  # Discovery functions
  inherit (discovery) discoverAllModules discoverModulesInDir;

  # Config resolution
  inherit resolveModuleConfig allModulesWithConfigs;

  # Metadata functions
  inherit (moduleMetadata) createModuleMetadata validateModuleMetadata;

  # Utility functions
  inherit (utils) updateModuleConfig getModuleStatus enableModule disableModule formatModuleList;
}
```

#### 2.5 Add Backward Compatibility
**File**: `nixos/core/management/module-manager/lib/config-helpers.nix`

```nix
# Enhanced config helpers with backward compatibility
{
  lib,
  ...
}:

let
  # Backward compatible config loading
  loadConfigWithFallback = moduleName: configPath: fallbackPath:
    let
      primaryExists = builtins.pathExists configPath;
      fallbackExists = builtins.pathExists fallbackPath;
    in
      if primaryExists then
        builtins.trace "Loading config from: ${configPath}" (import configPath)
      else if fallbackExists then
        builtins.trace "Loading config from fallback: ${fallbackPath}" (import fallbackPath)
      else
        builtins.trace "No config found for ${moduleName}, using defaults" {};

  # Migration helper for old hardcoded paths
  migrateLegacyConfig = moduleName: oldPath: newPath:
    if builtins.pathExists oldPath && !builtins.pathExists newPath
    then {
      action = "migrate";
      from = oldPath;
      to = newPath;
      module = moduleName;
    }
    else null;

in {
  inherit
    loadConfigWithFallback
    migrateLegacyConfig;
}
```

## ✅ Success Criteria

- [ ] All system modules have proper metadata
- [ ] Module discovery uses centralized resolution
- [ ] Config loading works with new and old paths
- [ ] Backward compatibility maintained
- [ ] System rebuilds successfully

## 🧪 Testing

### Unit Tests
- [ ] Test metadata extraction from modules
- [ ] Test config resolution with different dimensions
- [ ] Test backward compatibility functions

### Integration Tests
- [ ] Test full module discovery with metadata
- [ ] Test system rebuild with updated modules
- [ ] Test config loading from multiple paths

## 📚 Documentation Updates

- [ ] Update module template with metadata examples
- [ ] Document metadata schema requirements
- [ ] Create migration guide for module updates

## 🔗 Next Steps

After completing Phase 2:
- Move to Phase 3: Implement advanced overlay functionality
- Ensure all modules work with new config resolution
- Test user-specific config scenarios
