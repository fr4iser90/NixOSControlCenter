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

### `registerCommandsFor moduleName commands`

Register CLI commands for a module. Top-level commands (no `parent`) automatically appear in the root GUI catalog.

```nix
cliRegistry.registerCommandsFor "homelab" [
  { name = "homelab"; domain = "homelab"; type = "manager"; ... }
  { name = "status"; parent = "homelab"; domain = "homelab"; ... }
]
```

### `registerGuiDomain id attrs`

Optional sidebar stub (useful when the module is disabled and has no commands yet).

```nix
cliRegistry.registerGuiDomain "homelab" {
  label = "Homelab";
  description = "Docker Swarm and stacks";
  enabled = cfg.enable or false;
}
```

### `getRegisteredCommands config`

Flattened list of all registered commands.

### `getSubcommands config parentName`

Commands with `parent = parentName`.

### `getCommandsByDomain` / `getDomains` / `getTopLevelCommands` / `getPublicCommands`

Helpers for filtering the registry.

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Usage Guide](./USAGE.md) - Usage examples
- [README.md](../README.md) - Module overview
- [CLI Schema](../../nixos-control-center/doc/CLI-SCHEMA.md) - Naming + GUI catalog rules
