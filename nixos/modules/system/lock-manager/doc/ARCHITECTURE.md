# Lock Manager - Architecture

## Overview

High-level architecture description of the Lock Manager (System Discovery) module.

## Components

### Module Structure

```
lock-manager/
├── README.md                    # Module overview
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── collectors/                  # Data collectors
├── handlers/                    # Business logic handlers
└── lib/                         # Utility functions
```

## Design Decisions

### Decision 1: Scanner-Based Architecture

**Context**: Need to collect various types of system data
**Decision**: Modular scanner architecture with separate collectors
**Rationale**: Flexible, extensible, maintainable
**Alternatives**: Monolithic collection (rejected - too complex)

### Decision 2: Metadata-Only Credential Scanning

**Context**: Need to document credentials without storing private keys
**Decision**: Store only metadata (fingerprints, key IDs) by default
**Rationale**: Security best practice, defense in depth
**Trade-offs**: Cannot restore private keys, but more secure

### Decision 3: Encryption Support

**Context**: Need secure storage of system snapshots
**Decision**: Support sops-nix and FIDO2/YubiKey encryption
**Rationale**: Multiple encryption methods for flexibility
**Alternatives**: Single encryption method (rejected - less flexible)

## Data Flow

```
System State → Scanners → Snapshot JSON → Encryption → Storage/GitHub
```

## Dependencies

### Internal Dependencies
- `core.base.user` - User account management

### External Dependencies
- `nixpkgs.sops` - SOPS encryption (optional)
- `nixpkgs.age-plugin-yubikey` - FIDO2 encryption (optional)
- `nixpkgs.jq` - JSON processing

## Extension Points

How other modules can extend this module:
- Custom scanners can be added to `collectors/`
- Encryption methods can be extended
- Storage backends can be customized

## Performance Considerations

- Scanner efficiency
- Snapshot generation speed
- Encryption performance
- Storage optimization

## Security Considerations

- Metadata-only credential scanning (default)
- Encryption support (sops/FIDO2)
- Secure storage
- GitHub upload security

See [SECURITY.md](./SECURITY.md) for detailed security information.
