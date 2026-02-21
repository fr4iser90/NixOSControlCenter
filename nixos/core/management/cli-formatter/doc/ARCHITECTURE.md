# CLI Formatter - Architecture

## Overview

High-level architecture description of the CLI Formatter module.

## Components

### Module Structure

```
cli-formatter/
├── README.md                    # Module overview
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── api.nix                      # API definition
├── colors.nix                   # Color definitions
├── core/                        # Core formatting functions
│   ├── default.nix
│   ├── layout.nix
│   └── text.nix
├── components/                  # Reusable components
│   ├── default.nix
│   ├── boxes.nix
│   ├── lists.nix
│   ├── progress.nix
│   └── tables.nix
├── interactive/                 # Interactive components
│   ├── default.nix
│   ├── fzf.nix
│   ├── menus.nix
│   ├── prompts.nix
│   ├── spinners.nix
│   └── tui/                     # TUI engine integration
└── status/                      # Status indicators
```

### Core Components

- **Colors**: Unified color system
- **Layout**: Flexible layout management
- **Text**: Text formatting and styling

### Interactive Components

- **FZF**: fzf-based menus
- **Prompts**: User input prompts
- **Spinners**: Loading indicators
- **TUI**: TUI engine integration

### Component System

Custom components can be defined with:
- Templates using CLI formatter API
- Refresh intervals
- Enable/disable options

## Design Decisions

### Decision 1: API-First Design

**Context**: Need to provide formatting capabilities to all modules
**Decision**: Comprehensive API accessible via `config.core.management.cli-formatter.api`
**Rationale**: Easy integration, consistent formatting, reusable components
**Alternatives**: Per-module formatting (rejected - inconsistent)

### Decision 2: Component System

**Context**: Need reusable formatting components
**Decision**: Component-based system with templates
**Rationale**: Reusable, customizable, maintainable
**Trade-offs**: Slightly more complex, but better organization

## Data Flow

```
Module Request → API → Component Selection → Formatting → Output
```

## Dependencies

### Internal Dependencies
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs.fzf` - fzf-based menus
- `nixpkgs` - Various formatting tools

## Extension Points

How other modules can extend this module:
- Custom components can be added via `components` option
- Custom templates can be defined
- API can be extended for new formatting needs

## Performance Considerations

- Formatting at runtime (minimal overhead)
- Component caching
- Efficient color/layout management

## Security Considerations

- Input validation for user prompts
- Safe template evaluation
- Component isolation
