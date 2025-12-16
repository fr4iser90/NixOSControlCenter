# Central Config Path Management - Phase 4: Testing & Validation

## 🎯 Phase Overview

**Duration**: 2 days
**Focus**: Comprehensive testing and validation
**Goal**: Ensure Nix system works reliably across all scenarios

## 📋 Objectives

- [ ] evaluation tests for all components
- [ ] Integration tests with flake inputs
- [ ] Performance validation
- [ ] Error handling validation
- [ ] Documentation updates
- [ ] Migration guide creation

## 🔧 Implementation Steps

### Day 1: Evaluation Testing

#### 4.1 Comprehensive Unit Tests

**File**: `nixos/core/management/module-manager/tests/pure-evaluation.test.nix`

```nix
# Comprehensive evaluation tests
{
  lib,
  inputs ? {},
  ...
}:

let
  # Mock config for testing
  mockConfig = {
    core.management.module-manager = {
      configPathStrategy = "categorized";
      baseConfigPath = inputs.configs or "./configs";
      managedUsers = ["alice" "bob"];
    };
    networking.hostName = "test-host";
  };

  # Test resolver with different scenarios
  resolver = import ../lib/config-path-resolver.nix {
    inherit lib;
    config = mockConfig;
    inherit inputs;
  };

  merger = import ../lib/config-merger.nix { inherit lib; };

  # Test cases
  testFlatStrategy = let
    paths = resolver.resolveConfigPaths "flat" "audio" {};
    expected = ["${mockConfig.core.management.module-manager.baseConfigPath}/audio-config.nix"];
  in paths == expected;

  testCategorizedStrategy = let
    paths = resolver.resolveConfigPaths "categorized" "packages" {
      user = "alice";
      hostname = "test-host";
    };
    expected = [
      "${mockConfig.core.management.module-manager.baseConfigPath}/users/alice/packages.nix"
      "${mockConfig.core.management.module-manager.baseConfigPath}/hosts/test-host/packages.nix"
      "${mockConfig.core.management.module-manager.baseConfigPath}/system/packages.nix"
      "${mockConfig.core.management.module-manager.baseConfigPath}/shared/packages.nix"
    ];
  in paths == expected;

  testDimensionValidation = let
    result = builtins.tryEval (
      resolver.validateDimensions { user = "test"; invalidKey = "value"; }
    );
  in !result.success;  # Should fail with invalid dimension

in {
  inherit
    testFlatStrategy
    testCategorizedStrategy
    testDimensionValidation;
}
```

#### 4.2 Integration Tests

**File**: `nixos/tests/central-config-path-management.nix`

```nix
# Integration test for the complete system
{
  lib,
  ...
}:

let
  testSystem = { config, ... }: {
    imports = [
      ../../core/management/module-manager
      ../../core/system/packages
      ../../core/system/audio
      # ... other updated modules
    ];

    # Test configuration
    core.management.module-manager = {
      configPathStrategy = "categorized";
      baseConfigPath = ./test-configs;
      managedUsers = ["testuser"];
    };
  };

in {
  name = "central-config-path-management";
  nodes.machine = testSystem;

  testScript = ''
    # Test that system evaluates and builds
    machine.start()
    machine.wait_for_unit("default.target")

    # Test that configs were loaded
    machine.succeed("systemctl status nixos-rebuild")

    # Test specific functionality
    machine.succeed("which git")  # From packages module
  '';
}
```

#### 4.3 Performance Tests

Measure evaluation time:

```bash
# Time evaluation
time nix-instantiate --eval --strict nixos/flake.nix

# Compare with old system
time nix-instantiate --eval --strict nixos/flake.nix  # Before changes
```

### Day 2: Documentation & Migration

#### 4.4 Create Migration Guide

**File**: `docs/migration/central-config-path-management.md`

```markdown
# Migration Guide: Central Config Path Management

## Overview

This guide helps migrate from hardcoded config paths to centralized config management.

## Before (Old Way)

```nix
# Module with hardcoded paths
let
  configFile = "/etc/nixos/configs/audio-config.nix";
  configData = import configFile;
in {
  services.pipewire = configData.services.pipewire;
}
```

## After (New Way)

```nix
# Module using resolver
let
  configResolver = import ../../../../management/module-manager/lib/config-path-resolver.nix {
    inherit lib config;
  };

  resolvedConfig = configResolver.loadMergedConfig "audio" {
    user = null;
    hostname = config.networking.hostName or null;
  };
in {
  config = lib.mkMerge [
    resolvedConfig
    { /* defaults */ }
  ];
}
```

## Migration Steps

1. Update flake inputs
2. Enable new config strategy
3. Migrate config files to new structure
4. Update modules one by one
5. Test and validate

## Config File Structure

### Old Structure
```
/etc/nixos/configs/
├── audio-config.nix
├── packages-config.nix
└── ...
```

### New Structure (Categorized)
```
/etc/nixos/configs/
├── system/
│   ├── audio.nix
│   └── packages.nix
├── shared/
│   ├── audio.nix
│   └── packages.nix
└── users/
    └── username/
        ├── audio.nix
        └── packages.nix
```
```

#### 4.5 Update Module Documentation

Update README files for all affected modules with new usage patterns.

#### 4.6 CLI Integration

Add commands to module-manager for testing and validation:

```bash
# Test evaluation
module-manager test-pure

# Validate config structure
module-manager validate-configs

# Show resolved paths
module-manager show-paths audio
```

## ✅ Success Criteria

- [ ] All evaluation tests pass
- [ ] Integration tests successful
- [ ] Performance acceptable
- [ ] Documentation complete
- [ ] Migration guide comprehensive

## 🧪 Testing

### Evaluation Tests
- [ ] All resolver functions work in mode
- [ ] No filesystem access during evaluation
- [ ] Error handling works

### Integration Tests
- [ ] Full system builds successfully
- [ ] Config loading works end-to-end
- [ ] Module interactions correct

### Performance Tests
- [ ] Evaluation time < 10% slower than before
- [ ] Memory usage reasonable
- [ ] Build time acceptable

## 📚 Documentation Updates

- [ ] Migration guide completed
- [ ] All module READMEs updated
- [ ] API documentation for resolver
- [ ] Troubleshooting guide

## 🔗 Next Steps

After Phase 4: Final deployment and production validation.
