# Module Manager

A core NixOS Control Center module that provides module discovery, configuration management, and automatic default configuration creation. This module is the foundation of the modular NixOS Control Center architecture.

## Overview

The Module Manager module is a **core module** that is always active and manages all modules in the NixOS Control Center. It discovers modules, manages their configurations, provides configuration helpers, and automatically creates default configurations for all discovered modules.

## Quick Start

```nix
# Module Manager is always active, no configuration needed
# It automatically discovers and manages all modules
```

## Features

- **Always Active**: Core module, no enable option needed
- **Module Discovery**: Automatic recursive module discovery
- **Configuration Management**: Centralized module configuration management
- **Default Configs**: Automatic creation of default configurations
- **Config Helpers**: Helper functions for module configuration
- **Metadata System**: Module metadata for discovery and management

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [API Reference](./doc/API.md) - Complete API documentation

## Related Components

- **System Manager**: System-level management
- **CLI Registry**: Command registration
- **All Modules**: Provides foundation for all modules
