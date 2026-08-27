# CLI Formatter

A core NixOS Control Center module that provides a unified CLI formatting system. This module provides consistent styling, colors, layouts, and interactive components for all CLI applications in the NixOS Control Center.

## Overview

The CLI Formatter module is a **core module** that is always active and provides formatting capabilities for CLI applications. It offers a comprehensive API for creating styled output, interactive menus, progress bars, tables, and other CLI components.

## Features

- **Always Active**: Core module, no enable option needed
- **Unified Styling**: Consistent colors and formatting across all CLI tools
- **Interactive Components**: Menus, prompts, spinners, progress bars
- **Layout System**: Flexible layout management for CLI output
- **Component System**: Customizable components with templates
- **TUI Integration**: Works with TUI engine for advanced interfaces

## Documentation

For detailed documentation, see:
- [Architecture](./doc/architecture.md) - System architecture and design decisions
- [Usage Guide](./doc/usage.md) - Detailed usage examples and best practices
- [API Reference](./doc/api.md) - Complete API documentation
- [Standards](./doc/standards.md) - What to offer, how update/other CLIs must look, audit
- [Copy rules](./doc/copy.md) - GUI vs CLI vs `--verbose` wording
- [cli.md](./doc/cli.md) - This module’s CLI contract
- Template for other modules: [cli.md.template](./doc/cli.md.template)

Audit: `bash tests/cli-formatter/validate-cli.sh`  
Manual vs auto: [tests/cli-formatter/MANUAL.md](../../../../tests/cli-formatter/MANUAL.md)

## Related Components

- **CLI Registry**: Command registration system
- **TUI Engine**: Advanced TUI interfaces
- **NCC**: Main control center integration
