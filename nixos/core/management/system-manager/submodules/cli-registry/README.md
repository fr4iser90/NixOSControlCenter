# Command Center

The NixOS Control Center (NCC) command system - a unified CLI interface for all NixOS Control Center operations.

## Overview

The Command Center provides a centralized command-line interface (`ncc`) that aggregates commands from all NixOS Control Center modules. It offers:

- **Unified CLI**: Single `ncc` command for all operations
- **Command Discovery**: Automatic command registration and help system
- **Multiple Aliases**: `ncc`, `nixcc`, `nixctl`, `nix-center`, `nix-control`
- **Rich Help System**: Detailed help for each command
- **Modular Architecture**: Commands are registered by individual modules

## Usage

```bash
# Show available commands
ncc

# Get help for a specific command
ncc help <command>

# Run a command
ncc <command> [arguments]
```

## Available Commands

Commands are automatically registered by modules. Common commands include:

- `system-update` - Update system configuration
- `module-manager` - Manage NixOS modules
- `backup` - Backup operations
- `lock` - System locking operations

## Configuration

The Command Center is configured via `systemConfig.command-center` in your `flake.nix`:

```nix
{
  systemConfig.command-center = {
    enable = true;  # Default: true for core modules
  };
}
```

## Command Registration

Modules register commands by adding to `core.management.system-manager.submodules.cli-registry.commands`:

```nix
{
  core.management.system-manager.submodules.cli-registry.commands = [
    {
      name = "my-command";
      script = "${myScript}/bin/my-command";
      description = "Description of my command";
      category = "management";
      longHelp = ''
        Detailed help text for my-command.

        Usage: ncc my-command [options]
      '';
    }
  ];
}
```

## Architecture

### Directory Structure

```
command-center/
├── README.md                 # This file
├── default.nix              # Main module imports
├── options.nix              # Configuration options
├── config.nix               # Implementation logic
├── command-center-config.nix # User configuration
├── lib/                     # Shared utilities
│   ├── default.nix          # Library exports
│   ├── types.nix            # Command type definitions
│   └── utils.nix            # Utility functions
└── registry/                # Legacy (archived)
    └── old-default.nix      # Previous implementation
```

### Key Components

- **`default.nix`**: Module structure and conditional imports
- **`options.nix`**: Defines `systemConfig.command-center` options
- **`config.nix`**: CLI implementation, symlink management, command execution
- **`lib/`**: Shared utilities for command processing
- **`command-center-config.nix`**: User configuration file

## Development

### Adding New Commands

1. Create a script using `pkgs.writeShellScriptBin`
2. Register it in your module's `commands.nix`:
   ```nix
   { config, lib, pkgs, systemConfig, ... }:
   let
     myScript = pkgs.writeShellScriptBin "my-command" ''
       #!/usr/bin/env bash
       echo "Hello from my command!"
     '';
   in {
     core.management.system-manager.submodules.cli-registry.commands = [
       {
         name = "my-command";
         script = "${myScript}/bin/my-command";
         description = "A simple example command";
         category = "examples";
         longHelp = "Usage: ncc my-command";
       }
     ];
   }
   ```

### Command Categories

Commands are automatically categorized. Categories include:
- `system` - System management commands
- `management` - Module management
- `infrastructure` - Infrastructure operations
- `security` - Security operations

## Symlink Management

User configuration is automatically symlinked to `/etc/nixos/configs/command-center-config.nix` for easy editing.

## Versioning

This module follows semantic versioning:
- **Current Version**: 1.0
- **Breaking Changes**: Will require migration
- **Backward Compatibility**: Maintained within major versions

## Dependencies

- `core.cli-formatter` - For formatted output
- Other modules register their commands here

## Troubleshooting

### Command Not Found
- Ensure the module providing the command is enabled
- Check that `systemConfig.command-center.enable = true`

### Help Not Showing
- Verify command registration in module's `commands.nix`
- Check for syntax errors in command definitions

### Permission Issues
- Commands run with user privileges
- System commands may require `sudo`
