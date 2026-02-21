# Module Manager - API Reference

## Overview

Complete API reference for the Module Manager module.

## Accessing Module Config

### `getModuleConfig moduleName`

**Description**: Get module configuration
**Parameters**:
- `moduleName` (String): Module name
**Returns**: Module configuration attribute set
**Example**:
```nix
getModuleConfig "audio"
```

### `getModuleConfigFromPath configPath`

**Description**: Get module configuration from config path
**Parameters**:
- `configPath` (String): Config path (e.g., "core.base.audio")
**Returns**: Module configuration attribute set
**Example**:
```nix
getModuleConfigFromPath "core.base.audio"
```

## Configuration Helpers

### `createModuleConfig options`

**Description**: Create module configuration
**Parameters**:
- `options` (AttrSet): Configuration options
**Returns**: Module configuration
**Example**:
```nix
configHelpers.createModuleConfig {
  enable = true;
  option = "value";
}
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
