# Module Manager Integration - Phase 3: Management Module Migration

## 🎯 PHASE OVERVIEW

**Estimated Time**: 3 hours
**Status**: Pending
**Goal**: Migrate management modules and submodules to new config system

## 📋 TASK BREAKDOWN

### 🔄 PENDING TASKS

#### 1. Update System Manager
- [x] Migrate `core/management/system-manager/default.nix`
- [x] Add _module.metadata (role: "internal")
- [x] Update config access pattern

#### 2. Update System Manager Submodules
- [x] Migrate `core/management/system-manager/submodules/system-logging/default.nix`
- [x] Migrate `core/management/system-manager/submodules/system-checks/default.nix`
- [x] Add metadata to submodules (implicit "internal" role)
- [x] Update conditional imports

#### 3. Update Module Manager
- [ ] Verify `core/management/module-manager/default.nix` has metadata
- [ ] Confirm module-manager config works correctly
- [ ] Test automatic module discovery

## 🔧 IMPLEMENTATION STEPS

### Step 1: System Manager Migration

**File: `core/management/system-manager/default.nix`**

**BEFORE:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, moduleConfig, ... }:

let
  # Use systemConfig from module-manager (_module.args)
  cfg = getModuleConfig "system-manager";
  # ... rest of module
```

**AFTER (add metadata):**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, moduleConfig, ... }:

{
  _module.metadata = {
    role = "internal";
    name = "system-manager";
    description = "Central system management and configuration";
    category = "management";
    subcategory = "system";
    stability = "stable";
  };

  imports = [
    ./options.nix
    ./config.nix
  ];
}

# Rest of module definition...
```

### Step 2: Submodule Migration

**File: `core/management/system-manager/submodules/system-logging/default.nix`**

**BEFORE:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
{
  imports = [
    ./options.nix
  ] ++ (lib.optionals ((getModuleConfig "core.management.system-manager.submodules.system-logging").enable or true) [
    ./config.nix
  ]);
}
```

**AFTER (add metadata):**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
{
  _module.metadata = {
    name = "system-logging";
    description = "Centralized system logging configuration";
    # role defaults to "internal" for submodules
  };

  imports = [
    ./options.nix
  ] ++ (lib.optionals ((getModuleConfig "core.management.system-manager.submodules.system-logging").enable or true) [
    ./config.nix
  ]);
}
```

**File: `core/management/system-manager/submodules/system-checks/default.nix`**

**BEFORE:**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "core.management.system-manager.submodules.system-checks";
in {
  imports = [
    ./options.nix
  ] ++ (lib.optionals (cfg.enable or true) [
    ./config.nix
  ]);
}
```

**AFTER (add metadata):**
```nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
{
  _module.metadata = {
    name = "system-checks";
    description = "Automated system health checks and monitoring";
    # role defaults to "internal" for submodules
  };

  imports = [
    ./options.nix
  ] ++ (lib.optionals ((getModuleConfig "core.management.system-manager.submodules.system-checks").enable or true) [
    ./config.nix
  ]);
}
```

### Step 3: Module Manager Verification

**File: `core/management/module-manager/default.nix`**

**Verify it has metadata:**
```nix
{
  _module.metadata = {
    role = "internal";
    name = "module-manager";
    description = "Automatic module discovery and configuration management";
    category = "management";
    subcategory = "modules";
    stability = "stable";
  };
  # ...
}
```

## 🎯 SUCCESS CRITERIA

- [ ] System-manager has proper metadata
- [ ] All submodules have metadata (explicit or implicit)
- [ ] Conditional imports work correctly
- [ ] Module discovery finds all modules
- [ ] System builds with management modules
- [ ] Submodule enable/disable works

## 🔍 TESTING

### Test Commands:

```bash
# Test management module loading
sudo nixos-rebuild switch --flake /etc/nixos#Gaming

# Test submodule discovery
nix-instantiate --eval -E 'let discovery = import ./core/management/module-manager/lib/discovery.nix { lib = import <nixpkgs> {}; }; in builtins.filter (m: m.category == "management") discovery.discoverAllModules'

# Test specific submodule
# Enable/disable system-logging in config and rebuild
```

### Debug Commands:

```bash
# Check discovered modules
nix-instantiate --eval -E 'let discovery = import ./core/management/module-manager/lib/discovery.nix { lib = import <nixpkgs> {}; }; in builtins.map (m: m.name) discovery.discoverAllModules'

# Check module configs
nix-instantiate --eval -E 'let lib = import <nixpkgs> {}; systemConfig = {}; moduleConfigLib = import ./core/management/module-manager/lib/module-config.nix; in (moduleConfigLib { inherit lib systemConfig; }).getModuleConfig "system-manager"'
```

## 📊 PROGRESS TRACKING

- **Phase Progress**: 0%
- **Time Spent**: 0 minutes
- **Estimated Completion**: 3 hours
- **Modules Remaining**: 3 management modules + submodules

## 🚀 NEXT PHASE

After management modules are migrated:

1. ✅ Phase 1: Flake Integration
2. ✅ Phase 2: Core Module Migration
3. ✅ Phase 3: Management Module Migration
4. 🔄 Phase 4: Testing & Cleanup
5. 📋 Final testing and documentation

**Management modules will be fully integrated!** 🎯
