# System Manager

A core NixOS Control Center module that provides system-level management, updates, backups, health checks, and configuration migration. This module manages the overall system state and provides essential system management capabilities.

## Overview

The System Manager module is a **core module** that provides system-level management for NixOS. It handles system updates, backups, health checks, configuration migration, and provides APIs for other modules to interact with system-level operations.

## Features

- **System Updates**: Configuration and channel updates
- **Backup Management**: Automatic backup creation and management
- **Health Checks**: System health monitoring and checks
- **Config Migration**: Automatic configuration migration
- **Version Checking**: NixOS version compatibility checking
- **Deprecation Warnings**: Warnings for deprecated configurations
- **API Access**: APIs for backup, config helpers, and more

## Architecture

### File Structure

```
system-manager/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── lib/                         # Utility functions
│   ├── backup-helpers.nix      # Backup utilities
│   └── ...
├── handlers/                    # Update handlers
├── scripts/                     # Management scripts
├── components/                  # System components
│   ├── system-checks/          # Health checks
│   ├── system-update/          # Update system
│   ├── config-migration/       # Config migration
│   └── ...
├── tui/                         # TUI interface
└── validators/                  # Configuration validators
```

### System Components

#### System Checks
- **Health Monitoring**: System health checks
- **Hardware Detection**: Automatic hardware detection
- **Configuration Validation**: System configuration validation

#### System Update
- **Configuration Updates**: Update from remote or local
- **Channel Updates**: Update flake inputs
- **Automatic Building**: Optional auto-build after updates

#### Config Migration
- **Schema Migration**: Migrate from v0 to v1 schema
- **Automatic Migration**: Automatic migration on detection
- **Backup Creation**: Automatic backups before migration

## Configuration

As a core module, system manager provides essential features that are always available:

```nix
{
  system-manager = {
    # Always available (Core)
    enableVersionChecker = true;         # Version checking
    enableDeprecationWarnings = true;    # Deprecation warnings
    enableChecks = true;                 # System health checks

    # Optional features
    enableUpdates = false;               # System updates (optional)
    auto-build = false;                  # Auto-build after updates

    # Optional components
    components.configMigration = {
      enable = false;  # Config migration (rarely needed after v0→v1)
    };
  };
}
```

## Usage

### System Updates

```bash
# Update configuration from remote repository
ncc system-update

# Update from local directory
ncc system-update --local /path/to/nixos

# Update channels (flake inputs)
ncc system-update --channels
```

### System Checks

```bash
# Run system health checks
ncc system-checks

# Check system configuration
ncc system-checks --config
```

### Backups

Backups are automatically created:
- Before system updates
- Before configuration migrations
- On system activation (if configured)

## Technical Details

### Update System

The update system supports:
- **Remote Updates**: From Git repository
- **Local Updates**: From local directory
- **Channel Updates**: Flake input updates
- **Automatic Backups**: Before updates

### Backup System

The backup system:
- Creates backups in `/var/backup/nixos/`
- Keeps last N backups (configurable)
- Automatic cleanup of old backups
- Timestamped backup names

### Health Checks

System checks include:
- Hardware detection
- Configuration validation
- Service status
- System health metrics

## API Usage

### Accessing the API

```nix
# In other modules
let
  systemManager = config.core.management.system-manager.api;
in
  systemManager.createBackup "backup-name"
```

### Available Functions

- **Backup Helpers**: Create, restore, list backups
- **Config Helpers**: Configuration management utilities
- **System Info**: System information queries

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Component-Based**: Modular system components
- **API-First**: Comprehensive APIs for modules
- **Extensible**: Easy to add new components
- **Integration**: Works with all modules

## Related Components

- **Module Manager**: Module discovery and management
- **CLI Registry**: Command registration
- **All Modules**: Provides system-level services
