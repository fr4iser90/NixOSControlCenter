# CLI Registry - API Reference

## Overview

Complete API reference for the CLI Registry module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.core.management.cli-registry.api;

# Build-time access (direct import)
api = getModuleApi "cli-registry";
```

## API Functions

### `getCommandsByCategory category`

**Description**: Get all commands in a category
**Parameters**:
- `category` (String): Category name
**Returns**: List of commands
**Example**:
```nix
api.getCommandsByCategory "system-management"
```

### `getCommandByName name`

**Description**: Get command by name
**Parameters**:
- `name` (String): Command name
**Returns**: Command or null
**Example**:
```nix
api.getCommandByName "system-update"
```

### `getCategories`

**Description**: Get all available categories
**Returns**: List of category names
**Example**:
```nix
api.getCategories
```

### `executeCommand name args`

**Description**: Execute a registered command
**Parameters**:
- `name` (String): Command name
- `args` (List): Command arguments
**Returns**: Command execution result
**Example**:
```nix
api.executeCommand "system-update" []
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
