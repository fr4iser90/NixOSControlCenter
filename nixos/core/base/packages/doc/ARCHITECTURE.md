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
    ├── base/                    # core + profile (desktop|server)
    ├── sets/                    # Optional system modules (atoms)
    ├── recipes/                 # System recipes → list of sets
    └── user-presets/            # User presets → userPackages
```

### Package Organization

#### Base Packages
- **desktop**: Essential desktop packages
- **server**: Essential server packages

#### Feature Sets
- **gaming** / **streaming** / **emulation** (slim RetroArch)
- **web-dev** / **python-dev** / **system-dev** / **game-engines**
- **docker** / **docker-rootless** / **podman**
- **qemu-vm** / **virt-manager** (separate; recipe: virt-desktop)
- **database** / **web-server** / **mail-server**

#### Presets
- **gaming-desktop**, **dev-lean**, **virt-desktop**, **homelab-server**
- User: **user-web-tools**, **user-python-tools**, **user-creative**
- Legacy: **dev-workstation** (prefer dev-lean); **game-dev** remaps → **game-engines**

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
**Decision**: V1 sets (`packageModules`) + global `systemPackages` + per-user `users.<name>.userPackages`
**Rationale**: Clear global vs user scope; one SSOT for user packages on the user leaf
**Trade-offs**: Sets remain module-based (may enable services), individual lists are nixpkgs names only

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
- Custom recipes → `components/recipes/`; user-presets → `components/user-presets/`
- Package metadata can be extended via `lib/metadata.nix`

## Performance Considerations

- Feature resolution at build time
- Package loading optimization
- Dependency resolution caching

## Security Considerations

- Package source verification
- Dependency security
- User package isolation
