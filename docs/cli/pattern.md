# NCC CLI command pattern

## Golden rule

```
ncc <domain> <action> [subaction] [args]
```

Every command belongs to a **domain**. Always.

## Philosophy

NCC is a modular control center, not a flat bin dump:

- Hierarchical (like `git`, `docker`, `kubectl`)
- Domain-driven (one module ≈ one domain)
- Scalable (new verbs stay under their domain)

### Levels

```
ncc                     → list domains
ncc <domain>            → help / actions for that domain
ncc <domain> <action>   → do the work
```

Examples:

```bash
ncc hardware status
ncc packages list
ncc system update --local /path/to/nixos
ncc network wifi scan
ncc modules list
```

Optional UI switches (where wired):

```bash
ncc network --gui
ncc network --tui
```

## Implementation

- Register via **cli-registry** (`getModuleApi "cli-registry"`) in `commands.nix`
- Format output via **cli-formatter**
- Do **not** add top-level one-off scripts outside a domain

Schema notes may also live under `nixos/core/management/nixos-control-center/doc/`.

## Historical note

Older [`migration.md`](./migration.md) described the move from many flat commands → hierarchical domains. That migration is largely **done** in the tree; treat it as history, this file as the live contract.
