# TUI Engine

A core NixOS Control Center module that provides a Terminal User Interface (TUI) engine for creating rich, interactive terminal interfaces. This module provides a Go-based TUI framework that modules can use to create advanced terminal interfaces.

## Overview

The TUI Engine module is a **core module** that provides a comprehensive TUI framework for NixOS Control Center modules. It's built with Go and provides components for creating interactive terminal interfaces with menus, forms, tables, and more.

## Features

- **Optional Core Module**: Can be enabled/disabled
- **Go-Based**: Built with Go for performance
- **Rich Components**: Menus, forms, tables, progress bars
- **Interactive**: Full keyboard navigation and input
- **Module Integration**: Easy integration with other modules
- **API Access**: Comprehensive API for TUI creation

## Architecture

### File Structure

```
tui-engine/
├── README.md                    # This documentation
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── api.nix                      # API definition
├── package.nix                  # Go package definition
├── flake.nix                    # Flake configuration
├── go.mod                       # Go module definition
├── go.sum                       # Go dependencies
├── gomod2nix.toml               # Go to Nix conversion
├── main.go                      # Main Go application
├── src/                         # Go source code
│   └── ...
└── scripts/                     # TUI scripts
```

### TUI Components

The TUI engine provides:
- **Menus**: Interactive menu systems
- **Forms**: Input forms with validation
- **Tables**: Data tables with sorting
- **Progress**: Progress bars and indicators
- **Navigation**: Keyboard navigation system

## Configuration

The TUI engine is an optional core module:

```nix
{
  tui-engine = {
    enable = true;  # Enable TUI engine
  };
}
```

## Usage

### Module Integration

Modules can use the TUI engine via the API:

```nix
# In module config.nix
{ config, ... }:

let
  tui = config.core.management.tui-engine.api;
in
  tui.createMenu {
    title = "Module Menu";
    items = [ ... ];
  }
```

### TUI Scripts

TUI scripts can be created using the engine:

```bash
# Run TUI interface
module-tui
```

## Technical Details

### Go Integration

The TUI engine:
- Uses Go for performance
- Integrates with Nix build system
- Provides Nix packages for Go applications
- Uses gomod2nix for dependency management

### Component System

The TUI engine provides:
- Reusable components
- Consistent styling
- Keyboard navigation
- Event handling

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Go-Based**: High-performance Go implementation
- **Component-Based**: Reusable TUI components
- **API-First**: Comprehensive API for modules
- **Extensible**: Easy to add new components

## Related Components

- **CLI Formatter**: CLI output formatting
- **CLI Registry**: Command registration
- **Module Manager**: Module management TUI
