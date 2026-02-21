# Network System - Architecture

## Overview

High-level architecture description of the Network System module.

## Components

### Module Structure

```
network/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── network-config.nix           # User configuration (symlinked)
├── handlers/                     # Network handlers
│   ├── networkmanager.nix      # NetworkManager configuration
│   └── firewall.nix            # Firewall configuration
├── lib/                         # Utility functions
│   └── rules.nix               # Firewall rule generation
└── processors/                  # Data processors
    └── services.nix            # Service processing
```

### Core Components

#### NetworkManager (`handlers/networkmanager.nix`)
- Wireless network management with power saving options
- MAC address randomization for privacy
- Configurable DNS settings

#### Firewall (`handlers/firewall.nix`)
- Service-based firewall rule generation
- Automatic rule creation for configured services
- Trusted network support
- Security warnings for unsafe configurations

#### Utilities (`lib/`)
- **rules.nix**: Firewall rule generation logic
- Intelligent rule creation based on service configurations

## Design Decisions

### Decision 1: Service-Based Firewall

**Context**: Need to manage firewall rules for multiple services
**Decision**: Use service-based firewall rule generation
**Rationale**: Easier to manage, automatic rule creation, security warnings
**Alternatives**: Manual firewall rules (rejected - too complex)

### Decision 2: NetworkManager by Default

**Context**: Need network management for most users
**Decision**: Enable NetworkManager by default
**Rationale**: Works for most users, easy to configure
**Trade-offs**: May not be needed for server systems

## Data Flow

```
User Config → options.nix → config.nix → NetworkManager/Firewall Config
```

## Dependencies

### Internal Dependencies
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs.networkmanager` - Network management
- `nixpkgs.iptables` - Firewall rules

## Extension Points

How other modules can extend this module:
- Custom firewall rules can be added via options
- Network services can be configured via options
- NetworkManager configuration can be extended

## Performance Considerations

- NetworkManager power saving options
- Firewall rule optimization
- DNS resolution performance

## Security Considerations

- Firewall security warnings
- Service exposure levels (local vs public)
- NetworkManager security settings
- Trusted network configuration

See [SECURITY.md](./SECURITY.md) for detailed security information.
