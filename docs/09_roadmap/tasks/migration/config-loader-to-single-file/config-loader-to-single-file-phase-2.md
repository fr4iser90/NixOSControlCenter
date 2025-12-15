# Config Loader to Single File - Phase 2: Remove Config Loader

## 🎯 Phase Overview
**Time Estimate:** 3 hours
**Goal:** Fix ALL modules and remove config-loader from flake.nix

## 📋 Tasks

### 1. Update flake.nix
- [ ] Remove configLoader import line
- [ ] Remove systemConfig assignment using configLoader.loadSystemConfig
- [ ] Replace with direct import: `systemConfig = import ./system-config.nix;`

### 2. Fix ALL Module Configurations
Fix each module to read from correct systemConfig paths:

#### System Modules (core/system/*/config.nix):
- [ ] `hardware/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.hardware
- [ ] `boot/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.bootloader
- [ ] `audio/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.audio
- [ ] `desktop/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.desktop and systemConfig.system.localization
- [ ] `localization/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.localization
- [ ] `network/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.network
- [ ] `packages/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.system.packages
- [ ] `user/config.nix` - Keep configHelpers for hardware detection, ensure reads from systemConfig.users

#### Management Modules (keep unchanged for CLI functionality):
- [ ] `module-manager/config.nix` - Keep as-is (reads systemConfig.core.management.module-manager)
- [ ] `system-manager/config.nix` - Keep as-is (reads systemConfig.management.system-manager)
- [ ] `cli-registry/config.nix` - Keep as-is (reads systemConfig.core.management.system-manager.submodules.cli-registry)
- [ ] `cli-formatter/config.nix` - Keep as-is (reads systemConfig.core.management.system-manager.submodules.cli-formatter)
- [ ] `system-update/config.nix` - Keep as-is (reads systemConfig.core.management.system-manager.submodules.system-update)
- [ ] `system-logging/config.nix` - Keep as-is (reads from moduleConfig path)
- [ ] `system-checks/config.nix` - Keep as-is (reads systemConfig.core.management.system-manager.submodules.system-checks)

### 3. Delete Config Loader File
- [ ] Remove `nixos/core/management/system-manager/lib/config-loader.nix`
- [ ] Ensure no other files reference it

### 4. Verify All Imports
- [ ] Confirm system-config.nix is in correct location with all required paths
- [ ] Test that flake.nix can import it
- [ ] Check that all modules can read their expected config paths
- [ ] Verify configHelpers still work for automatic hardware detection

## 🔧 flake.nix Changes

**BEFORE:**
```nix
# Import config loader from system-manager
configLoader = import ./core/management/system-manager/lib/config-loader.nix {};

# Load and merge all configs using centralized loader
systemConfig = configLoader.loadSystemConfig ./. (./. + "/system-config.nix") (./. + "/configs");
```

**AFTER:**
```nix
# Load system configuration directly
systemConfig = import ./system-config.nix;
```

## ✅ Success Criteria
- [ ] flake.nix updated successfully
- [ ] config-loader.nix deleted
- [ ] No import errors in flake.nix
- [ ] systemConfig loads from single file

## 📝 Notes
- Keep all other flake.nix content unchanged
- Ensure systemConfig is still passed to nixosSystem modules
- Verify that configHelpers in modules still work for automatic hardware detection
