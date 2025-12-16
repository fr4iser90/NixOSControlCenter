# Central Config Path Management - Phase 5: Deployment & Documentation

## 🎯 Phase Overview

**Duration**: 1 day
**Focus**: Final validation and production deployment
**Goal**: Successfully deploy  config management system

## 📋 Objectives

- [ ] Full flake build validation
- [ ] Production deployment test
- [ ] Documentation finalization
- [ ] User acceptance validation
- [ ] Performance monitoring setup

## 🔧 Implementation Steps

### 5.1 Final System Validation

#### Full Flake Build Test

```bash
# Test complete flake evaluation
nix flake check

# Test system build
nixos-rebuild build --flake .#hostname --show-trace

# Test with different strategies
export CONFIG_STRATEGY=categorized
nixos-rebuild build --flake .#hostname
```

#### Production Deployment Test

```bash
# Dry run first
sudo nixos-rebuild dry-run --flake .#hostname

# If successful, deploy
sudo nixos-rebuild switch --flake .#hostname

# Monitor logs
journalctl -f -u nixos-rebuild
```

#### Rollback Validation

Ensure rollback works if needed:

```bash
# Test rollback capability
sudo nixos-rebuild switch --rollback
```

### 5.2 Documentation Finalization

#### 5.2.1 Complete User Documentation

**File**: `docs/central-config-path-management-user-guide.md`

```markdown
# Central Config Path Management - User Guide

## Overview

The central config path management system provides flexible,  Nix-compatible configuration loading.

## Quick Start

### 1. Enable the System

```nix
# flake.nix
{
  inputs.configs.url = "path:/etc/nixos/configs";
  inputs.configs.flake = false;
}

# nixos configuration
{
  core.management.module-manager = {
    configPathStrategy = "categorized";
    baseConfigPath = inputs.configs;
    managedUsers = ["yourusername"];
  };
}
```

### 2. Organize Configs

```
/etc/nixos/configs/
├── system/
│   ├── audio.nix
│   ├── packages.nix
│   └── network.nix
├── shared/
│   ├── packages.nix
│   └── desktop.nix
└── users/
    └── yourusername/
        ├── packages.nix
        └── audio.nix
```

### 3. Create User-Specific Config

```nix
# /etc/nixos/configs/users/yourusername/packages.nix
{
  packages = {
    additional = [
      "vscode"
      "firefox"
    ];
  };
}
```

## Advanced Usage

### Dimension-Based Configs

The system supports automatic config resolution based on dimensions:

- **User**: `users/{username}/module.nix`
- **Host**: `hosts/{hostname}/module.nix`
- **Environment**: `environments/{env}/module.nix`

### Config Precedence

Configs are merged in this order (last wins):
1. System defaults
2. Shared configs
3. Environment configs
4. Host configs
5. User configs (highest priority)

## Troubleshooting

### Common Issues

**Pure Evaluation Errors**
- Ensure no absolute paths in `baseConfigPath`
- Use `inputs.configs` or relative paths

**Config Not Loading**
- Check file permissions
- Verify flake inputs configuration
- Use `module-manager show-paths modulename` to debug

**Performance Issues**
- The system is  and should not impact evaluation speed significantly
- If slow, check for circular dependencies

### Debug Commands

```bash
# Show resolved paths for a module
module-manager show-paths audio

# Validate config structure
module-manager validate-configs

# Test  evaluation
nix-instantiate --eval nixos/core/management/module-manager/lib/config-path-resolver.test.nix
```
```

#### 5.2.2 Developer Documentation

**File**: `docs/central-config-path-management-developer-guide.md`

```markdown
# Central Config Path Management - Developer Guide

## Architecture

The system consists of three main components:

1. **config-path-resolver.nix**:  path resolution logic
2. **config-merger.nix**:  config merging logic
3. **Module integration**: Updated modules using the resolver

## API Reference

### resolveConfigPaths(strategy, moduleName, dimensions)

**Parameters:**
- `strategy`: "flat" | "categorized"
- `moduleName`: String (e.g., "audio")
- `dimensions`: { user?, hostname?, environment? }

**Returns:** Array of potential config paths

### loadMergedConfig(moduleName, dimensions)

**Parameters:**
- `moduleName`: String
- `dimensions`: Dimension object

**Returns:** Merged configuration attrset

## Adding New Modules

To add a new module to the system:

1. **Choose scope**: system | shared | user
2. **Add metadata**:
```nix
metadata = {
  name = "mymodule";
  scope = "system";
  mutability = "overlay";
};
```

3. **Use resolver**:
```nix
let
  configResolver = import ../../../../management/module-manager/lib/config-path-resolver.nix {
    inherit lib config;
  };

  resolvedConfig = configResolver.loadMergedConfig "mymodule" {
    user = null;  # For system modules
  };
in {
  config = lib.mkMerge [resolvedConfig { /* defaults */ }];
}
```

## Testing

### Unit Tests
```bash
# Run resolver tests
nix-instantiate --eval nixos/core/management/module-manager/lib/config-path-resolver.test.nix
```

### Integration Tests
```bash
# Run NixOS integration test
nix build .#checks.x86_64-linux.central-config-path-management
```
```

### 5.3 Performance Monitoring

#### 5.3.1 Set Up Monitoring

```bash
# Add to system monitoring
{
  # Monitor evaluation time
  systemd.services."config-evaluation-monitor" = {
    description = "Monitor config evaluation performance";
    script = ''
      start_time=$(date +%s%N)
      nix-instantiate --eval nixos/flake.nix >/dev/null
      end_time=$(date +%s%N)
      duration=$(( (end_time - start_time) / 1000000 ))
      echo "Config evaluation took: ${duration}ms" | systemd-cat
    '';
  };
}
```

### 5.4 User Acceptance

#### 5.4.1 Final Validation Checklist

- [ ] System boots successfully
- [ ] All services start correctly
- [ ] User-specific configs load
- [ ] Performance acceptable
- [ ] Documentation accessible

#### 5.4.2 User Feedback Collection

Set up feedback mechanism for users to report issues.

## ✅ Success Criteria

- [ ] Full system deploys successfully in production
- [ ] All documentation complete and accurate
- [ ] Performance meets requirements
- [ ] User acceptance testing passes
- [ ] Rollback procedures validated

## 🎉 Completion

After Phase 5: **Central Config Path Management System is production-ready!**

### Key Achievements

- ✅ **Pure Nix Compatible**: No absolute paths, works in  evaluation
- ✅ **Flexible Configuration**: Multiple strategies and dimensions
- ✅ **Centralized Management**: Module Manager controls all config paths
- ✅ **Backward Compatible**: Existing setups continue to work
- ✅ **Well Documented**: Comprehensive guides and API docs
- ✅ **Thoroughly Tested**: Unit, integration, and performance tests

### Next Steps

The system is now ready for:
- User adoption
- Further feature development
- Integration with other NixOS Control Center components

**Congratulations! 🎯**
