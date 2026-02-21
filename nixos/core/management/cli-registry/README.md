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

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [API Reference](./doc/API.md) - Complete API documentation

## Related Components

- **CLI Formatter**: Command output formatting
- **NCC**: Main control center integration
- **Module Manager**: Module discovery and management
