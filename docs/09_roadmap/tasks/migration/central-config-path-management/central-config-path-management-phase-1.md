# Central Config Path Management - Phase 1: Foundations Setup

## 🎯 Phase Overview

**Duration**: 2 days
**Focus**: Create the core infrastructure for centralized config management
**Goal**: Establish the foundational components without breaking existing functionality

## 📋 Objectives

- [ ] Create module metadata schema and validation system
- [ ] Implement basic config path resolver with strategy support
- [ ] Add new configuration options to module manager
- [ ] Create migration utility functions
- [ ] Set up categorized config directory structure

## 🔧 Implementation Steps

### Day 1: Module Metadata Schema

#### 1.1 Create Module Metadata Schema
**File**: `nixos/core/management/module-manager/lib/module-metadata.nix`

```nix
# Module metadata schema definition
{
  lib,
  ...
}:

let
  # Module scope definitions
  moduleScopes = {
    system = "system";     # System-wide modules (audio, network, etc.)
    shared = "shared";     # Shared modules that can be user-specific (packages)
    user = "user";         # Purely user-specific modules (none yet)
  };

  # Module mutability definitions
  moduleMutability = {
    exclusive = "exclusive";  # Only one config source (first wins)
    overlay = "overlay";      # Multiple sources merged (user overrides)
  };

  # Default dimensions by scope
  defaultDimensionsByScope = {
    system = [];           # No dimensions (global)
    shared = ["user"];     # User dimension allowed
    user = ["user"];       # Always user-specific
  };

  # Validate module metadata
  validateModuleMetadata = metadata:
    let
      requiredFields = ["name" "scope" "mutability"];
      hasRequired = lib.all (field: metadata ? ${field}) requiredFields;
      validScope = lib.elem metadata.scope (lib.attrValues moduleScopes);
      validMutability = lib.elem metadata.mutability (lib.attrValues moduleMutability);

      # Dimensions validation
      expectedDimensions = defaultDimensionsByScope.${metadata.scope} or [];
      hasCorrectDimensions = metadata.dimensions or [] == expectedDimensions;
    in
      if !hasRequired then
        throw "Module ${metadata.name}: Missing required fields: ${lib.concatStringsSep ", " requiredFields}"
      else if !validScope then
        throw "Module ${metadata.name}: Invalid scope '${metadata.scope}'. Must be one of: ${lib.concatStringsSep ", " (lib.attrValues moduleScopes)}"
      else if !validMutability then
        throw "Module ${metadata.name}: Invalid mutability '${metadata.mutability}'. Must be one of: ${lib.concatStringsSep ", " (lib.attrValues moduleMutability)}"
      else if !hasCorrectDimensions then
        throw "Module ${metadata.name}: Invalid dimensions ${lib.generators.toJSON metadata.dimensions}. Expected: ${lib.generators.toJSON expectedDimensions}"
      else
        metadata;

  # Create module metadata with defaults
  createModuleMetadata = {
    name,
    scope ? "system",
    mutability ? "overlay",
    dimensions ? null,
    description ? "",
    version ? "1.0",
    mutable ? true,
    ...
  }@args:
    let
      finalDimensions = if dimensions == null
        then defaultDimensionsByScope.${scope} or []
        else dimensions;
    in
      validateModuleMetadata {
        inherit name scope mutability description version mutable;
        dimensions = finalDimensions;
      };

in {
  inherit
    moduleScopes
    moduleMutability
    defaultDimensionsByScope
    validateModuleMetadata
    createModuleMetadata;
}
```

#### 1.2 Add Metadata to Module Manager Library
**File**: `nixos/core/management/module-manager/lib/default.nix`

```nix
# Add metadata import
moduleMetadata = import ./module-metadata.nix { inherit lib; };

# Export metadata functions
inherit (moduleMetadata) createModuleMetadata validateModuleMetadata;
```

### Day 2: Config Path Resolver

#### 2.1 Create Basic Config Path Resolver
**File**: `nixos/core/management/module-manager/lib/config-resolver.nix`

