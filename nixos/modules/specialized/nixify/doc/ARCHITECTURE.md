# Nixify - Architecture

## Overview

High-level architecture description of the Nixify module.

## Components

### Module Structure

```
nixify/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── commands.nix                 # CLI commands
├── snapshot/                    # Snapshot scripts
│   ├── windows/
│   ├── macos/
│   └── linux/
├── mapping/                     # Program mapping
├── web-service/                 # Web service
├── iso-builder/                 # ISO builder
└── doc/                         # Documentation
```

## Design Decisions

### Decision 1: System Separation

**Context**: Need to run on NixOS but scan other systems
**Decision**: Separate NixOS module and standalone snapshot scripts
**Rationale**: No NixOS dependencies on target systems
**Alternatives**: NixOS-only (rejected - limits functionality)

### Decision 2: Web Service Architecture

**Context**: Need to receive snapshots from target systems
**Decision**: HTTP web service with REST API
**Rationale**: Simple, cross-platform, accessible
**Alternatives**: Direct file transfer (rejected - less flexible)

## Data Flow

```
Target System → Snapshot Script → HTTP Upload → NixOS Web Service → Config Generation
```

## Dependencies

### Internal Dependencies
- `core.base.network` - Network configuration

### External Dependencies
- `nixpkgs.go` - Web service (Go)
- `nixpkgs.nix` - NixOS config generation

## Extension Points

How other modules can extend this module:
- Custom snapshot scripts can be added
- Mapping database can be extended
- Config generation can be customized

## Performance Considerations

- Snapshot script efficiency
- Web service performance
- Config generation speed

## Security Considerations

- Web service authentication
- Snapshot validation
- Network security
- Config generation security
