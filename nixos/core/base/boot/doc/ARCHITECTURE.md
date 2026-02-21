# Boot System - Architecture

## Overview

High-level architecture description of the Boot System module.

## Components

### Module Structure

```
boot/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
└── handlers/                    # Bootloader implementations
    ├── systemd-boot.nix        # systemd-boot configuration
    ├── grub.nix                # GRUB configuration
    └── refind.nix              # rEFInd configuration
```

### Bootloaders

#### systemd-boot (`bootloader = "systemd-boot"`)
- Modern UEFI bootloader
- Fast boot times
- Simple configuration
- Recommended for UEFI systems

#### GRUB (`bootloader = "grub"`)
- Traditional bootloader
- BIOS and UEFI support
- Advanced features
- Legacy system support

#### rEFInd (`bootloader = "refind"`)
- Graphical boot manager
- Multiple OS support
- Customizable themes
- Advanced users

## Design Decisions

### Decision 1: Handler Pattern

**Context**: Need to support multiple bootloaders with different configurations
**Decision**: Use handler pattern with separate files for each bootloader
**Rationale**: Clean separation of concerns, easy to add new bootloaders
**Alternatives**: Single file with conditionals (rejected - too complex)

### Decision 2: Dynamic Loading

**Context**: Bootloader selection at runtime
**Decision**: Conditionally import bootloader handler based on configuration
**Rationale**: Only load what's needed, cleaner module structure
**Trade-offs**: Slightly more complex default.nix, but better maintainability

## Data Flow

```
User Config → options.nix → default.nix → Handler Selection → Bootloader Config
```

## Dependencies

### Internal Dependencies
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs.systemd` - systemd-boot support
- `nixpkgs.grub2` - GRUB support
- `nixpkgs.refind` - rEFInd support

## Extension Points

How other modules can extend this module:
- Custom bootloader handlers can be added to `handlers/`
- Boot configuration can be extended via options

## Performance Considerations

- Initrd compression with Zstd level 19 and multi-threading
- Latest kernel packages for performance
- Minimal bootloader overhead

## Security Considerations

- Bootloader security settings
- Secure boot support (if available)
- Boot entry validation

See [SECURITY.md](./SECURITY.md) for detailed security information (if available).
