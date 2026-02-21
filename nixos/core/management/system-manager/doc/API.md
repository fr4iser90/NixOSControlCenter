# System Manager - API Reference

## Overview

Complete API reference for the System Manager module.

## Accessing the API

```nix
# Runtime access (when config is available)
api = config.core.management.system-manager.api;
```

## API Functions

### Backup Helpers

#### `createBackup name`

**Description**: Create a backup
**Parameters**:
- `name` (String): Backup name
**Returns**: Backup path
**Example**:
```nix
api.createBackup "backup-name"
```

#### `restoreBackup path`

**Description**: Restore a backup
**Parameters**:
- `path` (String): Backup path
**Returns**: Restore result
**Example**:
```nix
api.restoreBackup "/var/backup/nixos/backup-name"
```

#### `listBackups`

**Description**: List all backups
**Returns**: List of backup paths
**Example**:
```nix
api.listBackups
```

### Config Helpers

#### `getConfigPath`

**Description**: Get system config path
**Returns**: Config path string
**Example**:
```nix
api.getConfigPath
```

### System Info

#### `getSystemInfo`

**Description**: Get system information
**Returns**: System information attribute set
**Example**:
```nix
api.getSystemInfo
```

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
