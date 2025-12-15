# Config Loader Removal - Phase 1: Foundation Setup

## 🎯 Phase Overview
**Time Estimate:** 2 hours
**Goal:** Analyze current system and create consolidated configuration

## 📋 Tasks

### 1. Analyze Current Config-Loader System
- [ ] Read `config-loader.nix` to understand loading mechanism
- [ ] Identify all config template files (`*-config.nix`)
- [ ] Document current config structure and dependencies
- [ ] Verify current system works with config-loader

### 2. Identify All Configuration Templates
- [ ] `hardware-config.nix` - Hardware settings
- [ ] `boot-config.nix` - Bootloader configuration
- [ ] `audio-config.nix` - Audio system settings
- [ ] `desktop-config.nix` - Desktop environment
- [ ] `localization-config.nix` - Locale/timezone
- [ ] `network-config.nix` - Network settings
- [ ] `packages-config.nix` - Package management
- [ ] `user-config.nix` - User configuration
- [ ] `system-manager-config.nix` - System manager settings

### 3. Create Consolidated system-config.nix
- [ ] Create new `system-config.nix` in project root
- [ ] Merge all template configurations into single file
- [ ] Ensure proper Nix syntax and structure
- [ ] Add comments for each section

### 4. Backup Current Working System
- [ ] Create backup of current flake.nix
- [ ] Document current working state
- [ ] Prepare rollback procedure

## 🔍 Analysis Results

### Current Config-Loader Flow:
1. `flake.nix` calls `configLoader.loadSystemConfig`
2. Searches in `configs/` directory for `*-config.nix` files
3. Falls back to `/etc/nixos/configs/` if not found
4. Merges all configs into `systemConfig`

### Template Files Content:
```
hardware-config.nix:
{
  hardware = {
    cpu = "intel";
    gpu = "amd";
    ram = { sizeGB = 8; };
  };
}

boot-config.nix:
{
  bootloader = "systemd-boot";
}

audio-config.nix:
{
  audio = {
    enable = true;
    system = "pipewire";
  };
}
```

### Management Modules to Keep:
- `system-manager` - CLI orchestration
- `module-manager` - API provision (but simplified)
- All CLI submodules (formatter, registry, logging, etc.)

## ✅ Success Criteria
- [ ] All config templates identified and documented
- [ ] `system-config.nix` created with all configurations
- [ ] Current system backup available
- [ ] Clear understanding of what to keep vs remove

## 📝 Notes
- Keep CLI tools functional by preserving management modules
- Remove only the automatic config loading, not the CLI infrastructure
- Ensure all current configurations are preserved in new structure
