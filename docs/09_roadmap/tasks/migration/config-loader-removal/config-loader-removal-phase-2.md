# Config Loader Removal - Phase 2: Core Implementation

## 🎯 Phase Overview
**Time Estimate:** 3 hours
**Goal:** Remove config-loader and update all module configurations

## 📋 Tasks

### 1. Update flake.nix
- [ ] Remove config-loader import
- [ ] Remove `systemConfig = configLoader.loadSystemConfig(...)` line
- [ ] Replace with direct `systemConfig = import ./system-config.nix;`
- [ ] Ensure systemConfig is still passed to modules

### 2. Update System Module Configs
Update each `core/system/*/config.nix` to use direct systemConfig instead of configHelpers:

#### hardware/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.hardware`

#### boot/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.bootloader`

#### audio/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.audio`

#### desktop/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.desktop`

#### localization/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.localization`

#### network/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.network`

#### packages/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.packages`

#### user/config.nix
- [ ] Remove configHelpers import
- [ ] Replace `configHelpers.createModuleConfig` with direct config
- [ ] Read from `systemConfig.users`

### 3. Preserve Management Modules
- [ ] Keep `system-manager` and `module-manager` in `core/default.nix`
- [ ] Ensure CLI tools still have their APIs
- [ ] Keep all CLI submodules functional

### 4. Test Basic System Rebuild
- [ ] Run `sudo nixos-rebuild build` to check for syntax errors
- [ ] Fix any import or configuration errors
- [ ] Ensure all modules can read from systemConfig

## 🔧 Implementation Details

### flake.nix Changes:
```nix
# BEFORE:
configLoader = import ./core/management/system-manager/lib/config-loader.nix {};
systemConfig = configLoader.loadSystemConfig ./. (./. + "/system-config.nix") (./. + "/configs");

# AFTER:
systemConfig = import ./system-config.nix;
```

### Module Config Pattern:
```nix
# BEFORE:
{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  defaultConfig = builtins.readFile ./hardware-config.nix;
in {
  config = lib.mkIf ((systemConfig.system.hardware.enable or false) || true)
    (configHelpers.createModuleConfig {
      moduleName = "hardware";
      defaultConfig = defaultConfig;
    });
}

# AFTER:
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.hardware or {};
in {
  config = lib.mkIf (cfg.enable or true) {
    # Direct hardware configuration here
    boot.kernelModules = [ "kvm-amd" ];
    hardware.graphics.enable = true;
  };
}
```

## ✅ Success Criteria
- [ ] flake.nix updated successfully
- [ ] All system module configs updated
- [ ] Management modules preserved
- [ ] Basic rebuild succeeds without errors

## 📝 Notes
- Focus on getting the system to build first
- CLI functionality will be verified in next phase
- Keep management modules to preserve CLI tools
