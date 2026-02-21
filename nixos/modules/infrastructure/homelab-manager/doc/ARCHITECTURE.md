# Homelab Manager - Architecture

## Overview

High-level architecture description of the Homelab Manager module.

## Components

### Module Structure

```
homelab-manager/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── handlers/                    # Business logic handlers
│   ├── homelab-create.nix      # Environment creation
│   ├── homelab-fetch.nix       # Stack fetching
│   └── ...
├── lib/                         # Utility functions
└── tui/                         # TUI interface
```

## Design Decisions

### Decision 1: Docker Swarm Detection

**Context**: Need to support both single-server and Swarm modes
**Decision**: Auto-detect Swarm mode and adjust Docker configuration
**Rationale**: Seamless operation, no manual configuration needed
**Trade-offs**: Requires Docker state checking

### Decision 2: User-Based Access Control

**Context**: Need to control Docker access per user
**Decision**: Integrate with user module roles (virtualization role)
**Rationale**: Consistent with system access control
**Alternatives**: Separate Docker user management (rejected - redundant)

## Data Flow

```
User Config → Stack Definition → Docker Compose → Stack Deployment
```

## Dependencies

### Internal Dependencies
- `core.base.user` - User role management
- `core.base.packages` - Docker package management

### External Dependencies
- `nixpkgs.docker` - Docker runtime
- `nixpkgs.docker-compose` - Docker Compose

## Extension Points

How other modules can extend this module:
- Custom stack handlers can be added
- Docker configuration can be extended
- Stack management can be customized

## Performance Considerations

- Stack deployment efficiency
- Docker Swarm performance
- Resource management

## Security Considerations

- User-based Docker access control
- Stack isolation
- Network security
- Container security
