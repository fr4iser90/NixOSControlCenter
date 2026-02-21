# Module Manager

A core NixOS Control Center module that provides module discovery, configuration management, and automatic default configuration creation. This module is the foundation of the modular NixOS Control Center architecture.

## Overview

The Module Manager module is a **core module** that is always active and manages all modules in the NixOS Control Center. It discovers modules, manages their configurations, provides configuration helpers, and automatically creates default configurations for all discovered modules.

## Features

- **Always Active**: Core module, no enable option needed
- **Module Discovery**: Automatic recursive module discovery
- **Configuration Management**: Centralized module configuration management
- **Default Configs**: Automatic creation of default configurations
- **Config Helpers**: Helper functions for module configuration
- **Metadata System**: Module metadata for discovery and management

## Architecture

### File Structure

```
module-manager/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── lib/                         # Utility functions
│   ├── module-config.nix       # Module configuration utilities
│   ├── discovery.nix            # Module discovery
│   ├── utils.nix                # General utilities
│   └── ...
├── handlers/                    # Configuration handlers
├── scripts/                     # Management scripts
├── tui/                         # TUI interface
└── validators/                  # Configuration validators
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

## Configuration

As a core module, module manager is always active. Internal configuration:

```nix
{
  module-manager = {
    enabledModulesMap = { ... };      # Map of enabled modules
    moduleConfigMap = { ... };        # Module configuration map
    configHelpers = { ... };         # Configuration helpers
  };
}
```

## API Usage

### Accessing Module Config

```nix
# In other modules
let
  moduleConfig = getModuleConfig "module-name";
in
  moduleConfig.option-name
```

### Configuration Helpers

Configuration helpers are available via `_module.args.configHelpers`:

```nix
# In module config.nix
{ configHelpers, ... }:

configHelpers.createModuleConfig {
  # Configuration options
}
```

## Technical Details

### Module Discovery Process

1. **Scan Directories**: Recursively scan module directories
2. **Read Metadata**: Extract metadata from `default.nix`
3. **Organize**: Group by category and subcategory
4. **Register**: Register in module registry

### Configuration Loading

1. **Load System Config**: Load from `/etc/nixos/configs/`
2. **Merge Template**: Merge with `template-config.nix` defaults
3. **Merge Options**: Merge with `options.nix` defaults
4. **Provide Access**: Make available via `getModuleConfig`

### Default Config Creation

The module automatically creates default configurations:
- On system activation
- For all discovered modules
- From `template-config.nix` if available
- Or minimal `{ enable = false; }` if not

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Discovery Pattern**: Automatic module discovery
- **Configuration Management**: Centralized config management
- **Helper System**: Reusable configuration helpers
- **Extensible**: Easy to add new modules

## Related Components

- **System Manager**: System-level management
- **CLI Registry**: Command registration
- **All Modules**: Provides foundation for all modules