```nix
# Config path resolution logic
{
  lib,
  config,
  ...
}:

let
  cfg = config.core.management.module-manager;

  # Config strategies
  strategies = {
    flat = "flat";                    # /etc/nixos/configs/${module}-config.nix
    categorized = "categorized";      # /etc/nixos/configs/{system,shared,users/}/
    byUser = "by-user";              # /etc/nixos/configs/users/${user}/
    byCategory = "by-category";       # /etc/nixos/configs/${category}/
  };

  # Resolve config paths for a module based on strategy
  resolveConfigPaths = module: dimensions:
    let
      basePath = cfg.baseConfigPath or "/etc/nixos/configs";
      user = dimensions.user or null;
      hostname = dimensions.hostname or null;
      environment = dimensions.environment or null;

      # Strategy-specific path resolution
      pathsByStrategy = {
        flat = [
          "${basePath}/${module.name}-config.nix"
        ];

        categorized = lib.flatten [
          (lib.optional (user != null) "${basePath}/users/${user}/${module.name}.nix")
          "${basePath}/shared/${module.name}.nix"
          "${basePath}/system/${module.name}.nix"
        ];

        byUser = lib.optional (user != null) [
          "${basePath}/users/${user}/${module.name}.nix"
        ];

        byCategory = [
          "${basePath}/${module.scope}/${module.name}.nix"
        ];
      };

      # Filter existing paths (basic existence check)
      existingPaths = builtins.filter builtins.pathExists
        (pathsByStrategy.${cfg.configPathStrategy} or pathsByStrategy.flat);

    in {
      paths = existingPaths;
      strategy = cfg.configPathStrategy;
      precedence = pathsByStrategy.${cfg.configPathStrategy} or [];
    };

  # Load and merge configs from resolved paths
  loadMergedConfig = module: dimensions:
    let
      resolved = resolveConfigPaths module dimensions;
      configs = map (path: import path) resolved.paths;
    in
      if cfg.resolutionMode == "merge"
      then lib.mkMerge configs
      else lib.head configs;  # First wins for now

in {
  inherit
    strategies
    resolveConfigPaths
    loadMergedConfig;
}
```

#### 2.2 Update Module Manager Configuration
**File**: `nixos/core/management/module-manager/module-manager-config.nix`

```nix
{
  # Module Manager Configuration
  core.management.module-manager = {
    # Config path management (NEW)
    configPathStrategy = "categorized";  # flat | categorized | by-user | by-category
    baseConfigPath = "/etc/nixos/configs";
    resolutionMode = "merge";           # first | merge

    # User and environment management
    managedUsers = ["fr4iser"];
    managedHosts = [];
    environments = ["development" "staging" "production"];

    # Module categorization
    moduleCategories = {
      system = ["audio" "boot" "desktop" "hardware" "localization" "network"];
      shared = ["packages"];
      user = [];
    };

    # Advanced options
    enableCaching = true;
    enableGitIntegration = false;
    enableValidation = true;
  };
}
```

#### 2.3 Add Migration Utilities
**File**: `nixos/core/management/module-manager/lib/migration.nix`

```nix
# Migration utilities for config restructuring
{
  lib,
  ...
}:

let
  # Migrate from flat to categorized structure
  migrateFlatToCategorized = basePath: moduleName: scope:
    let
      oldPath = "${basePath}/${moduleName}-config.nix";
      newPath = "${basePath}/${scope}/${moduleName}.nix";
    in
      if builtins.pathExists oldPath && !builtins.pathExists newPath
      then {
        action = "move";
        from = oldPath;
        to = newPath;
        backup = "${oldPath}.backup";
      }
      else null;

  # Create directory structure
  ensureDirectories = basePath: categories:
    let
      createDir = category: "${basePath}/${category}";
      userDirs = map (user: "${basePath}/users/${user}") (import ./config.nix).core.management.module-manager.managedUsers or [];
    in
      map createDir categories ++ userDirs;

in {
  inherit
    migrateFlatToCategorized
    ensureDirectories;
}
```

## ✅ Success Criteria

- [ ] Module metadata schema validates correctly
- [ ] Config path resolver works for all strategies
- [ ] New module manager options are configurable
- [ ] Migration utilities handle basic restructuring
- [ ] Directory structure setup works correctly

## 🧪 Testing

### Unit Tests
- [ ] Test metadata validation with valid/invalid inputs
- [ ] Test path resolution for all strategies
- [ ] Test migration utilities

### Integration Tests
- [ ] Test module manager configuration loading
- [ ] Test directory creation utilities

## 📚 Documentation Updates

- [ ] Update module template with metadata requirements
- [ ] Document new configuration options
- [ ] Create migration guide for basic restructuring

## 🔗 Next Steps

After completing Phase 1:
- Move to Phase 2: Update all modules to use new metadata system
- Ensure backward compatibility is maintained
- Test basic config resolution without breaking existing system
