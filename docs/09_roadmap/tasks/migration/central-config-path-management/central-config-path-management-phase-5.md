# Central Config Path Management - Phase 5: Testing & Documentation

## 🎯 Phase Overview

**Duration**: 3 days
**Focus**: Validate the implementation and prepare for production
**Goal**: Ensure comprehensive testing and complete documentation

## 📋 Objectives

- [ ] Create comprehensive test suite for all config strategies
- [ ] Implement CLI tools for config management and debugging
- [ ] Add performance benchmarks and caching validation
- [ ] Create migration guides and documentation
- [ ] Test end-to-end migration scenarios

## 🔧 Implementation Steps

### Day 1: CLI Tools and Debugging

#### 5.4 Enhanced CLI Commands
**File**: `nixos/core/management/module-manager/commands.nix`

```nix
# Comprehensive CLI commands for config management
{
  config,
  lib,
  ...
}:

let
  cfg = config.core.management.module-manager;

in {
  # Config inspection commands
  "config-inspect" = {
    description = "Inspect configuration for a specific module";
    script = ''
      MODULE="$1"
      if [ -z "$MODULE" ]; then
        echo "Usage: module-manager config-inspect <module-name> [user]"
        exit 1
      fi

      USER="$2"
      echo "=== Config Inspection: $MODULE ==="

      # Show resolved paths
      echo "Resolved config paths:"
      ${lib.concatStringsSep "\n" (map (path: "echo \"  $path\"") [
        "/etc/nixos/configs/system/$MODULE.nix"
        "/etc/nixos/configs/shared/$MODULE.nix"
      ])}
      ${lib.optionalString (USER != "") "echo \"  /etc/nixos/configs/users/$USER/$MODULE.nix\""}

      # Show effective config
      echo ""
      echo "Effective configuration:"
      nix eval --raw ".#nixosConfigurations.$(hostname).config.core.system.$MODULE" 2>/dev/null || echo "Unable to evaluate config"
    '';
  };

  "config-diff" = {
    description = "Show differences between config sources";
    script = ''
      MODULE="$1"
      USER="$2"

      echo "=== Config Diff: $MODULE ==="
      echo "Comparing system vs user configuration"
      echo ""

      # Show diff between system and user configs
      SYSTEM_CONFIG="/etc/nixos/configs/system/$MODULE.nix"
      USER_CONFIG="/etc/nixos/configs/users/$USER/$MODULE.nix"

      if [ -f "$SYSTEM_CONFIG" ] && [ -f "$USER_CONFIG" ]; then
        diff -u "$SYSTEM_CONFIG" "$USER_CONFIG" || true
      else
        echo "Both system and user configs must exist for diff"
      fi
    '';
  };

  "config-create-template" = {
    description = "Create config template for a module";
    script = ''
      MODULE="$1"
      USER="$2"

      if [ -z "$MODULE" ]; then
        echo "Usage: module-manager config-create-template <module-name> [user]"
        exit 1
      fi

      if [ -n "$USER" ]; then
        TARGET_DIR="/etc/nixos/configs/users/$USER"
        TARGET_FILE="$TARGET_DIR/$MODULE.nix"
        mkdir -p "$TARGET_DIR"

        # Create user-specific template
        cat > "$TARGET_FILE" << 'EOF'
# User-specific configuration for MODULE
# This will override system defaults

{
  # Example: Override audio volume
  # audio.volume = 75;

  # Add your user-specific settings here
  # Remember: Some system-level settings cannot be overridden
}
EOF

        echo "Created user config template: $TARGET_FILE"
      else
        echo "Specify a user with --user to create user-specific config"
      fi
    '';
  };

  "config-validate-all" = {
    description = "Validate all configurations (Nix evaluation)";
    script = ''
      echo "=== Config Validation ==="
      echo "Validation happens automatically during nixos-rebuild"
      echo "Use 'nixos-rebuild build' to validate all configurations"
    '';
  };

  "config-show-structure" = {
    description = "Show current config directory structure";
    script = ''
      echo "=== Config Directory Structure ==="
      find /etc/nixos/configs -type f -name "*.nix" | sort | sed 's|/etc/nixos/configs/|  |'
    '';
  };
}
```

#### 5.5 Performance Benchmarking
**Nix performance testing** - Use `time nixos-rebuild build` to measure performance impact.

### Day 3: Documentation and Final Validation

#### 5.6 Create User Documentation
**File**: `docs/02_architecture/config-management.md`

