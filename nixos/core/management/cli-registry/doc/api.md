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
cliRegistry.registerCommandsFor "stacks" [
  { name = "stacks"; domain = "stacks"; type = "manager"; ... }
  { name = "status"; parent = "stacks"; domain = "stacks"; ... }
]
```

### `registerGuiDomain id attrs`

Optional sidebar stub (useful when the module is disabled and has no commands yet).

```nix
cliRegistry.registerGuiDomain "stacks" {
  label = "Stacks";
  description = "Docker Swarm and catalog stacks";
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

- [Architecture](./architecture.md) - System architecture
- [Usage Guide](./usage.md) - Usage examples
- [README.md](../README.md) - Module overview
- [CLI Schema](../../nixos-control-center/doc/cli-schema.md) - Naming + GUI catalog rules
