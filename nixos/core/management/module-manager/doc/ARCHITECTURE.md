# Module Manager - Architecture

## Overview

High-level architecture description of the Module Manager module.

## Components

### Module Structure

```
module-manager/
├── README.md                    # Module overview
├── CHANGELOG.md                   # Version history
├── default.nix                    # Main module entry point
├── options.nix                     # Configuration options
├── config.nix                      # Implementation logic
├── template-config.nix             # Default configuration template
├── commands.nix                    # CLI commands
├── lib/                            # Utility functions
│   ├── module-config.nix          # Module configuration utilities
│   ├── discovery.nix              # Module discovery
│   ├── utils.nix                  # General utilities
│   └── ...
├── handlers/                       # Configuration handlers
├── scripts/                        # Management scripts
├── tui/                            # TUI interface
└── validators/                     # Configuration validators
```

### Module Discovery

The module automatically discovers modules by:
- Recursively scanning module directories
- Reading module metadata from `default.nix`
- Organizing modules by category and subcategory

### Configuration Management

The module manages configurations by:
- Loading configurations from `/etc/nixos/configs/`
- Merging with template defaults
- Providing `getModuleConfig` function for modules

## Design Decisions

### Decision 1: Automatic Discovery

**Context**: Need to discover modules automatically
**Decision**: Recursive directory scanning with metadata extraction
**Rationale**: No manual registration, easy to add modules
**Alternatives**: Manual module registration (rejected - too complex)

### Decision 2: Configuration Merging

**Context**: Need to merge user configs with defaults
**Decision**: Three-tier merging (system config → template → options defaults)
**Rationale**: Flexible, user-friendly, maintains defaults
**Trade-offs**: More complex merging logic, but better user experience

### Decision 3: Default Config Creation

**Context**: Need default configs for all modules
**Decision**: Automatic creation on system activation
**Rationale**: User-friendly, no manual setup needed
**Trade-offs**: Requires activation scripts, but better UX

## Data Flow

```
Module Discovery → Metadata Extraction → Config Loading → Config Merging → Module Access
```

## Dependencies

### Internal Dependencies
- None (foundation module)

### External Dependencies
- `nixpkgs` - File system utilities

## Extension Points

How other modules can extend this module:
- Modules can provide metadata via `_module.metadata`
- Configuration helpers can be extended
- Discovery can be customized via validators

## Performance Considerations

- Module discovery at build time
- Configuration loading optimization
- Efficient config merging

## Security Considerations

- Configuration file permissions
- Module metadata validation
- Config helper security
