# Central Config Path Management - Phase 1:Foundation

## 🎯 Phase Overview

**Duration**: 2 days
**Focus**: EstablishNix compatible foundation
**Goal**: Create resolver library that works inevaluation mode

## 📋 Objectives

- [ ] Verify flake inputs configuration forevaluation
- [ ] Create config-path-resolver.nix withfunctions only
- [ ] Addpath options to module-manager-config.nix
- [ ] Implement flat strategy using relative paths or inputs
- [ ] Basicevaluation tests

## 🔧 Implementation Steps

### Day 1: Flake Input Verification & Basic Setup

#### 1.1 Verify flake.nix Configuration

**File**: `nixos/flake.nix`

Ensure configs input is properly configured forevaluation:

```nix
inputs.configs.url = "path:/etc/nixos/configs";
inputs.configs.flake = false;  # Important forevaluation
```

#### 1.2 CreateConfig Path Resolver

**File**: `nixos/core/management/module-manager/lib/config-path-resolver.nix`

```nix
#Config Path Resolver - NO absolute paths, NO side effects
{
  lib,
  config,
  inputs ? {},  # Optional flake inputs
  ...
}:

let
  cfg = config.core.management.module-manager;

  resolveConfigPaths = strategy: moduleName: dimensions:
    let
      basePath = cfg.baseConfigPath;  # Either input or relative
    in
      if strategy == "flat" then
        ["${basePath}/${moduleName}-config.nix"]
      else if strategy == "categorized" then
        let
          userPath = if dimensions.user != null
            then "${basePath}/users/${dimensions.user}/${moduleName}.nix"
            else null;
          systemPath = "${basePath}/system/${moduleName}.nix";
          sharedPath = "${basePath}/shared/${moduleName}.nix";
        in
          [userPath systemPath sharedPath]  # Filtered later
      else
        throw "Unknown config strategy: ${strategy}";

  filterValidPaths = paths: lib.filter (path: path != null) paths;

  getPrecedencePaths = strategy: moduleName: dimensions:
    filterValidPaths (resolveConfigPaths strategy moduleName dimensions);

in {
  # PublicAPI
  inherit resolveConfigPaths filterValidPaths getPrecedencePaths;
}
```

#### 1.3 AddOptions to Module Manager

**File**: `nixos/core/management/module-manager/module-manager-config.nix`

```nix
{
  config,
  lib,
  inputs ? {},
  ...
}:

let
  cfg = config.core.management.module-manager;
in {
  options.core.management.module-manager = {
    # Pure-compatible path configuration
    configPathStrategy = lib.mkOption {
      type = lib.types.enum ["flat" "categorized"];
      default = "flat";
      description = "Strategy for resolving config paths (pure evaluation compatible)";
    };

    baseConfigPath = lib.mkOption {
      type = lib.types.either lib.types.path lib.types.str;
      default = inputs.configs or "./configs";  # Fallback to relative
      description = "Base path for configs - must be(input or relative)";
    };

    # User management for user-specific configs
    managedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users for which separate configs are managed";
    };
  };
}
```

#### 1.4 Update lib/default.nix

**File**: `nixos/core/management/module-manager/lib/default.nix`

```nix
{
  config,
  lib,
  inputs ? {},
  ...
}:

let
  # Importresolver
  configPathResolver = import ./config-path-resolver.nix {
    inherit lib config inputs;
  };
in {
  # Exportresolver functions
  inherit (configPathResolver) resolveConfigPaths getPrecedencePaths;
}
```

### Day 2: Basic Testing & Validation

#### 2.1 CreateUnit Tests

**File**: `nixos/core/management/module-manager/lib/config-path-resolver.test.nix`

```nix
#unit tests - NO filesystem access, NO side effects
{
  lib,
  ...
}:

let
  # Mockconfig
  mockConfig = {
    core.management.module-manager = {
      configPathStrategy = "flat";
      baseConfigPath = "./configs";
      managedUsers = ["testuser"];
    };
  };

  # Test flat strategy (pure)
  testFlatStrategy = let
    resolver = import ./config-path-resolver.nix {
      inherit lib;
      config = mockConfig;
    };

    paths = resolver.resolveConfigPaths "flat" "audio" {};
    expected = ["./configs/audio-config.nix"];
  in
    if paths == expected then "PASS" else "FAIL: ${toString paths} != ${toString expected}";

  # Test categorized strategy (pure)
  testCategorizedStrategy = let
    resolver = import ./config-path-resolver.nix {
      inherit lib;
      config = mockConfig;
    };

    paths = resolver.resolveConfigPaths "categorized" "audio" { user = "testuser"; };
    expected = [
      "./configs/users/testuser/audio.nix"
      "./configs/system/audio.nix"
      "./configs/shared/audio.nix"
    ];
  in
    if paths == expected then "PASS" else "FAIL: ${toString paths} != ${toString expected}";

in {
  flatStrategy = testFlatStrategy;
  categorizedStrategy = testCategorizedStrategy;
}
```

#### 2.2 TestEvaluation

Run basicevaluation test:

```bash
# Test that the resolver evaluates purely
nix-instantiate --eval --strict nixos/core/management/module-manager/lib/config-path-resolver.test.nix
```

## ✅ Success Criteria

- [ ] config-path-resolver.nix created withfunctions
- [ ] No absolute paths used anywhere
- [ ] Basic unit tests pass
- [ ]evaluation works
- [ ] Flake inputs properly integrated

## 🧪 Testing

###Unit Tests
- [ ] Path resolution functions work
- [ ] Strategy implementations correct
- [ ] No side effects or filesystem access

### Integration Tests
- [ ] Resolver imports successfully
- [ ] Module manager config works

## 📚 Documentation Updates

- [ ]evaluation requirements documented
- [ ] API usage examples added

## 🔗 Next Steps

After Phase 1: Implement advanced resolution with dimensions and merging.
