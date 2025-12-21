# Module Manager Integration - Phase 2: Core Module Migration

## 🎯 PHASE OVERVIEW

**Estimated Time**: 3 hours
**Status**: Pending
**Goal**: Migrate all core/base modules to use the new config system

## 📋 TASK BREAKDOWN

### 🔄 PENDING TASKS

#### 1. Add Metadata to Root Modules
- [x] Update `core/base/boot/default.nix` with _module.metadata
- [x] Update `core/base/hardware/default.nix` with _module.metadata
- [x] Update `core/base/network/default.nix` with _module.metadata
- [x] Update `core/base/localization/default.nix` with _module.metadata
- [x] Update `core/base/user/default.nix` with _module.metadata
- [x] Update `core/base/desktop/default.nix` with _module.metadata
- [x] Update `core/base/audio/default.nix` with _module.metadata
- [x] Update `core/base/packages/default.nix` with _module.metadata

#### 2. Migrate Config Access Pattern
- [ ] Replace hardcoded `systemConfig.core.base.*` with `getModuleConfig`
- [ ] Use `lib.attrByPath` for robust config access
- [ ] Add default values for safety

#### 3. Update Import Logic
- [ ] Make imports conditional on `cfg.enable`
- [ ] Add debug assertions for development
- [ ] Test enable/disable functionality

## 🔧 IMPLEMENTATION STEPS

### Step 1: Metadata Template

**Add to each root module's default.nix:**

```nix
{
  _module.metadata = {
    role = "internal";  # "internal" | "optional"
    name = "module-name";
    description = "What this module does";
    category = "base";   # base | management | infrastructure | security | specialized
    subcategory = "specific-area";
    stability = "stable";
  };

  # Rest of module definition...
}
```

### Step 2: Config Access Migration

**FROM (hardcoded):**
```nix
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.base.desktop;  # ❌ HARDCODED
in {
  # ...
}
```

**TO (dynamic):**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = lib.attrByPath
    (lib.splitString "." (getModuleConfig "desktop").configPath)
    { enable = (getModuleConfig "desktop").defaultEnable; }
    systemConfig;  # ✅ ROBUST
in {
  imports = if cfg.enable then [
    ./desktop.nix
    # ... other imports
  ] else [];
  # ...
}
```

### Step 3: Module-Specific Updates

#### Boot Module (`core/base/boot/default.nix`)
```nix
# BEFORE
bootCfg = systemConfig.core.base.boot;

# AFTER
bootCfg = getModuleConfig "boot";
```

#### Hardware Module (`core/base/hardware/default.nix`)
```nix
# BEFORE
hardwareCfg = systemConfig.core.base.hardware;

# AFTER
hardwareCfg = getModuleConfig "hardware";
```

#### Network Module (`core/base/network/default.nix`)
```nix
# BEFORE
networkCfg = systemConfig.core.base.network;
localizationCfg = systemConfig.core.base.localization;

# AFTER
networkCfg = getModuleConfig "network";
localizationCfg = getModuleConfig "localization";
```

#### User Module (`core/base/user/default.nix`)
```nix
# BEFORE
userCfg = systemConfig.core.base.user;

# AFTER
userCfg = getModuleConfig "user";
```

#### Desktop Module (`core/base/desktop/default.nix`)
```nix
# BEFORE
desktopCfg = systemConfig.core.base.desktop;

# AFTER
desktopCfg = getModuleConfig "desktop";
```

#### Audio Module (`core/base/audio/default.nix`)
```nix
# BEFORE
audioCfg = systemConfig.core.base.audio;

# AFTER
audioCfg = getModuleConfig "audio";
```

#### Packages Module (`core/base/packages/default.nix`)
```nix
# BEFORE
packagesCfg = systemConfig.core.base.packages;

# AFTER
packagesCfg = getModuleConfig "packages";
```

## 🎯 SUCCESS CRITERIA

- [ ] All core/base modules have _module.metadata
- [ ] All modules use getModuleConfig instead of hardcoded paths
- [ ] All imports are conditional on cfg.enable
- [ ] System builds successfully
- [ ] Module enable/disable works correctly

## 🔍 TESTING

### Test Commands:

```bash
# Test each module individually
sudo nixos-rebuild switch --flake /etc/nixos#Gaming

# Test with modules disabled in config
# Edit systemConfig to disable various modules

# Verify discovery works
nix-instantiate --eval -E 'let discovery = import ./core/management/module-manager/lib/discovery.nix { lib = import <nixpkgs> {}; }; in builtins.length discovery.discoverAllModules'
```

### Debug Assertions:

Add to modules during development:
```nix
assertions = lib.optionals (config.debug or false) [
  {
    assertion = lib.hasAttrByPath
      (lib.splitString "." (getModuleConfig "module-name").configPath)
      systemConfig;
    message = "Missing config path for module-name";
  }
];
```

## 📊 PROGRESS TRACKING

- **Phase Progress**: 0%
- **Time Spent**: 0 minutes
- **Estimated Completion**: 3 hours
- **Modules Remaining**: 8 core modules

## 🚀 NEXT PHASE

After core modules are migrated:

1. ✅ Phase 1: Flake Integration
2. ✅ Phase 2: Core Module Migration
3. 🔄 Phase 3: Management Module Migration
4. 📋 Migrate system-manager and submodules

**All core modules will use dynamic config paths!** 🎯
