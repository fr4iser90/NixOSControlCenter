# Packages System

A core NixOS Control Center module that provides comprehensive package management with feature-based organization, intelligent dependency resolution, and preset configurations.

## Overview

The Packages System module is a **core module** that manages system-wide and user-specific packages for NixOS. It provides a feature-based package organization system with automatic dependency resolution, preset configurations, and intelligent Docker mode selection.

## Features

- **Feature-Based Packages**: Organized by features (gaming, development, virtualization)
- **Intelligent Dependencies**: Automatic dependency resolution and conflict detection
- **Preset Configurations**: Pre-configured package sets for common use cases
- **Docker Intelligence**: Automatic Docker mode selection (rootless vs root)
- **System/User Packages**: Separate system-wide and user-specific package management
- **Legacy Support**: Backward compatibility with old packageModules structure

## Architecture

### File Structure

```
packages/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── lib/                         # Utility functions
│   └── metadata.nix            # Package metadata and dependencies
└── components/                  # Package components
    ├── base/                    # Base packages
    │   ├── desktop.nix
    │   └── server.nix
    ├── presets/                 # Preset configurations
    │   ├── gaming-desktop.nix
    │   ├── dev-workstation.nix
    │   └── homelab-server.nix
    └── sets/                    # Feature-based package sets
        ├── docker.nix
        ├── docker-rootless.nix
        ├── gaming.nix
        ├── streaming.nix
        └── ...
```

### Package Organization

#### Base Packages
- **desktop**: Essential desktop packages
- **server**: Essential server packages

#### Feature Sets
- **gaming**: Gaming packages and launchers
- **streaming**: Streaming software
- **emulation**: Emulator packages
- **web-dev**: Web development tools
- **python-dev**: Python development tools
- **system-dev**: System development tools
- **game-dev**: Game development tools
- **docker**: Docker (root mode)
- **docker-rootless**: Docker (rootless mode)
- **podman**: Podman container runtime
- **qemu-vm**: QEMU/KVM virtualization
- **virt-manager**: Virtual machine manager
- **database**: Database servers
- **web-server**: Web server packages
- **mail-server**: Mail server packages

#### Presets
- **gaming-desktop**: Complete gaming environment
- **dev-workstation**: Full development environment
- **homelab-server**: Home server configuration

## Configuration

As a core module, the packages system is configured through the system config:

```nix
{
  packages = {
    # Legacy format (V1)
    packageModules = [ "gaming" "docker" "web-dev" ];

    # New format (V2)
    systemPackages = [ "firefox" "vscode" ];  # System-wide packages
    userPackages = {
      alice = [ "discord" "spotify" ];        # User-specific packages
      bob = [ "slack" "zoom" ];
    };

    # Preset configuration
    preset = {
      modules = [ "gaming-desktop" ];
    };

    # Docker configuration
    docker = {
      enable = true;
      root = null;  # null = auto-detect (root for Swarm/AI-Workspace)
    };
  };
}
```

## Technical Details

### Feature System

The module organizes packages by features:

- **Metadata**: Each feature has metadata (dependencies, conflicts, system type)
- **Dependency Resolution**: Automatic resolution of feature dependencies
- **Conflict Detection**: Detection and warning of conflicting features
- **System Type Filtering**: Desktop vs server feature filtering

### Docker Intelligence

The module automatically selects Docker mode:

- **Rootless**: Default mode for most users
- **Root**: Automatically enabled when Docker Swarm or AI-Workspace is active
- **Manual Override**: Can be manually specified via `docker.root`

### Package Loading

The module loads packages based on configuration:

- **Base**: System type base packages
- **Features**: Feature-based package sets
- **System Packages**: Direct system-wide packages
- **User Packages**: User-specific packages via home-manager

### Legacy Support

The module maintains backward compatibility:

- **packageModules**: Old format still supported
- **Automatic Conversion**: Old format converted to new feature system
- **Migration Path**: Clear migration from V1 to V2 format

## Usage

### Using Features

```nix
{
  packages = {
    packageModules = [
      "gaming"        # Gaming packages
      "docker"        # Docker (root mode)
      "web-dev"       # Web development tools
    ];
  };
}
```

### Using Presets

```nix
{
  packages = {
    preset = {
      modules = [ "gaming-desktop" ];  # Complete gaming setup
    };
  };
}
```

### Using System/User Packages

```nix
{
  packages = {
    systemPackages = [ "firefox" "vscode" ];
    userPackages = {
      alice = [ "discord" "spotify" ];
    };
  };
}
```

### Docker Configuration

```nix
{
  packages = {
    docker = {
      enable = true;
      root = false;  # Force rootless mode
    };
  };
}
```

## Dependencies

- **home-manager**: For user-specific packages
- **Package Metadata**: Feature definitions and dependencies

## Troubleshooting

### Common Issues

1. **Package Not Found**: Check package name in metadata
2. **Dependency Conflicts**: Review feature dependencies
3. **Docker Mode**: Verify Docker mode selection logic

### Debug Commands

```bash
# Check installed packages
nix-env -q

# Check package metadata
cat /etc/nixos/modules/core/base/packages/lib/metadata.nix

# Check Docker mode
docker info | grep "Root Dir"
```

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Feature-Based**: Packages organized by features
- **Metadata-Driven**: Package definitions in metadata
- **Intelligent Resolution**: Automatic dependency and conflict resolution
- **Legacy Support**: Backward compatibility maintained

## Related Components

- **System Manager**: System type detection
- **Home Manager**: User-specific package management
- **Docker Modules**: Docker configuration integration
