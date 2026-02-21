# CLI Registry

A core NixOS Control Center module that provides centralized command registration and management. This module collects commands from all modules and provides a unified command interface for the NixOS Control Center.

## Overview

The CLI Registry module is a **core module** that is always active and manages all CLI commands in the NixOS Control Center. It provides a central registry where modules can register their commands, and it organizes them by categories for easy discovery and execution.

## Features

- **Always Active**: Core module, no enable option needed
- **Centralized Registry**: All commands registered in one place
- **Category Organization**: Commands organized by categories
- **Module Integration**: Modules register commands via `commands.nix`
- **Command Discovery**: Automatic command discovery and categorization
- **API Access**: API for other modules to query available commands

## Architecture

### File Structure

```
cli-registry/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── api.nix                      # API definition
├── lib/                         # Utility functions
│   ├── types.nix               # Command type definitions
│   └── ...
├── cli/                         # CLI integration
└── scripts/                     # Registry scripts
```

### Command Structure

Commands are registered with the following structure:

```nix
{
  name = "command-name";
  description = "Command description";
  category = "category-name";
  script = pkgs.writeScriptBin "command-name" "...";
  # ... other command attributes
}
```

## Configuration

As a core module, CLI registry is always active. Optional user-defined commands:

```nix
{
  cli-registry = {
    commands = [
      {
        name = "custom-command";
        description = "Custom user command";
        category = "custom";
        script = pkgs.writeScriptBin "custom-command" "...";
      };
    ];
  };
}
```

## Module Integration

### Registering Commands

Modules register commands via `commands.nix`:

```nix
# In module/commands.nix
{ config, lib, pkgs, moduleName, ... }:

{
  config.core.management.cli-registry.commandSets.${moduleName} = [
    {
      name = "module-command";
      description = "Module command description";
      category = "module-category";
      script = pkgs.writeScriptBin "module-command" "...";
    };
  ];
}
```

## API Usage

### Accessing the API

```nix
# In other modules
let
  registry = config.core.management.cli-registry.api;
in
  registry.getCommandsByCategory "category-name"
```

### Available Functions

- **Command Query**: Get commands by category, name, etc.
- **Category List**: Get all available categories
- **Command Execution**: Execute registered commands

## Technical Details

### Command Discovery

The module automatically:
- Collects commands from all modules
- Organizes them by categories
- Provides unified access interface

### Command Categories

Categories are automatically derived from registered commands:
- System management
- Module management
- Configuration
- Development
- Custom categories

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Registry Pattern**: Centralized command registration
- **Module Integration**: Easy command registration for modules
- **API-First**: Comprehensive API for command access
- **Extensible**: User-defined commands support

## Related Components

- **CLI Formatter**: Command output formatting
- **NCC**: Main control center integration
- **Module Manager**: Module discovery and management
