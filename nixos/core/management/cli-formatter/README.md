# CLI Formatter

A core NixOS Control Center module that provides a unified CLI formatting system. This module provides consistent styling, colors, layouts, and interactive components for all CLI applications in the NixOS Control Center.

## Overview

The CLI Formatter module is a **core module** that is always active and provides formatting capabilities for CLI applications. It offers a comprehensive API for creating styled output, interactive menus, progress bars, tables, and other CLI components.

## Features

- **Always Active**: Core module, no enable option needed
- **Unified Styling**: Consistent colors and formatting across all CLI tools
- **Interactive Components**: Menus, prompts, spinners, progress bars
- **Layout System**: Flexible layout management for CLI output
- **Component System**: Customizable components with templates
- **TUI Integration**: Works with TUI engine for advanced interfaces

## Architecture

### File Structure

```
cli-formatter/
├── README.md                    # This documentation
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
    └── ...
```

## Configuration

As a core module, CLI formatter is always active. Optional configuration:

```nix
{
  cli-formatter = {
    config = {
      # Custom configuration options
    };
    components = {
      custom-component = {
        enable = true;
        refreshInterval = 5;
        template = "...";
      };
    };
  };
}
```

## API Usage

### Accessing the API

```nix
# In other modules
let
  formatter = config.core.management.cli-formatter.api;
in
  formatter.box "Title" "Content"
```

### Available Functions

- **Text Formatting**: Colors, styles, alignment
- **Layouts**: Boxes, sections, columns
- **Interactive**: Menus, prompts, spinners
- **Components**: Progress bars, tables, lists
- **TUI Integration**: Advanced TUI components

## Technical Details

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

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **API-First**: Comprehensive API for other modules
- **Component-Based**: Reusable formatting components
- **Extensible**: Custom components support
- **Integration**: Works with TUI engine

## Related Components

- **CLI Registry**: Command registration system
- **TUI Engine**: Advanced TUI interfaces
- **NCC**: Main control center integration
