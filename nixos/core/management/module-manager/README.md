# Module Manager

A core NixOS Control Center module that provides dynamic module management capabilities. This module automatically discovers all available NixOS modules from your current configuration and provides an interactive interface to enable/disable them.

## Overview

The Module Manager is a **core module** that dynamically scans your NixOS configuration to discover all available modules (system, management, and features). It provides the `ncc module-manager` command which offers an interactive fzf-based interface for toggling module states.

## Features

- **Dynamic Discovery**: Automatically finds all available modules from `systemConfig.system.*`, `systemConfig.management.*`, and `systemConfig.features.*`
- **Interactive Interface**: Uses `fzf` for multi-select module management
- **Real-time Status**: Shows current enable/disable status for each module
- **Automatic Config Generation**: Creates and updates module configuration files
- **System Rebuild**: Automatically triggers `nixos-rebuild switch` after changes

## Usage

### Command Line Interface

```bash
# Interactive module manager (requires sudo)
sudo ncc module-manager
```

The interface shows:
- Module name (e.g., `system.desktop`, `management.logging`, `features.system.lock`)
- Current status (`[true]` = enabled, `[false]` = disabled)
- Description of what the module does

Use **TAB** or **SPACE** to select multiple modules, then press **Enter** to toggle their states.

### Categories

- **system.* modules**: Core OS functionality (usually enabled by default)
- **management.* modules**: System management tools (usually enabled by default)
- **features.* modules**: Optional user features (usually disabled by default)

## Architecture

### File Structure

```
module-manager/
├── README.md                    # This documentation
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── commands.nix                 # Command registration
├── module-manager-config.nix    # User configuration (symlinked)
├── lib/                         # Utility functions
│   └── default.nix             # Shared library functions
└── handlers/                    # Business logic orchestration
    ├── module-manager.nix      # Main handler logic
    └── module-version-check.nix # Version checking logic
```

### Design Principles

- **Dynamic Discovery**: No hardcoded module lists - everything is read from your current `systemConfig`
- **Separation of Concerns**: Commands in `commands.nix`, business logic in `handlers/`, utilities in `lib/`
- **User Config Management**: Automatic symlink creation to `/etc/nixos/configs/module-manager-config.nix`

## Configuration

As a core module, the module manager requires no configuration and is always active. The user config file at `module-manager-config.nix` is minimal and primarily serves as a placeholder for future extensibility.

## Dependencies

- `fzf`: Interactive fuzzy finder
- `nix`: Nix package manager
- `bash`: Shell environment

## Technical Details

### Module Discovery

The module manager dynamically discovers modules by:

1. Scanning `systemConfig.system.*` for system modules
2. Scanning `systemConfig.management.*` for management modules
3. Scanning `systemConfig.features.*.*` for feature modules (nested structure)

### Configuration File Generation

When toggling modules, the manager generates appropriate configuration files:

- **System modules**: Creates `{ module-name = { enable = true; }; }`
- **Management modules**: Creates `{ module-name = { enable = true; }; }`
- **Feature modules**: Creates `{ features.category.module-name = { enable = true; }; }`

### Version Management

The module includes version tracking (`_version` in options) for future migration support.

## Examples

### Enable a Feature

```bash
sudo ncc module-manager
# Select "features.system.lock" with SPACE, press Enter
# System rebuilds automatically
```

### Check Module Status

The interface shows real-time status:
```
system.desktop                [true]     Desktop environment configuration
management.logging            [true]     System logging management
features.system.lock          [false]    System lock management feature
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure to run with `sudo`
2. **Module Not Found**: Ensure the module exists in your `systemConfig`
3. **Rebuild Failed**: Check system logs with `journalctl -u nixos-rebuild`

### Debug Mode

Enable verbose output by checking the generated configuration files in `/etc/nixos/configs/`.

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Core module**: Always active, no enable option
- **Dynamic discovery**: No hardcoded dependencies
- **Clean separation**: Commands, handlers, and utilities properly separated

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.
