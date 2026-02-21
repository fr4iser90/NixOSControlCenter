# NixOS Control Center

A core NixOS Control Center module that provides the main control center interface and command orchestration. This module is the entry point for all NixOS Control Center operations.

## Overview

The NixOS Control Center (NCC) module is a **core module** that is always active and provides the main CLI interface for the NixOS Control Center. It orchestrates commands, provides the main `ncc` command, and integrates all modules into a unified control center.

## Quick Start

```bash
# List all available commands
ncc

# Execute a command
ncc system-update

# Get help for a command
ncc help system-update
```

## Features

- **Always Active**: Core module, no enable option needed
- **Main CLI**: Provides the `ncc` command
- **Command Orchestration**: Orchestrates commands from all modules
- **Dangerous Operations**: Warning system for dangerous commands
- **API Access**: API for other modules to interact with NCC
- **Integration**: Integrates all modules into unified interface

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [API Reference](./doc/API.md) - Complete API documentation

## Related Components

- **CLI Registry**: Command registration
- **CLI Formatter**: Command output formatting
- **All Modules**: Integrates all modules
