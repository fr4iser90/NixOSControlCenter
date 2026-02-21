# System Manager

A core NixOS Control Center module that provides system-level management, updates, backups, health checks, and configuration migration. This module manages the overall system state and provides essential system management capabilities.

## Overview

The System Manager module is a **core module** that provides system-level management for NixOS. It handles system updates, backups, health checks, configuration migration, and provides APIs for other modules to interact with system-level operations.

## Quick Start

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
  };
}
```

## Features

- **System Updates**: Configuration and channel updates
- **Backup Management**: Automatic backup creation and management
- **Health Checks**: System health monitoring and checks
- **Config Migration**: Automatic configuration migration
- **Version Checking**: NixOS version compatibility checking
- **Deprecation Warnings**: Warnings for deprecated configurations
- **API Access**: APIs for backup, config helpers, and more

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [API Reference](./doc/API.md) - Complete API documentation

## Related Components

- **Module Manager**: Module discovery and management
- **CLI Registry**: Command registration
- **All Modules**: Provides system-level services
