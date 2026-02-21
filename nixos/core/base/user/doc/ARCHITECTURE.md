# User System - Architecture

## Overview

High-level architecture description of the User System module.

## Components

### Module Structure

```
user/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── user-config.nix              # User configuration (symlinked)
├── password-manager.nix         # Password management system
└── home-manager/                # User environment management
    ├── roles/                   # Role definitions
    └── shellInit/               # Shell initialization
```

### User Roles

#### Admin (`role = "admin"`)
- **Groups**: wheel, networkmanager, docker, podman, video, audio, render, input, seat
- **Sudo**: Full access without password prompt
- **Description**: Complete system administrator access

#### Restricted Admin (`role = "restricted-admin"`)
- **Groups**: wheel, networkmanager, video, audio
- **Sudo**: Full access with password prompt
- **Auto-Login**: Can be configured for TTY auto-login
- **Description**: Limited administrative access with restrictions

#### Virtualization (`role = "virtualization"`)
- **Groups**: docker, podman, libvirtd, kvm
- **Sudo**: Limited to Docker Swarm and node commands (passwordless)
- **Lingering**: Enabled for systemd user services
- **Description**: Specialized for container and VM management

#### Guest (`role = "guest"`)
- **Groups**: networkmanager
- **Sudo**: No sudo access
- **Description**: Basic user access with network permissions only

## Design Decisions

### Decision 1: Role-Based Access Control

**Context**: Need to manage user permissions efficiently
**Decision**: Use role-based access control with predefined roles
**Rationale**: Easier to manage, consistent permissions, security-focused
**Alternatives**: Per-user permission configuration (rejected - too complex)

### Decision 2: Password Manager Integration

**Context**: Need secure password handling
**Decision**: Integrate with password-manager for hashed passwords
**Rationale**: Secure storage, proper permissions, activation scripts
**Trade-offs**: Requires password-manager setup

### Decision 3: Shell Integration

**Context**: Need to support multiple shells
**Decision**: Automatic shell activation based on user preferences
**Rationale**: User-friendly, automatic setup
**Trade-offs**: Requires shell packages to be available

## Data Flow

```
User Config → options.nix → config.nix → Role Selection → User Creation → Group Assignment → Sudo Config
```

## Dependencies

### Internal Dependencies
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs` - Shell packages
- `home-manager` - User environment management

## Extension Points

How other modules can extend this module:
- Custom roles can be added to `home-manager/roles/`
- Custom shell initialization can be added to `home-manager/shellInit/`
- User configuration can be extended via options

## Performance Considerations

- User creation at build time
- Group assignment optimization
- Shell activation on demand

## Security Considerations

- Role-based access control (principle of least privilege)
- Secure password storage (hashed passwords)
- Sudo rule restrictions
- Service access control (lingering only for virtualization role)

See [SECURITY.md](./SECURITY.md) for detailed security information.
