# Central Config Path Management - Phase 2: Advanced Resolution

## 🎯 Phase Overview

**Duration**: 3 days
**Focus**: Implement advanced path resolution with dimensions
**Goal**: Full resolver functionality with user/host/env support

## 📋 Objectives

- [ ] Complete categorized strategy implementation
- [ ] Add dimension support (user, hostname, environment)
- [ ] Create config-merger.nix forconfig merging
- [ ] Implement loadMergedConfig function
- [ ] Add comprehensive error handling

## 🔧 Implementation Steps

### Day 1: Enhanced Path Resolution

#### 2.1 Extend Resolver with Dimensions

**File**: `nixos/core/management/module-manager/lib/config-path-resolver.nix`

Add full dimension support:

```nix
# Enhanced resolver with dimension support
resolveConfigPaths = strategy: moduleName: dimensions:
  let
    basePath = cfg.baseConfigPath;
    user = dimensions.user or null;
    hostname = dimensions.hostname or null;
    environment = dimensions.environment or null;
  in
    if strategy == "flat" then
      ["${basePath}/${moduleName}-config.nix"]
    else if strategy == "categorized" then
      let
        userPath = if user != null
          then "${basePath}/users/${user}/${moduleName}.nix"
          else null;
        hostPath = if hostname != null
          then "${basePath}/hosts/${hostname}/${moduleName}.nix"
          else null;
        envPath = if environment != null
          then "${basePath}/environments/${environment}/${moduleName}.nix"
          else null;
        sharedPath = "${basePath}/shared/${moduleName}.nix";
        systemPath = "${basePath}/system/${moduleName}.nix";
      in
        # Precedence order: user > host > env > shared > system
        [userPath hostPath envPath sharedPath systemPath]
    else
      throw "Unknown strategy: ${strategy}";
```

#### 2.2 Add Dimension Validation

```nix
validateDimensions = dimensions:
  let
    validKeys = ["user" "hostname" "environment"];
    invalidKeys = lib.attrNames (lib.filterAttrs (k: v: !lib.elem k validKeys) dimensions);
  in
    if invalidKeys != []
    then throw "Invalid dimension keys: ${lib.concatStringsSep ", " invalidKeys}"
    else dimensions;
```

### Day 2: Config Merging Implementation

#### 2.3 Create Config Merger

**File**: `nixos/core/management/module-manager/lib/config-merger.nix`

```nix
#config merger - NO side effects
{
  lib,
  ...
}:

let
  mergeConfigs = configs:
    let
      validConfigs = lib.filter (cfg: cfg != {} && cfg != null) configs;
    in
      lib.mkMerge validConfigs;

  loadAndMerge = paths: dimensions:
    let
      # Inmode, we can't check if files exist
      # Assume all provided paths are valid
      loadedConfigs = map (path: import path) (lib.filter (p: p != null) paths);
    in
      mergeConfigs loadedConfigs;

  getMergeInfo = strategy: moduleName: dimensions:
    let
      paths = resolveConfigPaths strategy moduleName dimensions;
    in {
      inherit paths;
      precedence = [
        "user-specific"   # highest priority
        "host-specific"
        "environment-specific"
        "shared"
        "system"          # lowest priority
      ];
      strategy = strategy;
    };

in {
  inherit mergeConfigs loadAndMerge getMergeInfo;
}
```

#### 2.4 Implement loadMergedConfig

**File**: `nixos/core/management/module-manager/lib/config-path-resolver.nix`

Add the main loading function:

```nix
let
  configMerger = import ./config-merger.nix { inherit lib; };

  # Main function: Resolve paths and load merged config
  loadMergedConfig = moduleName: dimensions:
    let
      validatedDims = validateDimensions dimensions;
      paths = resolveConfigPaths cfg.configPathStrategy moduleName validatedDims;
      validPaths = lib.filter (p: p != null) paths;
    in
      if validPaths == []
      then {}
      else configMerger.loadAndMerge validPaths validatedDims;
```

### Day 3: Error Handling & Testing

#### 2.5 Comprehensive Error Handling

```nix
safeLoadMergedConfig = moduleName: dimensions:
  let
    result = builtins.tryEval (loadMergedConfig moduleName dimensions);
  in
    if result.success
    then result.value
    else {
      error = result.value;
      fallback = {};  # Return empty config on error
    };
```

#### 2.6 Extended Unit Tests

**File**: `nixos/core/management/module-manager/lib/config-path-resolver.test.nix`

Add comprehensive tests for dimensions, merging, and error cases.

#### 2.7 Integration Tests

Test resolver with module manager integration.

## ✅ Success Criteria

- [ ] Categorized strategy with full dimension support
- [ ] Config merging works correctly
- [ ] loadMergedConfig function functional
- [ ] Error handling robust
- [ ] All unit tests pass

## 🧪 Testing

### Unit Tests
- [ ] All dimension combinations work
- [ ] Path precedence correct
- [ ] Config merging logic
- [ ] Error handling scenarios

### Integration Tests
- [ ] Resolver works with module manager
- [ ] Different strategies load correctly

## 📚 Documentation Updates

- [ ] Dimension usage documented
- [ ] Merging behavior explained
- [ ] Error handling guide

## 🔗 Next Steps

After Phase 2: Update all system modules to use theresolver.
