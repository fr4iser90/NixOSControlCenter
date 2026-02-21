# NixOS Control Center

A core NixOS Control Center module that provides the main control center interface and command orchestration. This module is the entry point for all NixOS Control Center operations.

## Overview

The NixOS Control Center (NCC) module is a **core module** that is always active and provides the main CLI interface for the NixOS Control Center. It orchestrates commands, provides the main `ncc` command, and integrates all modules into a unified control center.

## Features

- **Always Active**: Core module, no enable option needed
- **Main CLI**: Provides the `ncc` command
- **Command Orchestration**: Orchestrates commands from all modules
- **Dangerous Operations**: Warning system for dangerous commands
- **API Access**: API for other modules to interact with NCC
- **Integration**: Integrates all modules into unified interface

## Architecture

### File Structure

```
nixos-control-center/
├── README.md                    # This documentation
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── api.nix                      # API definition
├── api/                         # API components
├── components/                  # NCC components
│   └── ...
└── gui-architecture.md          # GUI architecture documentation
```

## Configuration

As a core module, NCC is always active. Optional configuration:

```nix
{
  nixos-control-center = {
    dangerousIgnore = false;  # Ignore dangerous command warnings
  };
}
```

## Usage

### Main Command

The `ncc` command is the main entry point:

```bash
# List all available commands
ncc

# Execute a command
ncc system-update

# Get help for a command
ncc help system-update
```

### Command Categories

Commands are organized by categories:
- System management
- Module management
- Configuration
- Development
- Custom categories

## Technical Details

### Command Orchestration

NCC orchestrates commands by:
- Collecting commands from CLI registry
- Organizing by categories
- Providing unified execution interface
- Handling dangerous operations

### Dangerous Operations

NCC warns about dangerous operations:
- System modifications
- Data deletion
- Configuration changes
- Can be bypassed with `dangerousIgnore = true`

### API Integration

NCC provides API for modules:
- Command registration
- Status queries
- System information
- Configuration access

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Orchestration Pattern**: Central command orchestration
- **Integration**: Integrates all modules
- **API-First**: Comprehensive API for modules
- **Extensible**: Easy to add new commands

## Related Components

- **CLI Registry**: Command registration
- **CLI Formatter**: Command output formatting
- **All Modules**: Integrates all modules
