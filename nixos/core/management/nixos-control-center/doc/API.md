# NixOS Control Center - API Reference

## Overview

Complete API reference for the NixOS Control Center module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.core.management.nixos-control-center.api;
```

## API Functions

### `executeCommand name args`

**Description**: Execute a command via NCC
**Parameters**:
- `name` (String): Command name
- `args` (List): Command arguments
**Returns**: Command execution result
**Example**:
```nix
api.executeCommand "system-update" []
```

### `getCommandInfo name`

**Description**: Get command information
**Parameters**:
- `name` (String): Command name
**Returns**: Command information
**Example**:
```nix
api.getCommandInfo "system-update"
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
