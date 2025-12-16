# Central Config Path Management - Phase 3: Module Integration

## 🎯 Phase Overview

**Duration**: 4 days
**Focus**: Update all system modules to useresolver
**Goal**: Replace hardcoded paths with centralizedconfig loading

## 📋 Objectives

- [ ] Update packages module to useresolver
- [ ] Update audio module to useresolver
- [ ] Update boot module to useresolver
- [ ] Update desktop module to useresolver
- [ ] Update hardware module to useresolver
- [ ] Update localization module to useresolver
- [ ] Update network module to useresolver
- [ ] Update user module to useresolver
- [ ] Maintain backward compatibility
- [ ] Test each module individually

## 🔧 Implementation Steps

### Pattern forModule Updates

For each module, replace hardcoded imports withresolver:

#### BEFORE (Impure - hardcoded paths):
```nix
# nixos/core/system/packages/default.nix
{ config, lib, ... }:

let
  # HARDCODED PATH - IMPURE!
  configFile = "/etc/nixos/configs/packages-config.nix";
  configData = import configFile;
in {
  # Use configData...
}
```

#### AFTER (Pure - resolver-based):
```nix
# nixos/core/system/packages/default.nix
{ config, lib, ... }:

let
  configResolver = import ../../../../management/module-manager/lib/config-path-resolver.nix {
    inherit lib config;
  };

  resolvedConfig = configResolver.loadMergedConfig "packages" {
    user = null;  # System scope
    hostname = config.networking.hostName or null;
    environment = null;
  };
in {
  # Use resolvedConfig instead of hardcoded import
  config = lib.mkMerge [
    resolvedConfig  # ← Centralized config loading
    {
      # Module defaults...
      environment.systemPackages = lib.mkDefault [
        # ... default packages
      ];
    }
  ];
}
```

### Day 1: Core Modules (packages, audio, boot)

#### 3.1 Update packages Module

**File**: `nixos/core/system/packages/default.nix`

- Replace hardcoded config loading
- Useresolver
- Maintain all existing functionality

#### 3.2 Update audio Module

**File**: `nixos/core/system/audio/default.nix`

- Same pattern as packages
- Preserve all audio configuration logic

#### 3.3 Update boot Module

**File**: `nixos/core/system/boot/default.nix`

- Update to use resolver
- Test bootloader configuration still works

### Day 2: System Modules (desktop, hardware)

#### 3.4 Update desktop Module

**File**: `nixos/core/system/desktop/default.nix`

- Complex module with multiple submodules
- Ensure all desktop configs load correctly

#### 3.5 Update hardware Module

**File**: `nixos/core/system/hardware/default.nix`

- GPU, CPU, memory configuration
- Critical for system functionality

### Day 3: Infrastructure Modules (localization, network, user)

#### 3.6 Update localization Module

**File**: `nixos/core/system/localization/default.nix`

- Timezone, locale settings
- System-wide configuration

#### 3.7 Update network Module

**File**: `nixos/core/system/network/default.nix`

- NetworkManager, firewall settings
- Critical infrastructure

#### 3.8 Update user Module

**File**: `nixos/core/system/user/default.nix`

- User management, home-manager integration
- May need user-specific config loading

### Day 4: Testing & Validation

#### 3.9 Individual Module Testing

Test each updated module:

```bash
# Test each module individually
nixos-rebuild build --flake .#test-host --show-trace

# Check that configs load without errors
nix-instantiate --eval nixos/core/system/packages/default.nix
```

#### 3.10 Backward Compatibility

Ensure old config structure still works during transition.

#### 3.11 Performance Validation

Ensureevaluation performance is maintained.

## ✅ Success Criteria

- [ ] All 8 system modules updated to useresolver
- [ ] No hardcoded paths remain in modules
- [ ] Each module loads configs correctly
- [ ] Backward compatibility maintained
- [ ]evaluation works for all modules

## 🧪 Testing

### Unit Tests
- [ ] Each module evaluates purely
- [ ] Config loading works
- [ ] No import errors

### Integration Tests
- [ ] Full system build succeeds
- [ ] All modules work together
- [ ] Config merging functional

### Regression Tests
- [ ] Old functionality preserved
- [ ] Performance not degraded

## 📚 Documentation Updates

- [ ] Update module READMEs
- [ ] Document resolver usage
- [ ] Migration examples

## 🔗 Next Steps

After Phase 3: Comprehensive testing and validation of the complete system.
