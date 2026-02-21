# CLI Formatter

A core NixOS Control Center module that provides a unified CLI formatting system. This module provides consistent styling, colors, layouts, and interactive components for all CLI applications in the NixOS Control Center.

## Overview

The CLI Formatter module is a **core module** that is always active and provides formatting capabilities for CLI applications. It offers a comprehensive API for creating styled output, interactive menus, progress bars, tables, and other CLI components.

## Quick Start

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

## Features

- **Always Active**: Core module, no enable option needed
- **Unified Styling**: Consistent colors and formatting across all CLI tools
- **Interactive Components**: Menus, prompts, spinners, progress bars
- **Layout System**: Flexible layout management for CLI output
- **Component System**: Customizable components with templates
- **TUI Integration**: Works with TUI engine for advanced interfaces

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [API Reference](./doc/API.md) - Complete API documentation

## Related Components

- **CLI Registry**: Command registration system
- **TUI Engine**: Advanced TUI interfaces
- **NCC**: Main control center integration