```markdown
# Central Config Path Management

## Overview

The NixOS Control Center uses a centralized config path management system that provides flexible, hierarchical configuration management with support for system-wide, shared, and user-specific settings.

## Config Structure

```
/etc/nixos/configs/
├── system/           # System-wide defaults (audio, network, etc.)
├── shared/           # Shared configs that can be user-specific (packages)
├── users/            # User-specific overrides
│   └── fr4iser/
│       ├── audio.nix
│       └── packages.nix
├── hosts/            # Host-specific configs
└── environments/     # Environment-specific configs (dev/staging/prod)
```

## Configuration Precedence

Configurations are loaded in the following order (later sources override earlier ones):

1. **System configs** (`system/`): Base system defaults
2. **Shared configs** (`shared/`): Optional shared settings
3. **User configs** (`users/{user}/`): User-specific overrides
4. **Host configs** (`hosts/{hostname}/`): Host-specific settings
5. **Environment configs** (`environments/{env}/`): Environment-specific settings

## Module Metadata

Each module defines metadata that controls its behavior:

```nix
{
  name = "audio";
  scope = "system";        # system | shared | user
  mutability = "overlay";  # exclusive | overlay
  dimensions = [];         # [] for global, ["user"] for user-specific
  description = "Audio system configuration";
  version = "1.0";
}
```

## User-Specific Configuration

Users can override system settings by creating configs in their user directory:

```bash
# Create user-specific audio config
module-manager config-create-template audio fr4iser

# Edit the created file
vim /etc/nixos/configs/users/fr4iser/audio.nix
```

Example user config:

```nix
{
  # Override system volume
  audio.volume = 75;

  # Set user-specific audio device
  # audio.device = "alsa_output.pci-0000_00_1f.3.analog-stereo";
}
```

## Security Restrictions

Some system-level settings cannot be overridden by users for security reasons:

- Display manager settings (`desktop.displayManager`)
- GPU configuration (`hardware.gpu`)
- Network interfaces (`network.interfaces`)
- Boot settings (`boot.loader`)

## CLI Commands

### Inspect Configurations

```bash
# Show resolved config for a module
module-manager config-inspect audio

# Show config diff between system and user
module-manager config-diff audio fr4iser
```

### Create Templates

```bash
# Create user config template
module-manager config-create-template packages fr4iser
```

### Validation

```bash
# Validate all configurations
module-manager config-validate-all

# Show directory structure
module-manager config-show-structure
```

## Migration from Old System

If you have existing `*-config.nix` files in `/etc/nixos/configs/`, run:

```bash
# Dry run first - shows what would migrate
sudo module-manager migrate-config-dry-run

# Perform migration - happens automatically during nixos-rebuild
sudo nixos-rebuild switch

# Configs are automatically moved to categorized structure
```

## Performance

The system includes caching to improve performance:

```bash
# Run performance benchmark (when implemented)
# time nixos-rebuild build

# Show cache statistics (when implemented)
# module-manager config-cache-stats
```

## Troubleshooting

### Common Issues

1. **Config not loading**: Check file permissions and syntax
2. **User config ignored**: Verify user is in `managedUsers` list
3. **Security restrictions**: Some paths cannot be overridden by users
4. **Performance issues**: Enable caching in module manager config

### Debug Commands

```bash
# Show detailed config resolution
module-manager config-inspect <module> --debug

# Test config loading performance
module-manager config-performance-test
```

## Best Practices

1. **Use user configs sparingly**: Only override what you need
2. **Test configs**: Always test with `nixos-rebuild build` first
3. **Keep backups**: The migration script creates automatic backups
4. **Use templates**: Start with `config-create-template` for new configs
5. **Validate regularly**: Run `config-validate-all` after changes
```

#### 5.7 Final Integration Tests
**Nix validation** - All validation happens automatically through Nix evaluation. Use `nixos-rebuild build` to validate configurations.

## ✅ Success Criteria

- [ ] CLI tools provide debugging and management capabilities
- [ ] Migration guides are complete and accurate
- [ ] Manual testing validates core functionality
- [ ] Documentation covers all new features
- [ ] System rebuilds work with new config structure

## 📚 Documentation Updates

- [ ] User guide for new config system
- [ ] Migration documentation
- [ ] API reference for CLI commands
- [ ] Troubleshooting guide

## 🔗 Final Steps

After completing Phase 5:
- System is ready for production deployment
- All functionality has been validated
- Documentation is complete and accurate
- Migration path is clear for existing users
