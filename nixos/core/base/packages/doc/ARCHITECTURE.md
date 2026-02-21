# Packages System - Architecture

## Overview

High-level architecture description of the Packages System module.

## Components

### Module Structure

```
packages/
├── README.md                    # Module overview
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
    ├── presets/                 # Preset configurations
    └── sets/                    # Feature-based package sets
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

## Design Decisions

### Decision 1: Feature-Based Organization

**Context**: Need to organize packages by functionality
**Decision**: Use feature-based organization with metadata
**Rationale**: Easier to manage, automatic dependency resolution
**Alternatives**: Flat package list (rejected - too complex)

### Decision 2: Docker Intelligence

**Context**: Need to select Docker mode automatically
**Decision**: Auto-detect Docker mode based on system configuration
**Rationale**: Reduces manual configuration, improves user experience
**Trade-offs**: May not always select optimal mode

### Decision 3: Legacy Support

**Context**: Need backward compatibility with old format
**Decision**: Support both V1 (packageModules) and V2 (systemPackages/userPackages)
**Rationale**: Smooth migration path, no breaking changes
**Trade-offs**: More complex code, but better user experience

## Data Flow

```
User Config → options.nix → config.nix → Feature Resolution → Package Loading
```

## Dependencies

### Internal Dependencies
- `core.management.system-manager` - System type detection
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs` - Package definitions
- `home-manager` - User-specific packages

## Extension Points

How other modules can extend this module:
- Custom features can be added to `components/sets/`
- Custom presets can be added to `components/presets/`
- Package metadata can be extended via `lib/metadata.nix`

## Performance Considerations

- Feature resolution at build time
- Package loading optimization
- Dependency resolution caching

## Security Considerations

- Package source verification
- Dependency security
- User package isolation
