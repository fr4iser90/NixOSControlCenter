# Boot Entry Manager - Architecture

## Overview

High-level architecture description of the Boot Entry Manager module.

## Components

### Module Structure

```
bootentry-manager/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── template-config.nix          # Template configuration file
├── lib/                         # Shared utility functions
│   ├── common.nix              # Common utilities
│   └── types.nix               # Type definitions
└── handlers/                   # Bootloader-specific implementations
    ├── systemd-boot.nix        # systemd-boot provider
    ├── grub.nix                # GRUB provider
    └── refind.nix              # rEFInd provider
```

### Providers

#### systemd-boot Provider
- **Storage**: JSON files in `/etc/nixos/boot/entries/`
- **Bootloader Integration**: Direct EFI entry management
- **Features**: Entry ordering, custom titles, parameters

#### GRUB Provider
- **Storage**: GRUB configuration integration
- **Bootloader Integration**: Menu entry management
- **Features**: Submenu support, custom kernels

#### rEFInd Provider
- **Storage**: rEFInd configuration files
- **Bootloader Integration**: Manual configuration updates
- **Features**: Icon support, theme integration

## Design Decisions

### Decision 1: Provider Pattern

**Context**: Need to support multiple bootloaders with different implementations
**Decision**: Use provider pattern with separate handlers for each bootloader
**Rationale**: Clean separation, easy to add new bootloaders
**Alternatives**: Single implementation (rejected - too complex)

### Decision 2: JSON Storage

**Context**: Need human-readable entry definitions
**Decision**: Use JSON files for boot entry storage
**Rationale**: Easy to edit, validate, and version control
**Trade-offs**: Requires JSON parsing, but better UX

## Data Flow

```
JSON Entry Files → Validation → Provider Selection → Bootloader Config Update
```

## Dependencies

### Internal Dependencies
- `core.base.boot` - Bootloader configuration

### External Dependencies
- `nixpkgs.jq` - JSON processing
- `nixpkgs.efibootmgr` - EFI boot management (for systemd-boot)

## Extension Points

How other modules can extend this module:
- Custom bootloader providers can be added to `handlers/`
- Entry validation can be extended
- Entry synchronization can be customized

## Performance Considerations

- Entry validation at build time
- Efficient bootloader updates
- Minimal activation overhead

## Security Considerations

- Entry validation (trusted sources only)
- Kernel/initrd path validation
- Boot entry access control
- EFI security (secure boot compatibility)
