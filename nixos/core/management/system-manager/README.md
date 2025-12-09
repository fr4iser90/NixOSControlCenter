# System Manager

A comprehensive core NixOS Control Center module that provides system management, update, and configuration capabilities. This module handles system updates, configuration validation, migration tools, and provides APIs for other modules.

## Overview

The System Manager is a **core module** that provides essential system management functionality for the NixOS Control Center. It includes system updates, configuration validation and migration, version checking, and management tools for channels, desktop environments, and features.

## Features

- **System Updates**: Update NixOS configuration from remote repositories or local directories
- **Configuration Management**: Validate, migrate, and manage system configuration structure
- **Version Checking**: Check module versions across core and feature modules
- **Channel Management**: Manage NixOS channels and flakes
- **Desktop Management**: Configure desktop environments and window managers
- **Feature Updates**: Update features with automatic migration support
- **API Services**: Provide configuration and backup helpers for other modules

## Architecture

### File Structure

```
system-manager/
├── README.md                           # This documentation
├── CHANGELOG.md                        # Version history
├── default.nix                         # Main module entry point
├── options.nix                         # Configuration options
├── config.nix                          # Implementation logic & symlink management
├── commands.nix                        # Command registration
├── system-manager-config.nix           # User configuration (symlinked)
├── SYSTEM_UPDATE_DOCUMENTATION.md      # Detailed update documentation
├── components/                         # Sub-components
│   └── config-migration/              # Configuration migration tools
├── handlers/                           # Business logic orchestration
│   ├── system-update.nix              # System update handler
│   ├── channel-manager.nix            # Channel management handler
│   ├── desktop-manager.nix            # Desktop management handler
│   └── feature-migration.nix          # Feature migration logic
├── lib/                                # Utility functions
│   ├── default.nix                    # Library exports
│   ├── config-loader.nix              # Configuration loading
│   ├── backup-helpers.nix             # Backup utilities
│   ├── config-helpers.nix             # Configuration helpers
│   └── version-helpers.nix            # Version management
├── scripts/                            # Executable CLI commands
│   ├── update-features.nix            # Feature update script
│   └── check-versions.nix             # Version checking script
└── validators/                         # Input validation
    └── config-validator.nix           # Configuration validation
```

### Design Principles

- **Core Module**: Always active, provides essential system management
- **Modular Components**: Separate handlers for different functionalities
- **API Provider**: Supplies utilities and helpers to other modules
- **Safe Updates**: Backup-first approach with rollback capabilities
- **Configuration Preservation**: Never overwrites user configurations

## Commands

### System Management Commands

- **`ncc system-update`**: Update NixOS configuration from repository
- **`ncc check-module-versions`**: Check versions of all modules
- **`ncc update-features`**: Update features with migration support
- **`ncc migrate-system-config`**: Migrate from monolithic to modular config
- **`ncc validate-system-config`**: Validate configuration structure

### Management Commands

- **`ncc channel-manager`**: Manage NixOS channels and flakes
- **`ncc desktop-manager`**: Configure desktop environments

## Configuration

As a core module, the system manager requires minimal configuration and is always active. The main configuration options are:

```nix
systemConfig.management.system-manager = {
  enableVersionChecker = true;     # Version checking (default: true)
  enableDeprecationWarnings = true; # Deprecation warnings (default: true)
  enableUpdates = false;           # Automatic updates (default: false)
  auto-build = false;              # Auto-build after updates (default: false)

  components.configMigration.enable = false; # Migration tools (default: false)
};
```

## API Services

The system manager provides APIs that other modules can use:

### Config Helpers (`config.core.management.system-manager.api.configHelpers`)
- `setupConfigFile`: Create symlinks for user configurations
- Configuration file management utilities

### Backup Helpers (`config.core.management.system-manager.api.backupHelpers`)
- `createBackup`: Create timestamped backups
- `cleanupBackups`: Remove old backups
- `restoreBackup`: Restore from backup

## Technical Details

### System Update Process

The system update functionality:

1. **Source Selection**: Choose between remote repository or local directory
2. **Backup Creation**: Creates timestamped backup of `/etc/nixos/`
3. **Selective Copying**: Updates module code while preserving user configs
4. **Version Migration**: Handles module version upgrades
5. **Optional Build**: Can automatically rebuild the system

### Configuration Structure

The module supports both legacy monolithic and modern modular configurations:

- **Monolithic**: All config in `system-config.nix`
- **Modular**: Config split across multiple files in `configs/`

### Version Management

Tracks versions for:
- **Core modules**: System management components
- **Feature modules**: Optional user features
- **NixOS versions**: Deprecation warnings for old versions

## Dependencies

- `nix`: Nix package manager
- `git`: For repository operations
- `rsync`: For efficient file copying
- `bash`: Shell environment

## Development

This module follows the unified MODULE_TEMPLATE architecture and serves as a reference implementation for complex core modules with multiple sub-components.

### Key Patterns

- **Handler Pattern**: Business logic separated into focused handlers
- **Script Pattern**: CLI commands implemented as executable scripts
- **API Pattern**: Services exposed via `config.core.*.api` namespace
- **Component Pattern**: Complex functionality split into sub-components

## Related Documentation

- [SYSTEM_UPDATE_DOCUMENTATION.md](SYSTEM_UPDATE_DOCUMENTATION.md) - Detailed update process
- [MODULE_TEMPLATE.md](../../docs/02_architecture/example_module/MODULE_TEMPLATE.md) - Module architecture
- [Config Migration](../../core/config/config-migration.nix) - Migration utilities
