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

**Manager `arguments`:** for a top-level `type = "manager"`, non-flag entries in
`arguments` (e.g. `"companion"`, `"tray"`) are expanded by the dispatcher into
`ncc <manager> <verb>` routes that call the manager script with the verb as
argv[0]. Prefer explicit `parent =` children when the verb has its own script
(packages/system). Use `arguments` when one binary handles all verbs
(`ncc ai …`, `ncc chronicle …`).

### `registerGuiDomain id attrs`

Optional sidebar stub (useful when the module is disabled and has no commands yet).

```nix
cliRegistry.registerGuiDomain "stacks" {
  label = "Stacks";
  description = "Docker Swarm and catalog stacks";
  enabled = cfg.enable or false;
}
```

### `registerGuiEnv id attrs`

Bake-time env exports for `ncc-gui` / `ncc-domain-gui` (JSON catalogs, bins).
gui-engine flattens and exports without hardwiring peer module paths.

```nix
cliRegistry.registerGuiEnv "hyprland" {
  NCC_HYPRLAND_CATALOG = "${catalogFile}";
  NCC_HYPRLAND_BIN = "${hyprlandCli}/bin/ncc-hyprland";
}
```

Domain pages must load catalogs from these env vars only — never `nix-instantiate` in the GUI hot path.

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
