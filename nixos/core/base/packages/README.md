# Packages System

A comprehensive core NixOS Control Center module that provides intelligent package management with features, presets, and automatic dependency resolution. This module supports dynamic package loading based on system type and user-selected features.

## Overview

The Packages System module is a **core module** that manages all system packages through a sophisticated feature-based system. It supports presets, individual features, legacy migration, and automatic dependency resolution.

## Features

- **Feature-Based Packaging**: Modular package management with named features
- **Preset Support**: Pre-configured package sets for common use cases
- **Automatic Dependencies**: Intelligent dependency resolution and conflict detection
- **Legacy Migration**: Automatic migration from old package structure
- **System Type Filtering**: Packages filtered by desktop/server system type
- **Docker Mode Intelligence**: Automatic root/rootless Docker selection

## Architecture

### File Structure

```
packages/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── packages-config.nix          # User configuration (symlinked)
├── metadata.nix                 # Feature metadata and migration rules
├── base/                        # Base packages by system type
│   ├── desktop.nix             # Desktop base packages
│   └── server.nix              # Server base packages
├── features/                    # Feature-specific packages
│   ├── gaming.nix              # Gaming packages
│   ├── docker.nix              # Docker (root mode)
│   ├── docker-rootless.nix     # Docker (rootless mode)
│   ├── web-dev.nix             # Web development
│   └── ...                     # More features
└── presets/                     # Pre-configured package sets
    ├── gaming-desktop.nix      # Gaming desktop preset
    ├── dev-workstation.nix     # Development workstation
    └── homelab-server.nix      # Homelab server
```

### Core Components

#### Metadata System (`metadata.nix`)
- **Feature Definitions**: System types, groups, dependencies, conflicts
- **Legacy Migration**: Maps old packageModules to new features
- **Dependency Resolution**: Automatic dependency and conflict checking

#### Base Packages (`base/`)
- **Desktop**: Common desktop packages (browsers, utilities, etc.)
- **Server**: Minimal server packages (system tools, monitoring)

#### Feature Packages (`features/`)
- **Gaming**: Steam, Discord, game launchers
- **Development**: Programming languages, IDEs, build tools
- **Virtualization**: Docker, Podman, QEMU, virt-manager
- **Server**: Databases, web servers, mail servers

#### Presets (`presets/`)
- **gaming-desktop**: Complete gaming environment
- **dev-workstation**: Full development environment
- **homelab-server**: Home server configuration

## Configuration

As a core module, the packages system provides flexible configuration options:

```nix
{
  packages = {
    # Use a preset (recommended for new setups)
    preset = "dev-workstation";

    # Or manually select features
    packageModules = [
      "web-dev"
      "python-dev"
      "docker"
      "gaming"
    ];

    # Add additional features beyond preset
    additionalPackageModules = [
      "streaming"
      "emulation"
    ];
  };
}
```

## Feature System

### Available Features

#### Gaming Features
- **gaming**: Steam, Epic Games, GOG, Discord
- **streaming**: OBS Studio, streaming tools
- **emulation**: Retro gaming emulation

#### Development Features
- **web-dev**: Node.js, npm, web development tools
- **python-dev**: Python development environment
- **system-dev**: C/C++, build tools (cmake, ninja, gcc)
- **game-dev**: Game engines, development tools

#### Virtualization Features
- **docker**: Docker (automatic root/rootless selection)
- **podman**: Podman containerization
- **qemu-vm**: QEMU/KVM virtual machines
- **virt-manager**: Virtualization GUI (requires qemu-vm)

#### Server Features
- **database**: PostgreSQL, MySQL
- **web-server**: Nginx, Apache
- **mail-server**: Mail server setup

### System Type Filtering

Features are automatically filtered by system type:
- **Desktop features**: Available only on desktop systems
- **Server features**: Available only on server systems
- **Universal features**: Available on both system types

### Dependency Resolution

The module automatically:
- **Resolves Dependencies**: Adds required packages for selected features
- **Detects Conflicts**: Prevents incompatible feature combinations
- **Validates System Type**: Ensures features are compatible with system type

## Docker Intelligence

### Automatic Mode Selection

The Docker feature automatically selects the appropriate mode:

- **Rootless Mode** (Default): Safer, sufficient for most use cases
- **Root Mode**: Automatically selected when:
  - Docker Swarm is active (requires root)
  - AI-Workspace is active (OCI containers need root)

### Legacy Support

- **docker-rootless**: Explicit rootless Docker (backward compatibility)
- **docker**: Legacy Docker feature (automatic mode selection)

## Legacy Migration

### Automatic Migration

The module automatically migrates from the old packageModules structure:

```nix
# Old structure (deprecated)
packages.packageModules = {
  development = {
    web = true;
    python = true;
  };
  server = {
    docker = true;
  };
};

# New structure (recommended)
packages = {
  packageModules = [
    "web-dev"
    "python-dev"
    "docker"
  ];
};
```

### Migration Warnings

The system provides warnings when using deprecated structures and guides users to migrate.

## Presets

### Available Presets

#### gaming-desktop
Complete gaming environment:
- Gaming launchers and communication
- Streaming tools
- Emulation support

#### dev-workstation
Full development environment:
- Web development tools
- Python development
- System development tools
- Docker support

#### homelab-server
Home server configuration:
- Docker containerization
- Database services
- Web server
- Basic server utilities

## Technical Details

### Package Loading Process

1. **Load Metadata**: Read feature definitions and constraints
2. **Apply Preset**: Load preset features if selected
3. **Add Custom Features**: Include additional package modules
4. **Legacy Migration**: Convert old structure if present
5. **System Filtering**: Filter by system type (desktop/server)
6. **Dependency Resolution**: Resolve dependencies and check conflicts
7. **Docker Mode Selection**: Determine Docker root/rootless mode
8. **Load Feature Modules**: Import and configure feature packages

### API Integration

The packages module integrates with other system components:
- **System Type Detection**: Uses `systemConfig.systemType`
- **Feature Detection**: Reads `systemConfig.features` for Docker mode logic
- **Config Helpers**: Uses system-manager API for symlink management

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Metadata-Driven**: Feature definitions drive package loading
- **Migration-Friendly**: Backward compatibility with legacy structures
- **Dependency-Aware**: Intelligent package relationship management
- **System-Aware**: Context-sensitive package selection

## Troubleshooting

### Common Issues

1. **Feature Not Available**: Check system type compatibility
2. **Dependency Conflicts**: Review feature conflicts in metadata
3. **Legacy Migration**: Update to new packageModules structure

### Debug Commands

```bash
# Check available features
nix-instantiate --eval -E "(import ./metadata.nix).features" | jq keys

# Validate configuration
nixos-rebuild dry-build
```

## Related Documentation

- [MODULE_TEMPLATE.md](../../docs/02_architecture/example_module/MODULE_TEMPLATE.md) - Module architecture
- [system-update.md](../../core/management/system-manager/SYSTEM_UPDATE_DOCUMENTATION.md) - Update process
